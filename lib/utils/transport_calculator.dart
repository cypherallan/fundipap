import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class TransportCalculator {
  static FirebaseDatabase get _rtdb => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://fundipap-global-default-rtdb.firebaseio.com',
  );

  static Future<Map<String, dynamic>> calc({
    required Map<String, dynamic> jobData,
    required String fundiId,
    double? overrideFundiLat,
    double? overrideFundiLng,
  }) async {
    try {
      double? jobLat, jobLng;

      // 1. Job location - check all your real keys
      for (var k in [
        'geopoint',
        'location',
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
      jobLat ??= double.tryParse(
        '${jobData['customerLat'] ?? jobData['clientLat'] ?? jobData['lat'] ?? jobData['latitude'] ?? ''}',
      );
      jobLng ??= double.tryParse(
        '${jobData['customerLng'] ?? jobData['clientLng'] ?? jobData['lng'] ?? jobData['longitude'] ?? ''}',
      );

      double? fundiLat = overrideFundiLat;
      double? fundiLng = overrideFundiLng;

      // 2. RTDB LIVE - same as card - 30.6km source
      if (fundiLat == null) {
        try {
          final snap = await _rtdb.ref('live_locations/$fundiId').get();
          if (snap.exists) {
            var m = Map<String, dynamic>.from(snap.value as Map);
            fundiLat = (m['lat'] as num).toDouble();
            fundiLng = (m['lng'] as num).toDouble();
          }
        } catch (_) {}
      }

      // 3. Job's live fields
      fundiLat ??=
          (jobData['fundiLiveLat'] ??
                  jobData['fundiLatAtVisit'] ??
                  jobData['fundiLatitude'])
              ?.toDouble();
      fundiLng ??=
          (jobData['fundiLiveLng'] ??
                  jobData['fundiLng'] ??
                  jobData['fundiLngAtVisit'] ??
                  jobData['fundiLongitude'])
              ?.toDouble();

      // 4. fundis collection (your throttled)
      if (fundiLat == null) {
        try {
          var doc = await FirebaseFirestore.instance
              .collection('fundis')
              .doc(fundiId)
              .get();
          var f = doc.data() ?? {};
          if (f['location'] is GeoPoint) {
            fundiLat = (f['location'] as GeoPoint).latitude;
            fundiLng = (f['location'] as GeoPoint).longitude;
          } else if (f['geopoint'] is GeoPoint) {
            fundiLat = (f['geopoint'] as GeoPoint).latitude;
            fundiLng = (f['geopoint'] as GeoPoint).longitude;
          }
        } catch (_) {}
      }

      // 5. users fallback (old)
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
          }
        } catch (_) {}
      }

      if (jobLat == null ||
          jobLng == null ||
          fundiLat == null ||
          fundiLng == null ||
          jobLat == 0) {
        return {'km': 0.0, 'fee': 100, 'mode': 'boda', 'error': 'no coords'};
      }

      double meters = Geolocator.distanceBetween(
        fundiLat,
        fundiLng,
        jobLat,
        jobLng,
      );
      double km = meters / 1000;

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
      return {'km': 0.0, 'fee': 100, 'mode': 'boda', 'error': e.toString()};
    }
  }
}
