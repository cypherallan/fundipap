import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'timeline/fundi_customer_timeline_page.dart';
import 'job_details_screen.dart';

class FundiNotificationsPage extends StatefulWidget {
  const FundiNotificationsPage({super.key});
  @override
  State<FundiNotificationsPage> createState() => _FundiNotificationsPageState();
}

class _FundiNotificationsPageState extends State<FundiNotificationsPage> {
  final List<Map<String, dynamic>> _acceptedBids = [];
  final List<Map<String, dynamic>> _clientCounters = [];
  final List<Map<String, dynamic>> _sentBids = [];
  final List<Map<String, dynamic>> _acceptedCounters = [];
  StreamSubscription? _bidsSub;
  List<DocumentSnapshot> _assignedJobs = [];
  StreamSubscription? _jobsSub;
  StreamSubscription? _jobsSub2;
  Set<String> _excludedJobIds = {};
  final Map<String, DocumentSnapshot> _jobsMap = {};

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _mergeIntoMap(List<DocumentSnapshot> docs) {
    for (var doc in docs) {
      var job = doc.data() as Map<String, dynamic>;
      var status = (job['status'] ?? '').toString().toLowerCase();
      if (status.contains('cancel') || job['reposted'] == true) {
        _excludedJobIds.add(doc.id);
        _jobsMap.remove(doc.id);
        continue;
      }
      _excludedJobIds.remove(doc.id);
      _jobsMap[doc.id] = doc;
    }
    _assignedJobs = _jobsMap.values.toList();
    if (mounted) setState(() {});
  }

