import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'fundi_customer_timeline_page.dart';

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
  Set<String> _excludedJobIds = {};

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  void _initListeners() {
    _bidsSub?.cancel();
    _jobsSub?.cancel();
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
            if (_excludedJobIds.contains(jId)) continue;
            _acceptedBids.add({
              'jobId': jId,
              'bidId': b.id,
              'jobTitle': (bid['jobTitle'] ?? bid['title'] ?? 'Job').toString(),
              'clientName':
                  (bid['customerName'] ?? bid['clientName'] ?? 'Client')
                      .toString(),
              'clientId': (bid['customerId'] ?? '').toString(),
              'price': bid['price'] ?? 0,
              'totalCost': bid['totalCost'] ?? 0,
              'transportFee': bid['transportFee'] ?? 0,
              'createdAt': bid['updatedAt'] ?? bid['createdAt'],
              'isRead': bid['isReadByFundi'] == true,
            });
          }
          if (mounted) setState(() {});
        });

    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          List<DocumentSnapshot> mine = [];
          Set<String> excluded = {};
          for (var doc in snap.docs) {
            var job = doc.data();
            var status = (job['status'] ?? '').toString().toLowerCase();
            if (status.contains('cancel') || job['reposted'] == true) {
              excluded.add(doc.id);
              continue;
            }
            mine.add(doc);
          }
          _excludedJobIds = excluded;
          _assignedJobs = mine;
          if (mounted) setState(() {});
        });
  }

  Future<void> _onRefresh() async {
    _initListeners();
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _markThisClientAsRead(String clientKey) async {
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _acceptedBids.where((e) => e['clientId'] == clientKey)) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignedIds = _assignedJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};
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
      };
    }
    for (var doc in _assignedJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var title = (job['title'] ?? 'Job').toString();
      var cName = (job['customerName'] ?? job['clientName'] ?? 'Client')
          .toString();
      grouped[doc.id] = {
        'jobId': doc.id,
        'clientName': cName,
        'clientId': (job['customerId'] ?? cName).toString(),
        'category': title,
        'jobData': job,
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': job['fundiHasUnread'] != true,
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
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: FundipapColors.blackGray,
                            child: Text(
                              (g['clientName'] as String)[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
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
                            g['clientName'],
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
                            await _markThisClientAsRead(g['clientId']);
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
