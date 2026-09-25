import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_bell.dart';
import 'filter_bar.dart';
import 'fundi_list.dart';
import 'header.dart';
import '../rating/rate_fundi_screen.dart';

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

      // Deduplicate by jobId
      final Map<String, QueryDocumentSnapshot> map = {};
      for (var d in [...snap1.docs, ...snap2.docs]) {
        map[d.id] = d;
      }

      final unrated = map.values.where((d) {
        var data = d.data() as Map<String, dynamic>;
        return data['clientRated'] != true;
      }).toList();

      if (unrated.isNotEmpty && mounted) {
        var first = unrated.first;
        var data = first.data() as Map<String, dynamic>;

        String fundiId =
            (data['fundiId'] ??
                    data['assignedFundiId'] ??
                    data['acceptedFundiId'] ??
                    data['selectedFundiId'] ??
                    data['fundiUid'] ??
                    data['fundiID'] ??
                    data['acceptedFundiUid'] ??
                    '')
                .toString()
                .trim();

        String fundiName =
            (data['assignedFundiName'] ??
                    data['fundiDisplayName'] ??
                    data['acceptedFundiName'] ??
                    'Fundi')
                .toString();

        String trade =
            (data['trade'] ??
                    data['category'] ??
                    data['serviceType'] ??
                    data['skill'] ??
                    '')
                .toString();

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
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Column(
      children: [
        Container(
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
        CustomerHomeFilterBar(
          radius: _radius,
          filter: _filter,
          onRadiusChanged: (v) => setState(() => _radius = v),
          onFilterChanged: (v) => setState(() => _filter = v),
        ),
        if (_loadingLoc) const LinearProgressIndicator(),
        Expanded(
          child: CustomerHomeFundiList(
            userPos: _userPos,
            radius: _radius,
            filter: _filter,
          ),
        ),
      ],
    );
  }
}
