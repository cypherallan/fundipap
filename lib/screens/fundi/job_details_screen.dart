import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'fundi_bid_dialog.dart';
import 'client_profile_screen.dart';

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final double? distanceKm;
  final Map<String, dynamic>? me;
  final int completedJobs;
  final bool hasBid; // <-- ADDED

  const JobDetailsScreen({
    super.key,
    required this.job,
    this.distanceKm,
    this.me,
    this.completedJobs = 0,
    this.hasBid = false, // <-- default false
  });

  @override
  Widget build(BuildContext context) {
    final photos = (job['photos'] ?? job['images'] ?? []) as List;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final jobId = job['id'] ?? job['jobId'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Job Details',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewPadding.bottom + 12,
          ),
          color: Colors.white,
          // DOUBLE CHECK FROM FIRESTORE TOO (in case opened directly)
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .collection('bids')
                .doc(uid)
                .snapshots(),
            builder: (ctx, bidSnap) {
              bool alreadyBid =
                  hasBid || (bidSnap.hasData && bidSnap.data!.exists);
              if (alreadyBid) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FundipapColors.greenSuccess.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FundipapColors.greenSuccess.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: FundipapColors.greenSuccess,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have placed a bid on this job. Wait for client feedback',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: FundipapColors.greenSuccess,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => showFundiBidDialog(
                  context: context,
                  job: job,
                  me: me,
                  completedJobs: completedJobs,
                ),
                child: Text(
                  'PLACE BID • KES ${job['budget'] ?? job['offeredPrice'] ?? 1500} OFFERED',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(job['customerId'] ?? job['clientId'])
                  .get(),
              builder: (_, snap) {
                var client = snap.data?.data() as Map<String, dynamic>?;
                var name =
                    client?['username'] ??
                    client?['name'] ??
                    job['customerUsername'] ??
                    job['customerName'] ??
                    'Client';
                var rating = (client?['clientRating'] ?? 4.5).toDouble();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: FundipapColors.blackGray,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                Text(
                                  ' $rating • ${client?['jobsPosted'] ?? 0} jobs',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                            Text(
                              job['location'] ?? 'Kisumu',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientProfileScreen(
                                clientId: job['customerId'] ?? job['clientId'],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'View Profile',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              job['title'] ?? 'Job',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Chip(
                  label: Text(
                    (job['category'] ?? 'General').toString().toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceKm != null)
                  Chip(
                    label: Text(
                      '${distanceKm!.toStringAsFixed(1)} km away',
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                    backgroundColor: FundipapColors.primaryYellow,
                  ),
                const Spacer(),
                Text(
                  'KES ${job['budget'] ?? job['offeredPrice'] ?? ''} OFFERED',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              job['description'] ?? 'No description',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            if (photos.isNotEmpty) ...[
              Text(
                'Photos from client',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(photos[i]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fundis have rated this client. Check profile for stubborn reports.',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
