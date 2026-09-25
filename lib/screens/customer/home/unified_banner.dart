import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../confirm/fundi_page.dart';
import '../tracking/customer_tracking_screen.dart';
import '../../customer/my_jobs/customer_confirmed_jobs_page.dart';
import '../confirm/client_price_approval_screen.dart';

class CustomerUnifiedBanner extends StatefulWidget {
  const CustomerUnifiedBanner({super.key});
  @override
  State<CustomerUnifiedBanner> createState() => _CustomerUnifiedBannerState();
}

class _CustomerUnifiedBannerState extends State<CustomerUnifiedBanner> {
  final List<Map<String, dynamic>> _bids = [];
  final List<Map<String, dynamic>> _activeJobs = [];
  StreamSubscription? _jobsSub;
  StreamSubscription? _activeJobsSub;
  final Map<String, StreamSubscription> _bidsSubs = {};

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;

    // 1. BIDS - fundi sent bid
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
                  _bids.removeWhere((b) => b['jobId'] == jobId);
                  for (var bidDoc in bidsSnap.docs) {
                    var bid = bidDoc.data();
                    if (bid['status'] == 'rejected' ||
                        bid['status'] == 'accepted' ||
                        bid['deletedForFundi'] == true) {
                      continue;
                    }
                    _bids.add({
                      'type': 'bid',
                      'jobId': jobId,
                      'bidId': bidDoc.id,
                      'jobTitle': jobData['title'] ?? 'Job',
                      'jobData': jobData,
                      'bidData': bid,
                      'fundiName': bid['fundiName'] ?? 'Fundi',
                      'price': bid['price'] ?? 0,
                    });
                  }
                  if (mounted) setState(() {});
                });
          }
        });

    // 2. ACTIVE JOBS - ONLY fundi actions, with proper travelling check
    _activeJobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            'assigned',
            'confirmed',
            'travelling',
            'site_visit',
            'in_progress',
            'pending_completion',
            'job_completed',
          ],
        )
        .snapshots()
        .listen((snap) {
          _activeJobs.clear();
          for (var doc in snap.docs) {
            var job = doc.data();
            var jobId = doc.id;
            var reneg = job['renegotiation'] as Map<String, dynamic>?;
            String? title;
            String? body;
            String? action;
            IconData? icon;
            Color? bg;

            // ONLY fundi actions, and travelling only AFTER fundi clicks Start Site Visit
            // Check travelling flag first
            bool isTravelling =
                (job['travelling'] == true) ||
                (job['siteVisitStarted'] == true) ||
                (job['status'] == 'travelling');

            if (isTravelling && (job['siteVisitDone'] != true)) {
              title = 'Fundi is travelling';
              body =
                  '${job['assignedFundiName'] ?? 'Fundi'} is on the way to ${job['title']}';
              icon = Icons.directions_bike;
              bg = Colors.blue.shade50;
              action = 'tracking';
            }
            // Site visited
            else if (job['siteVisitDone'] == true &&
                job['status'] == 'site_visit' &&
                (reneg == null || reneg['requested'] != true)) {
              title = 'Fundi visited site';
              body = '${job['assignedFundiName']} visited • ${job['title']}';
              icon = Icons.location_on;
              bg = Colors.blue.shade50;
              action = 'site_visited';
            }
            // New price requested
            else if (reneg != null &&
                reneg['requested'] == true &&
                reneg['status'] == 'pending') {
              title = 'Fundi requested new price';
              body =
                  '${reneg['reason'] ?? 'Needs review'} • KES ${reneg['newPrice'] ?? ''}';
              icon = Icons.request_quote;
              bg = Colors.orange.shade50;
              action = 'new_price';
            }
            // Parts confirmed
            else if (reneg != null &&
                reneg['currentPhase'] == 'parts_confirmed_by_fundi') {
              title = 'Fundi confirmed parts';
              body = 'Parts available • ${job['title']}';
              icon = Icons.check_circle;
              bg = Colors.green.shade50;
              action = 'parts_confirmed';
            }
            // Working
            else if (reneg != null &&
                reneg['currentPhase'] == 'fundi_working') {
              title = 'Fundi is working';
              body = '${job['assignedFundiName']} working on ${job['title']}';
              icon = Icons.build;
              bg = Colors.green.shade50;
              action = 'working';
            } else if (job['status'] == 'in_progress') {
              title = 'Fundi is working';
              body = '${job['assignedFundiName']} • ${job['title']}';
              icon = Icons.construction;
              bg = Colors.green.shade50;
              action = 'working';
            }
            // Completed
            else if (reneg != null &&
                reneg['currentPhase'] == 'completed_by_fundi') {
              title = 'Fundi completed job';
              body = '${job['title']} • Confirm completion';
              icon = Icons.task_alt;
              bg = Colors.green.shade100;
              action = 'completed';
            } else if (job['status'] == 'job_completed' ||
                job['status'] == 'pending_completion') {
              title = 'Fundi completed job';
              body = '${job['title']} • Review & release';
              icon = Icons.verified;
              bg = Colors.green.shade100;
              action = 'completed';
            }

            if (title != null && action != null) {
              _activeJobs.add({
                'type': 'job',
                'jobId': jobId,
                'jobData': job,
                'jobTitle': job['title'] ?? 'Job',
                'title': title,
                'body': body!,
                'icon': icon!,
                'bg': bg!,
                'action': action,
                'fundiName': job['assignedFundiName'] ?? 'Fundi',
              });
            }
          }
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _activeJobsSub?.cancel();
    for (var s in _bidsSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._bids, ..._activeJobs];
    if (all.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active,
                size: 16,
                color: FundipapColors.blackGray,
              ),
              const SizedBox(width: 6),
              Text(
                all.any((e) => e['type'] == 'bid')
                    ? 'Incoming Bids • ${all.length}'
                    : 'Updates • ${all.length}',
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
              itemCount: all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                var item = all[i];
                bool isBid = item['type'] == 'bid';
                return InkWell(
                  onTap: () {
                    if (isBid) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConfirmFundiPage(
                            jobId: item['jobId'],
                            jobData:
                                item['jobData'], // <-- ConfirmFundiPage uses jobData (correct)
                            bidId: item['bidId'],
                            bidData: item['bidData'],
                          ),
                        ),
                      );
                    } else {
                      final action = item['action'] as String? ?? '';
                      final jobId = item['jobId'] as String;
                      final jobData = item['jobData'] as Map<String, dynamic>;

                      if (action == 'tracking') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerTrackingScreen(
                              jobId: jobId,
                              job: jobData, // <-- FIXED: job not jobData
                            ),
                          ),
                        );
                      } else if (action == 'new_price') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientPriceApprovalScreen(
                              jobId: jobId,
                              job: jobData, // <-- FIXED: was jobData
                            ),
                          ),
                        );
                      } else {
                        // site_visited, parts_confirmed, working, completed
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerConfirmedJobsPage(
                              initialJobId: jobId,
                              initialAction: action,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isBid
                          ? FundipapColors.primaryYellow.withValues(alpha: 0.18)
                          : item['bg'] as Color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.primaryYellow),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: FundipapColors.blackGray,
                          child: isBid
                              ? Text(
                                  (item['fundiName'] as String).isNotEmpty
                                      ? item['fundiName'][0].toUpperCase()
                                      : 'F',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isBid
                                    ? '${item['fundiName']} bid KES ${item['price']}'
                                    : item['title'],
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isBid
                                    ? 'for ${item['jobTitle']}'
                                    : item['body'],
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
