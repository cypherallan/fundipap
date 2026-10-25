import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    if (!snap.exists) return;
    var j = snap.data() as Map<String, dynamic>;
    var reneg = j['renegotiation'] as Map<String, dynamic>?;

    bool fundiDone =
        (j['fundiConfirmedComplete'] ?? false) ||
        j['status'] == 'job_completed' ||
        reneg?['currentPhase'] == 'completed_by_fundi';

    if (!fundiDone) {
      await jobRef.update({
        'clientConfirmedComplete': true,
        'status': 'pending_completion',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(
            'confirmCompletionSecure',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          );
      await callable.call({'jobId': jobId});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') return;
      rethrow;
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
