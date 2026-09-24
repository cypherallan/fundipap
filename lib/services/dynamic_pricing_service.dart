import 'package:cloud_firestore/cloud_firestore.dart';

class DynamicPricingService {
  static Stream<DocumentSnapshot> statsStream(
    String categoryId,
    String subcategoryId, {
    String? faultId,
  }) {
    String docId = '${categoryId}__${subcategoryId}';
    if (faultId != null && faultId.isNotEmpty) docId = '${docId}__$faultId';
    return FirebaseFirestore.instance
        .collection('pricingStats')
        .doc(docId)
        .snapshots();
  }

  static String formatRange(Map<String, dynamic> stats) {
    int min = (stats['min'] ?? 0) as int;
    int max = (stats['max'] ?? 0) as int;
    int avg = (stats['avg'] ?? 0) as int;
    int count = (stats['count'] ?? 0) as int;
    if (count == 0) return 'KES $min - $max';
    return 'KES $min - $max (Avg $avg from $count bids)';
  }

  static Future<Map<String, dynamic>?> getStats(
    String categoryId,
    String subcategoryId, {
    String? faultId,
  }) async {
    String docId = '${categoryId}__${subcategoryId}';
    if (faultId != null && faultId.isNotEmpty) docId = '${docId}__$faultId';
    var doc = await FirebaseFirestore.instance
        .collection('pricingStats')
        .doc(docId)
        .get();
    return doc.data();
  }

  static List<Map<String, dynamic>> sortBids({
    required List<Map<String, dynamic>> bids,
    required String sortBy,
    required bool ascending,
  }) {
    List<Map<String, dynamic>> sorted = List.from(bids);
    sorted.sort((a, b) {
      double getVal(Map<String, dynamic> bid) {
        switch (sortBy) {
          case 'price':
            return (bid['amount'] ?? bid['price'] ?? bid['bidAmount'] ?? 0)
                .toDouble();
          case 'rating':
            return (bid['fundiRating'] ?? bid['rating'] ?? 0).toDouble();
          case 'jobsDone':
            return (bid['fundiJobsCompleted'] ?? bid['jobsDone'] ?? 0)
                .toDouble();
          case 'distance':
            return (bid['distanceKm'] ?? bid['distance'] ?? 9999).toDouble();
          case 'fraud':
            return (bid['fraudCount'] ?? 0).toDouble();
          default:
            return 0.0;
        }
      }

      int cmp = getVal(a).compareTo(getVal(b));
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  // FIXES "recordBid isn't defined"
  static Future<void> recordBid({
    required String categoryId,
    required String subcategoryId,
    String? faultId,
    required int bidAmount,
    required String fundiId,
    required String jobId,
  }) async {
    String docId = '${categoryId}__${subcategoryId}';
    if (faultId != null && faultId.isNotEmpty) docId = '${docId}__$faultId';
    var ref = FirebaseFirestore.instance.collection('pricingStats').doc(docId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      var snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'categoryId': categoryId,
          'subcategoryId': subcategoryId,
          'faultId': faultId,
          'min': bidAmount,
          'max': bidAmount,
          'avg': bidAmount,
          'count': 1,
          'total': bidAmount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        var data = snap.data() as Map<String, dynamic>;
        int count = (data['count'] ?? 0) as int;
        int avgForTotal = (data['avg'] ?? 0) as int;
        int total = (data['total'] as int?) ?? (avgForTotal * count);
        int min = (data['min'] ?? bidAmount) as int;
        int max = (data['max'] ?? bidAmount) as int;
        int newCount = count + 1;
        int newTotal = total + bidAmount;
        tx.update(ref, {
          'min': bidAmount < min ? bidAmount : min,
          'max': bidAmount > max ? bidAmount : max,
          'avg': (newTotal / newCount).round(),
          'count': newCount,
          'total': newTotal,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
