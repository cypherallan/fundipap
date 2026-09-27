import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfirmFundiReviews extends StatelessWidget {
  final String fundiId;
  const ConfirmFundiReviews({super.key, required this.fundiId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Feedbacks',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fundis')
              .doc(fundiId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return Text(
                'No feedbacks yet',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
              );
            }
            return Column(
              children: snap.data!.docs.map((d) {
                var r = d.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text((r['clientName'] ?? 'C')[0]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r['clientName'] ?? 'Client',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${r['rating'] ?? 5}★',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                            Text(
                              r['comment'] ?? '',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
