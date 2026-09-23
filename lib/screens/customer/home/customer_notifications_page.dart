import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../confirm/confirm_fundi_page.dart';
import 'customer_fundi_timeline_page.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});
  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  final List<Map<String, dynamic>> _bids = [];
  StreamSubscription? _jobsSub;
  final Map<String, StreamSubscription> _bidsSubs = {};
  List<DocumentSnapshot> _activeJobs = [];
  StreamSubscription? _activeSub;

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'bidding', 'assigned', 'confirmed'])
        .snapshots()
        .listen((jobsSnap) {
          for (var jobDoc in jobsSnap.docs) {
            var jobId = jobDoc.id;
            if (_bidsSubs.containsKey(jobId)) continue;
            _bidsSubs[jobId] = FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .collection('bids')
                .snapshots()
                .listen((bidsSnap) {
                  _bids.removeWhere((b) => b['jobId'] == jobId);
                  for (var b in bidsSnap.docs) {
                    var bid = b.data();
                    if (bid['deletedForFundi'] == true) continue;
                    _bids.add({
                      'jobId': jobId,
                      'bidId': b.id,
                      'jobTitle': jobDoc.data()['title'] ?? '',
                      'jobData': jobDoc.data(),
                      'bidData': bid,
                      'fundiName': bid['fundiName'] ?? 'Fundi',
                      'fundiId': (bid['fundiId'] ?? bid['fundiName'])
                          .toString(),
                      'status': bid['status'] ?? 'pending',
                      'createdAt': bid['createdAt'],
                      'isRead': bid['isReadByCustomer'] == true,
                    });
                  }
                  if (mounted) setState(() {});
                });
          }
        });
    _activeSub = FirebaseFirestore.instance
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
            'completed',
          ],
        )
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _activeJobs = snap.docs);
        });
  }

  Future<void> _markThisFundiAsRead(String fundiKey) async {
    setState(() {
      for (var b in _bids) {
        if (b['fundiId'] == fundiKey || b['fundiName'] == fundiKey)
          b['isRead'] = true;
      }
    });
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _bids.where(
        (e) => e['fundiId'] == fundiKey || e['fundiName'] == fundiKey,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'isReadByCustomer': true},
        );
      }
      for (var d in _activeJobs) {
        var j = d.data() as Map<String, dynamic>;
        var assignedKey = (j['assignedFundiId'] ?? j['assignedFundiName'] ?? '')
            .toString();
        if (assignedKey == fundiKey) {
          batch.update(d.reference, {
            'customerHasUnread': false,
            'customerLastSeenAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('clear fundi failed $e');
    }
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _activeSub?.cancel();
    for (var s in _bidsSubs.values) s.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJobIds = _activeJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};

    for (var b in _bids) {
      if (activeJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['fundiId']}";
      grouped[key] = {
        'jobId': b['jobId'],
        'fundiName': b['fundiName'],
        'fundiId': b['fundiId'],
        'category':
            (b['jobData']['title'] ??
                    b['jobTitle'] ??
                    b['jobData']['category'] ??
                    'Job')
                .toString(),
        'jobData': b['jobData'],
        'bidData': b['bidData'],
        'bidId': b['bidId'],
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'type': 'bid',
        'isPendingBid': b['status'] == 'pending',
        'isRead': b['isRead'] == true,
      };
    }

    for (var doc in _activeJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var fundiId =
          (job['assignedFundiId'] ?? job['assignedFundiName'] ?? 'Fundi')
              .toString();
      var reneg = job['renegotiation'] as Map<String, dynamic>?;
      bool isNewPrice =
          reneg != null &&
          reneg['requested'] == true &&
          reneg['status'] == 'pending';

      grouped[doc.id] = {
        'jobId': doc.id,
        'fundiName': (job['assignedFundiName'] ?? 'Fundi').toString(),
        'fundiId': fundiId,
        'category': (job['title'] ?? job['category'] ?? 'Job').toString(),
        'jobData': job,
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'type': 'active',
        'isRead': (job['customerHasUnread'] != true) && !isNewPrice,
        'isNewPrice': isNewPrice,
      };
    }

    var list = grouped.values.toList()
      ..sort(
        (a, b) =>
            (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime)),
      );

    Map<String, int> fundiUnreadCounts = {};
    for (var g in list) {
      if (g['isRead'] == false) {
        fundiUnreadCounts[g['fundiId']] =
            (fundiUnreadCounts[g['fundiId']] ?? 0) + 1;
      }
    }
    int totalTabCounter = fundiUnreadCounts.values.fold(0, (a, b) => a + b);

    return Column(
      children: [
        Container(
          color: totalTabCounter > 0
              ? FundipapColors.primaryYellow.withOpacity(0.2)
              : Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                totalTabCounter > 0
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                totalTabCounter > 0
                    ? '$totalTabCounter new notifications'
                    : 'No new notifications',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No jobs yet',
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    var g = list[i];
                    String fundiKey = g['fundiId'] as String;
                    int badgeCount = fundiUnreadCounts[fundiKey] ?? 0;
                    bool isUnreadGroup = badgeCount > 0;
                    bool isNewPrice = g['isNewPrice'] == true;

                    Color cardColor;
                    Color borderColor;
                    if (isNewPrice) {
                      cardColor = Colors.orange.shade50;
                      borderColor = Colors.orange;
                    } else if (isUnreadGroup) {
                      cardColor = Colors.yellow.shade50;
                      borderColor = FundipapColors.primaryYellow;
                    } else {
                      cardColor = Colors.white;
                      borderColor = Colors.black12;
                    }

                    return Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: FundipapColors.blackGray,
                              child: Text(
                                (g['fundiName'] as String)[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (badgeCount > 0)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '$badgeCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          g['category'],
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g['fundiName'],
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                            if (isNewPrice)
                              Text(
                                'New price requested',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        trailing: isUnreadGroup
                            ? const Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 10,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          await _markThisFundiAsRead(fundiKey);
                          if (!context.mounted) return;
                          if (g['type'] == 'bid' && g['isPendingBid'] == true) {
                            final confirmed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConfirmFundiPage(
                                  jobId: g['jobId'],
                                  jobData: g['jobData'],
                                  bidId: g['bidId'],
                                  bidData: g['bidData'],
                                ),
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              // DO NOT push CustomerFundiTimelinePage here - stay on notifications list
                              return;
                            }
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerFundiTimelinePage(
                                  jobId: g['jobId'],
                                  fundiName: g['fundiName'],
                                  trade: g['category'],
                                  jobData: g['jobData'],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
