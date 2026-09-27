import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiCompletedTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  const FundiCompletedTab({super.key, required this.jobsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: jobsStream,
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(child: SelectableText('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data!.docs
            .where((d) => (d.data() as Map)['status'] == 'completed')
            .toList();
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No completed jobs',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var job = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPLETED • KES ${job['agreedPrice'] ?? job['budget']}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
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
