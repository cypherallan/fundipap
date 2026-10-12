import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeLevel { none, bronze, silver, gold }

enum FundiLevel { L1_NEW, L2_HUSTLER, L3_PRO, L4_ELITE }

class BadgeResult {
  final FundiLevel fundiLevel;
  final BadgeLevel badgeLevel;
  final int score;
  final bool isVerified;
  final bool isTrialGold;
  final DateTime? trialExpiresAt;
  final Map<String, int> breakdown;
  final double referralRate;
  final int fundiCommissionPct; // what fundi pays
  final int clientCommissionPct; // what client pays (always 5)
  final int jobsToNextLevel;
  final int pointsToNextBadge;

  BadgeResult({
    required this.fundiLevel,
    required this.badgeLevel,
    required this.score,
    required this.isVerified,
    required this.isTrialGold,
    this.trialExpiresAt,
    required this.breakdown,
    required this.referralRate,
    required this.fundiCommissionPct,
    required this.clientCommissionPct,
    required this.jobsToNextLevel,
    required this.pointsToNextBadge,
  });

  bool get isGold => badgeLevel == BadgeLevel.gold || isTrialGold;
}

class FundiBadgeService {
  static const int bronzeMin = 35;
  static const int silverMin = 70;
  static const int goldMin = 110;

