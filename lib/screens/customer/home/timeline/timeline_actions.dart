import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'timeline_utils.dart';
import '../../rating/rate_fundi_screen.dart';
import '../../../fundi/services/fundi_penalty_service.dart';

class TimelineActions {
  static Future<void> payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'confirmed',
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> payExtraEscrow(
    String jobId,
    int extraLabor,
    int extraToLock,
    String whoBuys,
  ) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final snap = await jobRef.get();
    final job = snap.data() as Map<String, dynamic>;

    int oldLabor = toInt(
      job['lastCounterAmount'] ?? job['laborCost'] ?? job['agreedPrice'] ?? 0,
    );
    int transport = toInt(job['transportFee'] ?? 164);
    String fundiId = (job['assignedFundiId'] ?? job['fundiId'] ?? '')
        .toString();

    int fundiPct = 10;
    if (fundiId.isNotEmpty) {
      var fundiSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fundiId)
          .get();
      var fd = fundiSnap.data() ?? {};
      if (fd['badgeLevel'] == 'gold' || fd['isTrialGold'] == true) {
        fundiPct = 5;
      } else if (fd['badgeLevel'] == 'silver')
        fundiPct = 8;
      else if (fd['badgeLevel'] == 'bronze')
        fundiPct = 10;
      else
        fundiPct = 15;
    }

    int newLabor = oldLabor + extraLabor;
    int newClientFee = (newLabor * 0.05).round();
    int newFundiFee = (newLabor * fundiPct / 100).round();
    int newTotal = newLabor + transport + newClientFee;
    int newFundiReceives = newLabor - newFundiFee + transport;

    await jobRef.update({
      'laborCost': newLabor,
      'agreedPrice': newLabor,
      'clientAppFee': newClientFee,
      'fundiAppFee': newFundiFee,
      'totalClientPays': newTotal,
      'totalCost': newTotal,
      'escrowAmount': newTotal,
      'fundiReceives': newFundiReceives,
      'extraToLock': 0,
      'extraLaborAmount': 0,
      'extraEscrowStatus': 'paid',
      'escrowStatus': 'held',
      'clientNeedsToTopup': false,
      'status': whoBuys == 'client'
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'renegotiation.status': 'extra_locked',
      'renegotiation.extraLocked': true,
      'renegotiation.currentPhase': whoBuys == 'client'
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> confirmPartsBought(String jobId) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final snap = await jobRef.get();
    String fundiId = '';
    String clientName = 'Client';
    if (snap.exists) {
      var data = snap.data() as Map<String, dynamic>;
      fundiId = (data['assignedFundiId'] ?? data['fundiId'] ?? '').toString();
      clientName = (data['customerName'] ?? data['clientName'] ?? 'Client')
          .toString();
    }

    await jobRef.update({
      'status': 'client_claims_parts_bought',
      'renegotiation.currentPhase': 'client_claims_parts_bought',
      'renegotiation.clientPartsBought': true,
      'renegotiation.clientPartsBoughtAt': FieldValue.serverTimestamp(),
      'renegotiation.status': 'client_claims_parts_bought',
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'customerUnreadType': 'parts_bought',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (fundiId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': fundiId,
          'toRole': 'fundi',
          'type': 'parts_bought',
          'jobId': jobId,
          'title': 'Client bought parts',
          'body':
              '$clientName marked materials as bought - confirm to start work',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('fundis')
            .doc(fundiId)
            .collection('notifications')
            .add({
              'jobId': jobId,
              'type': 'parts_bought',
              'title': 'Client bought parts',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
  }

  static Future<void> proceedWithFundi(
    String jobId,
    String fundiId,
    int expectedTotal,
  ) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final jobSnap = await jobRef.get();
    if (!jobSnap.exists) throw 'Job not found';
    final job = jobSnap.data() as Map<String, dynamic>;

    final q = await jobRef
        .collection('bids')
        .where('fundiId', isEqualTo: fundiId)
        .where(
          'status',
          whereIn: [
            'counter_accepted_by_fundi',
            'countered',
            'counter_accepted',
          ],
        )
        .limit(1)
        .get();
    final bidSnap = q.docs.isNotEmpty
        ? q.docs.first
        : (await jobRef
                  .collection('bids')
                  .where('status', isEqualTo: 'counter_accepted_by_fundi')
                  .limit(1)
                  .get())
              .docs
              .first;
    final bidId = bidSnap.id;
    final bidData = bidSnap.data();

    int labour = toInt(
      job['lastCounterAmount'] ??
          bidData['lastCounterAmount'] ??
          bidData['lastCounterPrice'] ??
          bidData['agreedPrice'] ??
          bidData['price'] ??
          job['laborCost'] ??
          job['agreedPrice'] ??
          0,
    );
    int transport = toInt(
      job['transportFee'] ?? bidData['transportFee'] ?? 100,
    );
    int clientFee = (labour * 0.05).round();
    int fundiFee = (labour * 0.05).round();
    int totalClient = labour + transport + clientFee;
    int fundiRec = labour - fundiFee + transport;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(jobRef, {
      'status': 'assigned',
      'assignedFundiId': fundiId,
      'assignedFundi': fundiId,
      'agreedPrice': labour,
      'laborCost': labour,
      'acceptedBidAmount': labour,
      'transportFee': transport,
      'clientAppFee': clientFee,
      'fundiAppFee': fundiFee,
      'totalClientPays': totalClient,
      'fundiReceives': fundiRec,
      'fundiPayoutAmount': fundiRec,
      'proceededAt': FieldValue.serverTimestamp(),
      'proceededWithFundiId': fundiId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(jobRef.collection('bids').doc(bidId), {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final others = await jobRef
        .collection('bids')
        .where(
          'status',
          whereIn: [
            'counter_accepted_by_fundi',
            'countered',
            'pending',
            'bidding',
          ],
        )
        .get();
    for (var d in others.docs) {
      if (d.id != bidId) {
        batch.update(d.reference, {
          'status': 'rejected',
          'rejectedReason': 'client_proceeded_with_other_fundi',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  static Future<void> confirmCompletion({
    required String jobId,
    required String fundiId,
    required String fundiName,
    required String trade,
    required BuildContext context,
    required Function(bool) onReleasing,
  }) async {
    onReleasing(true);
    try {
      var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
      var snap = await jobRef.get();
      if (!snap.exists) throw 'Job not found';
      var j = snap.data() as Map<String, dynamic>;
      var reneg = j['renegotiation'] as Map<String, dynamic>?;

      var fundiSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fundiId)
          .get();
      var fundiData = fundiSnap.data() ?? {};
      int fundiPct = 5;
      if (fundiData['isTrialGold'] == true) {
        fundiPct = 5;
      } else if (fundiData['badgeLevel'] == 'gold')
        fundiPct = 5;
      else if (fundiData['badgeLevel'] == 'silver')
        fundiPct = 8;
      else if (fundiData['badgeLevel'] == 'bronze')
        fundiPct = 10;
      else if (fundiData['badgeLevel'] == 'none')
        fundiPct = 15;

      int labour = toInt(
        j['lastCounterAmount'] ??
            j['laborCost'] ??
            j['agreedPrice'] ??
            j['acceptedBidAmount'] ??
            0,
      );
      int transport = toInt(j['transportFee'] ?? 100);
      int clientAppFee = (labour * 0.05).round();
      int fundiAppFee = (labour * fundiPct / 100).round();
      int totalClient = labour + transport + clientAppFee;
      int baseFundiReceives = labour - fundiAppFee + transport;

      if (reneg != null && reneg['newLaborTotal'] != null) {
        int newLabour = toInt(reneg['newLaborTotal']);
        int newTotalClient = toInt(
          reneg['newTotalClientPays'] ??
              newLabour + transport + (newLabour * 0.05).round(),
        );
        int newFundiReceives =
            newLabour - (newLabour * fundiPct / 100).round() + transport;
        totalClient = newTotalClient > 0 ? newTotalClient : totalClient;
        baseFundiReceives = newFundiReceives > 0
            ? newFundiReceives
            : baseFundiReceives;
      }

      int alreadyLocked = toInt(j['escrowAmount'] ?? totalClient);

      int finalFundiPayout = baseFundiReceives;
      double deductedThisJob = 0;
      String? deductionDisputeId;
      double? deductionRemainingAfter;

      if (fundiId.isNotEmpty) {
        var result = await FundiPenaltyService.applyPendingDeductionOnPayout(
          fundiId: fundiId,
          jobId: jobId,
          currentJobAmount: baseFundiReceives.toDouble(),
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
        'clientConfirmedComplete': true,
        'clientConfirmedCompletion': true,
        'escrowReleased': true,
        'completedAt': FieldValue.serverTimestamp(),
        'totalReleasedAmount': totalClient,
        'totalClientPays': totalClient,
        'fundiPayoutAmount': finalFundiPayout,
        'baseFundiPayoutBeforeDeduction': baseFundiReceives,
        'fundiReceives': finalFundiPayout,
        'deductionThisJob': deductedThisJob,
        'deductionDisputeId': deductionDisputeId,
        'deductionRemainingAfter': deductionRemainingAfter,
        'originalReleasedAmount': baseFundiReceives,
        'fundiPayoutAfterDeduction': finalFundiPayout,
        'totalClientPaid': totalClient,
        'initialEscrowReleased': alreadyLocked,
        'fundiHasUnread': true,
        'customerHasUnread': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(fundiId)
            .update({
              'totalEarned': FieldValue.increment(finalFundiPayout),
              'totalEarnings': FieldValue.increment(finalFundiPayout),
              'completedJobs': FieldValue.increment(1),
              'jobsDone': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        await FirebaseFirestore.instance.collection('fundis').doc(fundiId).set({
          'totalEarned': FieldValue.increment(finalFundiPayout),
          'completedJobs': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } catch (_) {}

      try {
        await FirebaseFirestore.instance
            .collection('fundis')
            .doc(fundiId)
            .collection('notifications')
            .add({
              'jobId': jobId,
              'type': deductedThisJob > 0
                  ? 'escrow_released_with_deduction'
                  : 'escrow_released',
              'title': deductedThisJob > 0
                  ? 'KES $finalFundiPayout released (KES ${deductedThisJob.toInt()} deducted for dispute ${deductionDisputeId?.substring(0, 6) ?? ''})'
                  : 'Client released KES $finalFundiPayout - Tap to view receipt',
              'amount': finalFundiPayout,
              'deduction': deductedThisJob,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}

      try {
        await FirebaseFirestore.instance
            .collection('escrowTransactions')
            .doc(jobId)
            .set({
              'jobId': jobId,
              'fundiId': fundiId,
              'status': 'released',
              'amount': totalClient,
              'fundiPayout': finalFundiPayout,
              'baseFundiPayout': baseFundiReceives,
              'deductionThisJob': deductedThisJob,
              'initialAmount': alreadyLocked,
              'releasedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {}

      if (!context.mounted) return;
      int displayRelease = finalFundiPayout;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deductedThisJob > 0
                ? 'Released KES $finalFundiPayout to Fundi (KES ${deductedThisJob.toInt()} deducted for prior dispute)'
                : 'Released KES $displayRelease to Fundi',
          ),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RateFundiScreen(
            jobId: jobId,
            fundiId: fundiId,
            fundiName: fundiName,
            trade: trade,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to release: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      onReleasing(false);
    }
  }
}
