import '../data/job_taxonomy.dart';

class Fundi {
  final String id;
  final String name;
  final String phone;
  final String skill; // backward compat: primary trade slug e.g. 'electrical'
  final double rating;
  final int completedJobs;

  // NEW - 24 categories system
  final List<String> categoryIds; // e.g. ['plumbing_waterworks', 'electrical']
  final List<String>
  subcategoryIds; // e.g. ['leaking_pipe', 'full_house_wiring']
  final String primaryCategoryId;
  final bool isVerified;
  final bool isAvailable;
  final double? lat;
  final double? lng;

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
  });

  // Check if fundi can do a job - matches category system
  bool canDoJob(String categoryId, String? subcategoryId) {
    if (categoryIds.contains(categoryId)) return true;
    if (categoryIds.contains('other_custom'))
      return true; // other can do anything
    // backward compat with old skill string
    var cat = FundiTaxonomy.categories.firstWhere(
      (c) => c['id'] == categoryId,
      orElse: () => {"slug": ""},
    );
    if (cat['slug'] == skill) return true;
    return false;
  }

  // Get display name for skills
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
    };
  }
}
