import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeLevel { none, bronze, silver, gold }

class BadgeResult {
  final BadgeLevel level;
  final int score;
  final bool isVerified;
  final Map<String, int> breakdown;
  final double referralRate; // 0.0 - 1.0
  BadgeResult({
    required this.level,
    required this.score,
    required this.isVerified,
    required this.breakdown,
    required this.referralRate,
  });
}

class FundiBadgeService {
  // ===== THRESHOLDS =====
  static const int bronzeMin = 35;
  static const int silverMin = 70;
  static const int goldMin = 120;

  // ===== MAIN CALCULATOR =====
  static BadgeResult calculate(
    Map<String, dynamic> fundi,
    Map<String, dynamic> stats,
  ) {
    int score = 0;
    Map<String, int> b = {};

    // 1. Cancellations - 30 pts max
    int cancels =
        (stats['cancellationCount'] ?? fundi['cancellationCount'] ?? 0) as int;
    int totalJobs =
        (stats['completedJobs'] ??
                fundi['completedJobs'] ??
                fundi['jobsDone'] ??
                0)
            as int;
    double cancelRate = totalJobs > 0 ? cancels / totalJobs : 0;
    if (cancels == 0) {
      b['cancellations'] = 30;
    } else if (cancelRate < 0.02) {
      b['cancellations'] = 20;
    } else if (cancelRate < 0.05) {
      b['cancellations'] = 10;
    } else {
      b['cancellations'] = -(cancels * 10);
    }
    score += b['cancellations']!;

    // 2. Fraud / Scam reports - 20 pts
    int fraud = (stats['fraudReports'] ?? fundi['fraudReports'] ?? 0) as int;
    b['fraud'] = fraud == 0 ? 20 : -(fraud * 20);
    score += b['fraud']!;

    // 3. Rating - 25 pts max
    double rating = _toDouble(fundi['averageRating'] ?? fundi['rating'] ?? 0);
    if (rating >= 4.8)
      b['rating'] = 25;
    else if (rating >= 4.5)
      b['rating'] = 15;
    else if (rating >= 4.0)
      b['rating'] = 5;
    else
      b['rating'] = 0;
    score += b['rating']!;

    // 4. Negative comments sentiment
    int negComments = (stats['negativeCommentsCount'] ?? 0) as int;
    b['negativeComments'] = -(negComments * 5);
    score += b['negativeComments']!;

    // 5. On-time delivery
    int onTime = (stats['onTimeDeliveries'] ?? 0) as int;
    b['onTime'] = (onTime ~/ 10) * 10; // 10 pts per 10 jobs
    if (b['onTime']! > 30) b['onTime'] = 30; // cap
    score += b['onTime']!;

    // 6. Profile complete in My Advert tab
    bool profileComplete = _isProfileComplete(fundi);
    b['profileComplete'] = profileComplete ? 20 : 0;
    score += b['profileComplete']!;

    // 7. KYC + Video intro
    bool kyc = fundi['kycVerified'] == true || fundi['idVerified'] == true;
    bool video = fundi['hasVideoIntro'] == true;
    b['kycVideo'] = (kyc ? 5 : 0) + (video ? 5 : 0);
    score += b['kycVideo']!;

    // 8. Tool photos
    bool tools =
        (fundi['toolPhotos'] != null &&
            (fundi['toolPhotos'] as List).isNotEmpty) ||
        fundi['hasTools'] == true;
    b['tools'] = tools ? 5 : 0;
    score += b['tools']!;

    // 9. Fast bidder <5 min
    double avgBid = _toDouble(
      stats['avgBidResponseMinutes'] ?? fundi['avgBidMinutes'] ?? 999,
    );
    b['fastBid'] = avgBid <= 5 ? 10 : 0;
    score += b['fastBid']!;

    // 10. Fast chat reply <10 min
    double avgChat = _toDouble(
      stats['avgChatResponseMinutes'] ?? fundi['avgChatMinutes'] ?? 999,
    );
    b['fastChat'] = avgChat <= 10 ? 10 : 0;
    score += b['fastChat']!;

    // 11. GPS arrival verified
    int arrivalOk = (stats['onTimeArrivalCount'] ?? 0) as int;
    b['arrival'] = (arrivalOk ~/ 5) * 5; // 5 pts per 5 arrivals
    if (b['arrival']! > 20) b['arrival'] = 20;
    score += b['arrival']!;

    // 12. Repeat clients
    int repeat = (stats['repeatClientCount'] ?? 0) as int;
    b['repeat'] = repeat * 5;
    if (b['repeat']! > 25) b['repeat'] = 25;
    score += b['repeat']!;

    // 13. Referrals - 2 pts each, cap 30
    int referrals =
        (stats['referralCount'] ?? fundi['referralCount'] ?? 0) as int;
    b['referrals'] = referrals * 2;
    if (b['referrals']! > 30) b['referrals'] = 30;
    score += b['referrals']!;

    // 14. Zero disputes
    int disputes = (stats['disputeCount'] ?? fundi['disputeCount'] ?? 0) as int;
    b['disputes'] = disputes == 0 ? 15 : -(disputes * 10);
    score += b['disputes']!;

    // 15. Jobs milestone
    if (totalJobs >= 100)
      b['milestone'] = 25;
    else if (totalJobs >= 50)
      b['milestone'] = 15;
    else if (totalJobs >= 10)
      b['milestone'] = 5;
    else
      b['milestone'] = 0;
    score += b['milestone']!;

    // 16. Account age + consistency
    b['tenure'] = _tenurePoints(fundi);
    score += b['tenure']!;

    // Penalty from cancellations / suspensions
    int penalty = (fundi['penaltyScore'] ?? 0) as int;
    b['penalty'] = -penalty;
    score += b['penalty']!;

    if (score < 0) score = 0;

    // Badge level
    BadgeLevel level;
    if (score >= goldMin)
      level = BadgeLevel.gold;
    else if (score >= silverMin)
      level = BadgeLevel.silver;
    else if (score >= bronzeMin)
      level = BadgeLevel.bronze;
    else
      level = BadgeLevel.none;

    // Referral rate
    double referralRate = totalJobs > 0 ? referrals / totalJobs : 0;

    // Verified check - elite
    bool verified =
        level == BadgeLevel.gold &&
        rating >= 4.8 &&
        totalJobs >= 50 &&
        referrals >= 20 &&
        cancels == 0 &&
        profileComplete &&
        fraud == 0 &&
        disputes == 0 &&
        kyc;

    return BadgeResult(
      level: level,
      score: score,
      isVerified: verified,
      breakdown: b,
      referralRate: referralRate,
    );
  }

