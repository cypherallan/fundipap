import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/transport_calculator.dart';

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

    // REAL TRANSPORT WITH MIN 100 RULE
    var transport = await TransportCalculator.calc(
      jobData: jobData,
      fundiId: bidData['fundiId'],
    );
    int transportFee = transport['fee'] as int;
    if (transportFee < 100) transportFee = 100; // YOUR RULE: min 100 if <=1km
    double km = transport['km'] as double;
    String mode = transport['mode'] as String;

    int labour = finalPrice.toInt();
    if (labour == 0) labour = (jobData['budgetMax'] ?? 1000) as int;
    int clientAppFee = (labour * 0.05).round(); // 250 client sees
    int fundiAppFee = (labour * 0.05).round(); // 250 hidden
    int adminComm = clientAppFee + fundiAppFee; // 500
    int totalLocked =
        labour + transportFee + clientAppFee; // 5000+100+250=5350 CLIENT
    int fundiPayout = labour - fundiAppFee + transportFee; // 4850 FUNDI

    await jobRef.update({
      'assignedFundi': bidData['fundiId'],
      'assignedFundiName': bidData['fundiName'],
      'assignedFundiPhone': bidData['fundiPhone'] ?? '',
      'acceptedBidId': bidRef.id,
      'agreedPrice': labour,
      'laborCost': labour,
      'transportFee': transportFee, // always >=100
      'transportDistanceKm': km,
      'transportMode': mode,
      'clientAppFee': clientAppFee,
      'fundiAppFee': fundiAppFee,
      'adminCommission': adminComm,
      'totalCost': totalLocked,
      'totalClientPays': totalLocked,
      'fundiReceives': fundiPayout,
      'fundiReceivesBreakdown': {
        'labour': labour,
        'transport': transportFee,
        'appFee': -fundiAppFee,
        'total': fundiPayout,
      },
      'escrowAmount': 0, // stays 0 until Mpesa paid
      'escrowStatus': 'pending',
      'escrowJob': labour,
      'escrowTransport': transportFee,
      'status': 'assigned',
      'acceptedBidAmount': labour,
      'updatedAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': true,
    });

    await bidRef.update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedPrice': labour,
      'transportFee': transportFee,
      'clientAppFee': clientAppFee,
      'fundiAppFee': fundiAppFee,
      'totalCost': totalLocked,
      'fundiReceives': fundiPayout,
    });

    await FirebaseFirestore.instance
        .collection('escrowTransactions')
        .doc(jobId)
        .set({
          'jobId': jobId,
          'clientId': FirebaseAuth.instance.currentUser!.uid,
          'fundiId': bidData['fundiId'],
          'amount': totalLocked, // 5350 to be locked
          'laborAmount': labour,
          'transportAmount': transportFee,
          'clientAppFee': clientAppFee,
          'fundiAppFee': fundiAppFee,
          'adminCommission': adminComm,
          'fundiPayout': fundiPayout,
          'status': 'pending_payment',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
