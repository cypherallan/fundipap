import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import 'fundi_home_logic.dart';
import 'fundi_bid_dialog.dart';
import '../../../services/fundi_penalty_service.dart';

mixin FundiHomeActionsMixin<T extends StatefulWidget> on State<T> {
  String get search;
  set search(String v);
  Map<String, dynamic>? get me;
  set me(Map<String, dynamic>? v);
  int get completedJobs;
  set completedJobs(int v);
  double get totalEarned;
  set totalEarned(double v);
  int get profilePct;
  set profilePct(int v);
  String get mySkill;
  set mySkill(String v);
  Position? get currentPos;
  set currentPos(Position? v);

  // online state
  bool _isOnline = false;
  bool get isOnline => _isOnline;
  StreamSubscription<Position>? _posSub;

  // ANTI-GLITCH LOCK
  Position? _stablePos;
  DateTime? _lastPosTime;

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  Future<void> initOnlineStatus() async {
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var doc = await FirebaseFirestore.instance
          .collection('fundis')
          .doc(uid)
          .get();
      bool wasOnline = doc.data()?['isOnline'] == true;
      if (wasOnline && mounted) {
        setState(() => _isOnline = true);
        await LocationService.startTracking(uid);
        _listenToLivePos();
      } else {
        await loadLocation(context);
      }
    } catch (e) {
      print('initOnlineStatus error: $e');
      await loadLocation(context);
    }
  }

  Future<void> loadLocation(BuildContext context) async {
    var pos = await LocationService.determinePosition(context);
    if (pos == null) return;
    if (!mounted) return;
    _stablePos = pos;
    _lastPosTime = DateTime.now();
    setState(() => currentPos = pos);
  }

  Future<void> toggleOnline(BuildContext context) async {
    var uid = FirebaseAuth.instance.currentUser!.uid;

    if (_isOnline) {
      await LocationService.stopTracking(uid);
      await _posSub?.cancel();
      if (!mounted) return;
      setState(() {
        _isOnline = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are Offline - not receiving jobs')),
      );
    } else {
      bool hasPerm = await LocationService.requestAlwaysPermission(context);
      if (!hasPerm) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission needed to go online'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isOnline = true);

      await LocationService.startTracking(uid);
      _listenToLivePos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('You are Online - receiving jobs near you (like Uber)'),
        ),
      );
    }
  }

  void _listenToLivePos() {
    _posSub?.cancel();
    _posSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;

      // Ignore very bad accuracy
      if (pos.accuracy > 100) {
        print('⚠️ IGNORED bad accuracy ${pos.accuracy}');
        return;
      }

      // LOCK TO FAKE - If we have fake, block real flips >300m within 30s
      if (_stablePos != null && _stablePos!.isMocked && !pos.isMocked) {
        double jump = Geolocator.distanceBetween(
          _stablePos!.latitude,
          _stablePos!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (jump > 300 &&
            _lastPosTime != null &&
            DateTime.now().difference(_lastPosTime!).inSeconds < 30) {
          print(
            '🚫 BLOCKED REAL FLIP ${jump.toStringAsFixed(0)}m - keeping fake ${_stablePos!.latitude},${_stablePos!.longitude}',
          );
          return;
        }
      }

      _stablePos = pos;
      _lastPosTime = DateTime.now();
      print(
        '✅ UI USING: ${pos.latitude},${pos.longitude} mocked=${pos.isMocked} acc=${pos.accuracy}',
      );
      setState(() => currentPos = pos);
    });
  }

  void disposeTracking() {
    _posSub?.cancel();
  }

  Future<void> loadMe() async {
    final result = await FundiHomeLogic.loadMe();
    if (!mounted) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundi', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double sum = 0;
    for (var doc in snap.docs) {
      var data = doc.data();
      int labour = _toInt(
        data['laborCost'] ??
            data['agreedPrice'] ??
            data['fundiBidAmount'] ??
            data['budget'] ??
            0,
      );
      int transport = _toInt(data['transportFee'] ?? 0);
      int fundiFee = _toInt(data['fundiAppFee'] ?? (labour * 0.05).round());
      int payout = _toInt(
        data['fundiReceives'] ??
            data['fundiPayoutAmount'] ??
            data['totalReleasedAmount'] ??
            labour - fundiFee + transport,
      );
      sum += payout.toDouble();
    }

    setState(() {
      me = result.me;
      completedJobs = snap.docs.length;
      totalEarned = sum;
      mySkill = result.mySkill;
      profilePct = result.profilePct;
    });
  }

  int relevanceScore(Map<String, dynamic> job) =>
      FundiHomeLogic.relevanceScore(job, me, mySkill);

  Future<void> bidForJob(BuildContext context, Map<String, dynamic> job) async {
    final jobId = job['id'] ?? job['jobId'] ?? '';
    if (jobId.toString().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job ID missing')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    bool canBid = await FundiPenaltyService.canFundiBid(uid);
    if (!canBid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'You are suspended for cancelling jobs. You cannot bid now.',
            ),
          ),
        );
      }
      return;
    }

    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Go Online first to bid for jobs')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => FundiBidDialog(jobId: jobId.toString(), jobData: job),
    );
  }
}