  static bool _isProfileComplete(Map<String, dynamic> f) {
    // My Advert tab requirements
    bool hasId = f['idUploaded'] == true || f['nationalIdUrl'] != null;
    bool hasGoodConduct =
        f['goodConductUrl'] != null || f['goodConductUploaded'] == true;
    bool hasTradeCert =
        f['tradeCertificateUrl'] != null || f['tradeCertUploaded'] == true;
    bool hasPhoto = f['profilePhotoUrl'] != null || f['photoUrl'] != null;
    bool hasBio = (f['bio'] ?? '').toString().length > 20;
    return hasId && hasGoodConduct && hasTradeCert && hasPhoto && hasBio;
  }

  static int _tenurePoints(Map<String, dynamic> f) {
    try {
      Timestamp? created = f['createdAt'] is Timestamp ? f['createdAt'] : null;
      if (created == null) return 0;
      int months = DateTime.now().difference(created.toDate()).inDays ~/ 30;
      if (months >= 12) return 15;
      if (months >= 6) return 10;
      if (months >= 3) return 5;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // ===== FIRESTORE UPDATE =====
  static Future<BadgeResult> recalcAndUpdate(String fundiId) async {
    var db = FirebaseFirestore.instance;
    var fundiSnap = await db.collection('fundis').doc(fundiId).get();
    if (!fundiSnap.exists) {
      fundiSnap = await db.collection('users').doc(fundiId).get();
    }
    var statsSnap = await db.collection('fundiStats').doc(fundiId).get();

    var fundiData = fundiSnap.data() ?? {};
    var statsData = statsSnap.data() ?? {};

    // merge referral count live
    var refQuery = await db
        .collection('referrals')
        .where('fundiId', isEqualTo: fundiId)
        .count()
        .get();
    statsData['referralCount'] = refQuery.count ?? 0;

    var result = calculate(fundiData, statsData);

    // Update fundi doc for fast client filtering
    await db.collection('fundis').doc(fundiId).set({
      'badgeLevel': result.level.name, // none/bronze/silver/gold
      'badgeScore': result.score,
      'isVerifiedFundi': result.isVerified,
      'referralCount': statsData['referralCount'],
      'referralRate': result.referralRate,
      'badgeBreakdown': result.breakdown,
      'badgeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Also update users collection if you use it for search
    await db.collection('users').doc(fundiId).set({
      'badgeLevel': result.level.name,
      'badgeScore': result.score,
      'isVerifiedFundi': result.isVerified,
    }, SetOptions(merge: true));

    return result;
  }

  // Call this via Cloud Function nightly or on triggers: rating, job completed, cancel, referral
  static Future<void> recalcAll() async {
    var db = FirebaseFirestore.instance;
    var all = await db.collection('fundis').get();
    for (var doc in all.docs) {
      await recalcAndUpdate(doc.id);
    }
  }
}
