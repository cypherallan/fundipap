import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../confirm_fundi_page.dart';

class CustomerBidNotifications extends StatefulWidget {
  const CustomerBidNotifications({super.key});
  @override
  State<CustomerBidNotifications> createState() =>
      _CustomerBidNotificationsState();
}

class _CustomerBidNotificationsState extends State<CustomerBidNotifications> {
  List<Map<String, dynamic>> _allBids = [];
  StreamSubscription? _jobsSub;
  final Map<String, StreamSubscription> _bidsSubs = {};

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    // listen to my jobs
    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'bidding'])
        .snapshots()
        .listen((jobsSnap) {
          for (var jobDoc in jobsSnap.docs) {
            var jobId = jobDoc.id;
            if (_bidsSubs.containsKey(jobId)) continue;
            var jobData = jobDoc.data();
            _bidsSubs[jobId] = FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .collection('bids')
                .orderBy('createdAt', descending: true)
                .snapshots()
                .listen((bidsSnap) {
                  // remove old bids for this job
                  _allBids.removeWhere((b) => b['jobId'] == jobId);
                  for (var bidDoc in bidsSnap.docs) {
                    var bid = bidDoc.data();
                    _allBids.add({
                      'jobId': jobId,
                      'bidId': bidDoc.id,
                      'jobTitle': jobData['title'] ?? 'Job',
                      'jobData': jobData,
                      'bidData': bid,
                      'fundiName': bid['fundiName'] ?? 'Fundi',
                      'price': bid['price'] ?? bid['offeredPrice'] ?? 0,
                      'fundiId': bid['fundiId'] ?? bid['id'] ?? '',
                      'createdAt': bid['createdAt'],
                    });
                  }
                  _allBids.sort((a, b) {
                    var ta = a['createdAt'] is Timestamp
                        ? (a['createdAt'] as Timestamp).toDate()
                        : DateTime.now();
                    var tb = b['createdAt'] is Timestamp
                        ? (b['createdAt'] as Timestamp).toDate()
                        : DateTime.now();
                    return tb.compareTo(ta);
                  });
                  if (mounted) setState(() {});
                });
          }
        });
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _bidsSubs.values.forEach((s) => s.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allBids.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                size: 16,
                color: FundipapColors.blackGray,
              ),
              const SizedBox(width: 6),
              Text(
                'Incoming Bids • ${_allBids.length}',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _allBids.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                var b = _allBids[i];
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConfirmFundiPage(
                        jobId: b['jobId'],
                        jobData: b['jobData'],
                        bidId: b['bidId'],
                        bidData: b['bidData'],
                      ),
                    ),
                  ),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FundipapColors.primaryYellow.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.primaryYellow),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: FundipapColors.blackGray,
                          child: Text(
                            (b['fundiName'][0] ?? 'F').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${b['fundiName']} bid KES ${b['price']}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'for ${b['jobTitle']}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
