import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_bell.dart';
import '../rating/rate_fundi_screen.dart';
import 'customer_home_header.dart';
import 'models/customer_home_models.dart';
import 'helpers/customer_home_utils.dart';
import 'widgets/customer_notifications_section.dart';
import '../home/widgets/pending/pending_section.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  Position? _userPos;
  bool _loadingLoc = true;
  Map<String, dynamic>? _me;
  int _completedJobs = 0;
  int _profilePct = 0;
  FilterType _pendingFilter = FilterType.all;

  final List<Map<String, dynamic>> _bids = [];
  StreamSubscription? _jobsSub;
  final Map<String, StreamSubscription> _bidsSubs = {};
  List<DocumentSnapshot> _activeJobs = [];
  StreamSubscription? _activeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getLocation();
      _loadMe();
      _loadCompletedCount();
      _enforcePendingRating();
      _initNotificationListeners();
    });
  }

  // ===== LISTENERS =====
  void _initNotificationListeners() {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _jobsSub?.cancel();
    _activeSub?.cancel();
    for (var s in _bidsSubs.values) s.cancel();
    _bidsSubs.clear();

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

  Future<void> _loadMe() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted)
      setState(() {
        _me = doc.data();
        _profilePct = calcProfilePct(_me);
      });
  }

  Future<void> _loadCompletedCount() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _completedJobs = snap.docs.length);
        });
  }

  Future<void> _getLocation() async {
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
          _userPos = pos;
          _loadingLoc = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  Future<void> _enforcePendingRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      var snap1 = await FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
      var snap2 = await FirebaseFirestore.instance
          .collection('jobs')
          .where('clientId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
      final Map<String, QueryDocumentSnapshot> map = {};
      for (var d in [...snap1.docs, ...snap2.docs]) map[d.id] = d;
      final unrated = map.values.where((d) {
        var data = d.data() as Map<String, dynamic>;
        bool notRated = data['clientRated'] != true;
        bool released =
            (data['escrowStatus'] ?? '') == 'released' ||
            (data['totalReleasedAmount'] ?? 0) != 0 ||
            (data['fundiPayoutAmount'] ?? 0) != 0;
        bool fundiConfirmed =
            data['fundiConfirmedPayment'] == true ||
            (data['fundiConfirmedPayment'] == null && released);
        return notRated && released && fundiConfirmed;
      }).toList();
      if (unrated.isNotEmpty && mounted) {
        var first = unrated.first;
        var data = first.data() as Map<String, dynamic>;
        String fundiId = (data['fundiId'] ?? data['assignedFundiId'] ?? '')
            .toString()
            .trim();
        String fundiName =
            (data['assignedFundiName'] ?? data['fundiDisplayName'] ?? 'Fundi')
                .toString();
        String trade = (data['trade'] ?? data['category'] ?? '').toString();
        Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => RateFundiScreen(
              jobId: first.id,
              fundiId: fundiId,
              fundiName: fundiName,
              trade: trade,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    await _getLocation();
    await _loadMe();
    _loadCompletedCount();
    _initNotificationListeners();
    if (mounted) setState(() {});
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
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Group notifications for header
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
        'jobData': {...b['jobData'], 'jobId': b['jobId']},
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
      grouped[doc.id] = {
        'jobId': doc.id,
        'fundiName': (job['assignedFundiName'] ?? 'Fundi').toString(),
        'fundiId': fundiId,
        'category': (job['title'] ?? job['category'] ?? 'Job').toString(),
        'jobData': {...job, 'jobId': doc.id},
        'latestAt': (job['updatedAt'] is Timestamp)
            ? (job['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        'type': 'active',
        'isRead': (job['customerHasUnread'] != true),
      };
    }
    var list = grouped.values.toList()
      ..sort(
        (a, b) =>
            (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime)),
      );
    Map<String, int> fundiUnreadCounts = {};
    for (var g in list) {
      if (g['isRead'] == false)
        fundiUnreadCounts[g['fundiId']] =
            (fundiUnreadCounts[g['fundiId']] ?? 0) + 1;
    }
    int totalTabCounter = fundiUnreadCounts.values.fold(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: FundipapColors.primaryYellow,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: FundipapColors.blackGray,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: CustomerHomeHeader(
                      me: _me,
                      profilePct: _profilePct,
                      completedJobs: _completedJobs,
                      onProfileTap: () {},
                    ),
                  ),
                  NotificationBell(userId: uid, iconColor: Colors.white),
                ],
              ),
            ),
          ),
          if (_loadingLoc)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverToBoxAdapter(
            child: CustomerNotificationsSection(
              groupedList: list,
              fundiUnreadCounts: fundiUnreadCounts,
              totalTabCounter: totalTabCounter,
              onMarkRead: _markThisFundiAsRead,
            ),
          ),
          SliverToBoxAdapter(
            child: CustomerPendingSection(
              uid: uid,
              pendingFilter: _pendingFilter,
              onFilterChanged: (v) => setState(() => _pendingFilter = v),
              userPos: _userPos,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
