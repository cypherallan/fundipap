import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class FundiHomeLogic {
  static final Map<String, List<String>> skillKeywords = {
    'electrical': [
      'electrical',
      'electrician',
      'wiring',
      'socket',
      'switch',
      'bulb',
      'light',
      'power',
    ],
    'plumbing': [
      'plumbing',
      'plumber',
      'pipe',
      'leak',
      'water',
      'tap',
      'sink',
      'toilet',
      'drainage',
    ],
    'carpentry': [
      'carpentry',
      'carpenter',
      'furniture',
      'wood',
      'door',
      'cabinet',
      'table',
      'chair',
    ],
    'masonry': [
      'masonry',
      'mason',
      'construction',
      'building',
      'brick',
      'cement',
      'plaster',
      'wall',
    ],
    'painting': ['painting', 'painter', 'paint', 'wall', 'color', 'decor'],
    'welding': ['welding', 'welder', 'metal', 'gate', 'grill', 'fabrication'],
    'mechanic': ['mechanic', 'car', 'vehicle', 'engine', 'garage', 'motor'],
  };

  static Future<
    ({
      Map<String, dynamic>? me,
      int completedJobs,
      double totalEarned,
      String mySkill,
      int profilePct,
    })
  >
  loadMe() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    var fundiDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    var jobsDone = await FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundi', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double sum = 0;
    for (var doc in jobsDone.docs) {
      var d = doc.data();
      sum += ((d['finalPrice'] ?? d['agreedPrice'] ?? d['budget'] ?? 0) as num)
          .toDouble();
    }

    var combined = {...?userDoc.data(), ...?fundiDoc.data()};
    int pct = 0;
    if ((combined['name'] ?? '').toString().length > 2) pct += 15;
    if ((combined['profession'] ?? combined['skill'] ?? '')
        .toString()
        .isNotEmpty)
      pct += 15;
    if ((combined['bio'] ?? '').toString().length > 20) pct += 20;
    if (combined['photoUrl'] != null) pct += 20;
    if ((combined['phone'] ?? '').toString().length > 5) pct += 5;
    if ((combined['location'] ?? '').toString().isNotEmpty) pct += 5;
    if ((combined['resumes'] as List?)?.isNotEmpty ?? false) pct += 10;
    if ((combined['certificates'] as List?)?.isNotEmpty ?? false) pct += 10;

    return (
      me: combined,
      completedJobs: jobsDone.docs.length,
      totalEarned: sum,
      mySkill: (combined['profession'] ?? combined['skill'] ?? 'General')
          .toString()
          .toLowerCase(),
      profilePct: pct.clamp(0, 100),
    );
  }

  static int relevanceScore(
    Map<String, dynamic> job,
    Map<String, dynamic>? me,
    String mySkill,
  ) {
    String text = "${job['title']} ${job['description']} ${job['category']}"
        .toLowerCase();
    int score = 0;
    String keyword = (me?['searchKeyword'] ?? mySkill).toLowerCase();
    if (text.contains(keyword)) score += 100;
    if (text.contains(mySkill)) score += 100;
    for (var s in (me?['otherSkills'] ?? [])) {
      if (text.contains(s.toString().toLowerCase())) score += 60;
    }
    return score;
  }

  // NEW: Real-time distance
  static double? distanceKm(Position? currentPos, Map job) {
    var lat = job['lat'] ?? job['latitude'];
    var lng = job['lng'] ?? job['longitude'];
    if (currentPos == null || lat == null || lng == null) return null;
    var meters = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
    return meters / 1000;
  }
}
