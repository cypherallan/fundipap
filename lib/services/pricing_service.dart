import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/job_taxonomy.dart';

class PricingService {
  static const String version = 'v2_2026_comprehensive';
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

  // FIXES "Too many positional arguments" - supports 0 AND 1 arg
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

  // FIXES "getPriceToShow isn't defined"
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
      String docId = '${categoryId}__${subcategoryId}';
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

  static Map<String, int> calculatePayout(int totalRelease) {
    int commission = (totalRelease * commissionPercent / 100).round();
    return {
      'total': totalRelease,
      'commission': commission,
      'fundiGets': totalRelease - commission,
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
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
}
