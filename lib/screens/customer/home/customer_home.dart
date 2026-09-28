import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_bell.dart';
import '../../../widgets/fundi_badge_chip.dart';
import '../../../services/fundi_badge_service.dart';
import 'customer_filter_bar.dart';
import 'customer_home_fundi_list.dart';
import 'customer_home_header.dart';
import '../rating/rate_fundi_screen.dart';

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
  _BidWithFundi({
    required this.bidDoc,
    required this.bid,
    required this.level,
    required this.verified,
    required this.referrals,
    required this.jobsDone,
    required this.rating,
    required this.penalty,
  });
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  double _radius = 5.0;
  String _filter = 'distance';
  Position? _userPos;
  bool _loadingLoc = true;
  Map<String, dynamic>? _me;
  int _completedJobs = 0;
  int _profilePct = 0;
  FilterType _pendingFilter = FilterType.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getLocation();
      _loadMe();
      _loadCompletedCount();
      _enforcePendingRating();
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
        return _BidWithFundi(
          bidDoc: b,
          bid: m,
          level: _parseBadge(f?['badgeLevel']),
          verified: f?['isVerifiedFundi'] == true,
          referrals: f?['referralCount'] ?? 0,
          jobsDone: f?['completedJobs'] ?? 0,
          rating: (f?['avgRating'] ?? 0).toDouble(),
          penalty: f?['penaltyScore'] ?? 0,
        );
      }),
    );
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
    if (doc.exists && mounted)
      setState(() {
        _me = doc.data();
        _profilePct = _calcProfilePct(_me);
      });
  }

  int _calcProfilePct(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int total = 5;
    int done = 0;
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
        _showEnableDialog();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLoc = false);
        _showPermDialog();
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

  void _showEnableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(
          'Enable Location',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'FundiPap needs location to find fundis near you in Kisumu.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Turn On'),
          ),
        ],
      ),
    );
  }

  void _showPermDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Needed'),
        content: const Text(
          'Location permission is permanently denied. Open settings to allow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _getLocation();
    await _loadMe();
    _loadCompletedCount();
    if (mounted) setState(() {});
  }

  Widget _buildPendingSection(String uid) {
    // pending = status open OR pending (your app uses open)
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
                snap2.connectionState == ConnectionState.waiting)
              return const LinearProgressIndicator();
            final Map<String, QueryDocumentSnapshot> map = {};
            if (snap1.hasData) for (var d in snap1.data!.docs) map[d.id] = d;
            if (snap2.hasData) for (var d in snap2.data!.docs) map[d.id] = d;
            var jobs = map.values.toList();
            if (jobs.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Pending Jobs - Bids',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                // ONE FILTER DROPDOWN - Badge is one option inside it
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<FilterType>(
                        value: _pendingFilter,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: FilterType.all,
                            child: Text(
                              'All Fundis',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.verified,
                            child: Text(
                              'Verified',
                              style: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.topRated,
                            child: Text(
                              'Top Rated',
                              style: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.highReferral,
                            child: Text(
                              'High Referral',
                              style: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.clean,
                            child: Text(
                              'Clean Record',
                              style: GoogleFonts.montserrat(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.badge,
                            child: Row(
                              children: [
                                Text(
                                  'Badge',
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
                ),
                const SizedBox(height: 8),
                ...jobs.map((jobDoc) {
                  var job = jobDoc.data() as Map<String, dynamic>;
                  var jobId = jobDoc.id;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        job['title'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        'KES ${job['budgetMin'] ?? job['budget'] ?? ''} - ${job['budgetMax'] ?? ''} • ${job['status']}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('jobs')
                              .doc(jobId)
                              .collection('bids')
                              .snapshots(),
                          builder: (_, bSnap) {
                            if (!bSnap.hasData)
                              return const LinearProgressIndicator();
                            if (bSnap.data!.docs.isEmpty)
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No bids yet'),
                              );
                            return FutureBuilder<List<_BidWithFundi>>(
                              future: _enrichBids(bSnap.data!.docs),
                              builder: (_, s) {
                                if (!s.hasData)
                                  return const LinearProgressIndicator();
                                var list = s.data!;
                                // Badge ranking: Gold first, Grey last, skip missing
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
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('No fundis for this filter'),
                                  );
                                return Column(
                                  children: filtered
                                      .map(
                                        (e) => Container(
                                          margin: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            8,
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF6F6F6),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${e.bid['fundiName'] ?? 'Fundi'} • KES ${e.bid['price']}',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              FundiBadgeChip(
                                                level: e.level,
                                                isVerified: e.verified,
                                                referralCount: e.referrals,
                                                jobsDone: e.jobsDone,
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
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
          SliverToBoxAdapter(child: _buildPendingSection(uid)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Fundis Near You',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: CustomerHomeFilterBar(
              radius: _radius,
              filter: _filter,
              onRadiusChanged: (v) => setState(() => _radius = v),
              onFilterChanged: (v) => setState(() => _filter = v),
            ),
          ),
          if (_loadingLoc)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 600,
              child: CustomerHomeFundiList(
                userPos: _userPos,
                radius: _radius,
                filter: _filter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
