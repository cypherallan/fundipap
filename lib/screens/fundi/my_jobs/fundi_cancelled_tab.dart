import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiCancelledTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  const FundiCancelledTab({super.key, required this.jobsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: jobsStream,
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        var docs = snap.data!.docs
            .where(
              (d) => [
                'cancelled',
                'cancelled_after_arrival',
              ].contains((d.data() as Map)['status']),
            )
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No cancelled jobs',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var job = docs[i].data() as Map<String, dynamic>;
            bool byClient = (job['cancelledBy'] ?? '') == 'client';
            bool afterArrival = job['status'] == 'cancelled_after_arrival';
            int transport =
                (job['transportFee'] ?? job['fundiPayout'] ?? 0) as int;

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
                        byClient ? 'By Client' : 'By You',
                        style: GoogleFonts.inter(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${job['cancelReason'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        // FIXED: no else-if with comma
                        if (byClient && afterArrival)
                          Text(
                            'You get transport: KES $transport',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        if (byClient && !afterArrival)
                          Text(
                            'Cancelled before travel - no payout',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        if (!byClient)
                          Text(
                            'You cancelled - counts to your rate',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                      ],
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
