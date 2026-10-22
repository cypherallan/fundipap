import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/fundi_badge_service.dart';
import '../../../services/fundi_penalty_service.dart';

mixin PostJobEscrowActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> payEscrowSimulated(
    BuildContext context,
    String jobId,
    double amount,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'confirmed',
        'escrowStatus': 'held',
        'escrowAmount': amount,
        'escrowHeldAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .set({
            'status': 'held',
            'escrowStatus': 'held',
            'amount': amount,
            'paidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KES ${amount.toInt()} held - Job Confirmed!'),
            backgroundColor: FundipapColors.greenSuccess,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> acceptRenegotiation(
    String jobId,
    Map<String, dynamic> renegotiation,
    double oldPrice,
  ) async {
    double newPrice =
        (renegotiation['newPrice'] ??
                renegotiation['lastCounterAmount'] ??
                oldPrice)
            .toDouble();
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'agreedPrice': newPrice,
      'totalCost': newPrice,
      'escrowAmount': newPrice,
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': newPrice,
          'by': 'fundi',
          'reason': renegotiation['reason'],
          'at': DateTime.now().toIso8601String(),
          'type': 'renegotiated',
        },
      ]),
      'renegotiation': {'requested': false, 'status': 'accepted'},
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (newPrice > oldPrice) {
      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .update({
            'amount': newPrice,
            'topUpRequired': newPrice - oldPrice,
            'status': 'topup_pending',
          });
    }
  }

  Future<void> confirmCompletionClient(String jobId) async {
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var snap = await jobRef.get();
    var j = snap.data() as Map<String, dynamic>;
    var reneg = j['renegotiation'] as Map<String, dynamic>?;

    int initialAmount =
        (j['escrowAmount'] ??
                j['lastCounterAmount'] ??
                j['laborCost'] ??
                j['agreedPrice'] ??
                j['acceptedBidAmount'] ??
                j['budgetMax'] ??
                j['budget'] ??
                0)
            .toInt();
    int extraAmount =
        (j['extraLaborAmount'] ??
                reneg?['extraLabor'] ??
                reneg?['pendingLabor'] ??
                0)
            .toInt();
    int newLaborTotal = (reneg?['newLaborTotal'] ?? 0).toInt();

    int totalRelease = newLaborTotal > 0
        ? newLaborTotal
        : initialAmount + extraAmount;
    if (totalRelease == 0) totalRelease = initialAmount;

    bool fundiDone =
        (j['fundiConfirmedComplete'] ?? false) ||
        j['status'] == 'job_completed' ||
        reneg?['currentPhase'] == 'completed_by_fundi';

    await jobRef.update({
      'clientConfirmedComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (fundiDone) {
      String fundiId = (j['assignedFundiId'] ?? j['assignedFundi'] ?? '')
          .toString();
      int commissionPct = 10;
      if (fundiId.isNotEmpty) {
        try {
          var fundiDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fundiId)
              .get();
          if (fundiDoc.exists) {
            var badge = FundiBadgeService.calculate(
              fundiDoc.data()!,
              fundiDoc.data()!,
            );
            commissionPct = badge.fundiCommissionPct;
          }
        } catch (_) {}
      }
      int platformFee = (totalRelease * commissionPct / 100).round();
      int baseFundiPayout = totalRelease - platformFee;

      // ===== NEW: CHECK FOR 50% DEDUCTION FROM REPEAT JOB DISPUTE =====
      int finalFundiPayout = baseFundiPayout;
      double deductedThisJob = 0;
      String? deductionDisputeId;
      double? deductionRemainingAfter;

      if (fundiId.isNotEmpty) {
        var result = await FundiPenaltyService.applyPendingDeductionOnPayout(
          fundiId: fundiId,
          jobId: jobId,
          currentJobAmount: baseFundiPayout.toDouble(),
        );
        finalFundiPayout = (result['fundiPayout'] as double).round();
        deductedThisJob = result['deducted'] as double;
        deductionDisputeId = result['disputeId'] as String?;
        deductionRemainingAfter = result['remaining'] as double?;
      }

      await jobRef.update({
        'status': 'completed',
        'escrowStatus': 'released',
        'extraEscrowStatus': 'released',
        'completedAt': FieldValue.serverTimestamp(),
        'totalReleasedAmount': totalRelease,
        'fundiPayoutAmount': finalFundiPayout,
        'baseFundiPayoutBeforeDeduction': baseFundiPayout,
        'deductionThisJob': deductedThisJob,
        'deductionDisputeId': deductionDisputeId,
        'deductionRemainingAfter': deductionRemainingAfter,
        'originalReleasedAmount': baseFundiPayout,
        'fundiPayoutAfterDeduction': finalFundiPayout,
        'platformFee': platformFee,
        'fundiCommissionPct': commissionPct,
        'initialEscrowReleased': initialAmount,
        'extraEscrowReleased': extraAmount,
        'fundiHasUnread': true,
      });

      if (fundiId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(fundiId)
              .update({
                'totalEarned': FieldValue.increment(finalFundiPayout),
                'balance': FieldValue.increment(finalFundiPayout),
                'completedJobs': FieldValue.increment(1),
              });
        } catch (_) {}
        // Also update fundis collection balance
        try {
          await FirebaseFirestore.instance
              .collection('fundis')
              .doc(fundiId)
              .set({
                'totalEarned': FieldValue.increment(finalFundiPayout),
                'balance': FieldValue.increment(finalFundiPayout),
              }, SetOptions(merge: true));
        } catch (_) {}
      }

      try {
        await FirebaseFirestore.instance
            .collection('escrowTransactions')
            .doc(jobId)
            .update({
              'status': 'released',
              'amount': totalRelease,
              'platformFee': platformFee,
              'fundiPayout': finalFundiPayout,
              'baseFundiPayout': baseFundiPayout,
              'deductionThisJob': deductedThisJob,
              'commissionPct': commissionPct,
              'initialAmount': initialAmount,
              'extraAmount': extraAmount,
              'releasedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    } else {
      await jobRef.update({'status': 'pending_completion'});
    }
  }

  Future<void> showClientRateFundiDialog(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Rate ${job['assignedFundiName'] ?? 'Fundi'}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      Icons.star,
                      color: i < rating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => setSt(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'Feedback'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                var fundiId = job['assignedFundi'];
                var uid = FirebaseAuth.instance.currentUser!.uid;
                var userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .collection('reviews')
                    .add({
                      'clientId': uid,
                      'clientName': userDoc.data()?['username'] ?? 'Client',
                      'rating': rating,
                      'comment': commentCtrl.text.trim(),
                      'jobId': jobId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                var fundiDoc = await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .get();
                var oldCount = (fundiDoc.data()?['ratingCount'] ?? 0) as int;
                var oldAvg = (fundiDoc.data()?['averageRating'] ?? 4.5)
                    .toDouble();
                var newAvg = ((oldAvg * oldCount) + rating) / (oldCount + 1);
                await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .update({
                      'jobsCompleted': FieldValue.increment(1),
                      'ratingCount': FieldValue.increment(1),
                      'averageRating': newAvg,
                      'rating': newAvg,
                    });
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .update({'clientRated': true});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanks! Fundi rated')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