  static BadgeResult calculate(
    Map<String, dynamic> fundi,
    Map<String, dynamic> stats,
  ) {
    int score = 0;
    Map<String, int> b = {};

    int completedJobs =
        (stats['completedJobs'] ??
                fundi['completedJobs'] ??
                fundi['jobsDone'] ??
                0)
            as int;
    int cancels =
        (stats['cancellationCount'] ?? fundi['cancellationCount'] ?? 0) as int;
    int fraud = (stats['fraudReports'] ?? fundi['fraudReports'] ?? 0) as int;
    double rating = _toDouble(fundi['averageRating'] ?? fundi['rating'] ?? 0);
    int onTime = (stats['onTimeDeliveries'] ?? 0) as int;
    int onTimeTotal = (stats['onTimeTotal'] ?? completedJobs) as int;
    int disputes = (stats['disputeCount'] ?? fundi['disputeCount'] ?? 0) as int;
    int negComments =
        (stats['negativeCommentsCount'] ?? stats['wouldNotReferCount'] ?? 0)
            as int;
    int repeatClients = (stats['repeatClientCount'] ?? 0) as int;
    int referrals =
        (stats['referralCount'] ?? fundi['referralCount'] ?? 0) as int;
    int arrivalOk = (stats['onTimeArrivalCount'] ?? 0) as int;
    int arrivalTotal = (stats['arrivalTotal'] ?? completedJobs) as int;

    // 1. Cancellations
    double cancelRate = completedJobs > 0 ? cancels / completedJobs : 0;
    if (cancels == 0)
      b['cancellations'] = 10;
    else if (cancelRate < 0.02)
      b['cancellations'] = 10;
    else if (cancelRate < 0.05)
      b['cancellations'] = 5;
    else
      b['cancellations'] = 0;
    score += b['cancellations']!;

    // 2. Zero Fraud
    b['fraud'] = fraud == 0 ? 10 : 0;
    score += b['fraud']!;

    // 3. Rating
    if (rating >= 4.8)
      b['rating'] = 15;
    else if (rating >= 4.5)
      b['rating'] = 10;
    else if (rating >= 4.0)
      b['rating'] = 5;
    else
      b['rating'] = 0;
    score += b['rating']!;

    // 4. On-Time
    double onTimeRate = onTimeTotal > 0 ? onTime / onTimeTotal : 0;
    if (onTimeRate >= 0.9 || (completedJobs < 10 && onTime == completedJobs))
      b['onTime'] = 10;
    else if (onTimeRate >= 0.8)
      b['onTime'] = 5;
    else
      b['onTime'] = 0;
    score += b['onTime']!;

    // 5. Profile Complete
    bool profileComplete = _isProfileComplete(fundi);
    b['profileComplete'] = profileComplete ? 10 : 0;
    score += b['profileComplete']!;

    // 6. KYC
    bool kyc = fundi['kycVerified'] == true || fundi['idVerified'] == true;
    b['kyc'] = kyc ? 10 : 0;
    score += b['kyc']!;

    // 7. Fast Response
    double avgBid = _toDouble(
      stats['avgBidResponseMinutes'] ?? fundi['avgBidMinutes'] ?? 999,
    );
    double avgChat = _toDouble(
      stats['avgChatResponseMinutes'] ?? fundi['avgChatMinutes'] ?? 999,
    );
    int fastPts = 0;
    if (avgBid <= 5) fastPts += 5;
    if (avgChat <= 10) fastPts += 5;
    b['fastResponse'] = fastPts;
    score += fastPts;

    // 8. GPS Arrival
    double arrivalRate = arrivalTotal > 0 ? arrivalOk / arrivalTotal : 0;
    if (arrivalRate >= 0.9 || arrivalOk >= 5)
      b['arrival'] = 10;
    else if (arrivalRate >= 0.7)
      b['arrival'] = 5;
    else
      b['arrival'] = completedJobs < 5 ? 5 : 0; // grace for new
    score += b['arrival']!;

    // 9. Zero Disputes + Would Refer
    if (disputes == 0 && negComments == 0)
      b['trust'] = 10;
    else if (disputes == 0)
      b['trust'] = 5;
    else
      b['trust'] = 0;
    score += b['trust']!;

    // 10. Repeat + Referral
    double referralRate = completedJobs > 0 ? referrals / completedJobs : 0;
    if (referralRate >= 0.15 || repeatClients >= 3)
      b['referral'] = 10;
    else if (referralRate >= 0.08 || repeatClients >= 1)
      b['referral'] = 5;
    else
      b['referral'] = 0;
    score += b['referral']!;

    // BONUS: Jobs Milestone
    if (completedJobs >= 100)
      b['milestone'] = 25;
    else if (completedJobs >= 50)
      b['milestone'] = 15;
    else if (completedJobs >= 10)
      b['milestone'] = 5;
    else
      b['milestone'] = 0;
    score += b['milestone']!;

    // BONUS: Tenure
    b['tenure'] = _tenurePoints(fundi);
    score += b['tenure']!;

    if (score < 0) score = 0;
    if (score > 130) score = 130;

    // LEVEL from jobs
    FundiLevel fundiLevel;
    if (completedJobs >= 100)
      fundiLevel = FundiLevel.L4_ELITE;
    else if (completedJobs >= 50)
      fundiLevel = FundiLevel.L3_PRO;
    else if (completedJobs >= 10)
      fundiLevel = FundiLevel.L2_HUSTLER;
    else
      fundiLevel = FundiLevel.L1_NEW;

    // BADGE from score
    BadgeLevel badge;
    if (score >= goldMin)
      badge = BadgeLevel.gold;
    else if (score >= silverMin)
      badge = BadgeLevel.silver;
    else if (score >= bronzeMin)
      badge = BadgeLevel.bronze;
    else
      badge = BadgeLevel.none;

    // TRIAL GOLD LOGIC
    bool isTrialGold = false;
    DateTime? trialExpiresAt;
    bool hasVideo = fundi['hasVideoIntro'] == true;
    bool hasTools =
        (fundi['toolPhotos'] != null &&
            (fundi['toolPhotos'] as List).isNotEmpty) ||
        fundi['hasTools'] == true;
    bool qualifiesTrial =
        fundiLevel == FundiLevel.L1_NEW &&
        profileComplete &&
        kyc &&
        hasVideo &&
        hasTools &&
        score >= 30;

    // Check existing trial
    if (fundi['isTrialGold'] == true && fundi['trialExpiresAt'] != null) {
      var exp = fundi['trialExpiresAt'] is Timestamp
          ? (fundi['trialExpiresAt'] as Timestamp).toDate()
          : DateTime.tryParse(fundi['trialExpiresAt'].toString());
      if (exp != null && exp.isAfter(DateTime.now()) && completedJobs < 5) {
        isTrialGold = true;
        trialExpiresAt = exp;
        badge = BadgeLevel.gold; // show as gold
      }
    } else if (qualifiesTrial && badge == BadgeLevel.none) {
      isTrialGold = true;
      trialExpiresAt = DateTime.now().add(Duration(days: 7));
      badge = BadgeLevel.gold;
    }

    // COMMISSION by badge (trial gold pays bronze rate but shows gold)
    int fundiComm;
    if (isTrialGold)
      fundiComm = 10; // trial shows gold but pays bronze
    else if (badge == BadgeLevel.gold)
      fundiComm = 5;
    else if (badge == BadgeLevel.silver)
      fundiComm = 7;
    else
      fundiComm = 10; // bronze/none

    // VERIFIED - ELITE
    bool verified =
        badge == BadgeLevel.gold &&
        !isTrialGold &&
        rating >= 4.8 &&
        completedJobs >= 50 &&
        referrals >= 10 &&
        cancels == 0 &&
        profileComplete &&
        fraud == 0 &&
        disputes == 0 &&
        kyc;

    // Progress
    int jobsToNext = 0;
    if (fundiLevel == FundiLevel.L1_NEW)
      jobsToNext = 10 - completedJobs;
    else if (fundiLevel == FundiLevel.L2_HUSTLER)
      jobsToNext = 50 - completedJobs;
    else if (fundiLevel == FundiLevel.L3_PRO)
      jobsToNext = 100 - completedJobs;

    int ptsToNext = 0;
    if (badge == BadgeLevel.none)
      ptsToNext = bronzeMin - score;
    else if (badge == BadgeLevel.bronze)
      ptsToNext = silverMin - score;
    else if (badge == BadgeLevel.silver)
      ptsToNext = goldMin - score;

    return BadgeResult(
      fundiLevel: fundiLevel,
      badgeLevel: badge,
      score: score,
      isVerified: verified,
      isTrialGold: isTrialGold,
      trialExpiresAt: trialExpiresAt,
      breakdown: b,
      referralRate: referralRate,
      fundiCommissionPct: fundiComm,
      clientCommissionPct: 5,
      jobsToNextLevel: jobsToNext.clamp(0, 100),
      pointsToNextBadge: ptsToNext.clamp(0, 130),
    );
  }