  void _initListeners() {
    _bidsSub?.cancel();
    _jobsSub?.cancel();
    _jobsSub2?.cancel();
    _jobsMap.clear();
    _excludedJobIds.clear(); // FIX 1: clear excluded
    _assignedJobs = [];
    _acceptedBids.clear();
    _clientCounters.clear();
    _sentBids.clear();
    _acceptedCounters.clear();
    if (mounted)
      setState(() {}); // FIX 1: clear UI immediately, no flash of old

    var uid = FirebaseAuth.instance.currentUser!.uid;

    _bidsSub = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          _acceptedBids.clear();
          _clientCounters.clear();
          _sentBids.clear();
          _acceptedCounters.clear();
          for (var b in snap.docs) {
            var bid = b.data();
            var status = (bid['status'] ?? '').toString();
            var counterBy = (bid['counterBy'] ?? bid['lastCounterBy'] ?? '')
                .toString();
            var lastCounterBy = (bid['lastCounterBy'] ?? counterBy).toString();
            var jId = (bid['jobId'] ?? b.reference.parent.parent?.id ?? '')
                .toString();
            if (jId.isEmpty) continue;
            // FIX 2: DON'T check _excludedJobIds here, check in build() after jobs arrive

            bool isClientCounter =
                (status == 'countered' &&
                    lastCounterBy != uid &&
                    lastCounterBy != '') ||
                status == 'client_counter' ||
                (status == 'countered' && bid['clientCounterAmount'] != null);

            if (status == 'accepted') {
              _acceptedBids.add({
                'jobId': jId,
                'bidId': b.id,
                'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? 'Job')
                    .toString(),
                'clientName':
                    (bid['customerName'] ?? bid['clientName'] ?? 'Client')
                        .toString(),
                'clientId': (bid['customerId'] ?? '').toString(),
                'price': bid['price'] ?? 0,
                'createdAt': bid['updatedAt'] ?? bid['createdAt'],
                'isRead': bid['isReadByFundi'] == true,
                'type': 'accepted',
              });
            } else if (isClientCounter) {
              int amt =
                  ((bid['clientCounterAmount'] ?? bid['lastCounterAmount'] ?? 0)
                          as num)
                      .toInt();
              _clientCounters.add({
                'jobId': jId,
                'bidId': b.id,
                'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? 'Job')
                    .toString(),
                'clientName':
                    (bid['customerName'] ?? bid['clientName'] ?? 'Client')
                        .toString(),
                'clientId': (bid['customerId'] ?? '').toString(),
                'price': amt,
                'createdAt':
                    bid['counterAt'] ?? bid['updatedAt'] ?? bid['createdAt'],
                'isRead':
                    bid['clientCounterSeenByFundi'] == true ||
                    bid['fundiHasUnread'] == false,
                'type': 'counter',
                'bidData': bid,
              });
            } else if (status == 'counter_accepted_by_fundi') {
              int amt =
                  ((bid['agreedPrice'] ??
                              bid['price'] ??
                              bid['clientCounterAmount'] ??
                              0)
                          as num)
                      .toInt();
              _acceptedCounters.add({
                'jobId': jId,
                'bidId': b.id,
                'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? 'Job')
                    .toString(),
                'clientName':
                    (bid['customerName'] ?? bid['clientName'] ?? 'Client')
                        .toString(),
                'clientId': (bid['customerId'] ?? '').toString(),
                'price': amt,
                'createdAt':
                    bid['fundiAcceptedCounterAt'] ??
                    bid['updatedAt'] ??
                    bid['createdAt'],
                'isRead': bid['isReadByFundi'] == true,
                'type': 'accepted_counter',
              });
            } else if (status == 'pending') {
              _sentBids.add({
                'jobId': jId,
                'bidId': b.id,
                'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? 'Job')
                    .toString(),
                'clientName':
                    (bid['customerName'] ?? bid['clientName'] ?? 'Client')
                        .toString(),
                'clientId': (bid['customerId'] ?? '').toString(),
                'price': bid['amount'] ?? bid['bidAmount'] ?? bid['price'] ?? 0,
                'createdAt': bid['createdAt'] ?? bid['updatedAt'],
                'isRead': bid['isReadByFundi'] == true,
                'type': 'bid_sent',
              });
            }
          }
          if (mounted) setState(() {});
        });

    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          _mergeIntoMap(snap.docs);
        });
    _jobsSub2 = FirebaseFirestore.instance
        .collection('jobs')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          _mergeIntoMap(snap.docs);
        });
  }

  Future<void> _onRefresh() async {
    _initListeners();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _markThisClientAsRead(String clientKey, String jobId) async {
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _acceptedBids.where(
        (e) => e['clientId'] == clientKey && e['jobId'] == jobId,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'isReadByFundi': true},
        );
      }
      for (var b in _clientCounters.where(
        (e) => e['clientId'] == clientKey && e['jobId'] == jobId,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'clientCounterSeenByFundi': true, 'fundiHasUnread': false},
        );
        batch.update(
          FirebaseFirestore.instance.collection('jobs').doc(b['jobId']),
          {'fundiHasUnread': false},
        );
      }
      for (var b in _sentBids.where(
        (e) => e['clientId'] == clientKey && e['jobId'] == jobId,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'isReadByFundi': true},
        );
      }
      for (var b in _acceptedCounters.where(
        (e) => e['clientId'] == clientKey && e['jobId'] == jobId,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'isReadByFundi': true},
        );
      }
      for (var d in _assignedJobs.where((d) => d.id == jobId)) {
        batch.update(d.reference, {
          'fundiHasUnread': false,
          'fundiLastSeenAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _bidsSub?.cancel();
    _jobsSub?.cancel();
    _jobsSub2?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignedIds = _assignedJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};

    for (var b in _sentBids) {
      if (assignedIds.contains(b['jobId'])) continue;
      if (_excludedJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['clientId']}_sent";
      grouped[key] = {
        'jobId': b['jobId'],
        'bidId': b['bidId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': 'Bid sent - KES ${b['price']} • ${b['jobTitle']}',
        'jobData': {
          'title': b['jobTitle'],
          'status': 'bid_sent',
          'customerName': b['clientName'],
        },
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': b['isRead'] == true,
        'type': 'bid_sent',
      };
    }
    for (var b in _acceptedCounters) {
      if (assignedIds.contains(b['jobId'])) continue;
      if (_excludedJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['clientId']}_accepted_counter";
      grouped[key] = {
        'jobId': b['jobId'],
        'bidId': b['bidId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category':
            'Accepted counter bid - KES ${b['price']} • ${b['jobTitle']}',
        'jobData': {
          'title': b['jobTitle'],
          'status': 'counter_accepted',
          'customerName': b['clientName'],
        },
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': b['isRead'] == true,
        'type': 'accepted_counter',
      };
    }
    for (var b in _acceptedBids) {
      if (assignedIds.contains(b['jobId'])) continue;
      if (_excludedJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['clientId']}";
      grouped[key] = {
        'jobId': b['jobId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': b['jobTitle'],
        'jobData': {
          'title': b['jobTitle'],
          'status': 'accepted',
          'customerName': b['clientName'],
        },
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': b['isRead'] == true,
        'type': 'accepted',
      };
    }
    for (var b in _clientCounters) {
      if (assignedIds.contains(b['jobId'])) continue;
      if (_excludedJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['clientId']}_counter";
      grouped[key] = {
        'jobId': b['jobId'],
        'bidId': b['bidId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': '${b['jobTitle']} • Client countered KES ${b['price']}',
        'jobData': {
          'title': b['jobTitle'],
          'status': 'countered',
          'customerName': b['clientName'],
          'focusedBid': b['bidData'],
          'focusedBidId': b['bidId'],
        },
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': b['isRead'] == true,
        'type': 'counter',
      };
    }

    for (var doc in _assignedJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var title = (job['title'] ?? 'Job').toString();
      var cName = (job['customerName'] ?? job['clientName'] ?? 'Client')
          .toString();
      var reneg = job['renegotiation'] as Map<String, dynamic>?;
      var renegStatus = (reneg?['status'] ?? '').toString();
      bool isRenegCounter = renegStatus == 'countered_by_client';
      bool isRenegPendingExtra =
          renegStatus.contains('pending_extra_escrow') ||
          job['status'] == 'renegotiation_countered_by_client';
      bool isRenegPending =
          renegStatus == 'pending' &&
          reneg?['requested'] == true; // FIX 3: your new case
      int counterExtra = 0;
      if (isRenegCounter || isRenegPendingExtra) {
        counterExtra =
            int.tryParse(
              (reneg?['counterExtraLabor'] ?? reneg?['counterLabor'] ?? 0)
                  .toString(),
            ) ??
            0;
      }
      int pendingExtra = 0;
      if (isRenegPending) {
        pendingExtra =
            int.tryParse(
              (reneg?['extraToLock'] ??
                      reneg?['pendingLabor'] ??
                      reneg?['extraLabor'] ??
                      0)
                  .toString(),
            ) ??
            0;
      }
      String category = title;
      String type = 'assigned';
      if (isRenegCounter) {
        category = '$title • Client countered extra KES $counterExtra';
        type = 'counter';
      } else if (isRenegPending) {
        category =
            '$title • Waiting for client to approve extra KES $pendingExtra';
        type = 'reneg_pending';
      } // FIX 3
      grouped[doc.id] = {
        'jobId': doc.id,
        'clientName': cName,
        'clientId': (job['customerId'] ?? cName).toString(),
        'category': category,
        'jobData': job,
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': job['fundiHasUnread'] != true,
        'type': type,
      };
    }

    var list = grouped.values.toList();
    list.sort(
      (a, b) =>
          (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime)),
    );
    int totalUnread = list.where((g) => g['isRead'] == false).length;

    return Column(
      children: [
        Container(
          color: totalUnread > 0
              ? FundipapColors.primaryYellow.withOpacity(0.2)
              : Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                totalUnread > 0
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                totalUnread > 0
                    ? '$totalUnread new notifications'
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
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: FundipapColors.primaryYellow,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 200),
                      Center(
                        child: Text(
                          'No notifications',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      var g = list[i];
                      bool isCounter = g['type'] == 'counter';
                      bool isSent = g['type'] == 'bid_sent';
                      bool isAcceptedCounter = g['type'] == 'accepted_counter';
                      bool isRenegPending = g['type'] == 'reneg_pending';
                      return Card(
                        color: isCounter
                            ? Colors.orange.shade50
                            : isSent
                            ? Colors.blue.shade50
                            : isAcceptedCounter
                            ? Colors.green.shade50
                            : isRenegPending
                            ? Colors.purple.shade50
                            : null,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isCounter
                                ? Colors.orange.shade300
                                : isSent
                                ? Colors.blue.shade300
                                : isAcceptedCounter
                                ? Colors.green.shade300
                                : isRenegPending
                                ? Colors.purple.shade300
                                : Colors.transparent,
                            width:
                                isCounter ||
                                    isSent ||
                                    isAcceptedCounter ||
                                    isRenegPending
                                ? 1.2
                                : 0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: isCounter
                                ? Colors.orange.shade700
                                : isSent
                                ? Colors.blue.shade700
                                : isAcceptedCounter
                                ? Colors.green.shade700
                                : isRenegPending
                                ? Colors.purple.shade700
                                : FundipapColors.blackGray,
                            child: Icon(
                              isCounter
                                  ? Icons.compare_arrows
                                  : isSent
                                  ? Icons.send
                                  : isAcceptedCounter
                                  ? Icons.check_circle
                                  : isRenegPending
                                  ? Icons.hourglass_top
                                  : Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            g['category'],
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${g['clientName']}${isCounter
                                ? ' • Tap to Accept / Counter / Reject'
                                : isSent
                                ? ' • Waiting for client'
                                : isAcceptedCounter
                                ? ' • Waiting for client to confirm'
                                : isRenegPending
                                ? ' • Waiting for approval'
                                : ''}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          trailing: g['isRead'] == false
                              ? const Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 10,
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () async {
                            await _markThisClientAsRead(
                              g['clientId'],
                              g['jobId'],
                            );
                            if (!context.mounted) return;
                            if (isCounter && g['bidId'] != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailsScreen(
                                    job: {
                                      ...g['jobData'] as Map<String, dynamic>,
                                      'id': g['jobId'],
                                      'jobId': g['jobId'],
                                    },
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FundiCustomerTimelinePage(
                                    jobId: g['jobId'],
                                    clientName: g['clientName'],
                                    jobTitle: g['category'],
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
        ),
      ],
    );
  }
}
