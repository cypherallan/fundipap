import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

String _encodeGeohash(double lat, double lng) {
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  double latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  String hash = '';
  bool isEven = true;
  int bit = 0, ch = 0;
  while (hash.length < 9) {
    double mid;
    if (isEven) {
      mid = (lngMin + lngMax) / 2;
      if (lng > mid) {
        ch |= (1 << (4 - bit));
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      mid = (latMin + latMax) / 2;
      if (lat > mid) {
        ch |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }
    isEven = !isEven;
    if (bit < 4)
      bit++;
    else {
      hash += base32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

class LocationService {
  static StreamSubscription<Position>? _trackingSub;
  static bool _isTracking = false;

  // For one-time - NO intervalDuration
  static LocationSettings _currentSettings() {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      forceLocationManager: true,
    );
  }

  // For stream - WITH interval
  static LocationSettings _streamSettings() {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
      forceLocationManager: true,
    );
  }

  static Future<Position?> determinePosition(BuildContext context) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied)
      p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever)
      return null;
    try {
      return await GeolocatorPlatform.instance.getCurrentPosition(
        locationSettings: _currentSettings(),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  static Future<bool> requestAlwaysPermission(BuildContext context) async {
    await Geolocator.requestPermission();
    var p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Stream<Position> getPositionStream() {
    return GeolocatorPlatform.instance.getPositionStream(
      locationSettings: _streamSettings(),
    );
  }

  static Future<void> startTracking(String uid) async {
    if (_isTracking) await stopTracking(uid);
    _isTracking = true;
    try {
      Position initial = await GeolocatorPlatform.instance.getCurrentPosition(
        locationSettings: _currentSettings(),
      );
      await _updateFirestore(uid, initial, isOnline: true);
    } catch (e) {
    }

    _trackingSub = getPositionStream().listen(
      (pos) async {
        await _updateFirestore(uid, pos, isOnline: true);
      },
      onError: (e) {
      },
    );
  }

  static Future<void> stopTracking(String uid) async {
    await _trackingSub?.cancel();
    _trackingSub = null;
    _isTracking = false;
    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _updateFirestore(
    String uid,
    Position pos, {
    required bool isOnline,
  }) async {
    String geohash = _encodeGeohash(pos.latitude, pos.longitude);
    GeoPoint geo = GeoPoint(pos.latitude, pos.longitude);
    Map<String, dynamic> data = {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'location': geo,
      'liveLocation': geo,
      'geohash': geohash,
      'geopoint': geo,
      'accuracy': pos.accuracy,
      'heading': pos.heading,
      'speed': pos.speed,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'isLive': true,
      'isMocked': pos.isMocked,
    };
    await Future.wait([
      FirebaseFirestore.instance
          .collection('fundis')
          .doc(uid)
          .set(data, SetOptions(merge: true)),
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true)),
    ]);
  }

  static bool get isTracking => _isTracking;
}
