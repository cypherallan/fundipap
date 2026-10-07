import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiCancelledTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  final Stream<QuerySnapshot> bidsStream;
  const FundiCancelledTab({
    super.key,
    required this.jobsStream,
    required this.bidsStream,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fundis')
          .doc(uid)
          .collection('cancelledJobs')
          .orderBy('cancelledAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data == null || snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No cancelled jobs',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            var data = snap.data!.docs[i].data() as Map<String, dynamic>;
            bool byClient = (data['cancelledBy'] ?? '').toString() == 'client';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CANCELLED',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        data['type'] == 'withdrawn'
                            ? 'By You'
                            : (byClient ? 'By Client' : 'By You'),
                        style: GoogleFonts.inter(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['title'] ?? 'Job',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You cancelled this job',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Reason: ${data['cancelReason'] ?? 'Withdrawn'}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
