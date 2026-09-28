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
import '../../customer/confirm/confirm_fundi_page.dart';

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

  Future<void> _deleteJob(String jobId) async {
    var bids = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .get();
    for (var d in bids.docs) {
      await d.reference.delete();
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
  }

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
      if (mounted) {
        setState(() {
          _userPos = pos;
          _loadingLoc = false;
        });
      }
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

  // <-- ADJUST PATH to where ConfirmFundiPage lives
  // if your path is different: import '../post_job/confirm_fundi/confirm_fundi_page.dart';

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
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            final Map<String, QueryDocumentSnapshot> map = {};
            if (snap1.hasData) for (var d in snap1.data!.docs) map[d.id] = d;
            if (snap2.hasData) for (var d in snap2.data!.docs) map[d.id] = d;
            var jobs = map.values.toList();
            if (jobs.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: FundipapColors.primaryYellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.pending_actions,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pending Jobs',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${jobs.length}',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                  const SizedBox(height: 14),
                  ...jobs.map((jobDoc) {
                    var job = jobDoc.data() as Map<String, dynamic>;
                    var jobId = jobDoc.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
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
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.fromLTRB(
                            16,
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
                                    padding: const EdgeInsets.all(24),
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
                                    if (filtered.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'No fundis for this filter',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    }
                                    return Column(
                                      children: filtered.map((e) {
                                        // NAVIGATE TO CONFIRM FUNDI PAGE
                                        void openConfirm() {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ConfirmFundiPage(
                                                jobId: jobId,
                                                jobData: job,
                                                bidId: e.bidDoc.id,
                                                bidData: e.bid,
                                              ),
                                            ),
                                          );
                                        }

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
                                                              color:
                                                                  Colors.white,
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
                                                                  e.bid['fundiName'] ??
                                                                      'Fundi',
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
                                                                        left: 4,
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
                                                                  fontSize: 10,
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
                                                                  fontSize: 10,
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
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                    Text(
                                                      'KES ${e.bid['price'] ?? e.bid['amount'] ?? e.bid['bidAmount'] ?? 0}',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontWeight:
                                                                FontWeight.w800,
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
                                                        onPressed: openConfirm,
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
                                                        onPressed: openConfirm,
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
          SliverToBoxAdapter(child: _buildPendingSection(uid)),
          // REMOVED the extra "Fundis Near You" Text - FundiList already has it
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
              height: 700,
              child: CustomerHomeFundiList(
                userPos: _userPos,
                radius: _radius,
                filter: _filter,
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
              height: 700,
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
