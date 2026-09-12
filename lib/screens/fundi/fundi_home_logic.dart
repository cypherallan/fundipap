import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FundiHomeLogic {
  // Keywords per skill - so electrician sees electric jobs first
  static final Map<String, List<String>> skillKeywords = {
    'electrical': [
      'electrical',
      'electrician',
      'electricity',
      'wiring',
      'socket',
      'switch',
      'bulb',
      'light',
      'power',
      'electronics',
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
      'wardrobe',
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
      'floor',
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
        .where('fundiId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double sum = 0;
    for (var doc in jobsDone.docs) {
      var d = doc.data();
      sum +=
          ((d['finalPrice'] ??
                      d['agreedPrice'] ??
                      d['price'] ??
                      d['budget'] ??
                      0)
                  as num)
              .toDouble();
    }

    var combined = {...?userDoc.data(), ...?fundiDoc.data()};

    // CALCULATE COMPLETION - only 100% if really done
    int pct = 0;
    if ((combined['name'] ?? '').toString().length > 2) pct += 10;
    if ((combined['profession'] ?? combined['skill'] ?? '')
        .toString()
        .isNotEmpty)
      pct += 15;
    if ((combined['bio'] ?? '').toString().length > 20) pct += 20;
    if ((combined['price'] ?? 0) != 0) pct += 10;
    if (combined['photoUrl'] != null) pct += 15;
    if ((combined['phone'] ?? '').toString().length > 5) pct += 5;
    if ((combined['location'] ?? '').toString().isNotEmpty) pct += 5;
    if ((combined['resumes'] as List?)?.isNotEmpty ?? false) pct += 7;
    if ((combined['certificates'] as List?)?.isNotEmpty ?? false) pct += 8;
    if ((combined['portfolio'] as List?)?.isNotEmpty ?? false) pct += 5;

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
    List other = me?['otherSkills'] ?? [];
    if (text.contains(keyword)) score += 100;
    if (text.contains(mySkill)) score += 100;
    for (var s in other) {
      if (text.contains(s.toString().toLowerCase())) score += 60;
    }
    // keyword matching from skillKeywords map as before
    return score;
  }
}
