import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wastmobile/services/sound_service.dart';

/// Handles local (on-device) push notifications with normal and loud alarm channels.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Completer<void>? _initCompleter;

  static const _channelId = 'wastepick_main';
  static const _channelName = 'WastePick Alerts';
  static const _channelDesc = 'Pickup status and account notifications';

  static const _alarmChannelId = 'wastepick_collector_alarm';
  static const _alarmChannelName = 'Collector Request Alarm';
  static const _alarmChannelDesc = 'Loud alerts when a new pickup request arrives';

  static String? _lastRequestStatus;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    try {
      await _plugin
          .initialize(const InitializationSettings(android: android, iOS: ios))
          .timeout(const Duration(seconds: 5));

      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification'),
            enableVibration: true,
          ),
        );

        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: _alarmChannelDesc,
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('alarm'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

        await androidPlugin?.requestNotificationsPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      }
    } catch (e) {
      debugPrint('NotificationService failed to initialize: $e');
    } finally {
      _initialized = true;
      _initCompleter?.complete();
      _initCompleter = null;
    }
  }

  static Future<void> show(String title, String body, {int id = 0}) async {
    SoundService.playNotification();
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Loud alarm notification for collectors — high priority + looping in-app audio.
  static Future<void> showCollectorAlarm(String title, String body, {int id = 10}) async {
    await SoundService.playCollectorAlarm();
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800]),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      ticker: 'New pickup request',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static void onRequestStatusChanged(
    String? newStatus, {
    String? collectorName,
  }) {
    if (newStatus == null || newStatus == _lastRequestStatus) return;
    final previous = _lastRequestStatus;
    _lastRequestStatus = newStatus;

    switch (newStatus) {
      case 'proposed':
        show(
          'Collector Found!',
          collectorName != null
              ? '$collectorName has been matched to your request. Please confirm.'
              : 'A collector has been matched to your request. Please confirm.',
          id: 1,
        );
      case 'assigned':
        if (previous == 'proposed') {
          show('Confirmed!', 'Your collector is heading to you.', id: 2);
        }
      case 'on_way':
        show(
          'Collector On the Way',
          '${collectorName ?? "Your collector"} is heading to your location.',
          id: 3,
        );
      case 'arrived':
        show(
          'Collector Has Arrived',
          '${collectorName ?? "Your collector"} is at your location.',
          id: 4,
        );
      case 'completed':
        show(
          'Pickup Completed!',
          'Your waste has been collected. Please rate your experience.',
          id: 5,
        );
      case 'cancelled':
        show('Pickup Cancelled', 'Your pickup request was cancelled.', id: 6);
    }
  }

  static void onIncomingRequestChanged({
    bool hasNew = false,
    String? customerName,
  }) {
    if (hasNew) {
      showCollectorAlarm(
        'New Pickup Request!',
        customerName != null
            ? 'New request from $customerName near you. Tap to accept.'
            : 'A new pickup request is near your location. Tap to accept.',
        id: 10,
      );
    } else {
      SoundService.stopAlarm();
      _plugin.cancel(10);
    }
  }

  static void reset() {
    _lastRequestStatus = null;
    SoundService.stopAlarm();
  }
}
