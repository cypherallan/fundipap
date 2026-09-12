import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';

Future<void> showFundiBidDialog({
  required BuildContext context,
  required Map<String, dynamic> job,
  required Map<String, dynamic>? me,
  required int completedJobs,
}) async {
  final priceCtrl = TextEditingController();
  var uid = FirebaseAuth.instance.currentUser!.uid;
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        'Bid for ${job['title']}',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      content: TextField(
        controller: priceCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Your price KES',
          hintText: 'e.g. 1500',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.primaryYellow,
          ),
          onPressed: () async {
            if (priceCtrl.text.isEmpty) return;
            await FirebaseFirestore.instance
                .collection('jobs')
                .doc(job['id'])
                .collection('bids')
                .doc(uid)
                .set({
                  'fundiId': uid,
                  'fundiName': me?['name'] ?? 'Fundi',
                  'photoUrl': me?['photoUrl'],
                  'rating': me?['rating'] ?? 4.5,
                  'jobsDone': completedJobs,
                  'price': int.tryParse(priceCtrl.text) ?? 0,
                  'customerId':
                      job['customerId'] ?? job['clientId'], // <-- ADDED
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'pending', // <-- ADDED for filtering
                });
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bid sent ✓ client will see it')),
            );
          },
          child: Text(
            'Send Bid',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
