import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class TransportCalculator {
  static Future<Map<String, dynamic>> calc({
    required Map<String, dynamic> jobData,
    required String fundiId,
  }) async {
    try {
      double? jobLat, jobLng;

      // 1. Try all GeoPoint keys you actually use
      for (var k in [
        'locationGeo',
        'locationGeoPoint',
        'clientLocation',
        'customerLocation',
        'customerGeoPoint',
        'jobLocation',
      ]) {
        if (jobData[k] is GeoPoint) {
          jobLat = (jobData[k] as GeoPoint).latitude;
          jobLng = (jobData[k] as GeoPoint).longitude;
          break;
        }
      }
      // 2. Try all double keys you actually use
      jobLat ??= double.tryParse(
        '${jobData['customerLat'] ?? jobData['clientLat'] ?? jobData['lat'] ?? jobData['latitude'] ?? ''}',
      );
      jobLng ??= double.tryParse(
        '${jobData['customerLng'] ?? jobData['clientLng'] ?? jobData['lng'] ?? jobData['longitude'] ?? ''}',
      );

      double? fundiLat, fundiLng;

      // 3. Best source is job's live fundi location, not users collection (stale)
      fundiLat =
          (jobData['fundiLiveLat'] ??
                  jobData['fundiLat'] ??
                  jobData['fundiLatAtVisit'] ??
                  jobData['fundiLatitude'])
              ?.toDouble();
      fundiLng =
          (jobData['fundiLiveLng'] ??
                  jobData['fundiLng'] ??
                  jobData['fundiLngAtVisit'] ??
                  jobData['fundiLongitude'])
              ?.toDouble();

      // 4. Fallback to users collection if not in job
      if (fundiLat == null) {
        try {
          var doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fundiId)
              .get();
          var f = doc.data() ?? {};
          if (f['lastLocation'] is GeoPoint) {
            fundiLat = (f['lastLocation'] as GeoPoint).latitude;
            fundiLng = (f['lastLocation'] as GeoPoint).longitude;
          } else if (f['currentLocation'] is GeoPoint) {
            fundiLat = (f['currentLocation'] as GeoPoint).latitude;
            fundiLng = (f['currentLocation'] as GeoPoint).longitude;
          } else {
            fundiLat = double.tryParse(
              '${f['lat'] ?? f['latitude'] ?? f['lastLat'] ?? ''}',
            );
            fundiLng = double.tryParse(
              '${f['lng'] ?? f['longitude'] ?? f['lastLng'] ?? ''}',
            );
          }
        } catch (_) {}
      }

      if (jobLat == null ||
          jobLng == null ||
          fundiLat == null ||
          fundiLng == null ||
          jobLat == 0) {
        return {'km': 0.0, 'fee': 0, 'mode': 'boda', 'error': 'no coords'};
      }

      double meters = Geolocator.distanceBetween(
        fundiLat,
        fundiLng,
        jobLat,
        jobLng,
      );
      double km = meters / 1000;

      // YOUR RULE: <=1km = 100 round trip
      int fee;
      String mode;
      if (km <= 1) {
        fee = 100;
        mode = 'boda';
      } else if (km <= 3) {
        mode = 'boda';
        fee = (100 + ((km - 1) * 60)).round();
      } else if (km <= 10) {
        mode = 'tuk';
        fee = (100 + ((km - 1) * 60)).round();
      } else {
        mode = 'pickup';
        fee = (100 + ((km - 1) * 60)).round();
      }
      if (fee < 100) fee = 100;

      return {'km': km, 'fee': fee, 'mode': mode, 'meters': meters};
    } catch (e) {
      return {'km': 0.0, 'fee': 0, 'mode': 'boda', 'error': e.toString()};
    }
  }
}
