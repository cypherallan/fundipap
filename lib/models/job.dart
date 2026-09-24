import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/job_taxonomy.dart';

enum JobStatus {
  open,
  assigned,
  travelling,
  site_visit,
  in_progress,
  job_completed,
  pending_completion,
  completed,
  cancelled,
  disputed,
}

class Job {
  final String id;
  final String title;
  final String description;
  final String customOtherText;

  // --- NEW TAXONOMY (24 categories) - SYSTEM DICTATES PRICE ---
  final String categoryId; // e.g. plumbing_waterworks
  final String categorySlug; // e.g. plumbing (backward compat)
  final String categoryName; // e.g. Plumbing & Waterworks
  final String? subcategoryId;
  final String? subcategoryName;
  final String? faultId;
  final String? faultName;

  // --- SYSTEM PRICING - CLIENT/FUNDI NEVER DICTATE ---
  final int systemPriceMin;
  final int systemPriceMax;
  final int systemPriceAvg;
  final int siteVisitFee;
  final int estimatedTotal; // avg + siteVisit
  final String pricingVersion;
  final String priceDictatedBy; // always 'system'
  final bool requiresSiteVisit;
  final bool isOtherCategory;

  // --- OLD COMPAT FIELDS (auto-filled from system) ---
  final int budget;
  final int offeredPrice;
  final int? budgetMin;
  final int? budgetMax;
  final int amount; // alias for budget for your old UI

  // --- LOCATION ---
  final double? lat;
  final double? lng;
  final GeoPoint? clientLocation;
  final String? locationText;

  // --- STATUS / ESCROW ---
  JobStatus status;
  final String escrowStatus;
  final String? extraEscrowStatus;
  final int? escrowAmount;
  final int? extraLaborAmount;
  final int? totalReleasedAmount;

  final String customerId;
  final String? assignedFundiId;
  final String? assignedFundiName;

