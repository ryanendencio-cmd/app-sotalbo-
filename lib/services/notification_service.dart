import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../widgets/admin_mobile_chrome.dart';

/// Top-level background message handler required by firebase_messaging.
/// Runs in a background isolate when a notification arrives and the app is closed/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // If this is a data-only payload (no 'notification' field in FCM payload),
  // show a heads-up notification using local notifications so it pops up on the phone
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'BuildTrack Alert';
    final body = message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';
    if (body.isNotEmpty || title.isNotEmpty) {
      await NotificationService.showNotification(
        title: title,
        body: body,
        id: message.messageId.hashCode,
        payload: jsonEncode(message.data),
      );
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Global navigator key to navigate directly to target screens when notifications are clicked
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId = 'buildtrack_alerts_v2';
  static const String _channelName = 'BuildTrack Alerts';
  static const String _channelDesc =
      'Notifications for requests, approvals, and rejections';
  static const String _shownPrefKey = 'shown_push_notification_ids';
  static const String _fcmTokenPrefKey = 'fcm_device_token';

  static bool _isInitialized = false;

  /// Initialize local notifications, FCM background/foreground handlers, & permissions
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                handleNotificationTap(decoded);
              }
            } catch (_) {
              handleNotificationTap({'message': payload});
            }
          }
        },
      );

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();

          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidPlugin.createNotificationChannel(channel);
        }
      }

      // Initialize Firebase Cloud Messaging if not running on unsupported platforms
      if (!kIsWeb) {
        await _initializeFirebaseMessaging();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  /// Configure Firebase Cloud Messaging (FCM) listeners, permissions, and token registration
  static Future<void> _initializeFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permissions (required for Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Authorization Status: ${settings.authorizationStatus}');

      // Enable heads-up notification display while app is in foreground
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground message listener: show high-priority heads-up local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final title = notification?.title ??
            message.data['title']?.toString() ??
            'BuildTrack Alert';
        final body = notification?.body ??
            message.data['body']?.toString() ??
            message.data['message']?.toString() ??
            '';

        if (title.isNotEmpty || body.isNotEmpty) {
          showNotification(
            title: title,
            body: body,
            id: message.messageId.hashCode,
            payload: jsonEncode(message.data),
          );
        }
      });

      // Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationTap(message.data);
      });

      // Handle notification tap when app was completely terminated/closed
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationTap(initialMessage.data);
        });
      }

      // Fetch and save the unique FCM Device Token
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Device Token retrieved: $token');
        await saveAndSyncDeviceToken(token);
      }

      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Device Token refreshed: $newToken');
        saveAndSyncDeviceToken(newToken);
      });
    } catch (e) {
      debugPrint('NotificationService _initializeFirebaseMessaging error: $e');
    }
  }

  /// Save the FCM Device Token locally and register it with the backend server
  static Future<void> saveAndSyncDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenPrefKey, token);

      // Send to backend if available
      await ApiService.registerDeviceToken(token);
    } catch (e) {
      debugPrint('saveAndSyncDeviceToken error: $e');
    }
  }

  /// Called after successful login to ensure token is synced with current user profile
  static Future<void> syncTokenAfterLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_fcmTokenPrefKey);
      if (token != null && token.isNotEmpty) {
        await ApiService.registerDeviceToken(token);
      } else if (!kIsWeb) {
        final freshToken = await FirebaseMessaging.instance.getToken();
        if (freshToken != null) {
          await saveAndSyncDeviceToken(freshToken);
        }
      }
    } catch (e) {
      debugPrint('syncTokenAfterLogin error: $e');
    }
  }

  /// Show an immediate local push notification on the mobile status bar / lock screen
  static Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: const Color(0xFFA63228),
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notifId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await _notificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService showNotification error: $e');
    }
  }

  /// Navigate to the appropriate screen when a push notification is tapped
  static void handleNotificationTap(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentContext != null) {
          handleNotificationTap(data);
        }
      });
      return;
    }

    final isWorker = ApiService.currentUserRole == 'worker';
    final type = (data['type'] ?? '').toString().toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final message = (data['message'] ?? data['body'] ?? '').toString().toLowerCase();
    final action = (data['action'] ?? data['screen'] ?? '').toString().toLowerCase();
    final combined = '$type $title $message $action';

    if (combined.contains('cash advance') ||
        combined.contains('vale') ||
        type.contains('cash')) {
      if (isWorker) {
        Navigator.of(context).pushNamed('/worker_salary');
      } else {
        Navigator.of(context).pushNamed('/cash_advance');
      }
      return;
    }

    if (combined.contains('attendance') ||
        combined.contains('time in') ||
        combined.contains('time out') ||
        combined.contains('early out') ||
        combined.contains('overtime')) {
      if (isWorker) {
        Navigator.of(context).pushNamed('/worker_attendance');
      } else {
        Navigator.of(context).pushNamed('/attendance_management');
      }
      return;
    }

    if (combined.contains('tool') || combined.contains('equipment')) {
      if (isWorker) {
        Navigator.of(context).pushNamed('/worker_tools');
      } else {
        navigateAdminMobileSection(context, 1);
      }
      return;
    }

    // Default to admin notification router if admin
    if (!isWorker) {
      navigateFromAdminNotification(context, data);
    }
  }

  /// Check a list of remote notifications and trigger phone push notification for new alerts
  static Future<void> checkAndShowNewNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    if (kIsWeb) return;
    if (notifications.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shownIds = (prefs.getStringList(_shownPrefKey) ?? []).toSet();

      // On first run, seed only read notifications so any unread alert still pops up
      if (shownIds.isEmpty) {
        final initialReadIds = notifications
            .where((n) =>
                n['read'] == true ||
                n['read']?.toString().toLowerCase() == 'true')
            .map((n) => n['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        await prefs.setStringList(_shownPrefKey, initialReadIds);
        shownIds.addAll(initialReadIds);
      }

      bool hasNew = false;
      for (final notif in notifications) {
        final id = notif['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        if (!shownIds.contains(id)) {
          final isRead = notif['read'] == true ||
              notif['read']?.toString().toLowerCase() == 'true';

          if (!isRead) {
            final title = (notif['title'] ?? 'BuildTrack Alert').toString();
            final message = (notif['message'] ?? '').toString();
            await showNotification(
              title: title,
              body: message,
              id: id.hashCode,
              payload: jsonEncode(notif),
            );
          }
          shownIds.add(id);
          hasNew = true;
        }
      }

      if (hasNew) {
        final updatedList = shownIds.toList();
        if (updatedList.length > 200) {
          updatedList.removeRange(0, updatedList.length - 200);
        }
        await prefs.setStringList(_shownPrefKey, updatedList);
      }
    } catch (e) {
      debugPrint('NotificationService checkAndShow error: $e');
    }
  }
}
