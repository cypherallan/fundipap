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
  debugPrint("BG HANDLER START: ${msg.messageId}");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("BG HANDLER INIT DONE");
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
      debugPrint("FCM FOREGROUND: ${msg.notification?.title}");
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
      debugPrint("SAVE TOKEN START uid=$uid");
      if (uid == null) {
        debugPrint("SAVE TOKEN ABORT: uid null");
        return;
      }
      try {
        final t = await messaging.getToken();
        debugPrint(
          "SAVE TOKEN GOT token=${t?.substring(0, 20)}... for uid=$uid",
        );
        if (t == null) return;

        var old = await FirebaseFirestore.instance
            .collection('fundis')
            .where('fcmToken', isEqualTo: t)
            .get();
        debugPrint(
          "SAVE TOKEN QUERY: found ${old.docs.length} docs with same token",
        );
        for (var d in old.docs) {
          debugPrint(
            "SAVE TOKEN CHECK: doc ${d.id} vs my uid $uid - isOther=${d.id != uid} isOnline=${d.data()['isOnline']}",
          );
          if (d.id != uid) {
            debugPrint(
              "!!! ZOMBIE SUSPECT: Deleting token from other fundi ${d.id} and setting isOnline=false!!!",
            );
            await d.reference.update({
              'fcmToken': FieldValue.delete(),
              'fcmTokens': FieldValue.arrayRemove([t]),
              'isOnline': false,
            });
            debugPrint("SAVE TOKEN: cleaned other doc ${d.id}");
          }
        }

        debugPrint("SAVE TOKEN: updating users/$uid");
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': t,
          'fcmTokens': FieldValue.arrayUnion([t]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("SAVE TOKEN: updating fundis/$uid isOnline=true");
        await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
          'fcmToken': t,
          'fcmTokens': FieldValue.arrayUnion([t]),
          'isOnline': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint("SAVE TOKEN DONE uid=$uid");
      } catch (e) {
        debugPrint("SAVE TOKEN ERROR: $e");
      }
    }

    messaging.onTokenRefresh.listen((t) async {
      debugPrint("TOKEN REFRESH: new token ${t.substring(0, 20)}...");
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint("TOKEN REFRESH uid=$uid");
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
      debugPrint("AUTH STATE CHANGE: uid=${u?.uid} email=${u?.email}");
      saveToken(u?.uid);
    });

    debugPrint(
      "INITIAL SAVE TOKEN for ${FirebaseAuth.instance.currentUser?.uid}",
    );
    saveToken(FirebaseAuth.instance.currentUser?.uid);
  });
}
