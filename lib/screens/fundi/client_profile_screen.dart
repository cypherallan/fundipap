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
          var raw = snap.data!.data();
          var data = (raw as Map<String, dynamic>?) ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('client_ratings')
                .where('clientId', isEqualTo: clientId)
                .snapshots(),
            builder: (_, rSnap) {
              var ratings = rSnap.data?.docs ?? [];
              double avg = 4.5;
              if (ratings.isNotEmpty) {
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
                          ' ${avg.toStringAsFixed(1)} (${ratings.length} ratings)',
                          style: GoogleFonts.inter(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Past Jobs: ${data['jobsPosted'] ?? 0}',
                    style: GoogleFonts.inter(),
                  ),
                  const Divider(height: 32),
                  Text(
                    'What fundis say',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...ratings.map((doc) {
                    var rd = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(
                          rd['comment'] ?? 'No comment',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        subtitle: Text(
                          '★ ${rd['rating']}',
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
