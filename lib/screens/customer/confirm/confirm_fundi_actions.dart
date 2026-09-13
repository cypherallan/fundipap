import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

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

  Future<void> confirmFundi() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'assigned',
      'assignedFundi': bidData['fundiId'],
      'assignedFundiName': bidData['fundiName'],
      'agreedPrice': bidData['price'],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(bidId)
        .update({'status': 'accepted'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bidData['fundiName']} confirmed!'),
        backgroundColor: FundipapColors.greenSuccess,
      ),
    );
    Navigator.pop(context);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${bidData['fundiName']} rejected'),
        backgroundColor: FundipapColors.redAlert,
      ),
    );
    Navigator.pop(context);
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
    var reason = reasonCtrl.text.trim();
    await FirebaseFirestore.instance.collection('fraud_reports').add({
      'fundiId': fundiId,
      'clientId': uid,
      'jobId': jobId,
      'reason': reason,
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