  final List<String> photos;
  final DateTime? createdAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    this.customOtherText = '',
    required this.categoryId,
    required this.categorySlug,
    required this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.faultId,
    this.faultName,
    required this.systemPriceMin,
    required this.systemPriceMax,
    required this.systemPriceAvg,
    required this.siteVisitFee,
    required this.estimatedTotal,
    this.pricingVersion = 'v1_2025_kisumu',
    this.priceDictatedBy = 'system',
    this.requiresSiteVisit = true,
    this.isOtherCategory = false,
    required this.budget,
    required this.offeredPrice,
    this.budgetMin,
    this.budgetMax,
    required this.amount,
    this.lat,
    this.lng,
    this.clientLocation,
    this.locationText,
    this.status = JobStatus.open,
    this.escrowStatus = 'pending',
    this.extraEscrowStatus,
    this.escrowAmount,
    this.extraLaborAmount,
    this.totalReleasedAmount,
    required this.customerId,
    this.assignedFundiId,
    this.assignedFundiName,
    this.photos = const [],
    this.createdAt,
  });

  // System pricing resolver - NEVER takes input from client/fundi
  static Map<String, int> getSystemPrice(
    String categoryId,
    String subcategoryId,
  ) {
    try {
      var cat = FundiTaxonomy.categories.firstWhere(
        (c) => c['id'] == categoryId,
      );
      var subs = cat['subcategories'] as List;
      var sub = subs.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id'] == subcategoryId,
      );
      return {
        'min': sub['priceMin'] as int,
        'max': sub['priceMax'] as int,
        'avg': ((sub['priceMin'] + sub['priceMax']) / 2).round(),
      };
    } catch (_) {
      return {'min': 1200, 'max': 2500, 'avg': 1800};
    }
  }

  factory Job.fromFirestore(DocumentSnapshot doc) {
    var d = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      customOtherText: d['customOtherText'] ?? '',
      categoryId: d['categoryId'] ?? d['category'] ?? 'electrical',
      categorySlug: d['categorySlug'] ?? d['category'] ?? 'electrical',
      categoryName: d['categoryName'] ?? d['category'] ?? 'Electrical',
      subcategoryId: d['subcategoryId'],
      subcategoryName: d['subcategoryName'],
      faultId: d['faultId'],
      faultName: d['faultName'],
      systemPriceMin: (d['systemPriceMin'] ?? d['budgetMin'] ?? 0).toInt(),
      systemPriceMax: (d['systemPriceMax'] ?? d['budgetMax'] ?? 0).toInt(),
      systemPriceAvg: (d['systemPriceAvg'] ?? d['budget'] ?? 0).toInt(),
      siteVisitFee: (d['siteVisitFee'] ?? FundiTaxonomy.siteVisitFeeStandard)
          .toInt(),
      estimatedTotal: (d['estimatedTotal'] ?? 0).toInt(),
      pricingVersion: d['pricingVersion'] ?? 'v1_2025_kisumu',
      priceDictatedBy: d['priceDictatedBy'] ?? 'system',
      requiresSiteVisit: d['requiresSiteVisit'] ?? true,
      isOtherCategory: d['isOtherCategory'] ?? false,
      budget: (d['budget'] ?? 0).toInt(),
      offeredPrice: (d['offeredPrice'] ?? d['budget'] ?? 0).toInt(),
      budgetMin: (d['budgetMin'] as num?)?.toInt(),
      budgetMax: (d['budgetMax'] as num?)?.toInt(),
      amount: (d['budget'] ?? d['offeredPrice'] ?? 0).toInt(),
      lat: (d['lat'] ?? d['customerLat'])?.toDouble(),
      lng: (d['lng'] ?? d['customerLng'])?.toDouble(),
      clientLocation: d['clientLocation'] as GeoPoint?,
      locationText: d['location'] as String?,
      status: _parseStatus(d['status']),
      escrowStatus: d['escrowStatus'] ?? 'pending',
      extraEscrowStatus: d['extraEscrowStatus'],
      escrowAmount: (d['escrowAmount'] as num?)?.toInt(),
      extraLaborAmount: (d['extraLaborAmount'] as num?)?.toInt(),
      totalReleasedAmount: (d['totalReleasedAmount'] as num?)?.toInt(),
      customerId: d['customerId'] ?? d['clientId'] ?? '',
      assignedFundiId: d['assignedFundi'] ?? d['assignedFundiId'],
      assignedFundiName: d['assignedFundiName'],
      photos: List<String>.from(d['photos'] ?? d['images'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static JobStatus _parseStatus(String? s) {
    switch (s) {
      case 'open':
        return JobStatus.open;
      case 'assigned':
        return JobStatus.assigned;
      case 'travelling':
        return JobStatus.travelling;
      case 'site_visit':
        return JobStatus.site_visit;
      case 'in_progress':
        return JobStatus.in_progress;
      case 'job_completed':
        return JobStatus.job_completed;
      case 'pending_completion':
        return JobStatus.pending_completion;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      case 'disputed':
        return JobStatus.disputed;
      default:
        return JobStatus.open;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'customOtherText': customOtherText,
      'categoryId': categoryId,
      'categorySlug': categorySlug,
      'categoryName': categoryName,
      'category': categorySlug, // backward compat
      'subcategoryId': subcategoryId,
      'subcategoryName': subcategoryName,
      'faultId': faultId,
      'faultName': faultName,
      'systemPriceMin': systemPriceMin,
      'systemPriceMax': systemPriceMax,
      'systemPriceAvg': systemPriceAvg,
      'siteVisitFee': siteVisitFee,
      'estimatedTotal': estimatedTotal,
      'pricingVersion': pricingVersion,
      'priceDictatedBy': priceDictatedBy,
      'requiresSiteVisit': requiresSiteVisit,
      'isOtherCategory': isOtherCategory,
      'budget': budget,
      'offeredPrice': offeredPrice,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
    };
  }
}
