import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FraudReviewTab extends StatelessWidget {
  const FraudReviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fraudReports')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No pending fraud reports ✓',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(8),
          children: snap.data!.docs.map((doc) {
            var d = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  '${d['fundiName'] ?? 'Fundi'} - ${d['type'] ?? 'report'}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${d['reason'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Job: ${d['jobTitle'] ?? ''} • JobId: ${d['jobId'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () async {
                        await doc.reference.update({
                          'status': 'rejected',
                          'reviewedAt': FieldValue.serverTimestamp(),
                          'reviewedBy': FirebaseAuth.instance.currentUser!.uid,
                        });
                      },
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.redAlert,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () async {
                        await doc.reference.update({
                          'status': 'approved',
                          'reviewedAt': FieldValue.serverTimestamp(),
                          'reviewedBy': FirebaseAuth.instance.currentUser!.uid,
                        });
                      },
                      child: const Text(
                        'Approve -> 15%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
