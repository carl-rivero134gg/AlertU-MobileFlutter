import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level entry point function for background messaging.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🚨 Background Message Received: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// High-priority notification channel for Android foreground alerts
  static const AndroidNotificationChannel _emergencyChannel =
  AndroidNotificationChannel(
    'emergency_alerts_channel',
    'Emergency Alerts',
    description: 'High priority alerts for safety and incident reports',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Main initialization sequence
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _requestPermission();
    await _setupLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _setupForegroundHandler();
    await _setupNotificationTapHandlers();
    await getFcmToken();

    _isInitialized = true;
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: true,
    );

    debugPrint('🔔 FCM Permission Status: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@drawable/logo1');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTapPayload(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_emergencyChannel);
    }
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Foreground Message Received: ${message.notification?.title}');

      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        showLocalNotification(
          id: message.hashCode,
          title: 'AlertU',
          body: notification.body?.trim().isNotEmpty == true
              ? notification.body!.trim()
              : 'You have a new AlertU update.',
          payload: message.data.toString(),
        );
      }
    });
  }

  Future<bool> areNotificationsEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;

    try {
      final citizens = FirebaseFirestore.instance.collection('citizens');

      final directSnapshot = await citizens.doc(uid).get();
      if (directSnapshot.exists) {
        return directSnapshot.data()?['notificationsEnabled'] != false;
      }

      final authUidQuery = await citizens
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (authUidQuery.docs.isNotEmpty) {
        return authUidQuery.docs.first.data()['notificationsEnabled'] != false;
      }

      final legacyUidQuery = await citizens
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (legacyUidQuery.docs.isNotEmpty) {
        return legacyUidQuery.docs.first.data()['notificationsEnabled'] != false;
      }

      return true;
    } catch (error) {
      debugPrint('⚠️ Could not read notification preference: $error');
      return true;
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!await areNotificationsEnabled()) {
      debugPrint('🔕 Local notification suppressed because notifications are disabled.');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _emergencyChannel.id,
      _emergencyChannel.name,
      channelDescription: _emergencyChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/logo1',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> _setupNotificationTapHandlers() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTapPayload(initialMessage.data.toString());
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📲 User tapped notification from background!');
      _handleNotificationTapPayload(message.data.toString());
    });
  }

  void _handleNotificationTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('👉 Navigating/Processing Payload: $payload');
  }

  Future<String?> getFcmToken() async {
    try {
      final token = await _messaging.getToken();

      debugPrint('=================== 🔑 FCM TOKEN ===================');
      debugPrint('🔥 FCM Token: $token');
      debugPrint('====================================================');

      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('================ 🔄 FCM TOKEN REFRESHED ================');
        debugPrint('🔄 FCM Token Refreshed: $newToken');
        debugPrint('========================================================');
      });

      return token;
    } catch (e) {
      debugPrint('❌ Error fetching FCM Token: $e');
      return null;
    }
  }
}