import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import '../rating/rate_fundi_screen.dart';
import 'customer_home_header.dart';
import 'models/customer_home_models.dart';
import 'helpers/customer_home_utils.dart';
import 'widgets/customer_notifications_section.dart';
import 'widgets/pending/pending_section.dart';

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

  void _initNotificationListeners() {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _jobsSub?.cancel();
    _activeSub?.cancel();
    for (var s in _bidsSubs.values) s.cancel();
    _bidsSubs.clear();

    // FIX: include counter_accepted so notification stays after restart
    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            'open',
            'bidding',
            'assigned',
            'confirmed',
            'counter_accepted',
            'counter_accepted_by_fundi',
          ],
        )
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
                    var bidRaw = b.data();
                    var bid = Map<String, dynamic>.from(bidRaw);
                    if (bid['deletedForFundi'] == true) continue;
                    var jobRaw = jobDoc.data();
                    _bids.add({
                      'jobId': jobId,
                      'bidId': b.id,
                      'jobTitle': jobRaw['title'] ?? '',
                      'jobData': Map<String, dynamic>.from(jobRaw),
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
            'awaiting_extra_escrow',
            'renegotiation_countered_by_client',
            'countered_by_client',
            'waiting_for_client_to_buy_parts',
            'fundi_buying_parts',
            'renegotiation_countered',
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
        // FIX: also check jobId == fundiKey because grouped uses jobId as key
        if (b['fundiId'] == fundiKey ||
            b['fundiName'] == fundiKey ||
            b['jobId'] == fundiKey)
          b['isRead'] = true;
      }
    });
    try {
      var batch = FirebaseFirestore.instance.batch();
      for (var b in _bids.where(
        (e) =>
            e['fundiId'] == fundiKey ||
            e['fundiName'] == fundiKey ||
            e['jobId'] == fundiKey,
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
        var j = Map<String, dynamic>.from(d.data() as Map);
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
        var data = Map<String, dynamic>.from(d.data() as Map);
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
        var data = Map<String, dynamic>.from(first.data() as Map);
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
    final activeJobIds = _activeJobs.map((d) => d.id).toSet();
    Map<String, Map<String, dynamic>> grouped = {};
    Map<String, List<Map<String, dynamic>>> bidsByJob = {};
    for (var b in _bids) {
      if (activeJobIds.contains(b['jobId'])) continue;
      var jobDataRaw = b['jobData'] as Map;
      var jobDataSafe = Map<String, dynamic>.from(jobDataRaw);
      if ((jobDataSafe['status'] ?? '').toString() == 'completed') continue;
      bidsByJob.putIfAbsent(b['jobId'].toString(), () => []).add(b);
    }

    for (var entry in bidsByJob.entries) {
      entry.value.sort((a, b) {
        var aT = a['createdAt'] is Timestamp
            ? (a['createdAt'] as Timestamp).toDate()
            : DateTime.now();
        var bT = b['createdAt'] is Timestamp
            ? (b['createdAt'] as Timestamp).toDate()
            : DateTime.now();
        return bT.compareTo(aT);
      });

      // FIX: if any bid is accepted counter, prioritize it
      var acceptedBids = entry.value
          .where(
            (x) => (x['status'] ?? '').toString().contains(
              'counter_accepted_by_fundi',
            ),
          )
          .toList();
      var latest = acceptedBids.isNotEmpty
          ? acceptedBids.first
          : entry.value.first;

      var jobDataRaw = latest['jobData'] as Map;
      var jobDataSafe = Map<String, dynamic>.from(jobDataRaw);
      var bidDataSafe = Map<String, dynamic>.from(latest['bidData'] as Map);
      var unread = entry.value.where((x) => x['isRead'] != true).length;

      bool isAccepted = (latest['status'] ?? '').toString().contains(
        'counter_accepted_by_fundi',
      );

      grouped[entry.key] = {
        'jobId': entry.key,
        'fundiName': isAccepted
            ? (latest['fundiName'] ?? 'Fundi').toString()
            : entry.value.length == 1
            ? (latest['fundiName'] ?? 'Fundi').toString()
            : '${entry.value.length} fundis',
        'fundiId': entry.key,
        'category':
            (jobDataSafe['title'] ??
                    latest['jobTitle'] ??
                    jobDataSafe['category'] ??
                    'Job')
                .toString(),
        'jobData': {...jobDataSafe, 'jobId': entry.key},
        'bidData': bidDataSafe,
        'bidId': (latest['bidId'] ?? '').toString(),
        'bidCount': entry.value.length,
        'bidStatus': (latest['status'] ?? '').toString(), // FIX: send status
        'agreedPrice':
            bidDataSafe['agreedPrice'] ??
            bidDataSafe['clientCounterAmount'] ??
            0,
        'clientCounterAmount': bidDataSafe['clientCounterAmount'] ?? 0,
        'latestAt': (latest['createdAt'] is Timestamp)
            ? (latest['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        'type': isAccepted ? 'counter_accepted_by_fundi' : 'bid',
        'isPendingBid': true,
        'isRead': isAccepted
            ? false
            : unread == 0, // FIX: accepted always shows as new until proceed
      };
    }
    for (var doc in _activeJobs) {
      var job = Map<String, dynamic>.from(doc.data() as Map);
      if ((job['status'] ?? '').toString() == 'completed') continue;
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

    // FIX: sort accepted counters to top
    list.sort((a, b) {
      bool aAcc =
          (a['bidStatus'] ?? '').toString().contains(
            'counter_accepted_by_fundi',
          ) ||
          a['type'] == 'counter_accepted_by_fundi';
      bool bAcc =
          (b['bidStatus'] ?? '').toString().contains(
            'counter_accepted_by_fundi',
          ) ||
          b['type'] == 'counter_accepted_by_fundi';
      if (aAcc && !bAcc) return -1;
      if (!aAcc && bAcc) return 1;
      return (b['latestAt'] as DateTime).compareTo((a['latestAt'] as DateTime));
    });

    Map<String, int> fundiUnreadCounts = {};
    for (var g in list) {
      if (g['isRead'] == false) {
        fundiUnreadCounts[g['fundiId'].toString()] =
            (fundiUnreadCounts[g['fundiId'].toString()] ?? 0) + 1;
      }
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
