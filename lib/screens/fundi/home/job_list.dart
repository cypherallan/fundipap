import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'logic.dart';
import 'job_card.dart';
import 'job_details_screen.dart';

class FundiHomeJobList extends StatelessWidget {
  final String search;
  final String mySkill;
  final Map<String, dynamic>? me;
  final int completedJobs;
  final int Function(Map<String, dynamic> job) relevanceScore;
  final Future<void> Function(BuildContext context, Map<String, dynamic> job)
  onBid;
  final dynamic currentPos;

  const FundiHomeJobList({
    super.key,
    required this.search,
    required this.mySkill,
    required this.me,
    required this.completedJobs,
    required this.relevanceScore,
    required this.onBid,
    required this.currentPos,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: FundipapColors.primaryYellow,
            ),
          );
        }
        var docs = snap.data!.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        if (search.isNotEmpty) {
          docs = docs
              .where(
                (m) => "${m['title']} ${m['description']} ${m['category']}"
                    .toLowerCase()
                    .contains(search),
              )
              .toList();
        }
        docs.sort((a, b) => relevanceScore(b).compareTo(relevanceScore(a)));
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No jobs for $mySkill yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white60),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length > 10 ? 10 : docs.length,
          itemBuilder: (_, i) {
            var data = docs[i];
            int score = relevanceScore(data);
            bool isMatch = score > 0;
            double? km = FundiHomeLogic.distanceKm(currentPos, data);
            var uid = FirebaseAuth.instance.currentUser!.uid;
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(data['id'])
                  .collection('bids')
                  .doc(uid)
                  .snapshots(),
              builder: (ctx, bidSnap) {
                if (!bidSnap.hasData) return const SizedBox.shrink();
                var bidData = bidSnap.data!.data() as Map<String, dynamic>?;
                bool hasBid = bidSnap.data!.exists;
                bool isRejected = bidData?['status'] == 'rejected';
                bool deletedForFundi = bidData?['deletedForFundi'] == true;
                String reason =
                    bidData?['rejectionReason'] ??
                    bidData?['rejectionCategory'] ??
                    'No reason given';
                if (deletedForFundi) return const SizedBox.shrink();
                if (isRejected) {
                  return GestureDetector(
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(data['id'])
                          .collection('bids')
                          .doc(uid)
                          .update({
                            'rejectedRead': true,
                            'rejectedReadAt': FieldValue.serverTimestamp(),
                          });
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(
                            'Offer Rejected',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              color: FundipapColors.redAlert,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your bid of KES ${bidData?['price']} for "${data['title']}" was rejected.',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reason:',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      reason,
                                      style: GoogleFonts.inter(fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Category: ${bidData?['rejectionCategory'] ?? ''}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You can no longer bid on this job.',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Return Home'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FundipapColors.redAlert,
                              ),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('jobs')
                                    .doc(data['id'])
                                    .collection('bids')
                                    .doc(uid)
                                    .update({'deletedForFundi': true});
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Job removed from your list'),
                                  ),
                                );
                              },
                              child: const Text(
                                'Delete Bid',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: FundipapColors.redAlert),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.block,
                                size: 16,
                                color: FundipapColors.redAlert,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'OFFER REJECTED',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: FundipapColors.redAlert,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'KES ${bidData?['price']}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data['title'] ?? '',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to read reason • You cannot bid again',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: FundipapColors.redAlert,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return FundiJobCard(
                  data: data,
                  isMatch: isMatch,
                  distanceKm: km,
                  hasBid: hasBid,
                  onBid: hasBid ? null : () => onBid(context, data),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailsScreen(
                          job: data,
                          distanceKm: km,
                          me: me,
                          completedJobs: completedJobs,
                          hasBid: hasBid,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
