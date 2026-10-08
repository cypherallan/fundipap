import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../models/customer_home_models.dart';
import '../../../post_new_job_screen.dart';
import 'pending_header.dart';
import 'pending_job_tile.dart';

class CustomerPendingSection extends StatelessWidget {
  final String uid;
  final Position? userPos;

  const CustomerPendingSection({
    super.key,
    required this.uid,
    required this.userPos,
  });

  @override
  Widget build(BuildContext context) {
    const pendingStatuses = [
      'open',
      'pending',
      'bidding',
      'countered',
      'countered_by_client',
      'countered_by_fundi',
      'client_counter',
      'counter_pending',
      'counter_accepted',
      'counter_accepted_by_fundi',
      'assigned',
      'confirmed',
    ];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: pendingStatuses)
          .snapshots(),
      builder: (context, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('clientId', isEqualTo: uid)
              .where('status', whereIn: pendingStatuses)
              .snapshots(),
          builder: (context, snap2) {
            if (snap1.connectionState == ConnectionState.waiting ||
                snap2.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(20),
                child: const LinearProgressIndicator(),
              );
            }
            final Map<String, QueryDocumentSnapshot> map = {};
            if (snap1.hasData) for (var d in snap1.data!.docs) map[d.id] = d;
            if (snap2.hasData) for (var d in snap2.data!.docs) map[d.id] = d;
            var jobs = map.values.toList();

            jobs = jobs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              return data['cancelled'] != true && data['autoCancelled'] != true;
            }).toList();

            jobs.sort((a, b) {
              var ad = a.data() as Map<String, dynamic>;
              var bd = b.data() as Map<String, dynamic>;
              bool aAcc =
                  (ad['counterAcceptedBy'] != null &&
                      (ad['counterAcceptedBy'] as List).isNotEmpty) ||
                  (ad['status'] ?? '').toString().contains('counter_accepted');
              bool bAcc =
                  (bd['counterAcceptedBy'] != null &&
                      (bd['counterAcceptedBy'] as List).isNotEmpty) ||
                  (bd['status'] ?? '').toString().contains('counter_accepted');
              if (aAcc && !bAcc) return -1;
              if (!aAcc && bAcc) return 1;
              return 0;
            });

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PendingHeader(count: jobs.length),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostNewJobScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: Text(
                        'Post New Job',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (jobs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              size: 28,
                              color: Colors.black26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pending jobs',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap Post New Job above to get bids',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...jobs.map(
                      (jobDoc) => PendingJobTile(
                        jobDoc: jobDoc,
                        filter: FilterType.all,
                        userPos: userPos,
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
