import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import 'fundi_home_logic.dart';
import 'fundi_bid_dialog.dart';

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

    // Real earnings from completed jobs
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundi', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double sum = 0;
    for (var doc in snap.docs) {
      var data = doc.data();
      sum +=
          ((data['agreedPrice'] ?? data['budget'] ?? data['totalCost'] ?? 0)
                  as num)
              .toDouble();
    }

    setState(() {
      me = result.me;
      completedJobs = snap.docs.length; // real count
      totalEarned = sum; // real total
      mySkill = result.mySkill;
      profilePct = result.profilePct;
    });
  }

  int relevanceScore(Map<String, dynamic> job) =>
      FundiHomeLogic.relevanceScore(job, me, mySkill);

  Future<void> bidForJob(BuildContext context, Map<String, dynamic> job) async {
    await showFundiBidDialog(
      context: context,
      job: job,
      me: me,
      completedJobs: completedJobs,
    );
  }
}
