import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/transport_calculator.dart';

mixin ConfirmFundiActionsMixin<T extends StatefulWidget> on State<T> {
  Map<String, dynamic>? get fundi;
  set fundi(Map<String, dynamic>? v);
  Map<String, dynamic>? get user;
  set user(Map<String, dynamic>? v);
  bool get loading;
  set loading(bool v);

  String get jobId;
  Map<String, dynamic> get jobData;
  String get bidId;
  Map<String, dynamic> get bidData;

  List<String> get rejectReasons => [
    'Price too high',
    'Found another fundi with better offer',
    'Poor ratings / fraud cases',
    'Not available quickly',
    'Client cancelled / changed mind',
    'Other',
  ];

  Future<void> loadFundi() async {
    var fundiId = bidData['fundiId'];
    var fDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(fundiId)
        .get();
    var uDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fundiId)
        .get();
    setState(() {
      fundi = fDoc.data();
      user = uDoc.data();
      loading = false;
    });
  }

  Future<Map<String, dynamic>> getTransportPreview() async {
    return await TransportCalculator.calc(
      jobData: jobData,
      fundiId: bidData['fundiId'],
    );
  }

  // NEW SIGNATURE - receives receipt from ConfirmFundiPage
  Future<void> confirmFundi({
    int? totalToLock,
    int? clientAppFee,
    int? fundiAppFee,
    int? fundiReceives,
    int? transportFee,
    int? labor,
  }) async {
    int finalPrice =
        labor ??
        (bidData['amount'] ??
                bidData['bidAmount'] ??
                bidData['price'] ??
                jobData['budget'] ??
                0)
            .toInt();
    if (finalPrice == 0) finalPrice = (jobData['budgetMax'] ?? 1000).toInt();

    var t = await TransportCalculator.calc(
      jobData: jobData,
      fundiId: bidData['fundiId'],
    );
    int transFee = transportFee ?? t['fee'] as int;
    double km = t['km'] as double;
    String mode = t['mode'] as String;

    // YOUR RULE: 10% split = 5% client + 5% fundi, transport NOT deducted
    int cAppFee =
        clientAppFee ?? (finalPrice * 0.05).round(); // 250 client sees
    int fAppFee =
        fundiAppFee ?? (finalPrice * 0.05).round(); // 250 hidden from client
    int adminComm = cAppFee + fAppFee; // 500 you keep
    int totalLocked =
        totalToLock ?? (finalPrice + transFee + cAppFee); // 5350 client pays
    int fundiPayout =
        fundiReceives ?? (finalPrice - fAppFee + transFee); // 4850 fundi gets

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'assigned',
      'assignedFundi': bidData['fundiId'],
      'assignedFundiName': bidData['fundiName'],
      'assignedFundiId': bidData['fundiId'],
      'agreedPrice': finalPrice,
      'laborCost': finalPrice,
      'transportFee': transFee,
      'transportDistanceKm': km,
      'transportMode': mode,
      // NEW BREAKDOWN - THIS IS WHERE YOUR PROFIT IS LOCKED
      'clientAppFee': cAppFee,
      'fundiAppFee': fAppFee,
      'adminCommission': adminComm,
      'totalCost': totalLocked, // 5350 - shown to client as total
      'totalClientPays': totalLocked,
      'fundiReceives': fundiPayout, // 4850 - shown to fundi only on completion
      'fundiReceivesBreakdown': {
        'labour': finalPrice,
        'transport': transFee,
        'appFee': -fAppFee,
        'total': fundiPayout,
      },
      'escrowAmount': 0, // stays 0 until Mpesa paid
      'escrowStatus': 'pending',
      'acceptedBidAmount': finalPrice,
      'acceptedBidId': bidId,
      'updatedAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': true,
    });

    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(bidId)
        .update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'acceptedPrice': finalPrice,
          'transportFee': transFee,
          'clientAppFee': cAppFee,
          'fundiAppFee': fAppFee,
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
          'laborAmount': finalPrice, // 5000
          'transportAmount': transFee, // 100
          'clientAppFee': cAppFee, // 250
          'fundiAppFee': fAppFee, // 250
          'adminCommission': adminComm, // 500
          'fundiPayout': fundiPayout, // 4850
          'status': 'pending_payment',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> rejectFundi() async {
    String selectedReason = rejectReasons[0];
    final otherCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Reject ${bidData['fundiName']}?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: rejectReasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => selectedReason = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: otherCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: selectedReason == 'Other'
                      ? 'Explain reason *'
                      : 'More details (optional)',
                  border: const OutlineInputBorder(),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.redAlert,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Reject',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(bidId)
        .update({
          'status': 'rejected',
          'rejectionCategory': selectedReason,
          'rejectionReason': otherCtrl.text.trim().isEmpty
              ? selectedReason
              : otherCtrl.text.trim(),
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser!.uid,
        });
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  Future<void> reportFraud() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Report ${bidData['fundiName']}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Asked for money upfront and disappeared',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.redAlert,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var fundiId = bidData['fundiId'];
    var uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('fraud_reports').add({
      'fundiId': fundiId,
      'clientId': uid,
      'jobId': jobId,
      'reason': reasonCtrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('fundis').doc(fundiId).update({
      'fraudCount': FieldValue.increment(1),
      'fraudCases': FieldValue.increment(1),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted. Admin will review.'),
        backgroundColor: FundipapColors.redAlert,
      ),
    );
  }
}
