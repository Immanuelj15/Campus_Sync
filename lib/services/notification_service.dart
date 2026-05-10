import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:campus_sync/firebase_options.dart';
import 'package:campus_sync/services/db_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class NotificationService {
  NotificationService({FirebaseMessaging? messaging, DbService? dbService})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _dbService = dbService ?? DbService();

  final FirebaseMessaging _messaging;
  final DbService _dbService;

  Future<void> initialize(
    GlobalKey<ScaffoldMessengerState> messengerKey,
  ) async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      provisional: false,
      sound: true,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      await _dbService.saveFcmToken(uid: user.uid, token: token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _dbService.saveFcmToken(uid: currentUser.uid, token: token);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      final messenger = messengerKey.currentState;
      if (messenger == null) {
        return;
      }
      final title = message.notification?.title ?? 'Campus Sync';
      final body = message.notification?.body ?? 'You have a new update.';
      messenger.showSnackBar(SnackBar(content: Text('$title: $body')));
    });
  }

  Future<void> syncTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      await _dbService.saveFcmToken(uid: user.uid, token: token);
    }
  }
}
