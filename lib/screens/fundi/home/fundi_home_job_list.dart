import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'fundi_home_logic.dart';
import 'fundi_job_card.dart';
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
          .where(
            'status',
            whereIn: [
              'open',
              'accepted',
              'assigned',
              'confirmed',
              'cancelled',
              'cancelled_after_arrival',
              'auto_cancelled_no_arrival',
            ],
          )
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

        // keep cancelled docs here - we will filter after checking bid
        docs = docs.where((m) {
          var status = (m['status'] ?? '').toString().toLowerCase();
          var escrow = (m['escrowStatus'] ?? 'pending')
              .toString()
              .toLowerCase();
          if (m['reposted'] == true) return false;
          // don't hide cancelled yet - let inner builder decide if fundi bid
          if (status.contains('complete') || status == 'closed') return false;
          if (['held', 'paid', 'locked', 'released'].contains(escrow))
            return false;
          return true;
        }).toList();

        if (search.isNotEmpty) {
          docs = docs
              .where(
                (m) => "${m['title']} ${m['description']} ${m['category']}"
                    .toLowerCase()
                    .contains(search.toLowerCase()),
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
          itemCount: docs.length > 20 ? 20 : docs.length,
          itemBuilder: (_, i) {
            var data = docs[i];
            int score = relevanceScore(data);
            bool isMatch = score > 0;
            double? km = FundiHomeLogic.distanceKm(currentPos, data);
            var uid = FirebaseAuth.instance.currentUser!.uid;

            // detect cancelled at job level
            bool jobIsCancelled =
                (data['cancelled'] == true) ||
                (data['autoCancelled'] == true) ||
                (data['status'] ?? '').toString().toLowerCase().contains(
                  'cancel',
                );

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
                bool deletedForFundi =
                    bidData?['deletedForFundi'] == true ||
                    bidData?['deletedForFundiAt'] != null;
                String reason =
                    bidData?['rejectionReason'] ??
                    bidData?['rejectionCategory'] ??
                    'No reason given';

                if (deletedForFundi) return const SizedBox.shrink();

                // FIX: read status from bidData, not from job data
                final String? myBidStatus = bidData?['status']?.toString();
                bool isCancelledByClient = myBidStatus == 'cancelled_by_client';
                bool isWithdrawn =
                    myBidStatus == 'withdrawn' || myBidStatus == 'cancelled';

                // if job cancelled and fundi never bid - hide
                if (jobIsCancelled && !hasBid) return const SizedBox.shrink();

                if (isRejected) {
                  // ... keep your rejected dialog as is ...
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
                                  ],
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
                                    .set({
                                      'deletedForFundi': true,
                                      'deletedForFundiAt':
                                          FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                                Navigator.pop(context);
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

                // FIXED: green only if bid is active, not cancelled_by_client
                bool hasBidActive =
                    hasBid && !isCancelledByClient && !isWithdrawn;

                // inject status into data for card
                data['bidStatus'] = myBidStatus;

                return FundiJobCard(
                  data: data,
                  isMatch: isMatch,
                  distanceKm: km,
                  hasBid: hasBidActive, // <-- not green when client cancelled
                  bidStatus: myBidStatus, // <-- orange banner
                  onBid: hasBidActive || jobIsCancelled || isCancelledByClient
                      ? null
                      : () => onBid(context, data),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailsScreen(
                          job: data,
                          distanceKm: km,
                          me: me,
                          completedJobs: completedJobs,
                          hasBid: hasBidActive,
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
