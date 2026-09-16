import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_bell.dart';
import '../../../notifications/notification_service.dart';
import 'bid_widgets/customer_bid_notifications.dart';
import 'customer_home_filter_bar.dart';
import 'customer_home_fundi_list.dart';
import 'customer_home_header.dart';

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
    });
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
    if ((data['photoUrl'] ?? data['profileImage'] ?? '')
        .toString()
        .isNotEmpty) {
      done++;
    }
    if ((data['location'] ?? data['address'] ?? '').toString().isNotEmpty) {
      done++;
    }
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
              // === NOTIFICATION BELL FOR CONFIRMED JOBS ===
              NotificationBell(userId: uid, iconColor: Colors.white),
            ],
          ),
        ),
        // Show confirmed jobs notifications banner (fundi working, job completed)
        StreamBuilder<QuerySnapshot>(
          stream: NotificationService.getUserNotificationsStream(uid),
          builder: (_, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty)
              return const SizedBox.shrink();
            // Only show latest unread confirmed-related notification
            var latest = snap.data!.docs.where((d) {
              var type = (d.data() as Map)['type'] ?? '';
              return [
                'fundi_working',
                'job_completed',
                'parts_confirmed',
                'parts_bought',
                'payment_released',
              ].contains(type);
            }).toList();
            if (latest.isEmpty) return const SizedBox.shrink();
            var data = latest.first.data() as Map<String, dynamic>;
            bool isRead = data['isRead'] ?? false;
            if (isRead) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: data['type'] == 'job_completed'
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: data['type'] == 'job_completed'
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    data['type'] == 'job_completed'
                        ? Icons.check_circle
                        : Icons.construction,
                    size: 16,
                    color: data['type'] == 'job_completed'
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          data['body'] ?? '',
                          style: GoogleFonts.inter(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () =>
                        NotificationService.markAsRead(latest.first.id),
                  ),
                ],
              ),
            );
          },
        ),
        const CustomerBidNotifications(),
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
