import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../rating/rate_fundi_screen.dart';

class ClientCompletedTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Future<void> Function(BuildContext, String, Map<String, dynamic>)
  onRate;
  const ClientCompletedTab({
    super.key,
    required this.docs,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No completed jobs yet',
          style: GoogleFonts.inter(color: Colors.black45),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var d = docs[i].data() as Map<String, dynamic>;
        var jobId = docs[i].id;
        bool alreadyRated = d['clientRated'] == true;
        int rating = (d['clientRating'] ?? 0).toInt();
        String review = (d['clientReview'] ?? '').toString();
        String fundiName = (d['assignedFundiName'] ?? d['fundiName'] ?? 'Fundi')
            .toString();
        String fundiId = (d['fundiId'] ?? d['assignedFundiId'] ?? '')
            .toString();
        int paid =
            (d['totalReleasedAmount'] ??
                    d['fundiPayoutAmount'] ??
                    d['agreedPrice'] ??
                    d['budget'] ??
                    0)
                .toInt();

        return Card(
          color: alreadyRated ? Colors.green.shade50 : Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: alreadyRated ? Colors.green : Colors.orange.shade700,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      alreadyRated
                          ? Icons.check_circle
                          : Icons.star_rate_rounded,
                      color: alreadyRated
                          ? Colors.green
                          : Colors.orange.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alreadyRated
                            ? 'Job completed by $fundiName - Rated'
                            : 'Job completed by $fundiName - Rate now (Mandatory)',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: alreadyRated
                              ? Colors.green.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  d['title'] ?? '',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'KES $paid released • $fundiName',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                if (alreadyRated) ...[
                  Row(
                    children: List.generate(
                      5,
                      (s) => Icon(
                        Icons.star,
                        size: 16,
                        color: s < rating ? Colors.amber : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (review.isNotEmpty)
                    Text(
                      '"$review"',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Notifications for this fundi cleared',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'You released KES $paid to $fundiName. You must rate to clear this job. This is mandatory.',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        // Use your new mandatory screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RateFundiScreen(
                              jobId: jobId,
                              fundiId: fundiId,
                              fundiName: fundiName,
                              trade: (d['trade'] ?? '').toString(),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'RATE $fundiName NOW - MANDATORY',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
