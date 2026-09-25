import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import 'logic.dart';
import 'bid_dialog.dart';

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

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  Future<void> loadLocation(BuildContext context) async {
    var pos = await LocationService.determinePosition(context);
    if (pos == null) return;
    if (!mounted) return;
    setState(() => currentPos = pos);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'location': 'Kisumu',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Location save error: $e');
    }
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
      // NEW FORMULA: labour - 5% + transport = your payout
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
      totalEarned = sum; // now 5800 per 6000 labour job, not 6400
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
    await showDialog(
      context: context,
      builder: (_) => FundiBidDialog(jobId: jobId.toString(), jobData: job),
    );
  }
}