  static bool _isProfileComplete(Map<String, dynamic> f) {
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
      if (months >= 12) return 5;
      if (months >= 6) return 3;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 999;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 999;
  }

  static Future<BadgeResult> recalcAndUpdate(String fundiId) async {
    var db = FirebaseFirestore.instance;
    var fundiSnap = await db.collection('fundis').doc(fundiId).get();
    if (!fundiSnap.exists)
      fundiSnap = await db.collection('users').doc(fundiId).get();
    var statsSnap = await db.collection('fundiStats').doc(fundiId).get();
    var fundiData = fundiSnap.data() ?? {};
    var statsData = statsSnap.data() ?? {};
    var refQuery = await db
        .collection('referrals')
        .where('fundiId', isEqualTo: fundiId)
        .count()
        .get();
    statsData['referralCount'] = refQuery.count ?? 0;

    var result = calculate(fundiData, statsData);

    await db.collection('fundis').doc(fundiId).set({
      'badgeLevel': result.badgeLevel.name,
      'fundiLevel': result.fundiLevel.name, // L1_NEW etc
      'badgeScore': result.score,
      'isVerifiedFundi': result.isVerified,
      'isTrialGold': result.isTrialGold,
      'trialExpiresAt': result.trialExpiresAt,
      'fundiCommissionPct': result.fundiCommissionPct,
      'clientCommissionPct': result.clientCommissionPct,
      'referralCount': statsData['referralCount'],
      'referralRate': result.referralRate,
      'jobsToNextLevel': result.jobsToNextLevel,
      'pointsToNextBadge': result.pointsToNextBadge,
      'badgeBreakdown': result.breakdown,
      'badgeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await db.collection('users').doc(fundiId).set({
      'badgeLevel': result.badgeLevel.name,
      'fundiLevel': result.fundiLevel.name,
      'badgeScore': result.score,
      'isVerifiedFundi': result.isVerified,
      'isTrialGold': result.isTrialGold,
      'fundiCommissionPct': result.fundiCommissionPct,
    }, SetOptions(merge: true));

    return result;
  }
}
