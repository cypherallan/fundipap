import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientProfileScreen extends StatelessWidget {
  final String clientId;
  const ClientProfileScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Client Profile',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(clientId)
            .get(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var data = (snap.data!.data() as Map<String, dynamic>?) ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(clientId)
                .collection('clientReviews')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, rSnap) {
              var ratings = rSnap.data?.docs ?? [];
              double avg =
                  (data['clientRatingAvg'] ?? data['clientRating'] ?? 0)
                      .toDouble();
              int count = (data['clientRatingCount'] ?? ratings.length) as int;
              if (avg == 0 && ratings.isNotEmpty) {
                avg =
                    ratings
                        .map(
                          (d) =>
                              ((d.data() as Map)['rating'] as num).toDouble(),
                        )
                        .reduce((a, b) => a + b) /
                    ratings.length;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      child: Text(
                        ((data['name'] ?? 'C') as String)[0].toUpperCase(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      data['name'] ?? 'Client',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(
                          ' ${avg.toStringAsFixed(1)} ($count ${count == 1 ? 'rating' : 'ratings'})',
                          style: GoogleFonts.inter(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // REAL past jobs count from jobs collection
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('jobs')
                        .where('customerId', isEqualTo: clientId)
                        .where('status', isEqualTo: 'completed')
                        .snapshots(),
                    builder: (_, jobSnap) {
                      int done = jobSnap.data?.docs.length ?? 0;
                      return Text(
                        'Past Jobs: $done',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  Text(
                    'What fundis say',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (ratings.isEmpty)
                    Text(
                      'No reviews yet',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ...ratings.map((doc) {
                    var rd = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(
                          rd['comment'] ?? 'No comment',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        subtitle: Text(
                          '★ ${rd['rating']} • ${rd['fundiName'] ?? 'Fundi'}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
