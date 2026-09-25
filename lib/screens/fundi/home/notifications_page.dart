import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'customer_timeline_page.dart';

class FundiNotificationsPage extends StatefulWidget {
  const FundiNotificationsPage({super.key});
  @override
  State<FundiNotificationsPage> createState() => _FundiNotificationsPageState();
}

class _FundiNotificationsPageState extends State<FundiNotificationsPage> {
  final List<Map<String, dynamic>> _acceptedBids = [];
  StreamSubscription? _bidsSub;
  List<DocumentSnapshot> _assignedJobs = [];
  StreamSubscription? _jobsSub;

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _bidsSub = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snap) {
          _acceptedBids.clear();
          for (var b in snap.docs) {
            var bid = b.data();
            var jId = (bid['jobId'] ?? '').toString();
            if (jId.isEmpty) continue;
            _acceptedBids.add({
              'jobId': jId,
              'bidId': b.id,
              'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? '').toString(),
              'clientName': (bid['customerName'] ?? bid['clientName'] ?? '')
                  .toString(),
              'clientId': (bid['customerId'] ?? bid['customerName'] ?? '')
                  .toString(),
              'price': bid['price'] ?? bid['agreedPrice'] ?? 0,
              'totalCost':
                  bid['totalCost'] ?? bid['price'] ?? bid['agreedPrice'] ?? 0,
              'transportFee': bid['transportFee'] ?? 0,
              'createdAt': bid['updatedAt'] ?? bid['createdAt'],
              'isRead': bid['isReadByFundi'] == true,
            });
          }
          if (mounted) setState(() {});
        });
    _jobsSub = FirebaseFirestore.instance.collection('jobs').snapshots().listen(
      (snap) {
        List<DocumentSnapshot> mine = [];
        var uid2 = FirebaseAuth.instance.currentUser!.uid;
        for (var doc in snap.docs) {
          var job = doc.data();
          bool isMine =
              job['assignedFundiId'] == uid2 ||
              job['assignedFundi'] == uid2 ||
              job['fundiId'] == uid2 ||
              job['acceptedFundiId'] == uid2;
          if (isMine) mine.add(doc);
        }
        if (mounted) setState(() => _assignedJobs = mine);
      },
    );
  }

  bool _isWaiting(Map<String, dynamic> job) {
    var status = (job['status'] ?? '').toString();
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String rs = (reneg?['status'] ?? '').toString();

    // completed jobs are NEVER waiting - push to bottom
    const completed = [
      'completed',
      'job_completed',
      'cancelled',
      'closed',
      'disputed',
    ];
    if (completed.contains(status)) return false;

    // ANY renegotiation that needs action is waiting - HIGHEST PRIORITY
    if (reneg != null && reneg['requested'] == true) {
      if (rs == 'pending')
        return true; // you are waiting for client to confirm price review
      if (rs == 'countered_by_client') return true;
    }

    // active flow - all these are waiting/active and must be above completed
    const active = [
      'accepted',
      'assigned',
      'confirmed',
      'travelling',
      'site_visit',
      'in_progress',
      'pending_completion',
    ];
    if (active.contains(status)) return true;

    // escrow not locked yet but bid accepted = waiting for payment
    bool locked = escrow == 'held' || escrow == 'paid' || escrow == 'locked';
    if (!locked && status == 'accepted') return true;

    return false;
  }

  int _waitingPriority(Map<String, dynamic> job) {
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String rs = (reneg?['status'] ?? '').toString();
    String status = (job['status'] ?? '').toString();
    if (reneg != null && rs == 'pending')
      return 0; // waiting for client to confirm price review - TOP
    if (reneg != null && rs == 'countered_by_client') return 1;
    if (status == 'accepted') return 2; // waiting for escrow
    if (status == 'assigned' || status == 'confirmed') return 3;
    if (status == 'travelling') return 4;
    if (status == 'site_visit') return 5;
    if (status == 'in_progress') return 6;
    if (status == 'pending_completion') return 7;
    return 10; // completed
  }

  Future<void> _markThisClientAsRead(String clientKey) async {
    setState(() {
      for (var b in _acceptedBids) {
        if (b['clientId'] == clientKey || b['clientName'] == clientKey)
          b['isRead'] = true;
      }
    });
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _acceptedBids.where(
        (e) => e['clientId'] == clientKey || e['clientName'] == clientKey,
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
      for (var d in _assignedJobs) {
        var j = d.data() as Map<String, dynamic>;
        var cKey = (j['customerId'] ?? j['customerName'] ?? '').toString();
        var cName = (j['customerName'] ?? '').toString();
        if (cKey == clientKey || cName == clientKey) {
          batch.update(d.reference, {
            'fundiHasUnread': false,
            'fundiLastSeenAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _bidsSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignedIds = _assignedJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};
    for (var b in _acceptedBids) {
      if (assignedIds.contains(b['jobId'])) continue;
      if ((b['jobTitle'] as String).isEmpty ||
          (b['clientName'] as String).isEmpty)
        continue;
      String key = "${b['jobId']}_${b['clientId']}";
      int labor = (b['price'] ?? 0).toInt();
      int total = (b['totalCost'] ?? labor).toInt();
      int transport = (b['transportFee'] ?? 0).toInt();
      grouped[key] = {
        'jobId': b['jobId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': b['jobTitle'],
        'jobData': {
          'title': b['jobTitle'],
          'agreedPrice': labor,
          'laborCost': labor,
          'transportFee': transport,
          'totalCost': total,
          'escrowAmount': total,
          'escrowStatus': 'pending',
          'status': 'accepted',
          'customerName': b['clientName'],
        },
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': b['isRead'] == true,
      };
    }
    for (var doc in _assignedJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var title = (job['title'] ?? '').toString();
      var cName = (job['customerName'] ?? job['clientName'] ?? '').toString();
      if (title.isEmpty || cName.isEmpty) continue;
      var clientId = (job['customerId'] ?? cName).toString();
      // TRANSPORT SAFE READ
      int labor = (job['laborCost'] ?? job['agreedPrice'] ?? 0).toInt();
      int transport = (job['transportFee'] ?? 0).toInt();
      int total = (job['totalCost'] ?? job['escrowAmount'] ?? labor).toInt();
      grouped[doc.id] = {
        'jobId': doc.id,
        'clientName': cName,
        'clientId': clientId,
        'category': title,
        'jobData': job, // already has transport fields
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': job['fundiHasUnread'] != true,
        'labor': labor,
        'transport': transport,
        'total': total,
      };
    }

    var list = grouped.values.toList();
    list.sort((a, b) {
      var aJob = a['jobData'] as Map<String, dynamic>;
      var bJob = b['jobData'] as Map<String, dynamic>;
      bool aWaiting = _isWaiting(aJob);
      bool bWaiting = _isWaiting(bJob);

      // 1. WAITING FIRST - always on top, even if read
      if (aWaiting && !bWaiting) return -1;
      if (!aWaiting && bWaiting) return 1;

      // 2. Inside waiting group, sort by priority (pending price review = top)
      if (aWaiting && bWaiting) {
        int pa = _waitingPriority(aJob);
        int pb = _waitingPriority(bJob);
        if (pa != pb) return pa.compareTo(pb);
      }

      // 3. Unread first
      bool aUnread = a['isRead'] == false;
      bool bUnread = b['isRead'] == false;
      if (aUnread && !bUnread) return -1;
      if (!aUnread && bUnread) return 1;

      // 4. Latest first
      return (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime));
    });

    Map<String, int> clientUnreadCounts = {};
    for (var g in list) {
      if (g['isRead'] == false)
        clientUnreadCounts[g['clientId']] =
            (clientUnreadCounts[g['clientId']] ?? 0) + 1;
    }
    int total = clientUnreadCounts.values.fold(0, (a, b) => a + b);

    return Column(
      children: [
        Container(
          color: total > 0
              ? FundipapColors.primaryYellow.withOpacity(0.2)
              : Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                total > 0
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                total > 0 ? '$total new notifications' : 'No new notifications',
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
                  child: Text('No notifications', style: GoogleFonts.inter()),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    var g = list[i];
                    String clientKey = g['clientId'];
                    int badge = clientUnreadCounts[clientKey] ?? 0;
                    bool isUnreadGroup = badge > 0;
                    var jobData = g['jobData'] as Map<String, dynamic>;
                    var reneg =
                        jobData['renegotiation'] as Map<String, dynamic>?;
                    bool isPendingPrice =
                        reneg != null &&
                        reneg['requested'] == true &&
                        reneg['status'] == 'pending';
                    bool isCountered =
                        reneg != null &&
                        reneg['status'] == 'countered_by_client';
                    bool isWaiting = _isWaiting(jobData);

                    Color cardColor;
                    Color borderColor;
                    if (isPendingPrice) {
                      cardColor = Colors.orange.shade50;
                      borderColor = Colors.orange;
                    } else if (isCountered) {
                      cardColor = Colors.blue.shade50;
                      borderColor = Colors.blue;
                    } else if (isWaiting) {
                      cardColor = Colors.yellow.shade50;
                      borderColor = FundipapColors.primaryYellow;
                    } else {
                      cardColor = Colors.white;
                      borderColor = Colors.black12;
                    }

                    return Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: borderColor,
                          width: isWaiting ? 1.6 : 1,
                        ),
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
                                (g['clientName'] as String)[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (badge > 0)
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
                                    '$badge',
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
                              g['clientName'],
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                            Builder(
                              builder: (_) {
                                final int transport =
                                    (g['transport'] as int?) ??
                                    (g['jobData']['transportFee'] as int?) ??
                                    0;
                                final int total =
                                    (g['total'] as int?) ??
                                    (g['jobData']['totalCost'] as int?) ??
                                    (g['jobData']['escrowAmount'] as int?) ??
                                    0;
                                if (transport > 0 && total > 0) {
                                  return Text(
                                    'KES $total total (incl. transport $transport)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            if (isPendingPrice)
                              Text(
                                'Waiting for client to confirm price review',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (isCountered)
                              Text(
                                'Client countered price',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
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
                          await _markThisClientAsRead(clientKey);
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
      ],
    );
  }
}
