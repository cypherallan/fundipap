import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../app.dart';

void goBack(BuildContext context, int tab) {
  final email = FirebaseAuth.instance.currentUser?.email ?? '';
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => HomeNavigator(
        role: 'fundi',
        email: email,
        initialIndex: 2,
        initialJobStatusTab: tab,
      ),
    ),
    (r) => false,
  );
}

Future<void> counterAsFundi(
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
            decoration: const InputDecoration(labelText: 'New price KES'),
          ),
          TextField(
            controller: msgCtrl,
            decoration: const InputDecoration(labelText: 'Reason / breakdown'),
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
    'byName': userDoc.data()?['username'] ?? 'Fundi',
    'message': msgCtrl.text.trim(),
    'at': FieldValue.serverTimestamp(),
  });
  await bidRef.update({
    'status': 'countered',
    'lastCounterPrice': newPrice,
    'lastCounterAmount': newPrice,
    'lastCounterBy': uid,
    'counterBy': uid,
    'lastCounterAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
    'status': 'negotiating',
    'priceHistory': FieldValue.arrayUnion([
      {
        'price': newPrice,
        'by': uid,
        'type': 'counter_fundi',
        'at': DateTime.now().toIso8601String(),
      },
    ]),
    'updatedAt': FieldValue.serverTimestamp(),
    'customerHasUnread': true,
  });
}
