import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getLocation();
      _loadMe();
    });
  }

  Future<void> _loadMe() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && mounted) setState(() => _me = doc.data());
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
    return Column(
      children: [
        Container(
          color: FundipapColors.blackGray,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: CustomerHomeHeader(
            me: _me,
            profilePct: 75,
            completedJobs: 0,
            onProfileTap: () {},
          ),
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
