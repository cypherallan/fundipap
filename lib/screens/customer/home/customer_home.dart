import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_bell.dart';
import '../../../widgets/fundi_badge_chip.dart';
import '../../../services/fundi_badge_service.dart';
import '../../../widgets/animated_waiting_card.dart';
import 'customer_home_header.dart';
import '../rating/rate_fundi_screen.dart';
import '../confirm/confirm_fundi_page.dart';
import 'customer_fundi_timeline_page.dart';
import '../post_new_job_screen.dart';
import '../../customer/confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';

enum FilterType { all, verified, topRated, highReferral, clean, badge }

class _BidWithFundi {
  final QueryDocumentSnapshot bidDoc;
  final Map<String, dynamic> bid;
  final BadgeLevel level;
  final bool verified;
  final int referrals;
  final int jobsDone;
  final double rating;
  final int penalty;
  final double distanceKm;
  _BidWithFundi({
    required this.bidDoc,
    required this.bid,
    required this.level,
    required this.verified,
    required this.referrals,
    required this.jobsDone,
    required this.rating,
    required this.penalty,
    required this.distanceKm,
  });
}

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

  // Helpers duplicated from timeline
  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fb;
  }

  Future<void> _payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  BadgeLevel _parseBadge(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'gold':
        return BadgeLevel.gold;
      case 'silver':
        return BadgeLevel.silver;
      case 'bronze':
        return BadgeLevel.bronze;
      default:
        return BadgeLevel.none;
    }
  }

  double _getFundiLat(Map<String, dynamic>? f) {
    if (f == null) return 0;
    if (f['lat'] != null) return (f['lat'] as num).toDouble();
    if (f['latitude'] != null) return (f['latitude'] as num).toDouble();
    if (f['location'] is GeoPoint) return (f['location'] as GeoPoint).latitude;
    return 0;
  }

  double _getFundiLng(Map<String, dynamic>? f) {
    if (f == null) return 0;
    if (f['lng'] != null) return (f['lng'] as num).toDouble();
    if (f['longitude'] != null) return (f['longitude'] as num).toDouble();
    if (f['location'] is GeoPoint) return (f['location'] as GeoPoint).longitude;
    return 0;
  }

  Future<List<_BidWithFundi>> _enrichBids(
    List<QueryDocumentSnapshot> bids,
  ) async {
    return Future.wait(
      bids.map((b) async {
        var m = b.data() as Map<String, dynamic>;
        var fid = (m['fundiId'] ?? m['uid'] ?? '').toString();
        Map<String, dynamic>? f;
        if (fid.isNotEmpty) {
          var d = await FirebaseFirestore.instance
              .collection('users')
              .doc(fid)
              .get();
          f = d.data();
        }
        double dist = 0;
        if (_userPos != null && f != null) {
          double fLat = _getFundiLat(f);
          double fLng = _getFundiLng(f);
          if (fLat != 0 && fLng != 0) {
            dist =
                Geolocator.distanceBetween(
                  _userPos!.latitude,
                  _userPos!.longitude,
                  fLat,
                  fLng,
                ) /
                1000;
          }
        }
        return _BidWithFundi(
          bidDoc: b,
          bid: m,
          level: _parseBadge(f?['badgeLevel']),
          verified: f?['isVerifiedFundi'] == true,
          referrals: f?['referralCount'] ?? 0,
          jobsDone: f?['completedJobs'] ?? 0,
          rating: (f?['avgRating'] ?? 0).toDouble(),
          penalty: f?['penaltyScore'] ?? 0,
          distanceKm: dist,
        );
      }),
    );
  }

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

  Future<void> _deleteJob(String jobId) async {
    var bids = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .get();
    for (var d in bids.docs) await d.reference.delete();
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
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
        String fundiId =
            (data['fundiId'] ??
                    data['assignedFundiId'] ??
                    data['acceptedFundiId'] ??
                    '')
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

  Future<void> _loadMe() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _me = doc.data();
        _profilePct = _calcProfilePct(_me);
      });
    }
  }

  int _calcProfilePct(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int total = 5, done = 0;
    if ((data['name'] ?? '').toString().isNotEmpty) done++;
    if ((data['phone'] ?? '').toString().isNotEmpty) done++;
    if ((data['photoUrl'] ?? data['profileImage'] ?? '').toString().isNotEmpty)
      done++;
    if ((data['location'] ?? data['address'] ?? '').toString().isNotEmpty)
      done++;
    if ((data['email'] ?? '').toString().isNotEmpty) done++;
    return ((done / total) * 100).round();
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
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLoc = false);
        return;
      }
      if (perm == LocationPermission.denied) {
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

  Widget _timelineCard({
    required String title,
    required String body,
    required IconData icon,
    bool isDone = false,
    Widget? action,
    Widget? extra,
  }) {
    return Card(
      color: isDone ? Colors.green.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDone ? Colors.green : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isDone)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                if (isDone) const SizedBox(width: 6),
                Icon(
                  icon,
                  size: 18,
                  color: isDone ? Colors.green : Colors.black87,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isDone ? Colors.green.shade800 : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(body, style: GoogleFonts.inter(fontSize: 11)),
            if (extra != null) ...[const SizedBox(height: 6), extra],
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }

  Widget _buildHomeStatus(Map<String, dynamic> rawJob) {
    var job = rawJob;
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    var status = (job['status'] ?? '').toString();
    bool siteDone =
        _toBool(job['siteVisitDone']) || _toBool(job['siteVisited']);
    bool isTravelling =
        _toBool(job['travelling']) &&
        _toBool(job['siteVisitStarted']) &&
        !siteDone;
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String renegStatus = (reneg?['status'] ?? '').toString();
    String phase = (reneg?['currentPhase'] ?? '').toString();
    bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');
    int labour = _toInt(
      job['laborCost'] ?? job['agreedPrice'] ?? job['acceptedBidAmount'] ?? 0,
    );
    int transport = _toInt(job['transportFee'] ?? 0);
    int clientAppFee = _toInt(job['clientAppFee'] ?? (labour * 0.05).round());
    int totalToPay = _toInt(
      job['totalClientPays'] ??
          job['totalCost'] ??
          labour + transport + clientAppFee,
    );
    int alreadyLocked = _toInt(job['escrowAmount'] ?? 0);
    bool escrowHeldFlag =
        _toBool(job['escrowHeld']) || job['escrowPaidAt'] != null;
    bool escrowDone =
        ['held', 'paid', 'released'].contains(escrow) ||
        escrowHeldFlag ||
        alreadyLocked > 0 ||
        status == 'escrow_locked' ||
        status == 'completed';

    String jobId = (job['jobId'] ?? job['id'] ?? '').toString();

    if (status == 'completed') {
      return _timelineCard(
        title: 'Job completed - Done',
        body: 'KES $alreadyLocked released to fundi',
        icon: Icons.check_circle,
        isDone: true,
      );
    }

    if (!escrowDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrangeAnimatedWaitingCard(
            title: 'Waiting: Lock KES $totalToPay to escrow now',
            message:
                'Fundi confirmed. You need to pay to escrow to start the job.',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.primaryYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _payEscrow(jobId, totalToPay.toDouble()),
              child: Text(
                'Pay KES $totalToPay to Escrow',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!isTravelling &&
        !siteDone &&
        status != 'site_visit' &&
        status != 'in_progress' &&
        !status.contains('completed') &&
        phase != 'fundi_working') {
      return OrangeAnimatedWaitingCard(
        title: 'Waiting for fundi to start travelling',
        message:
            'Escrow KES $alreadyLocked secured. ${job['assignedFundiName'] ?? 'Fundi'} has NOT started travelling yet.',
      );
    }

    if (isTravelling && !siteDone) {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi is on the way - Waiting to arrive',
        message:
            '${job['assignedFundiName'] ?? 'Fundi'} is travelling to your location. Tracking live.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerTrackingScreen(jobId: jobId, job: job),
          ),
        ),
      );
    }

    if (needsExtraEscrow) {
      int extraToLock = _toInt(reneg?['extraToLock'] ?? 0);
      if (extraToLock == 0) {
        int newTotal = _toInt(reneg?['newTotalClientPays'] ?? 0);
        if (newTotal > 0) extraToLock = newTotal - alreadyLocked;
      }
      return OrangeAnimatedWaitingCard(
        title: 'Lock extra KES $extraToLock in escrow',
        message:
            'You accepted new price. Lock extra KES $extraToLock before fundi continues.',
      );
    }

    if (reneg != null &&
        _toBool(reneg['requested']) &&
        renegStatus == 'pending') {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi requests price review - Waiting for you',
        message:
            '${reneg['reasonDetails'] ?? 'Fundi sent new breakdown'} - Tap to REVIEW BREAKDOWN.',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientPriceApprovalScreen(jobId: jobId, job: job),
          ),
        ),
      );
    }

    if (phase == 'waiting_for_client_to_buy_parts') {
      return OrangeAnimatedWaitingCard(
        title: 'You will buy parts - Confirm when bought',
        message: 'Extra locked. Buy the listed parts then confirm.',
      );
    }

    if (phase == 'client_claims_parts_bought') {
      return OrangeAnimatedWaitingCard(
        title: 'Parts bought - Waiting for fundi to confirm',
        message: 'You marked parts as bought. Waiting for fundi to confirm.',
      );
    }

    if (phase == 'parts_confirmed_by_fundi') {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi confirmed parts - Waiting to start work',
        message:
            'Fundi confirmed parts are available. Waiting for him to tap Start Job.',
      );
    }

    if (status == 'site_visit' && phase.isEmpty) {
      return OrangeAnimatedWaitingCard(
        title: 'Waiting for fundi to start job',
        message:
            'Fundi arrived at your location and is on site. Waiting for him to Start Job.',
      );
    }

    if (phase == 'fundi_working' || status == 'in_progress') {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi is working - Waiting to complete',
        message:
            'Job in progress. Waiting for fundi to tap MARK JOB AS COMPLETED.',
      );
    }

    if (status == 'job_completed' || status == 'pending_completion') {
      int newLabour = _toInt(
        reneg?['newLaborTotal'] ?? labour + _toInt(reneg?['extraLabor'] ?? 0),
      );
      int newClientFee = (newLabour * 0.05).round();
      int newTotal = newLabour + transport + newClientFee;
      return _timelineCard(
        title: 'Job Completed - Confirm & Release KES $newTotal',
        body: 'Fundi marked job as complete. Confirm to release KES $newTotal',
        icon: Icons.verified,
        isDone: false,
      );
    }

    return _timelineCard(
      title: 'Bid accepted - Escrow locked KES $alreadyLocked',
      body: 'Escrow secured. Waiting for fundi to travel.',
      icon: Icons.verified,
      isDone: true,
    );
  }

  Widget _buildNotificationsSection() {
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

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: FundipapColors.primaryYellow,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    totalTabCounter > 0
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notifications',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                if (totalTabCounter > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalTabCounter new',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: GoogleFonts.inter(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          ...list.take(5).map((g) {
            String fundiKey = g['fundiId'] as String;
            int badgeCount = fundiUnreadCounts[fundiKey] ?? 0;
            var job = g['jobData'] as Map<String, dynamic>;
            var status = (job['status'] ?? '').toString();
            bool isCompleted = status == 'completed';
            Color borderCol = isCompleted
                ? Colors.green
                : Colors.orange.shade700;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1.5),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: FundipapColors.blackGray,
                          child: Text(
                            (g['fundiName'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
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
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      g['fundiName'],
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildHomeStatus(job),
                  ),
                ],
              ),
            );
          }),
          if (list.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  '${list.length - 5} more notifications',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: ['open', 'pending'])
          .snapshots(),
      builder: (context, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('clientId', isEqualTo: uid)
              .where('status', whereIn: ['open', 'pending'])
              .snapshots(),
          builder: (context, snap2) {
            if (snap1.connectionState == ConnectionState.waiting ||
                snap2.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(20),
                child: const LinearProgressIndicator(),
              );
            }
            final Map<String, QueryDocumentSnapshot> map = {};
            if (snap1.hasData) for (var d in snap1.data!.docs) map[d.id] = d;
            if (snap2.hasData) for (var d in snap2.data!.docs) map[d.id] = d;
            var jobs = map.values.toList();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pending Jobs',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FundipapColors.primaryYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${jobs.length}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<FilterType>(
                        value: _pendingFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list, size: 18),
                        items: [
                          DropdownMenuItem(
                            value: FilterType.all,
                            child: Text(
                              'Filter By',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.verified,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Verified',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.topRated,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Top Rated 4.5+',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.highReferral,
                            child: Row(
                              children: [
                                const Icon(Icons.people, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'High Referral 10+',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.clean,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.clean_hands,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Clean Record',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.badge,
                            child: Row(
                              children: [
                                Text(
                                  'Badge Ranking',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const FundiBadgeChip(level: BadgeLevel.gold),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _pendingFilter = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostNewJobScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: Text(
                        'Post New Job',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (jobs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              size: 28,
                              color: Colors.black26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pending jobs',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap Post New Job above to get bids',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...jobs.map((jobDoc) {
                      var job = jobDoc.data() as Map<String, dynamic>;
                      var jobId = jobDoc.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.fromLTRB(
                              12,
                              10,
                              12,
                              10,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: FundipapColors.blackGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  (job['title'] ?? 'J')[0].toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              job['title'] ?? 'Untitled Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FundipapColors.primaryYellow
                                          .withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'KES ${job['budgetMin'] ?? job['budget'] ?? '-'} - ${job['budgetMax'] ?? ''}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('jobs')
                                        .doc(jobId)
                                        .collection('bids')
                                        .snapshots(),
                                    builder: (_, s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${s.data?.docs.length ?? 0} bids',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.inter(),
                                  ),
                                  onTap: () => _deleteJob(jobId),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('jobs')
                                    .doc(jobId)
                                    .collection('bids')
                                    .snapshots(),
                                builder: (_, bSnap) {
                                  if (!bSnap.hasData)
                                    return const LinearProgressIndicator();
                                  if (bSnap.data!.docs.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.hourglass_empty,
                                            color: Colors.black26,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Waiting for fundis to bid',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return FutureBuilder<List<_BidWithFundi>>(
                                    future: _enrichBids(bSnap.data!.docs),
                                    builder: (_, s) {
                                      if (!s.hasData)
                                        return const LinearProgressIndicator();
                                      var list = s.data!;
                                      if (_pendingFilter == FilterType.badge) {
                                        final rank = {
                                          BadgeLevel.gold: 4,
                                          BadgeLevel.silver: 3,
                                          BadgeLevel.bronze: 2,
                                          BadgeLevel.none: 1,
                                        };
                                        list.sort(
                                          (a, b) => rank[b.level]!.compareTo(
                                            rank[a.level]!,
                                          ),
                                        );
                                      }
                                      var filtered = list.where((e) {
                                        switch (_pendingFilter) {
                                          case FilterType.verified:
                                            return e.verified;
                                          case FilterType.topRated:
                                            return e.rating >= 4.5;
                                          case FilterType.highReferral:
                                            return e.referrals >= 10;
                                          case FilterType.clean:
                                            return e.penalty < 20;
                                          case FilterType.badge:
                                          case FilterType.all:
                                            return true;
                                        }
                                      }).toList();
                                      if (filtered.isEmpty)
                                        return Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'No fundis for this filter',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      return Column(
                                        children: filtered.map((e) {
                                          void openConfirm() {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ConfirmFundiPage(
                                                      jobId: jobId,
                                                      jobData: job,
                                                      bidId: e.bidDoc.id,
                                                      bidData: e.bid,
                                                    ),
                                              ),
                                            );
                                          }

                                          String distanceText = e.distanceKm > 0
                                              ? ' (${e.distanceKm.toStringAsFixed(1)} km)'
                                              : '';
                                          return InkWell(
                                            onTap: openConfirm,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8F8F8),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.black12,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor:
                                                            Colors.black,
                                                        child: Text(
                                                          (e.bid['fundiName'] ??
                                                              'F')[0],
                                                          style:
                                                              GoogleFonts.montserrat(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    '${e.bid['fundiName'] ?? 'Fundi'}$distanceText',
                                                                    style: GoogleFonts.montserrat(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                if (e.verified)
                                                                  const Padding(
                                                                    padding:
                                                                        EdgeInsets.only(
                                                                          left:
                                                                              4,
                                                                        ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .verified,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.star,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .amber
                                                                      .shade700,
                                                                ),
                                                                Text(
                                                                  '${e.rating.toStringAsFixed(1)}',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  '${e.referrals} referrals • ${e.jobsDone} jobs',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .black54,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      FundiBadgeChip(
                                                        level: e.level,
                                                        isVerified: e.verified,
                                                        referralCount:
                                                            e.referrals,
                                                        jobsDone: e.jobsDone,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Bid',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .black54,
                                                            ),
                                                      ),
                                                      Text(
                                                        'KES ${e.bid['price'] ?? e.bid['amount'] ?? e.bid['bidAmount'] ?? 0}',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton(
                                                          style: OutlinedButton.styleFrom(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .black12,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'Counter',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                          ),
                                                          onPressed:
                                                              openConfirm,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                FundipapColors
                                                                    .blackGray,
                                                            foregroundColor:
                                                                Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            elevation: 0,
                                                          ),
                                                          child: Text(
                                                            'View & Accept',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                          onPressed:
                                                              openConfirm,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
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
          SliverToBoxAdapter(child: _buildNotificationsSection()),
          SliverToBoxAdapter(child: _buildPendingSection(uid)),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
