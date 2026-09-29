import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiDisputesScreen extends StatelessWidget {
  const FundiDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .where('fundiId', isEqualTo: uid)
          .snapshots(), // removed orderBy to avoid index
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                'Error: ${snap.error}',
                style: GoogleFonts.inter(fontSize: 11),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  'No disputes • Clean record ✓',
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          );
        }
        // sort in memory
        var docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          var ad = (a.data() as Map)['createdAt'];
          var bd = (b.data() as Map)['createdAt'];
          if (ad == null || bd == null) return 0;
          return (bd as Timestamp).compareTo(ad as Timestamp);
        });
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var d = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  d['reason'] ?? 'Dispute',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'Job ${d['jobId']?.toString().substring(0, 6) ?? ''} • ${d['status'] ?? 'open'}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                trailing: Chip(
                  label: Text(
                    d['status'] ?? 'open',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
