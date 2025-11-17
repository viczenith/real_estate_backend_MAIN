import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/core/credential_storage.dart';
import 'package:real_estate_app/services/navigation_service.dart';
import 'package:real_estate_app/services/notification_service.dart';

class PushNotificationService {
  PushNotificationService._internal();

  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() => _instance;
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  bool _syncInProgress = false;
  final StreamController<Map<String, dynamic>> _pushEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingPushEvents =>
      _pushEventController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _refreshFcmToken();
    _messaging.onTokenRefresh.listen(_refreshFcmToken);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage, onError: (Object error, StackTrace stackTrace) {
      log('🔔 FCM onMessage error: $error', stackTrace: stackTrace, name: 'PushNotificationService');
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp, onError: (Object error, StackTrace stackTrace) {
      log('🔔 FCM onMessageOpenedApp error: $error', stackTrace: stackTrace, name: 'PushNotificationService');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessageOpenedApp(initialMessage);
    }

    _initialized = true;
    log('🔔 PushNotificationService initialized', name: 'PushNotificationService');
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    await _showRemoteNotification(message, isForeground: false);
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      log('🔔 FCM permission status: ${settings.authorizationStatus}', name: 'PushNotificationService');
    } catch (e, st) {
      log('❌ Failed to request FCM permission: $e', stackTrace: st, name: 'PushNotificationService');
    }
  }

  Future<void> _refreshFcmToken([String? token]) async {
    try {
      final currentToken = token ?? await _messaging.getToken();
      if (currentToken == null || currentToken.isEmpty) return;

      await CredentialStorage.write('fcm_token', currentToken);
      log('🔔 FCM token refreshed', name: 'PushNotificationService');

      await syncTokenWithBackend();
    } catch (e, st) {
      log('❌ Failed to refresh FCM token: $e', stackTrace: st, name: 'PushNotificationService');
    }
  }

  Future<void> syncTokenWithBackend() async {
    if (_syncInProgress) return;

    final authToken = await NavigationService.getCurrentUserToken();
    final fcmToken = await CredentialStorage.read('fcm_token');

    if (authToken == null || authToken.isEmpty) {
      log('ℹ️ Skipping FCM sync – auth token missing', name: 'PushNotificationService');
      return;
    }
    if (fcmToken == null || fcmToken.isEmpty) {
      log('ℹ️ Skipping FCM sync – FCM token missing', name: 'PushNotificationService');
      return;
    }

    final alreadyRegistered = await CredentialStorage.read('registered_fcm_token');
    if (alreadyRegistered == fcmToken) {
      return;
    }

    _syncInProgress = true;
    try {
      await ApiService().registerDeviceToken(
        authToken: authToken,
        fcmToken: fcmToken,
        platform: _detectPlatform(),
      );
      await CredentialStorage.write('registered_fcm_token', fcmToken);
      log('✅ Synced FCM token with backend', name: 'PushNotificationService');
    } catch (e, st) {
      log('❌ Failed to sync FCM token with backend: $e', stackTrace: st, name: 'PushNotificationService');
    } finally {
      _syncInProgress = false;
    }
  }

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _showRemoteNotification(message, isForeground: true);
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    await _navigateFromMessage(message.data);
  }

  Future<void> _showRemoteNotification(RemoteMessage message, {required bool isForeground}) async {
    try {
      final notification = NotificationService();
      await notification.initialize();

      final data = message.data;
      final rawType = (data['type'] ?? data['notification_type'] ?? '').toString();
      final normalizedType = rawType.toLowerCase();
      final title = message.notification?.title ?? data['title'] ?? 'Notification';
      final body = message.notification?.body ?? data['body'] ?? data['message'] ?? '';
      final id = _extractNotificationId(data, message.messageId);

      if (normalizedType == 'chat_message_deleted') {
        _pushEventController.add({
          'type': rawType.isEmpty ? 'chat_message_deleted' : rawType,
          'title': title,
          'body': body,
          'data': Map<String, dynamic>.from(data),
          'message': message,
          'messageId': message.messageId,
          'sentTime': message.sentTime,
          'isForeground': isForeground,
        });
        return;
      }

      final isChatPayload = normalizedType.contains('chat') ||
          data.containsKey('chat_id') ||
          data['category']?.toString().toLowerCase().contains('chat') == true ||
          data.containsKey('sender_name');
      final isFromSelf = (data['is_sender']?.toString().toLowerCase() == 'true') ||
          (data['from_self']?.toString().toLowerCase() == 'true');

      if (isChatPayload && !isFromSelf) {
        final chatIdRaw = data['chat_id']?.toString() ?? '';
        final chatId = chatIdRaw.isNotEmpty
            ? chatIdRaw
            : (normalizedType.contains('marketer')
                ? 'marketer_chat'
                : (normalizedType.contains('client') ? 'client_chat' : 'admin_chat'));

        final senderName = data['sender_name']?.toString().isNotEmpty == true
            ? data['sender_name'].toString()
            : title;

        String messagePreview = body;
        if (messagePreview.isEmpty) {
          if (data['message']?.toString().isNotEmpty == true) {
            messagePreview = data['message'].toString();
          } else if (data['file_name']?.toString().isNotEmpty == true) {
            messagePreview = 'Sent ${data['file_name']}';
          } else if (data['file_url']?.toString().isNotEmpty == true) {
            messagePreview = 'Sent an attachment';
          } else {
            messagePreview = 'You have a new message';
          }
        }

        await notification.showChatMessageNotification(
          senderName: senderName,
          message: messagePreview,
          chatId: chatId,
          senderAvatar: data['sender_avatar'],
          messageData: data,
          forceShow: true,
        );

        _pushEventController.add({
          'type': rawType.isEmpty ? 'chat_message' : rawType,
          'title': title,
          'body': messagePreview,
          'data': Map<String, dynamic>.from(data),
          'message': message,
          'messageId': message.messageId,
          'sentTime': message.sentTime,
          'isForeground': isForeground,
        });
        return;
      }

      final fallbackType = rawType.isEmpty ? 'notification' : rawType;

      await notification.showInAppNotification(
        title: title,
        message: body.isEmpty ? 'Tap to view details' : body,
        notificationId: id,
        payload: data,
        category: data['category']?.toString(),
        isUrgent: (data['urgent']?.toString().toLowerCase() == 'true') ||
            normalizedType == 'urgent',
      );

      _pushEventController.add({
        'type': fallbackType,
        'title': title,
        'body': body,
        'data': Map<String, dynamic>.from(data),
        'message': message,
        'messageId': message.messageId,
        'sentTime': message.sentTime,
        'isForeground': isForeground,
      });
    } catch (e, st) {
      log('❌ Failed to present FCM notification: $e', stackTrace: st, name: 'PushNotificationService');
    }
  }

  Future<void> _navigateFromMessage(Map<String, dynamic> data) async {
    try {
      final token = await NavigationService.getCurrentUserToken();
      if (token == null || token.isEmpty) {
        log('⚠️ Cannot navigate from push notification – missing user token', name: 'PushNotificationService');
        return;
      }

      final type = data['type'] ?? data['notification_type'] ?? '';
      if (type == 'chat_message') {
        await NavigationService.navigateToChat(token);
        return;
      }

      final userNotificationId = int.tryParse(data['user_notification_id']?.toString() ?? data['notification_id']?.toString() ?? '');
      if (userNotificationId != null && userNotificationId > 0) {
        await NavigationService.navigateToNotifications(token);
        NavigationService.navigator?.pushNamed(
          '/client-notification-detail',
          arguments: {
            'token': token,
            'userNotificationId': userNotificationId,
          },
        );
        return;
      }

      await NavigationService.navigateToNotifications(token);
    } catch (e, st) {
      log('❌ Failed to navigate from push notification: $e', stackTrace: st, name: 'PushNotificationService');
    }
  }

  int _extractNotificationId(Map<String, dynamic> data, String? fallbackId) {
    final candidates = [
      data['notification_id'],
      data['user_notification_id'],
      data['id'],
      fallbackId,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = int.tryParse(candidate.toString());
      if (value != null && value > 0) return value;
    }

    return DateTime.now().millisecondsSinceEpoch % 2147483647;
  }
}
