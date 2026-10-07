import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../services/fundi_badge_service.dart';
import '../models/customer_home_models.dart';

int toInt(dynamic v, [int fb = 0]) {
  if (v == null) return fb;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fb;
}

bool toBool(dynamic v, [bool fb = false]) {
  if (v == null) return fb;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fb;
}

double toDouble(dynamic v, [double fb = 0.0]) {
  if (v == null) return fb;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fb;
}

BadgeLevel parseBadge(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'gold':
      return BadgeLevel.gold;
    case 'silver':
      return BadgeLevel.silver;
    case 'bronze':
      return BadgeLevel.bronze;
    default:
      return BadgeLevel.none;
  }
}

double getFundiLat(Map<String, dynamic>? f) {
  if (f == null) return 0;
  if (f['liveLocation'] is GeoPoint)
    return (f['liveLocation'] as GeoPoint).latitude;
  if (f['location'] is GeoPoint) return (f['location'] as GeoPoint).latitude;
  if (f['lat'] != null) return (f['lat'] as num).toDouble();
  if (f['latitude'] != null) return (f['latitude'] as num).toDouble();
  return 0;
}

double getFundiLng(Map<String, dynamic>? f) {
  if (f == null) return 0;
  if (f['liveLocation'] is GeoPoint)
    return (f['liveLocation'] as GeoPoint).longitude;
  if (f['location'] is GeoPoint) return (f['location'] as GeoPoint).longitude;
  if (f['lng'] != null) return (f['lng'] as num).toDouble();
  if (f['longitude'] != null) return (f['longitude'] as num).toDouble();
  return 0;
}

int calcProfilePct(Map<String, dynamic>? data) {
  if (data == null) return 0;
  int total = 5, done = 0;
  if ((data['name'] ?? '').toString().isNotEmpty) done++;
  if ((data['phone'] ?? '').toString().isNotEmpty) done++;
  if ((data['photoUrl'] ?? data['profileImage'] ?? '').toString().isNotEmpty)
    done++;
  if ((data['location'] ?? data['address'] ?? '').toString().isNotEmpty) done++;
  if ((data['email'] ?? '').toString().isNotEmpty) done++;
  return ((done / total) * 100).round();
}

Future<List<BidWithFundi>> enrichBids(
  List<QueryDocumentSnapshot> bids,
  Position? userPos,
) async {
  return Future.wait(
    bids.map((b) async {
      var m = b.data() as Map<String, dynamic>;
      var fid = (m['fundiId'] ?? m['uid'] ?? '').toString();
      Map<String, dynamic>? f;
      Map<String, dynamic>? fundiLive;

      if (fid.isNotEmpty) {
        var d = await FirebaseFirestore.instance
            .collection('users')
            .doc(fid)
            .get();
        f = d.data();
        try {
          var liveDoc = await FirebaseFirestore.instance
              .collection('fundis')
              .doc(fid)
              .get(const GetOptions(source: Source.server));
          fundiLive = liveDoc.data();
        } catch (_) {
          fundiLive = f;
        }
      }

      double dist = 0;
      if (userPos != null) {
        var locSource = fundiLive ?? f;
        double fLat = getFundiLat(locSource);
        double fLng = getFundiLng(locSource);
        if (locSource != null) {
          var geo =
              locSource['liveLocation'] ??
              locSource['location'] ??
              locSource['geopoint'];
          if (geo is GeoPoint) {
            fLat = geo.latitude;
            fLng = geo.longitude;
          }
        }
        if (fLat != 0 && fLng != 0) {
          dist =
              Geolocator.distanceBetween(
                userPos.latitude,
                userPos.longitude,
                fLat,
                fLng,
              ) /
              1000;
        }
      }

      // FIXED FINAL: read from fundis first, then users
      var src = fundiLive ?? f;
      double rating = toDouble(
        src?['averageRating'] ??
            src?['avgRating'] ??
            src?['rating'] ??
            f?['averageRating'] ??
            0,
      );
      int referrals = toInt(
        src?['referrals'] ??
            src?['referralCount'] ??
            src?['totalReferrals'] ??
            f?['referrals'] ??
            0,
      );
      int jobsDone = toInt(
        src?['jobsDone'] ??
            src?['completedJobs'] ??
            src?['jobsCompleted'] ??
            f?['jobsDone'] ??
            0,
      );
      int penalty = toInt(
        src?['penaltyScore'] ?? src?['penalty'] ?? f?['penaltyScore'] ?? 0,
      );

      return BidWithFundi(
        bidDoc: b,
        bid: m,
        level: parseBadge(src?['badgeLevel'] ?? f?['badgeLevel']),
        verified:
            (src?['isVerifiedFundi'] == true) ||
            (f?['isVerifiedFundi'] == true),
        referrals: referrals,
        jobsDone: jobsDone,
        rating: rating,
        penalty: penalty,
        distanceKm: dist,
      );
    }),
  );
}

Future<void> payEscrow(String jobId, double amount) async {
  await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
    'escrowStatus': 'held',
    'escrowAmount': amount,
    'escrowPaidAt': FieldValue.serverTimestamp(),
    'escrowHeld': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> deleteJob(String jobId) async {
  var bids = await FirebaseFirestore.instance
      .collection('jobs')
      .doc(jobId)
      .collection('bids')
      .get();
  for (var d in bids.docs) {
    await d.reference.delete();
  }
  await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
}
