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

  runApp(const FundiPapApp());

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
        return;
      }
      try {
        final t = await messaging.getToken();
        if (t == null) return;

        var old = await FirebaseFirestore.instance
            .collection('fundis')
            .where('fcmToken', isEqualTo: t)
            .get();
        for (var d in old.docs) {
          if (d.id != uid) {
            await d.reference.update({
              'fcmToken': FieldValue.delete(),
              'fcmTokens': FieldValue.arrayRemove([t]),
              'isOnline': false,
            });
          }
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
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {}
    }

    messaging.onTokenRefresh.listen((t) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': t,
        'fcmTokens': FieldValue.arrayUnion([t]),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'fcmToken': t,
        'fcmTokens': FieldValue.arrayUnion([t]),
      }, SetOptions(merge: true));
    });

    FirebaseAuth.instance.authStateChanges().listen((u) {
      saveToken(u?.uid);
    });
    saveToken(FirebaseAuth.instance.currentUser?.uid);
  });
}
