import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../fundi_profile.dart';
import '../../../services/fundi_badge_service.dart';
import 'fundi_home_jobs_tab.dart';
import 'timeline/fundi_customer_timeline_page.dart';
import 'job_details_screen.dart';
import 'fundi_home_logic.dart';

class FundiHome extends StatefulWidget {
  const FundiHome({super.key});
  @override
  State<FundiHome> createState() => _FundiHomeState();
}

class _FundiHomeState extends State<FundiHome> {
  Map<String, dynamic>? me;
  int completedJobs = 0;
  double totalEarned = 0;
  int profilePct = 0;
  String mySkill = 'General';
  Position? currentPos;
  bool _loadingLoc = true;
  String search = '';

  // notifications + pending
  final List<Map<String, dynamic>> _bids = [];
  StreamSubscription? _bidsSub;
  List<DocumentSnapshot> _assignedJobs = [];
  StreamSubscription? _assignedSub;
  Set<String> _excludedJobIds = {};
  final Map<String, DocumentSnapshot> _jobsMap = {};

  @override
  void initState() {
    super.initState();
    _loadMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocation();
      _initNotificationListeners();
    });
  }

  Future<void> _loadMe() async {
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return;
      var data = doc.data()!;
      if (!mounted) return;
      setState(() {
        me = data;
        completedJobs = (data['completedJobs'] ?? data['jobsDone'] ?? 0) as int;
        totalEarned = (data['totalEarned'] ?? data['totalEarnings'] ?? 0)
            .toDouble();
        mySkill = (data['skill'] ?? data['profession'] ?? 'General').toString();
        int pct = 0;
        if ((data['photoUrl'] ?? data['profilePhotoUrl']) != null) pct += 20;
        if ((data['bio'] ?? '').toString().length > 10) pct += 20;
        if ((data['skill'] ?? data['profession']) != null) pct += 20;
        if (data['idUploaded'] == true || data['nationalIdUrl'] != null)
          pct += 20;
        if ((data['phone'] ?? '').toString().isNotEmpty) pct += 20;
        profilePct = pct.clamp(0, 100);
      });
    } catch (_) {}
  }

  Future<void> _loadLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _loadingLoc = false);
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        if (mounted) setState(() => _loadingLoc = false);
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted)
        setState(() {
          currentPos = pos;
          _loadingLoc = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  void _mergeAssigned(List<DocumentSnapshot> docs) {
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

  void _initNotificationListeners() {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _bidsSub?.cancel();
    _assignedSub?.cancel();
    _bidsSub = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          _bids.clear();
          for (var b in snap.docs) {
            var bid = Map<String, dynamic>.from(b.data());
            if (bid['deletedForFundi'] == true) continue;
            var jId = (bid['jobId'] ?? b.reference.parent.parent?.id ?? '')
                .toString();
            if (jId.isEmpty || _excludedJobIds.contains(jId)) continue;
            _bids.add({
              'jobId': jId,
              'bidId': b.id,
              'jobTitle': bid['jobTitle'] ?? '',
              'jobData': {'title': bid['jobTitle'] ?? '', 'jobId': jId},
              'bidData': bid,
              'clientName':
                  bid['customerName'] ?? bid['clientName'] ?? 'Client',
              'clientId': (bid['customerId'] ?? '').toString(),
              'status': bid['status'] ?? 'pending',
              'createdAt':
                  bid['counterAt'] ?? bid['updatedAt'] ?? bid['createdAt'],
              'isRead':
                  bid['isReadByFundi'] == true ||
                  bid['clientCounterSeenByFundi'] == true,
              'price': bid['clientCounterAmount'] ?? bid['amount'] ?? 0,
            });
          }
          if (mounted) setState(() {});
        });
    _assignedSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
        .where('status', whereNotIn: ['completed', 'cancelled', 'closed'])
        .snapshots()
        .listen((snap) => _mergeAssigned(snap.docs));
  }

  Future<void> _markRead(String clientKey, String jobId) async {
    setState(() {
      for (var b in _bids) {
        if (b['clientId'] == clientKey || b['jobId'] == jobId)
          b['isRead'] = true;
      }
    });
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _bids.where(
        (e) => e['clientId'] == clientKey || e['jobId'] == jobId,
      )) {
        batch.update(
          FirebaseFirestore.instance
              .collection('jobs')
              .doc(b['jobId'])
              .collection('bids')
              .doc(b['bidId']),
          {'isReadByFundi': true, 'clientCounterSeenByFundi': true},
        );
      }
      await batch.commit();
    } catch (_) {}
  }

  int relevanceScore(Map<String, dynamic> job) {
    int s = 0;
    var cat = (job['category'] ?? '').toString().toLowerCase();
    if (mySkill.toLowerCase() == 'general')
      s += 1;
    else if (cat.contains(mySkill.toLowerCase()))
      s += 10;
    var title = (job['title'] ?? '').toString().toLowerCase();
    if (title.contains(mySkill.toLowerCase())) s += 5;
    return s;
  }

  Future<void> bidForJob(BuildContext context, Map<String, dynamic> job) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailsScreen(
          job: job,
          distanceKm: FundiHomeLogic.distanceKm(currentPos, job),
          me: me,
          completedJobs: completedJobs,
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadMe();
    await _loadLocation();
    _initNotificationListeners();
    if (mounted) setState(() {});
  }

  Color _badgeColor(BadgeLevel level) {
    switch (level) {
      case BadgeLevel.gold:
        return const Color(0xFFFFD700);
      case BadgeLevel.silver:
        return const Color(0xFFC0C0C0);
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.none:
        return Colors.transparent;
    }
  }

  @override
  void dispose() {
    _bidsSub?.cancel();
    _assignedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    BadgeResult? badgeResult;
    if (me != null) {
      try {
        badgeResult = FundiBadgeService.calculate(me!, me!);
      } catch (_) {}
    }
    BadgeLevel level = badgeResult?.level ?? BadgeLevel.none;
    bool hasBadge = level != BadgeLevel.none;

    // notifications grouped like CustomerHome
    final assignedIds = _assignedJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};
    for (var b in _bids) {
      if (assignedIds.contains(b['jobId'])) continue;
      if (_excludedJobIds.contains(b['jobId'])) continue;
      String key = "${b['jobId']}_${b['clientId']}";
      var status = (b['status'] ?? '').toString();
      bool isCounter = status == 'countered' || status == 'client_counter';
      String category = isCounter
          ? 'Client countered your labour charges'
          : 'Bid sent - KES ${b['price']} • ${b['jobTitle']}';
      grouped[key] = {
        'jobId': b['jobId'],
        'bidId': b['bidId'],
        'clientName': b['clientName'],
        'clientId': b['clientId'],
        'category': category,
        'jobData': b['jobData'],
        'bidData': b['bidData'],
        'latestAt': (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'type': isCounter ? 'counter' : 'bid_sent',
        'isRead': b['isRead'] == true,
      };
    }
    var notifList = grouped.values.toList()
      ..sort(
        (a, b) =>
            (b['latestAt'] as DateTime).compareTo(a['latestAt'] as DateTime),
      );
    int totalUnread = notifList.where((g) => g['isRead'] == false).length;

    return Scaffold(
      backgroundColor: FundipapColors.blackGray,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: FundipapColors.primaryYellow,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. MINIMAL PROFILE BANNER - no badge banner, no earnings banner, no bio, no profile banners
            SliverToBoxAdapter(
              child: Container(
                color: FundipapColors.blackGray,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: 74,
                          height: 74,
                          child: CircularProgressIndicator(
                            value: profilePct / 100,
                            strokeWidth: 3,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(
                              profilePct == 100
                                  ? FundipapColors.greenSuccess
                                  : FundipapColors.primaryYellow,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: CircleAvatar(
                            radius: 29,
                            backgroundColor: FundipapColors.primaryYellow,
                            backgroundImage: me?['photoUrl'] != null
                                ? NetworkImage(me!['photoUrl'])
                                : null,
                            child: me?['photoUrl'] == null
                                ? Text(
                                    (me?['name'] ?? 'F')[0].toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FundiProfile(),
                                ),
                              );
                              _loadMe();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: FundipapColors.primaryYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Habari, ${me?['name'] ?? 'Fundi'}',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            me?['profession'] ?? me?['skill'] ?? 'Fundi',
                            style: GoogleFonts.inter(
                              color: FundipapColors.primaryYellow,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedJobs jobs',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // RIGHT: badge icon above TOTAL EARNED - bigger as requested, value from FundiEarningsCard calculation
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasBadge)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: _badgeColor(level),
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _badgeColor(level).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _badgeColor(level)),
                                ),
                                child: Text(
                                  level.name.toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: _badgeColor(level),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (hasBadge) const SizedBox(height: 6),
                        // TOTAL EARNED bigger - from FundiEarningsCard totalEarned (labour -5% + transport)
                        Text(
                          'TOTAL EARNED',
                          style: GoogleFonts.montserrat(
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'KES ${totalEarned.toStringAsFixed(0)}',
                          style: GoogleFonts.montserrat(
                            color: const Color.fromARGB(255, 36, 255, 7),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_loadingLoc)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  color: FundipapColors.primaryYellow,
                ),
              ),

            // 2. NOTIFICATIONS - below header like client
            SliverToBoxAdapter(
              child: Container(
                color: FundipapColors.blackGray,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          totalUnread > 0
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          totalUnread > 0
                              ? '$totalUnread new'
                              : 'Notifications',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (totalUnread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: FundipapColors.primaryYellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalUnread',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (notifList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No notifications',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ...notifList.take(5).map((g) {
                      bool isCounter = g['type'] == 'counter';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCounter
                              ? Colors.orange.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCounter
                                ? Colors.orange.shade300
                                : Colors.transparent,
                            width: isCounter ? 1.2 : 0,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isCounter
                                ? Colors.orange.shade700
                                : FundipapColors.blackGray,
                            child: Icon(
                              isCounter ? Icons.compare_arrows : Icons.send,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            g['category'],
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${g['clientName']} • Tap to view',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                          trailing: g['isRead'] == false
                              ? const Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 8,
                                )
                              : const Icon(Icons.chevron_right, size: 16),
                          onTap: () async {
                            await _markRead(g['clientId'], g['jobId']);
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
                    }),
                  ],
                ),
              ),
            ),

            // 3. PENDING JOBS - after notifications like client
            SliverToBoxAdapter(
              child: Container(
                color: FundipapColors.blackGray,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Jobs',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_assignedJobs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No pending jobs',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ..._assignedJobs.take(3).map((doc) {
                      var job = doc.data() as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (job['title'] ?? 'Job').toString(),
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    (job['status'] ?? 'assigned').toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 4. JOBS NEAR YOU - continue normally after pending, using your FundiHomeJobsTab + FundiHomeJobList
            SliverToBoxAdapter(
              child: Container(
                color: FundipapColors.blackGray,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                child: FundiHomeJobsTab(
                  search: search,
                  onSearchChanged: (v) =>
                      setState(() => search = v.toLowerCase()),
                  mySkill: mySkill,
                  me: me,
                  completedJobs: completedJobs,
                  relevanceScore: relevanceScore,
                  onBid: bidForJob,
                  currentPos: currentPos,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
