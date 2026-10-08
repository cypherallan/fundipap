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
      fundiLat ??= (jobData['fundiLiveLat'] ?? jobData['fundiLatAtVisit'])
          ?.toDouble();
      fundiLng ??= (jobData['fundiLiveLng'] ?? jobData['fundiLngAtVisit'])
          ?.toDouble();

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
          }
        } catch (_) {}
      }

      if (jobLat == null ||
          jobLng == null ||
          fundiLat == null ||
          fundiLng == null ||
          jobLat == 0) {
        return {'km': 0.0, 'fee': 100, 'mode': 'boda', 'meters': 0};
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
      if (km < 1.0) {
        fee = 100; // your fixed RT
        mode = 'boda';
      } else if (km <= 5.0) {
        mode = 'boda';
        fee = (km * 60).round(); // 30 one-way *2 RT
        if (fee < 100) fee = 100;
      } else {
        mode = 'matatu';
        fee = (km * 10).round(); // 5 one-way *2 RT = matatu average
        if (fee < 150) fee = 150; // minimum matatu RT
      }

      return {'km': km, 'fee': fee, 'mode': mode, 'meters': meters};
    } catch (e) {
      return {'km': 0.0, 'fee': 100, 'mode': 'boda', 'error': e.toString()};
    }
  }
}
