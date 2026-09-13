import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

mixin PostJobEscrowActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> payEscrowSimulated(
    BuildContext context,
    String jobId,
    double amount,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'escrowStatus': 'held',
        'escrowAmount': amount,
        'escrowHeldAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KES ${amount.toInt()} held in escrow (simulated)'),
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
    double newPrice = (renegotiation['newPrice'] ?? oldPrice).toDouble();
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
    bool fundiDone = (snap.data()?['fundiConfirmedComplete'] ?? false);
    await jobRef.update({
      'clientConfirmedComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (fundiDone) {
      await jobRef.update({
        'status': 'completed',
        'escrowStatus': 'released',
        'completedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .update({
            'status': 'released',
            'releasedAt': FieldValue.serverTimestamp(),
          });
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
