import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/job_taxonomy.dart';
import '../screens/fundi/services/fundi_badge_service.dart';

class PricingService {
  static const String version = 'v3_2026_badge_commission';

  static const int clientCommissionPercent = 5;
  static const int fundiCommissionGold = 5;
  static const int fundiCommissionSilver = 8;
  static const int fundiCommissionBronze = 10;
  static const int fundiCommissionNone = 15;
  static const int fundiCommissionTrialGold = 5;
  static const int commissionPercent = 15;

  static Map<String, int> getPrice(String categoryId, String subcategoryId) {
    try {
      var cat = FundiTaxonomy.categories.firstWhere(
        (c) => c['id'] == categoryId,
      );
      var subs = cat['subcategories'] as List;
      var sub = subs.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id'] == subcategoryId,
      );
      int min = sub['priceMin'] as int;
      int max = sub['priceMax'] as int;
      int avg = ((min + max) / 2).round();
      return {'min': min, 'max': max, 'avg': avg};
    } catch (_) {
      return {'min': 1200, 'max': 2500, 'avg': 1800};
    }
  }

  static int getSiteVisitFee([String? categoryId, bool isOther = false]) {
    if (isOther) return FundiTaxonomy.siteVisitFeeOther;
    if (categoryId != null && categoryId.toLowerCase().contains('other')) {
      return FundiTaxonomy.siteVisitFeeOther;
    }
    return FundiTaxonomy.siteVisitFeeStandard;
  }

  static int getTotalToLock(
    String categoryId,
    String subcategoryId, {
    bool isOther = false,
  }) {
    var price = getPrice(categoryId, subcategoryId);
    int siteFee = getSiteVisitFee(categoryId, isOther);
    return price['avg']! + siteFee;
  }

  static int getFundiCommissionPct({
    required String badgeLevel,
    bool isTrialGold = false,
  }) {
    if (isTrialGold) return fundiCommissionTrialGold;
    switch (badgeLevel.toLowerCase()) {
      case 'gold':
      case 'l4_gold':
        return fundiCommissionGold;
      case 'silver':
      case 'l3_silver':
        return fundiCommissionSilver;
      case 'bronze':
      case 'l2_bronze':
        return fundiCommissionBronze;
      case 'none':
      case 'l1_new':
      default:
        return fundiCommissionNone;
    }
  }

  static int getFundiCommissionFromResult(BadgeResult badge) {
    if (badge.isTrialGold) return fundiCommissionTrialGold;
    switch (badge.badgeLevel) {
      case BadgeLevel.gold:
        return fundiCommissionGold;
      case BadgeLevel.silver:
        return fundiCommissionSilver;
      case BadgeLevel.bronze:
        return fundiCommissionBronze;
      case BadgeLevel.none:
        return fundiCommissionNone;
    }
  }

  static int getClientCommissionPct() => clientCommissionPercent;

  static Map<String, int> getCommissionBreakdown({
    required String badgeLevel,
    bool isTrialGold = false,
  }) {
    int fundiPct = getFundiCommissionPct(
      badgeLevel: badgeLevel,
      isTrialGold: isTrialGold,
    );
    int clientPct = clientCommissionPercent;
    return {
      'fundiPct': fundiPct,
      'clientPct': clientPct,
      'totalPct': fundiPct + clientPct,
    };
  }

  static Future<Map<String, dynamic>> getPriceToShow({
    required String categoryId,
    required String subcategoryId,
    String? faultId,
  }) async {
    var staticPrice = getPrice(categoryId, subcategoryId);
    int min = staticPrice['min']!;
    int max = staticPrice['max']!;
    int avg = staticPrice['avg']!;
    int count = 0;
    String source = 'static_fallback';
    try {
      String docId = '${categoryId}__$subcategoryId';
      if (faultId != null && faultId.isNotEmpty) docId = '${docId}__$faultId';
      var db = FirebaseFirestore.instance;
      var statsDoc = await db.collection('pricingStats').doc(docId).get();
      if (statsDoc.exists) {
        var data = statsDoc.data() as Map<String, dynamic>;
        if ((data['count'] ?? 0) >= 3) {
          min = (data['min'] ?? min) as int;
          max = (data['max'] ?? max) as int;
          avg = (data['avg'] ?? avg) as int;
          count = (data['count'] ?? 0) as int;
          source = 'market';
        }
      }
    } catch (_) {}
    String rangeText = count >= 5
        ? 'KES $min - $max (Avg: $avg from $count fundi bids)'
        : 'KES $min - $max (System estimate)';
    return {
      'source': source,
      'min': min,
      'max': max,
      'avg': avg,
      'count': count,
      'rangeText': rangeText,
      'priceMin': min,
      'priceMax': max,
      'priceAvg': avg,
    };
  }

  static bool isExtraValid(int basePrice, int extraAmount) {
    if (extraAmount <= 0) return false;
    return extraAmount <= basePrice * 1.0;
  }

  static int calculateTotalRelease(
    int initialEscrow,
    int extraLabor, {
    int? newLaborTotal,
  }) {
    if (newLaborTotal != null && newLaborTotal > 0) return newLaborTotal;
    int total = initialEscrow + extraLabor;
    if (total == 0) total = initialEscrow;
    return total;
  }

  static Map<String, int> calculatePayout(
    int totalRelease, {
    String? badgeLevel,
    bool isTrialGold = false,
    int? fundiCommissionOverride,
  }) {
    int fundiPct;
    if (fundiCommissionOverride != null) {
      fundiPct = fundiCommissionOverride;
    } else if (badgeLevel != null) {
      fundiPct = getFundiCommissionPct(
        badgeLevel: badgeLevel,
        isTrialGold: isTrialGold,
      );
    } else {
      fundiPct = commissionPercent;
    }

    int clientPct = clientCommissionPercent;
    int totalCommission = (totalRelease * (fundiPct + clientPct) / 100).round();
    return {
      'total': totalRelease,
      'commission': totalCommission,
      'fundiCommissionPct': fundiPct,
      'clientCommissionPct': clientPct,
      'fundiGets': totalRelease - totalCommission,
    };
  }

  static Map<String, int> calculateDetailedPayout({
    required int labor,
    required int transportFee,
    required String badgeLevel,
    bool isTrialGold = false,
  }) {
    int fundiPct = getFundiCommissionPct(
      badgeLevel: badgeLevel,
      isTrialGold: isTrialGold,
    );
    int clientFee = (labor * clientCommissionPercent / 100).round();
    int fundiFee = (labor * fundiPct / 100).round();
    int totalClientPays = labor + transportFee + clientFee;
    int fundiReceives = labor - fundiFee + transportFee;
    return {
      'labor': labor,
      'transportFee': transportFee,
      'clientFee': clientFee,
      'fundiFee': fundiFee,
      'fundiCommissionPct': fundiPct,
      'clientCommissionPct': clientCommissionPercent,
      'totalClientPays': totalClientPays,
      'fundiReceives': fundiReceives,
      'totalCommission': clientFee + fundiFee,
    };
  }

  static Future<void> seedPricingRules() async {
    var db = FirebaseFirestore.instance;
    for (var cat in FundiTaxonomy.categories) {
      String catId = cat['id'];
      var subs = cat['subcategories'] as List;
      for (var sub in subs) {
        var s = sub as Map<String, dynamic>;
        String docId = '${catId}__${s['id']}';
        await db.collection('pricingRules').doc(docId).set({
          'categoryId': catId,
          'categoryName': cat['name'],
          'categorySlug': cat['slug'],
          'subcategoryId': s['id'],
          'subcategoryName': s['name'],
          'priceMin': s['priceMin'],
          'priceMax': s['priceMax'],
          'priceAvg': ((s['priceMin'] + s['priceMax']) / 2).round(),
          'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
          'currency': 'KES',
          'pricingVersion': version,
          'priceDictatedBy': 'system',
          'requiresSiteVisit': true,
          'maxExtraPercent': 100,
          'commissionPercent': commissionPercent,
          'clientCommissionPercent': clientCommissionPercent,
          'fundiCommissionGold': fundiCommissionGold,
          'fundiCommissionSilver': fundiCommissionSilver,
          'fundiCommissionBronze': fundiCommissionBronze,
          'fundiCommissionNone': fundiCommissionNone,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
}
