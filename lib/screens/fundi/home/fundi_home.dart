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
import 'package:fundipap/widgets/animated_waiting_card.dart';
import '../../../services/fundi_waiting_state_service.dart';
import '../rating/rate_client_screen.dart';
import 'fundi_home_actions_mixin.dart';
import '../../../services/fundi_penalty_service.dart';

class FundiHome extends StatefulWidget {
  const FundiHome({super.key});
  @override
  State<FundiHome> createState() => _FundiHomeState();
}

class _FundiHomeState extends State<FundiHome> with FundiHomeActionsMixin {
  Map<String, dynamic>? me;
  int completedJobs = 0;
  double totalEarned = 0;
  int profilePct = 0;
  String mySkill = 'General';
  Position? currentPos;
  bool _loadingLoc = true;
  String search = '';

  final List<Map<String, dynamic>> _bids = [];
  StreamSubscription? _bidsSub;
  List<DocumentSnapshot> _assignedJobs = [];
  StreamSubscription? _assignedSub;
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

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    if (v is Timestamp) return true;
    return fb;
  }

  @override
  void initState() {
    super.initState();
    initOnlineStatus();
    _loadMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationListeners();
      _enforceMandatoryRating();
    });
  }

  @override
  void dispose() {
    disposeTracking();
    _bidsSub?.cancel();
    _assignedSub?.cancel();
    super.dispose();
  }

  Future<void> _enforceMandatoryRating() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var q = await FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
        .where('escrowStatus', isEqualTo: 'released')
        .where('fundiConfirmedPayment', isEqualTo: true)
        .get();

    for (var doc in q.docs) {
      var data = doc.data();
      bool rated =
          (data['fundiRated'] == true) || (data['fundiRatedClient'] == true);
      if (!rated) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => RateClientScreen(
              jobId: doc.id,
              clientId: (data['customerId'] ?? data['clientId'] ?? '')
                  .toString(),
              clientName:
                  (data['customerName'] ?? data['clientName'] ?? 'Client')
                      .toString(),
              trade: (data['title'] ?? data['trade'] ?? '').toString(),
            ),
          ),
          (r) => false,
        );
        break;
      }
    }
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

  void _initNotificationListeners() {
    _bidsSub?.cancel();
    _assignedSub?.cancel();
    _jobsMap.clear();
    _excludedJobIds.clear();
    _assignedJobs = [];
    _bids.clear();
    if (mounted) setState(() {});

    var uid = FirebaseAuth.instance.currentUser!.uid;

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
            if (jId.isEmpty) continue;
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
              'price': _toInt(
                bid['clientCounterAmount'] ??
                    bid['lastCounterAmount'] ??
                    bid['lastCounterPrice'] ??
                    bid['amount'] ??
                    bid['price'] ??
                    0,
              ),
            });
          }
          if (mounted) setState(() {});
        });

    // FIX: DO NOT exclude completed - we need it to show Client released
    _assignedSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          _jobsMap.clear();
          // keep excluded list but rebuild
          for (var d in snap.docs) {
            var job = d.data();
            var status = (job['status'] ?? '').toString().toLowerCase();
            bool isCancelled =
                status.contains('cancel') ||
                _toBool(job['cancelled']) ||
                _toBool(job['autoCancelled']) ||
                job['reposted'] == true;
            if (isCancelled) {
              _excludedJobIds.add(d.id);
              continue;
            }
            _excludedJobIds.remove(d.id);
            _jobsMap[d.id] = d;
          }
          _assignedJobs = _jobsMap.values.toList();
          if (mounted) setState(() {});
        });
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
    // ONLINE CHECK
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Go Online first to see and bid for jobs'),
        ),
      );
      return;
    }

    // SUSPENSION CHECK (from mixin)
    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool canBid = await FundiPenaltyService.canFundiBid(uid);
    if (!canBid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('You are suspended for cancelling jobs.'),
          ),
        );
      }
      return;
    }

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
  Widget build(BuildContext context) {
    BadgeResult? badgeResult;
    if (me != null) {
      try {
        badgeResult = FundiBadgeService.calculate(me!, me!);
      } catch (_) {}
    }
    BadgeLevel level = badgeResult?.level ?? BadgeLevel.none;
    bool hasBadge = level != BadgeLevel.none;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final assignedIds = _assignedJobs.map((d) => d.id).toSet();
    final assignedMap = {
      for (var d in _assignedJobs) d.id: (d.data() as Map<String, dynamic>),
    };
    Map<String, Map<String, dynamic>> grouped = {};
    for (var b in _bids) {
      if (_excludedJobIds.contains(b['jobId'])) continue;
      var jobDataForNotif =
          assignedMap[b['jobId']] ??
          (b['jobData'] as Map<String, dynamic>? ?? <String, dynamic>{});
      var bidDataForNotif = (b['bidData'] as Map<String, dynamic>?) ?? b;

      // FIX: ghost Bid sent after cancel - if job not in assignedMap and bid was accepted/withdrawn, skip
      bool isInAssigned = assignedMap.containsKey(b['jobId']);
      String bStatus = (bidDataForNotif['status'] ?? '')
          .toString()
          .toLowerCase();
      if (!isInAssigned &&
          (bStatus == 'accepted' ||
              bStatus == 'withdrawn' ||
              bStatus.contains('cancel')))
        continue;

      var jobStatusNotif = (jobDataForNotif['status'] ?? '')
          .toString()
          .toLowerCase();
      if (jobStatusNotif.contains('cancel') ||
          _toBool(jobDataForNotif['cancelled']) ||
          _toBool(jobDataForNotif['autoCancelled']))
        continue;
      FundiWaitingState? ws = getFundiWaitingState(
        job: jobDataForNotif,
        bid: bidDataForNotif,
        counterOffers: [],
        uid: uid,
      );
      String category;
      FundiWaitingType waitingType;
      if (ws != null) {
        category = ws.title;
        waitingType = ws.type;
      } else {
        var escrow = (jobDataForNotif['escrowStatus']?.toString() ?? 'pending')
            .toLowerCase();
        bool escrowDone = ['held', 'paid', 'released'].contains(escrow);
        bool siteDone =
            _toBool(jobDataForNotif['siteVisitDone']) ||
            _toBool(jobDataForNotif['siteVisited']) ||
            jobDataForNotif['siteVisitedAt'] != null;
        var renego = jobDataForNotif['renegotiation'] as Map<String, dynamic>?;
        bool renegoPending =
            renego != null &&
            renego['requested'] == true &&
            (renego['status'] ?? 'pending') == 'pending';
        if (assignedIds.contains(b['jobId']) &&
            escrowDone &&
            siteDone &&
            !renegoPending)
          continue;
        category = 'Bid sent - KES ${b['price']} • ${b['jobTitle']}';
        waitingType = FundiWaitingType.bidSent;
      }
      String key = "${b['jobId']}_${b['clientId']}";
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
        'isRead': b['isRead'] == true,
        'price': b['price'],
        'waitingType': waitingType,
      };
    }
    var notifList = grouped.values.toList()
      ..sort(
        (a, b) =>
            (b['latestAt'] as DateTime).compareTo(a['latestAt'] as DateTime),
      );
    int totalUnread = notifList.where((g) => g['isRead'] == false).length;
    int displayCount = totalUnread > 0 ? totalUnread : notifList.length;

    return Scaffold(
      backgroundColor: FundipapColors.blackGray,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: FundipapColors.primaryYellow,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
            // ONLINE TOGGLE - ADD HERE
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline ? Colors.green : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline
                              ? 'Online - Receiving Jobs'
                              : 'Offline - Not receiving',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isOnline
                                ? Colors.green.shade800
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isOnline,
                      activeColor: Colors.green,
                      onChanged: (_) => toggleOnline(context),
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

            // FIXED NOTIFICATIONS - ALL WAITING STATES ORANGE
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
                          displayCount > 0
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Notifications',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (displayCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$displayCount new',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
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
                      FundiWaitingType wt =
                          g['waitingType'] as FundiWaitingType;
                      bool isOrange =
                          wt == FundiWaitingType.bidSent ||
                          wt == FundiWaitingType.clientCounter ||
                          wt == FundiWaitingType.myCounter ||
                          wt == FundiWaitingType.waitingEscrow ||
                          wt == FundiWaitingType.waitingNewPriceApproval ||
                          wt == FundiWaitingType.escrowLocked ||
                          wt == FundiWaitingType.siteVisited ||
                          wt == FundiWaitingType.travelling ||
                          wt == FundiWaitingType.working ||
                          wt == FundiWaitingType.jobCompleted;

                      String msg;
                      if (wt == FundiWaitingType.clientCounter) {
                        msg =
                            "${g['clientName']} • Tap to view • Client countered!";
                      } else if (wt == FundiWaitingType.waitingEscrow)
                        msg =
                            "${g['clientName']} • Tap to view • Waiting to lock escrow";
                      else if (wt == FundiWaitingType.waitingNewPriceApproval)
                        msg =
                            "${g['clientName']} • Tap to view • Waiting extra approval";
                      else if (wt == FundiWaitingType.myCounter)
                        msg =
                            "${g['clientName']} • Tap to view • Waiting for client reaction";
                      else if (wt == FundiWaitingType.escrowLocked)
                        msg =
                            "${g['clientName']} • Tap to view • Escrow locked - Start site visit";
                      else if (wt == FundiWaitingType.travelling)
                        msg =
                            "${g['clientName']} • Tap to view • You are on the way";
                      else if (wt == FundiWaitingType.siteVisited)
                        msg =
                            "${g['clientName']} • Tap to view • Waiting for you to start work";
                      else
                        msg =
                            "${g['clientName']} • Tap to view • Waiting for client";

                      if (isOrange) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              OrangeAnimatedWaitingCard(
                                title: g['category'],
                                message: msg,
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
                              Positioned(
                                top: -6,
                                left: 30,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: FundipapColors.blackGray,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '$displayCount',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      // GREEN - escrowLocked, travelling, siteVisited
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.green.shade700,
                            child: const Icon(
                              Icons.check_circle,
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
                          trailing: const Icon(Icons.chevron_right, size: 16),
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
            SliverToBoxAdapter(
              child: Container(
                color: FundipapColors.blackGray,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                child: isOnline
                    ? FundiHomeJobsTab(
                        search: search,
                        onSearchChanged: (v) =>
                            setState(() => search = v.toLowerCase()),
                        mySkill: mySkill,
                        me: me,
                        completedJobs: completedJobs,
                        relevanceScore: relevanceScore,
                        onBid: bidForJob,
                        currentPos: currentPos,
                      )
                    : Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.wifi_off,
                              size: 48,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You are Offline',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Go Online to see nearby jobs',
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
