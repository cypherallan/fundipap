import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price.dart';
import 'fundi_visit_customer_tab.dart';

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
          var job = doc.data() as Map<String, dynamic>;
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
        continue; // skip hardcoded empty
      String key = "${b['jobId']}_${b['clientId']}";
      grouped[key] = {
        'jobId': b['jobId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': b['jobTitle'],
        'jobData': {
          'title': b['jobTitle'],
          'agreedPrice': b['price'],
          'escrowStatus': 'pending',
          'status': 'accepted',
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
      if (title.isEmpty || cName.isEmpty) continue; // no hardcoded Job/Client
      var clientId = (job['customerId'] ?? cName).toString();
      grouped[doc.id] = {
        'jobId': doc.id,
        'clientName': cName,
        'clientId': clientId,
        'category': title,
        'jobData': job,
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'isRead': job['fundiHasUnread'] != true,
      };
    }

    var list = grouped.values.toList()
      ..sort(
        (a, b) =>
            (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime)),
      );

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
                    bool unread = badge > 0;
                    bool isDone =
                        (g['jobData']['siteVisitDone'] == true) ||
                        (g['jobData']['status'] == 'in_progress') ||
                        (g['jobData']['status'] == 'job_completed');
                    String escrow = (g['jobData']['escrowStatus'] ?? 'pending')
                        .toString();
                    bool locked =
                        escrow == 'held' ||
                        escrow == 'paid' ||
                        escrow == 'locked';

                    Color bg;
                    Color border;
                    if (isDone || locked) {
                      bg = Colors.green.shade50;
                      border = Colors.green;
                    } else if (unread) {
                      bg = Colors.yellow.shade50;
                      border = FundipapColors.primaryYellow;
                    } else {
                      bg = Colors.white;
                      border = Colors.black12;
                    }

                    return Card(
                      color: bg,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: border),
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
                                (g['clientName'] as String).isNotEmpty
                                    ? (g['clientName'] as String)[0]
                                          .toUpperCase()
                                    : 'C',
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
                        subtitle: Text(
                          g['clientName'],
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        trailing: unread
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
                              builder: (_) => _FundiJobDetailPage(
                                jobId: g['jobId'],
                                job: g['jobData'],
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

class _FundiJobDetailPage extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> job;
  final String clientName;
  final String jobTitle;
  const _FundiJobDetailPage({
    required this.jobId,
    required this.job,
    required this.clientName,
    required this.jobTitle,
  });

  Future<void> _startSiteVisit(BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitCustomerScreen(jobId: jobId, job: job),
      ),
    );
  }

  void _openNewPrice(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundiRequestNewPriceScreen(jobId: jobId, job: job),
      ),
    );
  }

  Future<void> _startJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    var status = (job['status'] ?? '').toString();
    bool siteDone = job['siteVisitDone'] == true;
    bool travelling = job['travelling'] == true || status == 'travelling';
    double amount =
        ((job['escrowAmount'] ?? job['agreedPrice'] ?? job['budget'] ?? 0)
                as num)
            .toDouble();
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    bool locked = escrow == 'held' || escrow == 'paid' || escrow == 'locked';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FUNDI PAP - FUNDI'),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: FundipapColors.blackGray,
                  child: Text(
                    clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      jobTitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (locked || siteDone)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: locked || siteDone
                        ? Colors.green.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: locked || siteDone ? Colors.green : Colors.black12,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (escrow == 'pending')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            'Bid accepted. Waiting for $clientName to lock KES ${amount.toInt()} to escrow',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (locked &&
                          (status == 'assigned' || status == 'confirmed') &&
                          !travelling &&
                          !siteDone)
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Escrow locked KES ${amount.toInt()} by $clientName',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.blackGray,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                ),
                                icon: const Icon(Icons.navigation),
                                label: const Text(
                                  'Start Site Visit - Must Visit First',
                                ),
                                onPressed: () => _startSiteVisit(context),
                              ),
                            ),
                          ],
                        ),
                      if (travelling && !siteDone)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            'You are on the way to $clientName',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      if (siteDone &&
                          status == 'site_visit' &&
                          (reneg == null || reneg['requested'] != true))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ Site visited - Green as reacted',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _startJob,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          FundipapColors.greenSuccess,
                                    ),
                                    child: const Text(
                                      'START JOB',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _openNewPrice(context),
                                    child: const Text('Request New Price'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (status == 'in_progress')
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Working - stays green, not deleted',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
