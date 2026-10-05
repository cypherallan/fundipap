import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'timeline/fundi_customer_timeline_page.dart';
import 'job_details_screen.dart';
import 'package:fundipap/widgets/animated_waiting_card.dart';
import '../../../services/fundi_waiting_state_service.dart';

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

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    String s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return fb;
    return int.tryParse(s.split('.').first) ?? fb;
  }

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
    _excludedJobIds.clear();
    _assignedJobs = [];
    _acceptedBids.clear();
    _clientCounters.clear();
    _sentBids.clear();
    _acceptedCounters.clear();
    if (mounted) setState(() {});

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
              int amt = _toInt(
                bid['clientCounterAmount'] ?? bid['lastCounterAmount'] ?? 0,
              );
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
              int amt = _toInt(
                bid['agreedPrice'] ??
                    bid['price'] ??
                    bid['clientCounterAmount'] ??
                    0,
              );
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
                'price': _toInt(
                  bid['amount'] ?? bid['bidAmount'] ?? bid['price'] ?? 0,
                ),
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
        .listen((snap) => _mergeIntoMap(snap.docs));
    _jobsSub2 = FirebaseFirestore.instance
        .collection('jobs')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) => _mergeIntoMap(snap.docs));
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
    final uid = FirebaseAuth.instance.currentUser!.uid;
    Map<String, Map<String, dynamic>> grouped = {};

    // 1. Build assigned jobs FIRST - they have highest priority
    for (var doc in _assignedJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var title = (job['title'] ?? 'Job').toString();
      var cName = (job['customerName'] ?? job['clientName'] ?? 'Client')
          .toString();

      FundiWaitingState? ws = getFundiWaitingState(
        job: job,
        bid: job,
        counterOffers: [],
        uid: uid,
      );

      String category;
      String type;
      FundiWaitingType waitingType;

      if (ws != null) {
        category = ws.title;
        type = ws.type.name;
        waitingType = ws.type;
      } else {
        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        var renegStatus = (reneg?['status'] ?? '').toString();
        bool isRenegCounter = renegStatus == 'countered_by_client';
        bool isRenegPending =
            renegStatus == 'pending' && reneg?['requested'] == true;
        int counterExtra = _toInt(
          reneg?['counterExtraLabor'] ?? reneg?['counterLabor'] ?? 0,
        );
        int pendingExtra = _toInt(
          reneg?['extraToLock'] ??
              reneg?['pendingLabor'] ??
              reneg?['extraLabor'] ??
              0,
        );
        if (isRenegCounter) {
          category = '$title • Client countered extra KES $counterExtra';
          type = 'counter';
          waitingType = FundiWaitingType.clientCounter;
        } else if (isRenegPending) {
          category =
              '$title • Waiting for client to approve extra KES $pendingExtra';
          type = 'reneg_pending';
          waitingType = FundiWaitingType.waitingNewPriceApproval;
        } else {
          category = title;
          type = 'assigned';
          waitingType = FundiWaitingType.escrowLocked;
        }
      }

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
        'waitingType': waitingType,
      };
    }

    // 2. All jobIds that already have progress - NEVER show bid_sent for them
    Set<String> jobsWithProgress = grouped.keys.toSet();
    jobsWithProgress.addAll(_acceptedBids.map((e) => e['jobId'] as String));
    jobsWithProgress.addAll(_acceptedCounters.map((e) => e['jobId'] as String));
    jobsWithProgress.addAll(_clientCounters.map((e) => e['jobId'] as String));
    // also any job in _jobsMap with agreedPrice / escrow
    for (var entry in _jobsMap.entries) {
      var j = entry.value.data() as Map<String, dynamic>;
      int agreed = _toInt(j['agreedPrice'] ?? j['acceptedBidAmount'] ?? 0);
      int escAmt = _toInt(j['escrowAmount'] ?? j['lockedEscrow'] ?? 0);
      String esc = (j['escrowStatus'] ?? '').toString().toLowerCase();
      if (agreed > 0 ||
          escAmt > 0 ||
          ['held', 'paid', 'released'].contains(esc)) {
        jobsWithProgress.add(entry.key);
      }
    }

    // 3. Now add other notifications ONLY if jobId not already has progress
    for (var b in _clientCounters) {
      if (jobsWithProgress.contains(b['jobId'])) continue;
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
        'waitingType': FundiWaitingType.clientCounter,
      };
    }

    for (var b in _acceptedCounters) {
      if (jobsWithProgress.contains(b['jobId'])) continue;
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
        'waitingType': FundiWaitingType.myCounter,
      };
    }

    for (var b in _acceptedBids) {
      if (jobsWithProgress.contains(b['jobId'])) continue;
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
        'waitingType': FundiWaitingType.bidSent,
      };
    }

    // 4. Bid sent LAST and with same jobId check - this is where 20000 was leaking
    for (var b in _sentBids) {
      if (jobsWithProgress.contains(b['jobId'])) continue;
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
        'waitingType': FundiWaitingType.bidSent,
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
                      FundiWaitingType wt =
                          g['waitingType'] as FundiWaitingType;
                      bool isOrange =
                          wt == FundiWaitingType.bidSent ||
                          wt == FundiWaitingType.clientCounter ||
                          wt == FundiWaitingType.myCounter ||
                          wt == FundiWaitingType.waitingEscrow ||
                          wt == FundiWaitingType.waitingNewPriceApproval ||
                          wt == FundiWaitingType.escrowLocked ||
                          wt == FundiWaitingType.travelling ||
                          wt == FundiWaitingType.siteVisited ||
                          wt == FundiWaitingType.working ||
                          wt == FundiWaitingType.jobCompleted;

                      if (isOrange) {
                        String msg;
                        if (wt == FundiWaitingType.clientCounter)
                          msg =
                              "${g['clientName']} • Tap to Accept / Counter / Reject";
                        else if (wt == FundiWaitingType.waitingEscrow)
                          msg = "${g['clientName']} • Waiting to lock escrow";
                        else if (wt == FundiWaitingType.escrowLocked)
                          msg = "${g['clientName']} • Tap to Start site visit";
                        else if (wt == FundiWaitingType.travelling)
                          msg = "${g['clientName']} • You are on the way";
                        else if (wt == FundiWaitingType.siteVisited)
                          msg =
                              "${g['clientName']} • Waiting for you to start work";
                        else
                          msg = "${g['clientName']} • Tap to view";

                        return OrangeAnimatedWaitingCard(
                          title: g['category'],
                          message: msg,
                          onTap: () async {
                            await _markThisClientAsRead(
                              g['clientId'],
                              g['jobId'],
                            );
                            if (!context.mounted) return;
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
                          },
                        );
                      }

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
