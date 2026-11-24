import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'buildtrack_alerts';
  static const String _channelName = 'BuildTrack Alerts';
  static const String _channelDesc =
      'Notifications for requests, approvals, and rejections';
  static const String _shownPrefKey = 'shown_push_notification_ids';

  static bool _isInitialized = false;

  /// Initialize local notification channels & permissions
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
      await _notificationsPlugin.initialize(initSettings);

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
          );
          await androidPlugin.createNotificationChannel(channel);
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize error: $e');
    }
  }

  /// Show an immediate local push notification on the mobile status bar
  static Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    if (kIsWeb) return;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notifId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await _notificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      debugPrint('NotificationService showNotification error: $e');
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

      // On first run, seed existing IDs to prevent flooding old alerts
      if (shownIds.isEmpty) {
        final initialIds = notifications
            .map((n) => n['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
        await prefs.setStringList(_shownPrefKey, initialIds);
        return;
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
            );
          }
          shownIds.add(id);
          hasNew = true;
        }
      }

      if (hasNew) {
        // Keep list bounded to last 200 IDs
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

