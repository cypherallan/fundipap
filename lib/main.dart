import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'app.dart';

final _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage msg) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const FundiPapApp()); // <-- FIRST, so no stuck logo

  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) return;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    const channel = AndroidNotificationChannel(
      'jobs',
      'Jobs',
      description: 'Fundipap job updates',
      importance: Importance.max,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final n = msg.notification;
      if (n == null) return;
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: n.title,
        body: n.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'jobs',
            'Jobs',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
          ),
        ),
      );
    });

    Future<void> saveToken(String? uid) async {
      if (uid == null) {
        debugPrint("SAVE TOKEN: uid null, skip");
        return;
      }
      try {
        final t = await messaging.getToken();
        debugPrint("SAVE TOKEN: uid=$uid token=$t");
        if (t == null) {
          debugPrint(
            "SAVE TOKEN: token null - google-services.json missing or emulator",
          );
          return;
        }
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': t,
          'fcmTokens': FieldValue.arrayUnion([t]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
          'fcmToken': t,
          'fcmTokens': FieldValue.arrayUnion([t]),
          'isOnline': true,
          'geopoint': const GeoPoint(
            -1.286389,
            36.817223,
          ), // temp Nairobi, update later with real location
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("SAVE TOKEN: saved to users/$uid and fundis/$uid");
      } catch (e) {
        debugPrint("SAVE TOKEN ERROR: $e");
      }
    }

    FirebaseAuth.instance.authStateChanges().listen((u) {
      debugPrint("AUTH STATE: ${u?.uid}");
      if (u != null) saveToken(u.uid);
    });
    // also save after 2 sec delay for cold start
    Future.delayed(const Duration(seconds: 2), () {
      saveToken(FirebaseAuth.instance.currentUser?.uid);
    });

    messaging.onTokenRefresh.listen((t) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': t,
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'fcmToken': t,
        'fcmTokens': FieldValue.arrayUnion([t]),
      }, SetOptions(merge: true));
    });
    FirebaseAuth.instance.authStateChanges().listen((u) => saveToken(u?.uid));
    saveToken(FirebaseAuth.instance.currentUser?.uid);
  });
}
