import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../chats/chat_screen.dart';

class CustomerFundiProfileScreen extends StatelessWidget {
  final Map<String, dynamic> fundi;
  final double distanceKm;
  const CustomerFundiProfileScreen({
    super.key,
    required this.fundi,
    this.distanceKm = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Fundi Profile',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(fundi: fundi)),
            ),
            icon: const Icon(Icons.message),
            label: Text(
              'Message ${fundi['name'] ?? 'Fundi'}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: FundipapColors.primaryYellow,
                    child: Text(
                      (fundi['name'] ?? 'F')[0],
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              fundi['name'] ?? 'Fundi',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            if (fundi['verified'] == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.verified,
                                  color: FundipapColors.greenSuccess,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${fundi['skill'] ?? 'General Fundi'} • ${fundi['category'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            Text(
                              ' ${fundi['rating'] ?? 4.5} ',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '(${fundi['reviews'] ?? fundi['jobs'] ?? 0} jobs)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.place,
                              size: 14,
                              color: Colors.black45,
                            ),
                            Text(
                              ' ${distanceKm.toStringAsFixed(1)} km',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats
            Row(
              children: [
                _statCard(
                  'Jobs',
                  '${fundi['jobs'] ?? fundi['completedJobs'] ?? 0}',
                ),
                const SizedBox(width: 10),
                _statCard('Price', 'KES ${fundi['price'] ?? '-'}'),
                const SizedBox(width: 10),
                _statCard('Success', '${fundi['successRate'] ?? '98'}%'),
              ],
            ),
            const SizedBox(height: 16),
            // About
            Text(
              'About',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                fundi['bio'] ??
                    fundi['description'] ??
                    'Experienced ${fundi['skill'] ?? 'fundi'} in Kisumu. Verified, reliable, and rated highly by clients.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Skills',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var s
                    in (fundi['skills'] as List? ??
                        [fundi['skill'] ?? 'General']))
                  Chip(
                    label: Text(
                      s.toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: FundipapColors.primaryYellow.withValues(
                      alpha: 0.3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Reviews stream
            Text(
              'Reviews',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fundis')
                  .doc(fundi['id'])
                  .collection('reviews')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                if (snap.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No reviews yet',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((d) {
                    var r = d.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                r['customerName'] ?? 'Client',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: List.generate(
                                  (r['rating'] ?? 5) as int,
                                  (_) => const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['comment'] ?? '',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
