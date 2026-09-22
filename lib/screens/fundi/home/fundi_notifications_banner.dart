import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'job_details_screen.dart';

class FundiNotificationsBanner extends StatefulWidget {
  const FundiNotificationsBanner({super.key});

  @override
  State<FundiNotificationsBanner> createState() =>
      _FundiNotificationsBannerState();
}

class _FundiNotificationsBannerState extends State<FundiNotificationsBanner> {
  final List<Map<String, dynamic>> _clientActions = [];
  StreamSubscription? _activeJobsSub;
  StreamSubscription? _bidsSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 1. CLIENT ACTIONS ON MY BIDS - counter, accept, decline
    // Inverse of customer_unified_banner.dart which shows fundi -> client
    _bidsSub = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) async {
          final List<Map<String, dynamic>> tmp = [];
          for (var bidDoc in snap.docs) {
            final bid = bidDoc.data();
            final status = bid['status'] as String?;
            // Only show client actions
            if (status != 'countered' &&
                status != 'client_counter' &&
                status != 'accepted' &&
                status != 'rejected')
              continue;

            final jobId = bidDoc.reference.parent.parent?.id;
            if (jobId == null) continue;
            final jobDoc = await FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .get();
            final jobData = jobDoc.data() ?? {};

            // Skip if job assigned to another fundi
            if (jobData['assignedFundiId'] != null &&
                jobData['assignedFundiId'] != uid) {
              if (status == 'accepted') continue;
            }

            String title;
            String body;
            IconData icon;
            Color bg;

            if (status == 'countered' || status == 'client_counter') {
              title = 'Client countered your bid';
              body =
                  'KES ${bid['counterPrice'] ?? bid['clientCounterPrice'] ?? bid['price'] ?? ''} • ${jobData['title'] ?? 'Job'}';
              icon = Icons.compare_arrows;
              bg = Colors.orange.shade50;
            } else if (status == 'accepted') {
              title = 'Client accepted your bid';
              body = '${jobData['title'] ?? 'Job'} • Tap to confirm';
              icon = Icons.check_circle;
              bg = Colors.green.shade50;
            } else {
              title = 'Client declined your bid';
              body = '${jobData['title'] ?? 'Job'}';
              icon = Icons.cancel;
              bg = Colors.red.shade50;
            }

            tmp.add({
              'jobId': jobId,
              'jobData': jobData,
              'title': title,
              'body': body,
              'icon': icon,
              'bg': bg,
              'type': 'bid',
              'createdAt': bid['updatedAt'] ?? bid['createdAt'],
            });
          }
          _mergeAndSort(tmp, isBid: true);
        });

    // 2. ACTIVE JOBS - client bought parts, released escrow
    _activeJobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
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
          final List<Map<String, dynamic>> tmp = [];
          for (var doc in snap.docs) {
            final job = doc.data();
            final jobId = doc.id;
            final reneg = job['renegotiation'] as Map<String, dynamic>?;

            String? title;
            String? body;
            IconData? icon;
            Color? bg;

            if (reneg != null &&
                reneg['requestedBy'] == 'client' &&
                reneg['status'] == 'pending') {
              title = 'Client countered price';
              body =
                  '${reneg['reason'] ?? 'Counter offer'} • KES ${reneg['newPrice'] ?? ''}';
              icon = Icons.request_quote;
              bg = Colors.orange.shade50;
            } else if (reneg != null &&
                reneg['acceptedBy'] == 'client' &&
                reneg['status'] == 'accepted') {
              title = 'Client accepted new price';
              body = 'KES ${reneg['newPrice']} • ${job['title']}';
              icon = Icons.price_check;
              bg = Colors.green.shade50;
            } else if (reneg != null &&
                reneg['rejectedBy'] == 'client' &&
                reneg['status'] == 'rejected') {
              title = 'Client declined price';
              body = '${job['title']}';
              icon = Icons.block;
              bg = Colors.red.shade50;
            } else if (reneg != null &&
                (reneg['currentPhase'] == 'parts_bought_by_client' ||
                    reneg['currentPhase'] == 'client_bought_parts' ||
                    job['partsBoughtByClient'] == true)) {
              title = 'Client bought materials';
              body = 'Parts ready • ${job['title']}';
              icon = Icons.shopping_cart;
              bg = Colors.orange.shade50;
            } else if (job['escrowReleasedByClient'] == true ||
                (reneg != null && reneg['escrowReleased'] == true) ||
                (reneg != null &&
                    reneg['currentPhase'] == 'escrow_released_by_client')) {
              title = 'Client released escrow';
              body = 'Payment in escrow • ${job['title']}';
              icon = Icons.account_balance_wallet;
              bg = Colors.blue.shade50;
            } else if (job['clientConfirmedCompletion'] == true) {
              title = 'Client confirmed completion';
              body = '${job['title']} • Payment released';
              icon = Icons.payments;
              bg = Colors.green.shade100;
            }

            if (title != null) {
              tmp.add({
                'jobId': jobId,
                'jobData': job,
                'title': title,
                'body': body!,
                'icon': icon!,
                'bg': bg!,
                'type': 'job',
                'createdAt': job['updatedAt'] ?? job['clientActionAt'],
              });
            }
          }
          _mergeAndSort(tmp, isBid: false);
        });
  }

  void _mergeAndSort(
    List<Map<String, dynamic>> newItems, {
    required bool isBid,
  }) {
    _clientActions.removeWhere((e) => e['type'] == (isBid ? 'bid' : 'job'));
    _clientActions.addAll(newItems);
    _clientActions.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      DateTime da;
      DateTime db;
      if (ta is Timestamp) {
        da = ta.toDate();
      } else if (ta is DateTime)
        // ignore: curly_braces_in_flow_control_structures
        da = ta;
      else
        // ignore: curly_braces_in_flow_control_structures
        da = DateTime.now();
      if (tb is Timestamp) {
        db = tb.toDate();
      } else if (tb is DateTime)
        // ignore: curly_braces_in_flow_control_structures
        db = tb;
      else
        // ignore: curly_braces_in_flow_control_structures
        db = DateTime.now();
      return db.compareTo(da);
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bidsSub?.cancel();
    _activeJobsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_clientActions.isEmpty) return const SizedBox.shrink();

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
                'Client Updates • ${_clientActions.length}',
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
              itemCount: _clientActions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = _clientActions[i];
                return InkWell(
                  onTap: () {
                    // Both types go to job details, which can then open my_jobs page
                    // job_details_screen.dart is in same folder as this banner
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) {
                          final jobMap = {
                            ...item['jobData'] as Map<String, dynamic>,
                            'id': item['jobId'],
                            'jobId': item['jobId'],
                          };
                          return JobDetailsScreen(job: jobMap);
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item['bg'] as Color,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.primaryYellow),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: FundipapColors.blackGray,
                          child: Icon(
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
                                item['title'],
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['body'],
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
