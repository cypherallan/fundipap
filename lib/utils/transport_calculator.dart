import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class TransportCalculator {
  // returns {km: double, fee: int, mode: String}
  static Future<Map<String, dynamic>> calc({
    required Map<String, dynamic> jobData,
    required String fundiId,
  }) async {
    try {
      // 1. Job lat/lng
      double jobLat = 0, jobLng = 0;
      if (jobData['locationGeo'] is GeoPoint) {
        jobLat = (jobData['locationGeo'] as GeoPoint).latitude;
        jobLng = (jobData['locationGeo'] as GeoPoint).longitude;
      } else {
        jobLat =
            double.tryParse('${jobData['lat'] ?? jobData['latitude'] ?? 0}') ??
            0;
        jobLng =
            double.tryParse('${jobData['lng'] ?? jobData['longitude'] ?? 0}') ??
            0;
      }

      // 2. Fundi lat/lng from users collection
      double fundiLat = 0, fundiLng = 0;
      try {
        var fundiDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(fundiId)
            .get();
        var f = fundiDoc.data() ?? {};
        if (f['lastLocation'] is GeoPoint) {
          fundiLat = (f['lastLocation'] as GeoPoint).latitude;
          fundiLng = (f['lastLocation'] as GeoPoint).longitude;
        } else {
          fundiLat = double.tryParse('${f['lat'] ?? f['latitude'] ?? 0}') ?? 0;
          fundiLng = double.tryParse('${f['lng'] ?? f['longitude'] ?? 0}') ?? 0;
        }
      } catch (_) {}

      double km = 2.0; // default if no coords
      if (jobLat != 0 && fundiLat != 0) {
        double meters = Geolocator.distanceBetween(
          fundiLat,
          fundiLng,
          jobLat,
          jobLng,
        );
        km = meters / 1000;
      }

      // 3. Mode + fee
      String mode;
      int fee;
      if (km <= 3) {
        mode = 'boda';
        fee = 150 + (km * 50).toInt(); // base 150 + 50 per km
      } else if (km <= 10) {
        mode = 'tuk';
        fee = 300 + (km * 60).toInt();
      } else {
        mode = 'pickup';
        fee = 500 + (km * 70).toInt();
      }
      if (fee < 100) fee = 100;

      return {'km': km, 'fee': fee, 'mode': mode};
    } catch (_) {
      // NEVER throw - this is why your notifications went empty before
      return {'km': 0.0, 'fee': 0, 'mode': 'boda'};
    }
  }
}
