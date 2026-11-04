import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:system_alert_window/system_alert_window.dart';
import '../../core/navigation/app_navigator_key.dart';
import '../../shared/widgets/panic_button_popup.dart';
import '../../features/panic_button/data/models/panic_button_mobile_response_model.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'guardify_default',
    'Rumara Security Notifications',
    description: 'Default notifications channel',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _panicAndroidChannel =
      AndroidNotificationChannel(
    'guardify_panic_v4',
    'Rumara Security Panic Alerts',
    description: 'Panic button emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    sound: const UriAndroidNotificationSound('android.resource://android/raw/alarm'), // System alarm sound
  );

  Future<void> initialize() async {
    final initializationSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: const DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final type = data['type']?.toString();
            if (type == 'panic_button') {
              _showPanicButtonPopup(data);
            }
          }
        } catch (_) {
          // ignore
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(_androidChannel);
      await androidPlugin?.createNotificationChannel(_panicAndroidChannel);

      await androidPlugin?.requestNotificationsPermission();
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle notification when app is opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check if app was opened from a terminated state via notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('🚨 [PushNotification] App opened from terminated state via notification');
      // Delay to ensure app is fully initialized
      Future.delayed(const Duration(milliseconds: 1000), () {
        _handleMessageOpenedApp(initialMessage);
      });
    }
  }

  Future<void> showPanicOverlayOrNotification(
    Map<String, dynamic> rawData, {
    bool canRequestOverlayPermission = false,
  }) async {
    if (Platform.isAndroid) {
      final shown = await _tryShowPanicOverlay(
        rawData,
        canRequestOverlayPermission: canRequestOverlayPermission,
      );
      if (shown) return;
    }

    await showPanicFullScreenNotification(rawData);
  }

  Future<bool> _tryShowPanicOverlay(
    Map<String, dynamic> rawData, {
    required bool canRequestOverlayPermission,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final hasPermission = await SystemAlertWindow.checkPermissions(
        prefMode: SystemWindowPrefMode.OVERLAY,
      );

      if (hasPermission != true) {
        if (!canRequestOverlayPermission) return false;

        final granted = await SystemAlertWindow.requestPermissions(
          prefMode: SystemWindowPrefMode.OVERLAY,
        );
        if (granted != true) return false;
      }

      final title = 'PANIC BUTTON';
      final body = rawData['IncidentName']?.toString() ??
          rawData['incidentName']?.toString() ??
          rawData['Description']?.toString() ??
          rawData['description']?.toString() ??
          'Ada situasi darurat';

      final ok = await SystemAlertWindow.showSystemWindow(
        prefMode: SystemWindowPrefMode.OVERLAY,
        notificationTitle: title,
        notificationBody: body,
        gravity: SystemWindowGravity.TOP,
      );

      if (ok != true) return false;

      await SystemAlertWindow.sendMessageToOverlay(rawData);
      return true;
    } catch (_) {
      return false;
    }
  }
  
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('🚨 [PushNotification] Message opened app - data: ${message.data}');
    
    // Check if this is a panic button notification
    final type = message.data['type']?.toString();
    
    if (type == 'panic_button') {
      print('🚨 [PushNotification] Panic button notification opened app');
      // Wait a bit for app to be fully ready
      await Future.delayed(const Duration(milliseconds: 500));
      _showPanicButtonPopup(message.data);
      return;
    }
    
    // Handle other notification types if needed
    print('ℹ️ [PushNotification] Regular notification opened app');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Check if this is a panic button notification
    final type = message.data['type']?.toString();
    
    if (type == 'panic_button') {
      // Show panic button popup with vibration
      _showPanicButtonPopup(message.data);
      return;
    }

    // Handle regular notification
    await _showForegroundNotification(message);
  }

  void _showPanicButtonPopup(Map<String, dynamic> data) {
    print('🚨 [PushNotification] Showing panic button popup...');
    
    // Wait for context to be available (especially when app is opened from terminated state)
    _waitForContextAndShow(data);
  }
  
  void _waitForContextAndShow(Map<String, dynamic> data, {int retryCount = 0}) {
    final navigatorKey = AppNavigatorKey.navigatorKey;
    final context = navigatorKey.currentContext;
    
    if (context == null) {
      if (retryCount < 10) {
        // Retry up to 10 times (5 seconds total)
        print('⚠️ [PushNotification] Context not available, retrying... (${retryCount + 1}/10)');
        Future.delayed(const Duration(milliseconds: 500), () {
          _waitForContextAndShow(data, retryCount: retryCount + 1);
        });
        return;
      } else {
        print('❌ [PushNotification] Cannot show panic popup: No context available after retries');
        return;
      }
    }
    
    print('✅ [PushNotification] Context available, proceeding to show popup');
    
    // Extract and parse data
    _processAndShowPopup(data, context);
  }
  
  void _processAndShowPopup(Map<String, dynamic> data, BuildContext context) {

    // Extract data field (the actual panic button data)
    Map<String, dynamic> panicButtonData;
    
    print('🔍 [PushNotification] Received data keys: ${data.keys.toList()}');
    print('🔍 [PushNotification] Data content: $data');
    
    if (data.containsKey('data')) {
      final dataField = data['data'];
      print('🔍 [PushNotification] Data field type: ${dataField.runtimeType}');
      print('🔍 [PushNotification] Data field content: $dataField');
      
      if (dataField is Map) {
        // Data is already a Map
        panicButtonData = Map<String, dynamic>.from(dataField);
        print('✅ [PushNotification] Data is Map, extracted: $panicButtonData');
      } else if (dataField is String) {
        // Data is a JSON string, need to parse it
        try {
          print('🔍 [PushNotification] Data is String, attempting to parse JSON...');
          panicButtonData = jsonDecode(dataField) as Map<String, dynamic>;
          print('✅ [PushNotification] Successfully parsed JSON string: $panicButtonData');
        } catch (e) {
          print('⚠️ [PushNotification] Failed to parse JSON string: $e');
          // Fallback: use all data except 'type'
          panicButtonData = Map<String, dynamic>.from(data);
          panicButtonData.remove('type');
        }
      } else {
        // Unknown type, use all data except 'type'
        print('⚠️ [PushNotification] Data field is unknown type, using all data');
        panicButtonData = Map<String, dynamic>.from(data);
        panicButtonData.remove('type');
      }
    } else {
      // If data is not nested, use all data except 'type'
      print('⚠️ [PushNotification] No "data" field found, using all data except "type"');
      panicButtonData = Map<String, dynamic>.from(data);
      panicButtonData.remove('type');
    }

    print('🔍 [PushNotification] Final panicButtonData keys: ${panicButtonData.keys.toList()}');
    print('🔍 [PushNotification] Final panicButtonData: $panicButtonData');

    // Try to parse as PanicButtonMobileResponseModel (new simplified model)
    PanicButtonMobileResponseModel? mobileResponseModel;
    if (panicButtonData.isNotEmpty) {
      try {
        mobileResponseModel = PanicButtonMobileResponseModel.fromJson(panicButtonData);
        print('✅ [PushNotification] Successfully parsed panic button mobile response');
        print('✅ [PushNotification] Parsed model - Reporter: ${mobileResponseModel.reporter ?? "null"}');
        print('✅ [PushNotification] Parsed model - AreasName: ${mobileResponseModel.areasName ?? "null"}');
        print('✅ [PushNotification] Parsed model - IncidentName: ${mobileResponseModel.incidentName ?? "null"}');
        print('✅ [PushNotification] Parsed model - Description: ${mobileResponseModel.description ?? "null"}');
        print('✅ [PushNotification] Parsed model - Status: ${mobileResponseModel.status ?? "null"}');
        print('✅ [PushNotification] Parsed model - ReporterDate: ${mobileResponseModel.reporterDate ?? "null"}');
      } catch (e, stackTrace) {
        print('⚠️ [PushNotification] Failed to parse panic button mobile response: $e');
        print('⚠️ [PushNotification] Stack trace: $stackTrace');
        print('⚠️ [PushNotification] Raw data: $panicButtonData');
        // Continue with raw data if parsing fails
        mobileResponseModel = null;
      }
    } else {
      print('⚠️ [PushNotification] panicButtonData is empty!');
    }

    // Show popup that cannot be closed
    print('🚨 [PushNotification] Displaying panic button popup dialog...');
    
    // Use rootNavigator to ensure dialog shows even when app is opened from terminated state
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      useRootNavigator: true, // Important: use root navigator
      builder: (dialogContext) {
        print('✅ [PushNotification] Panic button popup dialog created');
        return PanicButtonPopup(
          mobileResponseData: mobileResponseModel,
          rawData: panicButtonData,
          durationSeconds: 45, // 45 seconds (between 30-60)
        );
      },
    );
    print('✅ [PushNotification] Panic button popup dialog shown');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) {
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        // Use system default notification sound (no custom file needed)
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Cancel all active notifications (used when stopping panic alarm)
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      print('✅ [PushNotificationService] All notifications cancelled');
    } catch (e) {
      print('⚠️ [PushNotificationService] Error cancelling notifications: $e');
    }
  }

  Future<void> showPanicFullScreenNotification(Map<String, dynamic> rawData) async {
    if (!Platform.isAndroid) return;

    Map<String, dynamic> panicData;
    if (rawData.containsKey('data')) {
      final dataField = rawData['data'];
      if (dataField is Map) {
        panicData = Map<String, dynamic>.from(dataField);
      } else if (dataField is String) {
        try {
          panicData = jsonDecode(dataField) as Map<String, dynamic>;
        } catch (_) {
          panicData = Map<String, dynamic>.from(rawData);
        }
      } else {
        panicData = Map<String, dynamic>.from(rawData);
      }
    } else {
      panicData = Map<String, dynamic>.from(rawData);
    }

    PanicButtonMobileResponseModel? model;
    try {
      model = PanicButtonMobileResponseModel.fromJson(panicData);
    } catch (_) {
      model = null;
    }

    final titleParts = <String>['PANIC'];
    final incidentName = model?.incidentName ??
        panicData['IncidentName']?.toString() ??
        panicData['incidentName']?.toString();
    if (incidentName != null && incidentName.isNotEmpty) {
      titleParts.add(incidentName);
    }
    final title = titleParts.join(' - ');

    final bodyParts = <String>[];
    final areasName = model?.areasName ??
        panicData['AreasName']?.toString() ??
        panicData['areasName']?.toString();
    if (areasName != null && areasName.isNotEmpty) {
      bodyParts.add(areasName);
    }

    final reporter = model?.reporter ??
        panicData['Reporter']?.toString() ??
        panicData['reporter']?.toString();
    if (reporter != null && reporter.isNotEmpty) {
      bodyParts.add('Pelapor: $reporter');
    }

    final status = model?.status ??
        panicData['Status']?.toString() ??
        panicData['status']?.toString();
    if (status != null && status.isNotEmpty) {
      bodyParts.add('Status: $status');
    }

    final reporterDateRaw = model?.reporterDate ??
        panicData['ReporterDate']?.toString() ??
        panicData['reporterDate']?.toString();
    if (reporterDateRaw != null && reporterDateRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(reporterDateRaw);
      if (parsed != null) {
        try {
          bodyParts.add(DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(parsed));
        } catch (_) {
          bodyParts.add(parsed.toString());
        }
      } else {
        bodyParts.add(reporterDateRaw);
      }
    }

    final description = model?.description ??
        panicData['Description']?.toString() ??
        panicData['description']?.toString();
    if (description != null && description.isNotEmpty) {
      bodyParts.add(description);
    }

    final body = bodyParts.isNotEmpty
        ? bodyParts.join(' • ')
        : 'Ada situasi darurat - tap untuk membuka';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _panicAndroidChannel.id,
        _panicAndroidChannel.name,
        channelDescription: _panicAndroidChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        // Don't auto-launch UI while app is in background. User must tap notification.
        fullScreenIntent: false,
        playSound: true,
        sound: const UriAndroidNotificationSound('android.resource://android/raw/alarm'), // System alarm sound
        enableVibration: true,
        ticker: 'panic',
      ),
    );

    final payload = jsonEncode({
      'type': 'panic_button',
      ...rawData,
    });

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
