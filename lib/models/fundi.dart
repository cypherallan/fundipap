import '../data/fundi_taxonomy.dart';

class Fundi {
  final String id;
  final String name;
  final String phone;
  final String skill;
  final double rating;
  final int completedJobs;
  final List<String> categoryIds;
  final List<String> subcategoryIds;
  final String primaryCategoryId;
  final bool isVerified;
  final bool isAvailable;
  final double? lat;
  final double? lng;
  final String fundiLevel;
  final String badgeLevel;
  final int badgeScore;
  final bool isTrialGold;
  final bool isVerifiedFundi;
  final int fundiCommissionPct;

  Fundi({
    required this.id,
    required this.name,
    this.phone = '',
    required this.skill,
    this.rating = 4.5,
    this.completedJobs = 0,
    this.categoryIds = const [],
    this.subcategoryIds = const [],
    this.primaryCategoryId = 'electrical',
    this.isVerified = false,
    this.isAvailable = true,
    this.lat,
    this.lng,
    this.fundiLevel = 'L1_NEW',
    this.badgeLevel = 'none',
    this.badgeScore = 0,
    this.isTrialGold = false,
    this.isVerifiedFundi = false,
    this.fundiCommissionPct = 10,
  });

  bool canDoJob(String categoryId, String? subcategoryId) {
    if (categoryIds.contains(categoryId)) return true;
    if (categoryIds.contains('other_custom')) return true;
    var cat = FundiTaxonomy.categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {"slug": ""},
    );
    if (cat['slug'] == skill) return true;
    return false;
  }

  List<String> get skillNames {
    return categoryIds.map((cid) {
      try {
        var cat = FundiTaxonomy.categories.firstWhere((c) => c['id'] == cid);
        return cat['name'] as String;
      } catch (_) {
        return cid;
      }
    }).toList();
  }

  String get levelLabel {
    switch (fundiLevel) {
      case 'L1_NEW':
        return 'L1 NEWBIE';
      case 'L2_HUSTLER':
        return 'L2 HUSTLER';
      case 'L3_PRO':
        return 'L3 PRO';
      case 'L4_ELITE':
        return 'L4 ELITE';
      default:
        return fundiLevel;
    }
  }

  String get badgeLabel {
    if (isTrialGold) return 'GOLD TRIAL';
    return badgeLevel.toUpperCase();
  }

  bool get isGold => badgeLevel == 'gold' || isTrialGold;

  factory Fundi.fromMap(String id, Map<String, dynamic> d) {
    return Fundi(
      id: id,
      name: d['name'] ?? d['username'] ?? 'Fundi',
      phone: d['phone'] ?? '',
      skill: d['skill'] ?? d['trade'] ?? d['primarySkill'] ?? 'electrical',
      rating: (d['rating'] ?? 4.5).toDouble(),
      completedJobs: (d['completedJobs'] ?? 0).toInt(),
      categoryIds: List<String>.from(
        d['categoryIds'] ??
            d['categories'] ??
            [d['primaryCategoryId'] ?? 'electrical'],
      ),
      subcategoryIds: List<String>.from(d['subcategoryIds'] ?? []),
      primaryCategoryId:
          d['primaryCategoryId'] ?? d['categoryIds']?.first ?? 'electrical',
      isVerified: d['isVerified'] ?? false,
      isAvailable: d['isAvailable'] ?? true,
      lat: d['lat']?.toDouble(),
      lng: d['lng']?.toDouble(),
      fundiLevel: d['fundiLevel'] ?? 'L1_NEW',
      badgeLevel: d['badgeLevel'] ?? 'none',
      badgeScore: (d['badgeScore'] ?? 0).toInt(),
      isTrialGold: d['isTrialGold'] ?? false,
      isVerifiedFundi: d['isVerifiedFundi'] ?? false,
      fundiCommissionPct: (d['fundiCommissionPct'] ?? 10).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'skill': skill,
      'trade': skill,
      'primarySkill': skill,
      'rating': rating,
      'completedJobs': completedJobs,
      'categoryIds': categoryIds,
      'categories': categoryIds,
      'subcategoryIds': subcategoryIds,
      'primaryCategoryId': primaryCategoryId,
      'isVerified': isVerified,
      'isAvailable': isAvailable,
      'lat': lat,
      'lng': lng,
      'fundiLevel': fundiLevel,
      'badgeLevel': badgeLevel,
      'badgeScore': badgeScore,
      'isTrialGold': isTrialGold,
      'isVerifiedFundi': isVerifiedFundi,
      'fundiCommissionPct': fundiCommissionPct,
    };
  }
}
