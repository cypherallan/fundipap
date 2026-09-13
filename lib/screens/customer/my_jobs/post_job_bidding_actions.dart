import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

mixin PostJobBiddingActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> handleCounterBid(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
    double currentPrice,
  ) async {
    try {
      String? bidId = job['acceptedBidId']?.toString();
      DocumentReference bidRef;
      if (bidId != null && bidId.isNotEmpty) {
        bidRef = FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('bids')
            .doc(bidId);
      } else {
        final assignedFundi = job['assignedFundi'];
        if (assignedFundi == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No assigned fundi')));
          return;
        }
        final q = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('bids')
            .where('fundiId', isEqualTo: assignedFundi)
            .limit(1)
            .get();
        if (q.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bid not found for counter')),
          );
          return;
        }
        bidRef = q.docs.first.reference;
      }
      await counterBid(context, bidRef, jobId, currentPrice);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Counter error: $e')));
    }
  }

  Future<void> counterBid(
    BuildContext context,
    DocumentReference bidRef,
    String jobId,
    double currentPrice,
  ) async {
    final ctrl = TextEditingController(text: currentPrice.toString());
    final msgCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Counter Offer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Your counter KES'),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / breakdown',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double newPrice = double.tryParse(ctrl.text) ?? currentPrice;
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    await bidRef.collection('counterOffers').add({
      'price': newPrice,
      'by': uid,
      'byName': userDoc.data()?['username'] ?? 'Client',
      'message': msgCtrl.text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    await bidRef.update({
      'status': 'countered',
      'lastCounterPrice': newPrice,
      'lastCounterBy': uid,
      'lastCounterAt': FieldValue.serverTimestamp(),
    });
    var jobSnap = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    var hasReneg = (jobSnap.data()?['renegotiation']?['requested'] == true);
    if (hasReneg) {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'negotiating',
        'renegotiation.status': 'countered_by_client',
        'renegotiation.newPrice': newPrice,
        'renegotiation.reason': msgCtrl.text.trim(),
        'renegotiation.lastCounterBy': uid,
        'renegotiation.lastCounterAt': FieldValue.serverTimestamp(),
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_client',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'negotiating',
        'renegotiation': {'requested': false},
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_client',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> acceptBid(
    BuildContext context,
    DocumentReference bidRef,
    String jobId,
    Map<String, dynamic> bidData,
  ) async {
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var jobSnap = await jobRef.get();
    var jobData = jobSnap.data() ?? {};
    double finalPrice =
        (bidData['lastCounterPrice'] ??
                bidData['price'] ??
                jobData['budget'] ??
                0)
            .toDouble();
    await jobRef.update({
      'assignedFundi': bidData['fundiId'],
      'assignedFundiName': bidData['fundiName'],
      'assignedFundiPhone': bidData['fundiPhone'] ?? '',
      'acceptedBidId': bidRef.id,
      'agreedPrice': finalPrice,
      'laborCost': finalPrice,
      'totalCost': finalPrice,
      'status': 'assigned',
      'escrowStatus': 'pending',
      'escrowAmount': finalPrice,
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': finalPrice,
          'by': FirebaseAuth.instance.currentUser!.uid,
          'at': DateTime.now().toIso8601String(),
          'type': 'accepted',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await bidRef.update({'status': 'accepted'});
    var otherBids = await jobRef
        .collection('bids')
        .where('status', whereIn: ['pending', 'countered', 'bidding'])
        .get();
    for (var b in otherBids.docs) {
      if (b.id != bidRef.id) {
        await b.reference.update({
          'status': 'rejected',
          'rejectionCategory': 'Another offer accepted',
        });
      }
    }
    await FirebaseFirestore.instance
        .collection('escrowTransactions')
        .doc(jobId)
        .set({
          'jobId': jobId,
          'clientId': FirebaseAuth.instance.currentUser!.uid,
          'fundiId': bidData['fundiId'],
          'amount': finalPrice,
          'status': 'pending_payment',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
