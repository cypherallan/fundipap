import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static StreamSubscription<Position>? _trackingSub;
  static bool _isTracking = false;
  static DateTime _lastFirestoreWrite = DateTime.fromMillisecondsSinceEpoch(0);
  static double? _lastLat;
  static double? _lastLng;

  // FIX FOR ANDROID BLACK SCREEN - use instanceFor with explicit URL
  static FirebaseDatabase get _rtdb {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://fundipap-global-default-rtdb.firebaseio.com',
    );
  }

  static LocationSettings _streamSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  static LocationSettings _currentSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  static Future<Position?> determinePosition(BuildContext context) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever)
        return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: _currentSettings(),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<bool> requestAlwaysPermission(BuildContext context) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever)
        return false;
      return p == LocationPermission.always ||
          p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  // THIS WAS MISSING - needed by fundi_home_actions_mixin
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(locationSettings: _streamSettings());
  }

  static Future<void> startTracking(String uid) async {
    if (_isTracking) await stopTracking(uid);
    _isTracking = true;
    try {
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    _trackingSub = getPositionStream().listen((pos) async {
      await _updateRealtime(uid, pos);
      await _updateFirestoreThrottled(uid, pos);
    }, onError: (_) {});
  }

  static Future<void> _updateRealtime(String uid, Position pos) async {
    try {
      await _rtdb.ref('live_locations/$uid').set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'heading': pos.heading,
        'speed': pos.speed,
        'ts': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint("RTDB error: $e");
    }
  }

  static Future<void> _updateFirestoreThrottled(
    String uid,
    Position pos,
  ) async {
    try {
      final now = DateTime.now();
      if (_lastLat != null) {
        double dist = Geolocator.distanceBetween(
          _lastLat!,
          _lastLng!,
          pos.latitude,
          pos.longitude,
        );
        if (dist < 50) return;
        if (dist < 500 && now.difference(_lastFirestoreWrite).inSeconds < 60)
          return;
      } else {
        if (now.difference(_lastFirestoreWrite).inSeconds < 10) return;
      }
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastFirestoreWrite = now;
      GeoPoint geo = GeoPoint(pos.latitude, pos.longitude);
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'location': geo,
        'geopoint': geo,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> stopTracking(String uid) async {
    try {
      await _trackingSub?.cancel();
    } catch (_) {}
    _trackingSub = null;
    _isTracking = false;
    _lastLat = null;
    _lastLng = null;
    try {
      await _rtdb.ref('live_locations/$uid').remove();
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static bool get isTracking => _isTracking;

  static Stream<DatabaseEvent> trackFundi(String fundiId) {
    return _rtdb.ref('live_locations/$fundiId').onValue;
  }
}
