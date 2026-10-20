import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authState => _auth.authStateChanges();

  Future<String?> _getTokenAndLocation() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<GeoPoint?> _getGeo() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      var pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<User?> login({required String email, required String password}) async {
    var cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    var uid = cred.user!.uid;

    String? token = await _getTokenAndLocation();
    GeoPoint? geo = await _getGeo();

    if (token != null) {
      try {
        var old = await _db
            .collection('fundis')
            .where('fcmToken', isEqualTo: token)
            .get();
        for (var d in old.docs) {
          if (d.id != uid) {
            await d.reference.update({
              'fcmToken': FieldValue.delete(),
              'fcmTokens': FieldValue.arrayRemove([token]),
              'isOnline': false,
              'lastSeen': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (_) {}
    }

    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    var role = await getUserRole(uid);
    if (role == 'fundi') {
      await _db.collection('fundis').doc(uid).set({
        'fcmToken': token,
        'fcmTokens': token != null ? FieldValue.arrayUnion([token]) : [],
        'geopoint': geo,
        'location': geo ?? '',
        'locationLat': geo?.latitude,
        'locationLng': geo?.longitude,
        'locationSet': geo != null,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return cred.user;
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String role,
    required String phone,
    String? name,
    String? username,
    String? profession,
    String? searchKeyword,
    List<String>? otherSkills,
  }) async {
    var cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    var uid = cred.user!.uid;

    String? fcmToken;
    GeoPoint? geo;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      geo = await _getGeo();
    } catch (_) {}

    if (fcmToken != null) {
      try {
        var old = await _db
            .collection('fundis')
            .where('fcmToken', isEqualTo: fcmToken)
            .get();
        for (var d in old.docs) {
          if (d.id != uid) {
            await d.reference.update({
              'fcmToken': FieldValue.delete(),
              'fcmTokens': FieldValue.arrayRemove([fcmToken]),
            });
          }
        }
      } catch (_) {}
    }

    await _db.collection('users').doc(uid).set({
      'name': name ?? '',
      'username': username ?? '',
      'email': email,
      'role': role,
      'phone': phone,
      'skill': profession ?? 'General',
      'profession': profession ?? 'General',
      'searchKeyword': searchKeyword ?? profession?.toLowerCase() ?? 'general',
      'otherSkills': otherSkills ?? [],
      'photoUrl': null,
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (role == 'fundi') {
      await _db.collection('fundis').doc(uid).set({
        'name': name ?? '',
        'username': username ?? '',
        'email': email,
        'phone': phone,
        'skill': profession ?? 'General',
        'profession': profession ?? 'General',
        'searchKeyword':
            searchKeyword ?? profession?.toLowerCase() ?? 'general',
        'otherSkills': otherSkills ?? [],
        'specialization': profession ?? 'General',
        'bio': '',
        'price': 0,
        'rating': 5.0,
        'jobs': 0,
        'photoUrl': null,
        'resumes': [],
        'certificates': [],
        'portfolio': [],
        'location': geo ?? '',
        'geopoint': geo,
        'locationLat': geo?.latitude,
        'locationLng': geo?.longitude,
        'locationSet': geo != null,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken,
        'fcmTokens': fcmToken != null ? FieldValue.arrayUnion([fcmToken]) : [],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return cred.user;
  }

  Future<String?> getUserRole(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        String? token;
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (_) {}
        // Only update fundis if role is fundi
        var userDoc = await _db.collection('users').doc(uid).get();
        var role = userDoc.data()?['role'];
        if (role == 'fundi') {
          await _db.collection('fundis').doc(uid).set({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          if (token != null) {
            await _db.collection('fundis').doc(uid).update({
              'fcmToken': FieldValue.delete(),
              'fcmTokens': FieldValue.arrayRemove([token]),
            });
          }
        }
        await _db.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
