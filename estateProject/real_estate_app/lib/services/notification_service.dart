import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'navigation_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification settings
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _ledEnabled = true;
  bool _popupEnabled = true;

  // Message tracking for dynamic notifications
  Set<int> _processedMessageIds = <int>{};
  String? _lastSenderId;
  int _messageCount = 0;

  WebSocketChannel? _channel;

  // Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔔 Initializing notification service with enhanced features...');

    // Load notification preferences
    await _loadNotificationSettings();

    // Check if notifications are allowed first
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    print('🔔 Initial notification permission status: $isAllowed');

    // Initialize Awesome Notifications with enhanced configuration
    bool initSuccess = await AwesomeNotifications().initialize(
      'resource://mipmap/ic_company_logo',
      [
        NotificationChannel(
          channelGroupKey: 'real_estate_chat',
          channelKey: 'chat_messages',
          channelName: 'Chat Messages',
          channelDescription:
              'Real-time notifications for new chat messages from admin support',
          defaultColor: const Color(0xFF075E54), // WhatsApp dark green
          ledColor: const Color(0xFF25D366), // WhatsApp light green
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          onlyAlertOnce: false,
          playSound: _soundEnabled,
          soundSource:
              _soundEnabled ? 'resource://raw/notification_sound' : null,
          enableVibration: _vibrationEnabled,
          vibrationPattern: _vibrationEnabled
              ? Int64List.fromList([0, 500, 200, 500])
              : null, // WhatsApp-style vibration
          enableLights: _ledEnabled,
          criticalAlerts: false,
          defaultPrivacy: NotificationPrivacy.Public,
          icon: 'resource://mipmap/ic_company_logo',
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
        NotificationChannel(
          channelGroupKey: 'real_estate_chat',
          channelKey: 'file_messages',
          channelName: 'File Messages',
          channelDescription:
              'Notifications for file attachments and media from admin',
          defaultColor: const Color(0xFF075E54),
          ledColor: const Color(0xFF25D366),
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          onlyAlertOnce: false,
          playSound: _soundEnabled,
          soundSource:
              _soundEnabled ? 'resource://raw/notification_sound' : null,
          enableVibration: _vibrationEnabled,
          vibrationPattern: _vibrationEnabled
              ? Int64List.fromList([150, 100, 150])
              : null, // Different pattern for files
          enableLights: _ledEnabled,
          criticalAlerts: false,
          defaultPrivacy: NotificationPrivacy.Public,
          icon: 'resource://drawable/ic_file_notification',
          defaultRingtoneType: DefaultRingtoneType.Notification,
        ),
        NotificationChannel(
          channelGroupKey: 'real_estate_chat',
          channelKey: 'admin_alerts',
          channelName: 'Admin Alerts',
          channelDescription: 'Important alerts and announcements from admin',
          defaultColor: const Color(0xFFFF5722), // Orange for alerts
          ledColor: const Color(0xFFFF5722),
          importance: NotificationImportance.Max, // Highest priority
          channelShowBadge: true,
          onlyAlertOnce: false,
          playSound: true, // Always play sound for alerts
          soundSource: 'resource://raw/notification_sound',
          enableVibration: true, // Always vibrate for alerts
          vibrationPattern: Int64List.fromList(
              [200, 100, 200, 100, 200]), // More prominent vibration
          enableLights: true, // Always show LED for alerts
          criticalAlerts: true,
          defaultPrivacy: NotificationPrivacy.Public,
          icon: 'resource://mipmap/ic_company_logo',
          defaultRingtoneType: DefaultRingtoneType.Alarm,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'real_estate_chat',
          channelGroupName: 'Real Estate Chat',
        ),
      ],
      debug: false, // Set to false for production
    );

    print('🔔 Awesome Notifications initialization result: $initSuccess');

    if (!initSuccess) {
      print('❌ Failed to initialize Awesome Notifications');
      _isInitialized = false;
      return;
    }

    // Immediately request permissions
    bool hasPermissions = await AwesomeNotifications().isNotificationAllowed();
    print('🔔 Current notification permissions: $hasPermissions');

    if (!hasPermissions) {
      print('🔔 Requesting notification permissions...');
      hasPermissions =
          await AwesomeNotifications().requestPermissionToSendNotifications();
      print('🔔 Permission request result: $hasPermissions');
    }

    // Set action handlers for interactive notifications
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    // Initialize Flutter Local Notifications for iOS compatibility
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For important alerts
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print(
        '🔔 Notification service initialized successfully with enhanced features');
  }

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
  }

  Stream<dynamic> get realTimeNotifications {
    return _channel?.stream ?? const Stream.empty();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  // Load notification settings from shared preferences
  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool('notification_sound') ?? true;
      _vibrationEnabled = prefs.getBool('notification_vibration') ?? true;
      _ledEnabled = prefs.getBool('notification_led') ?? true;
      _popupEnabled = prefs.getBool('notification_popup') ?? true;

      print('🔔 Loaded notification settings:');
      print('   Sound: $_soundEnabled');
      print('   Vibration: $_vibrationEnabled');
      print('   LED: $_ledEnabled');
      print('   Popup: $_popupEnabled');
    } catch (e) {
      print('⚠️ Failed to load notification settings, using defaults: $e');
      // Use default settings if loading fails
    }
  }

  Future<int?> showDownloadNotification(String fileName) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'file_messages',
          title: 'Downloading $fileName',
          body: 'Download in progress',
          notificationLayout: NotificationLayout.ProgressBar,
          progress: 0,
          locked: true,
          autoDismissible: false,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'type': 'file_download',
            'file_name': fileName,
          },
        ),
      );
      return notificationId;
    } catch (e) {
      print('❌ Failed to show download notification: $e');
      return null;
    }
  }

  Future<void> updateDownloadNotification({
    required int notificationId,
    required String fileName,
    required double progress,
  }) async {
    try {
      final percent = progress.isNaN ? 0 : (progress * 100).clamp(0, 100).round();
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'file_messages',
          title: 'Downloading $fileName',
          body: '$percent% completed',
          notificationLayout: NotificationLayout.ProgressBar,
          progress: percent.toDouble(),
          locked: true,
          autoDismissible: false,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'type': 'file_download',
            'file_name': fileName,
          },
        ),
      );
    } catch (e) {
      print('⚠️ Failed to update download notification: $e');
    }
  }

  Future<void> completeDownloadNotification({
    required int notificationId,
    required String fileName,
    required String filePath,
    String? fileUrl,
  }) async {
    try {
      await AwesomeNotifications().cancel(notificationId);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'file_messages',
          title: fileName,
          body: 'Download complete · Tap Open to view',
          notificationLayout: NotificationLayout.Default,
          locked: false,
          autoDismissible: true,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'type': 'file_download_complete',
            'file_name': fileName,
            'file_path': filePath,
            if (fileUrl != null) 'file_url': fileUrl,
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'open_file',
            label: 'Open',
            actionType: ActionType.Default,
          ),
        ],
      );
    } catch (e) {
      print('⚠️ Failed to finalize download notification: $e');
    }
  }

  Future<void> failDownloadNotification({
    required int notificationId,
    required String fileName,
    String? reason,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'file_messages',
          title: fileName,
          body: reason != null && reason.isNotEmpty
              ? 'Download failed: $reason'
              : 'Download failed',
          notificationLayout: NotificationLayout.Default,
          locked: false,
          autoDismissible: true,
          displayOnForeground: true,
          displayOnBackground: true,
          payload: {
            'type': 'file_download_failed',
            'file_name': fileName,
          },
        ),
      );
    } catch (e) {
      print('⚠️ Failed to show download failure notification: $e');
    }
  }

  Future<void> cancelDownloadNotification(int notificationId) async {
    try {
      await AwesomeNotifications().cancel(notificationId);
    } catch (e) {
      print('⚠️ Failed to cancel download notification: $e');
    }
  }

  static Future<void> _openDownloadedFileFromNotification(
    String filePath,
    String fileUrl,
    String fileName,
  ) async {
    try {
      if (kIsWeb) {
        if (fileUrl.isNotEmpty) {
          final uri = Uri.tryParse(fileUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        return;
      }

      if (filePath.isNotEmpty) {
        await OpenFile.open(filePath);
        return;
      }

      if (fileUrl.isNotEmpty) {
        final uri = Uri.tryParse(fileUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      print('⚠️ No valid file path or URL to open for $fileName');
    } catch (e) {
      print('❌ Failed to open downloaded file from notification: $e');
    }
  }

  // Save notification settings
  Future<void> updateNotificationSettings({
    bool? sound,
    bool? vibration,
    bool? led,
    bool? popup,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (sound != null) {
        _soundEnabled = sound;
        await prefs.setBool('notification_sound', sound);
      }
      if (vibration != null) {
        _vibrationEnabled = vibration;
        await prefs.setBool('notification_vibration', vibration);
      }
      if (led != null) {
        _ledEnabled = led;
        await prefs.setBool('notification_led', led);
      }
      if (popup != null) {
        _popupEnabled = popup;
        await prefs.setBool('notification_popup', popup);
      }

      print('🔔 Updated notification settings');

      // Reinitialize with new settings
      _isInitialized = false;
      await initialize();
    } catch (e) {
      print('❌ Failed to save notification settings: $e');
    }
  }

  // Static methods for notification lifecycle events
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    print('🔔 Notification created: ${receivedNotification.title}');
  }

  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    print('🔔 Notification displayed: ${receivedNotification.title}');
  }

  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('🔔 Notification dismissed: ${receivedAction.title}');
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Navigate to chat screen when notification is tapped
    // You can implement navigation logic here
    // Removed debug print for production
  }

  // Request permissions
  Future<bool> requestPermissions() async {
    print('🔔 Requesting notification permissions...');

    // Request Awesome Notifications permissions
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    print('🔔 Current permission status: $isAllowed');

    if (!isAllowed) {
      print('🔔 Requesting permission from user...');
      isAllowed =
          await AwesomeNotifications().requestPermissionToSendNotifications();
      print('🔔 Permission request result: $isAllowed');
    }

    // Request Flutter Local Notifications permissions for iOS
    if (Platform.isIOS) {
      print('🔔 Requesting iOS specific permissions...');
      final iosPermissions = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      print('🔔 iOS permissions result: $iosPermissions');
    }

    // Also check system-level notification settings
    if (Platform.isAndroid) {
      print('🔔 Checking Android notification settings...');
      // You could add additional Android-specific permission checks here
    }

    print('🔔 Final permission status: $isAllowed');
    return isAllowed;
  }

  // Enhanced WhatsApp-style chat message notification with dynamic detection
  Future<void> showChatMessageNotification({
    required String senderName,
    required String message,
    required String chatId,
    String? senderAvatar,
    bool isGroup = false,
    Map<String, dynamic>? messageData,
    bool forceShow = false, // Force show even if app is foreground
  }) async {
    if (!_isInitialized) {
      print('🔔 NotificationService not initialized, initializing now...');
      await initialize();
    }

    // Enhanced message tracking for duplicates
    final messageId = messageData?['id'];
    if (messageId != null && _processedMessageIds.contains(messageId)) {
      print('🔔 Skipping duplicate notification for message ID: $messageId');
      return;
    }

    print('🔔 Creating enhanced notification:');
    print('   Sender: $senderName');
    print('   Message: "$message"');
    print('   Chat ID: $chatId');
    print('   Message ID: $messageId');
    print('   Force Show: $forceShow');

    // Check permissions first
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    print('🔔 Notification permission status: $isAllowed');

    if (!isAllowed) {
      print('❌ Notifications not allowed - requesting permissions');
      isAllowed =
          await AwesomeNotifications().requestPermissionToSendNotifications();
      print('🔔 Permission request result: $isAllowed');

      if (!isAllowed) {
        print('❌ User denied notification permissions');
        return;
      }
    }

    // Track conversation context for smart grouping
    bool isNewConversation = _lastSenderId != senderName;
    if (isNewConversation) {
      _messageCount = 1;
    } else {
      _messageCount++;
    }
    _lastSenderId = senderName;

    // Create unique notification ID
    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    print('🔔 Generated notification ID: $notificationId');

    // Enhanced message formatting for better readability
    String displayMessage = message;
    if (displayMessage.length > 100) {
      displayMessage = '${displayMessage.substring(0, 97)}...';
    }

    // Create conversation summary for grouped notifications
    String? summary;
    if (_messageCount > 1) {
      summary = isGroup
          ? '$_messageCount new messages'
          : '$_messageCount new messages from $senderName';
    }

    // Determine notification priority based on content
    String channelKey = 'chat_messages';

    // Check for urgent keywords
    if (_isUrgentMessage(message)) {
      channelKey = 'admin_alerts';
      print('🔔 Detected urgent message, using high priority channel');
    }

    try {
      // Show enhanced notification using Awesome Notifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: channelKey,
          groupKey: 'real_estate_chat_$chatId',
          title: senderName,
          body: displayMessage,
          summary: summary,
          notificationLayout: NotificationLayout.Messaging,
          largeIcon: senderAvatar ?? 'asset://assets/logo.png',
          icon: 'resource://drawable/ic_chat_notification',
          color: const Color(0xFF075E54),
          backgroundColor: const Color(0xFF075E54),
          payload: {
            'type': 'chat_message',
            'chat_id': chatId,
            'sender': senderName,
            'message_id': messageId?.toString() ?? '',
            'timestamp': DateTime.now().toIso8601String(),
          },
          autoDismissible: true,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          wakeUpScreen: true,
          customSound:
              _soundEnabled ? 'resource://raw/notification_sound' : null,
          category: NotificationCategory.Message,
          actionType: ActionType.Default,
          locked: false, // Allow swipe to dismiss
        ),
        actionButtons: _buildActionButtons(chatId, messageId?.toString()),
      );

      print(
          '🔔 Enhanced notification created successfully with ID: $notificationId');

      // Add to processed messages to prevent duplicates
      if (messageId != null) {
        _processedMessageIds.add(messageId);
        // Keep only last 100 message IDs to prevent memory issues
        if (_processedMessageIds.length > 100) {
          final sorted = _processedMessageIds.toList()..sort();
          _processedMessageIds = sorted.skip(50).toSet();
        }
      }

      // Update notification badge count
      await _updateBadgeCount();
      print('🔔 Badge count updated');

      // Trigger haptic feedback for immediate user feedback
      if (_vibrationEnabled) {
        await _triggerHapticFeedback();
      }
    } catch (e) {
      print('❌ Failed to create enhanced notification: $e');

      // Fallback to basic notification
      try {
        print('🔔 Attempting fallback notification...');
        await _showFallbackNotification(
          notificationId: notificationId,
          title: senderName,
          body: displayMessage,
          sound: _soundEnabled,
          vibration: _vibrationEnabled,
        );
        print('🔔 Fallback notification sent successfully');
      } catch (fallbackError) {
        print('❌ Fallback notification also failed: $fallbackError');
        rethrow;
      }
    }
  }

  // Build dynamic action buttons based on message context
  List<NotificationActionButton> _buildActionButtons(
      String chatId, String? messageId) {
    return [
      NotificationActionButton(
        key: 'reply',
        label: 'Reply',
        icon: 'resource://drawable/ic_reply',
        actionType: ActionType.SilentAction,
        requireInputText: true,
      ),
      NotificationActionButton(
        key: 'mark_read',
        label: 'Mark Read',
        icon: 'resource://drawable/ic_check',
        actionType: ActionType.SilentAction,
      ),
      NotificationActionButton(
        key: 'view_chat',
        label: 'View',
        icon: 'resource://drawable/ic_chat_notification',
        actionType: ActionType.Default,
      ),
    ];
  }

  // Check if message contains urgent keywords
  bool _isUrgentMessage(String message) {
    const urgentKeywords = [
      'urgent',
      'important',
      'asap',
      'emergency',
      'critical',
      'deadline',
      'immediate',
      'priority',
      'alert',
      'action required'
    ];

    final lowerMessage = message.toLowerCase();
    return urgentKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  // Trigger haptic feedback for enhanced user experience
  Future<void> _triggerHapticFeedback() async {
    try {
      // Implementation would require additional package like 'vibration'
      // For now, this is a placeholder for future enhancement
      print('🔔 Haptic feedback triggered');
    } catch (e) {
      print('⚠️ Haptic feedback failed: $e');
    }
  }

  // Enhanced fallback notification method using Flutter Local Notifications
  Future<void> _showFallbackNotification({
    required int notificationId,
    required String title,
    required String body,
    bool sound = true,
    bool vibration = true,
  }) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: 'ic_chat_notification',
      color: const Color(0xFF075E54),
      enableVibration: vibration,
      playSound: sound,
      sound: sound
          ? const RawResourceAndroidNotificationSound('notification_sound')
          : null,
      styleInformation: const BigTextStyleInformation(''),
      actions: const [
        AndroidNotificationAction(
          'reply',
          'Reply',
          icon: DrawableResourceAndroidBitmap('ic_reply'),
          inputs: [AndroidNotificationActionInput()],
        ),
        AndroidNotificationAction(
          'mark_read',
          'Mark Read',
          icon: DrawableResourceAndroidBitmap('ic_check'),
        ),
      ],
    );

    final iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sound,
      sound: sound ? 'notification_sound.mp3' : null,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: 'chat_message',
    );
  }

  // Enhanced file attachment notification
  Future<void> showFileMessageNotification({
    required String senderName,
    required String fileName,
    required String fileType,
    required String chatId,
    String? senderAvatar,
  }) async {
    if (!_isInitialized) await initialize();

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String fileEmoji = _getFileTypeEmoji(fileType);
    String notificationBody = '$fileEmoji $fileName';

    // Enhanced title for file notifications
    String title = '$senderName sent ${_getFileTypeDescription(fileType)}';

    // Determine channel based on file type
    String channelKey = 'file_messages';
    if (_isImportantFileType(fileType)) {
      channelKey = 'admin_alerts'; // Use high priority for important files
    }

    try {
      // Show enhanced notification using Awesome Notifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: channelKey,
          groupKey: 'real_estate_chat_$chatId',
          title: title,
          body: notificationBody,
          summary: 'File Attachment',
          notificationLayout: NotificationLayout.Messaging,
          largeIcon: senderAvatar ?? 'asset://assets/logo.png',
          icon: 'resource://drawable/ic_file_notification',
          color: const Color(0xFF075E54),
          backgroundColor: const Color(0xFF075E54),
          payload: {
            'type': 'file_message',
            'chat_id': chatId,
            'sender': senderName,
            'file_name': fileName,
            'file_type': fileType,
            'timestamp': DateTime.now().toIso8601String(),
          },
          autoDismissible: true,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          wakeUpScreen: true,
          customSound:
              _soundEnabled ? 'resource://raw/notification_sound' : null,
          category: NotificationCategory.Message,
          actionType: ActionType.Default,
          locked: false,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'download',
            label: 'Download',
            icon: 'resource://drawable/ic_download',
            actionType: ActionType.SilentAction,
          ),
          NotificationActionButton(
            key: 'view_chat',
            label: 'View Chat',
            icon: 'resource://drawable/ic_chat_notification',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'mark_read',
            label: 'Mark Read',
            icon: 'resource://drawable/ic_check',
            actionType: ActionType.SilentAction,
          ),
        ],
      );

      print('🔔 Enhanced file notification created successfully');
      await _updateBadgeCount();

      if (_vibrationEnabled) {
        await _triggerHapticFeedback();
      }
    } catch (e) {
      print('❌ Failed to create file notification: $e');
      // Fallback to basic notification
      await _showFallbackNotification(
        notificationId: notificationId,
        title: title,
        body: notificationBody,
        sound: _soundEnabled,
        vibration: _vibrationEnabled,
      );
    }
  }

  // Check if file type is important (documents, PDFs, etc.)
  bool _isImportantFileType(String fileType) {
    const importantTypes = ['pdf', 'document', 'spreadsheet', 'presentation'];
    return importantTypes.contains(fileType.toLowerCase());
  }

  // Get human-readable file type description
  String _getFileTypeDescription(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'a PDF document';
      case 'image':
        return 'an image';
      case 'document':
        return 'a document';
      case 'spreadsheet':
        return 'a spreadsheet';
      case 'presentation':
        return 'a presentation';
      case 'text':
        return 'a text file';
      default:
        return 'a file';
    }
  }

  // Get emoji for file type
  String _getFileTypeEmoji(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
      case 'document':
        return '📝';
      case 'xls':
      case 'xlsx':
      case 'spreadsheet':
        return '📊';
      case 'ppt':
      case 'pptx':
      case 'presentation':
        return '📋';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'image':
        return '🖼️';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'video':
        return '🎥';
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'audio':
        return '🎵';
      case 'txt':
      case 'text':
        return '📄';
      default:
        return '📎';
    }
  }

  // Enhanced update badge count with conversation tracking
  Future<void> _updateBadgeCount() async {
    try {
      // Get actual unread message count from your chat storage
      int unreadCount = await _getUnreadMessageCount();
      await AwesomeNotifications().setGlobalBadgeCounter(unreadCount);
      print('🔔 Badge count updated to: $unreadCount');
    } catch (e) {
      print('⚠️ Failed to update badge count: $e');
    }
  }

  // Enhanced unread count logic
  Future<int> _getUnreadMessageCount() async {
    try {
      // This should be implemented based on your actual chat storage
      // For now, return a placeholder count
      // In a real app, you would query your local database or API
      return _messageCount > 0 ? _messageCount : 0;
    } catch (e) {
      print('⚠️ Failed to get unread count: $e');
      return 0;
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      await _flutterLocalNotificationsPlugin.cancelAll();
      await AwesomeNotifications().setGlobalBadgeCounter(0);
      _processedMessageIds.clear();
      _messageCount = 0;
      _lastSenderId = null;
      print('🔔 All notifications cleared');
    } catch (e) {
      print('⚠️ Failed to clear notifications: $e');
    }
  }

  // Open media attachment URLs safely
  Future<void> openMediaAttachment(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw Exception('Invalid URL');
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Unable to open attachment link');
      }
    } catch (e) {
      print('⚠️ Failed to open media attachment: $e');
      rethrow;
    }
  }

  // Clear notifications for specific chat
  Future<void> clearChatNotifications(String chatId) async {
    try {
      await AwesomeNotifications()
          .cancelNotificationsByGroupKey('real_estate_chat_$chatId');
      print('🔔 Cleared notifications for chat: $chatId');
    } catch (e) {
      print('⚠️ Failed to clear chat notifications: $e');
    }
  }

  // Reset conversation tracking when chat is opened
  void resetConversationTracking() {
    _messageCount = 0;
    _lastSenderId = null;
    print('🔔 Conversation tracking reset');
  }

  // Enhanced notification action handler
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    final payload = receivedAction.payload ?? {};
    final buttonKey = receivedAction.buttonKeyPressed;

    print('🔔 Notification action received:');
    print('   Button: $buttonKey');
    print('   Payload: $payload');
    print('   Type: ${payload['type']}');

    try {
      final notificationType = payload['type'] ?? '';

      if (notificationType == 'in_app_notification') {
        // Handle in-app notification actions
        switch (buttonKey) {
          case 'view_notification':
            await _navigateToNotifications(payload['notification_id'] ?? '');
            break;

          case 'mark_read':
            await _markNotificationAsRead(payload['notification_id'] ?? '');
            break;

          case 'urgent_action':
            await _navigateToNotificationDetail(
                payload['notification_id'] ?? '');
            break;

          default:
            // Default action - open notifications list
            await _navigateToNotifications(payload['notification_id'] ?? '');
            break;
        }
      } else {
        // Handle chat notification actions
        switch (buttonKey) {
          case 'reply':
            final userInput = receivedAction.buttonKeyInput;
            if (userInput.isNotEmpty) {
              await _sendQuickReply(
                payload['chat_id'] ?? '',
                userInput,
                payload['message_id'] ?? '',
              );
            }
            break;

          case 'mark_read':
            await _markChatAsRead(
              payload['chat_id'] ?? '',
              payload['message_id'] ?? '',
            );
            break;

          case 'download':
            await _downloadFile(
              payload['file_name'] ?? '',
              payload['chat_id'] ?? '',
            );
            break;

          case 'open_file':
            await _openDownloadedFileFromNotification(
              payload['file_path'] ?? '',
              payload['file_url'] ?? '',
              payload['file_name'] ?? '',
            );
            break;

          case 'view_chat':
            await _navigateToChat(payload['chat_id'] ?? '');
            break;

          default:
            // Default action - open chat
            await _navigateToChat(payload['chat_id'] ?? '');
            break;
        }

        if ((buttonKey.isEmpty) && (payload['type'] == 'file_download_complete')) {
          await _openDownloadedFileFromNotification(
            payload['file_path'] ?? '',
            payload['file_url'] ?? '',
            payload['file_name'] ?? '',
          );
        }
      }
    } catch (e) {
      print('❌ Error handling notification action: $e');
    }
  }

  // Enhanced quick reply implementation
  static Future<void> _sendQuickReply(
      String chatId, String message, String originalMessageId) async {
    try {
      print('🔔 Sending quick reply: "$message" to chat: $chatId');
      // TODO: Implement actual API call to send reply
      // This would integrate with your existing chat API

      // For now, just log the action
      print('🔔 Quick reply sent successfully');

      // Clear the specific notification after reply
      if (originalMessageId.isNotEmpty) {
        await AwesomeNotifications()
            .cancel(int.tryParse(originalMessageId) ?? 0);
      }
    } catch (e) {
      print('❌ Quick reply failed: $e');
    }
  }

  // Enhanced mark as read implementation
  static Future<void> _markChatAsRead(String chatId, String messageId) async {
    try {
      print('🔔 Marking chat as read: $chatId, message: $messageId');
      // TODO: Implement actual API call to mark messages as read

      // Clear notifications for this chat
      await AwesomeNotifications()
          .cancelNotificationsByGroupKey('real_estate_chat_$chatId');

      // Reset badge count
      await AwesomeNotifications().setGlobalBadgeCounter(0);

      print('🔔 Chat marked as read successfully');
    } catch (e) {
      print('❌ Mark as read failed: $e');
    }
  }

  // Enhanced file download implementation
  static Future<void> _downloadFile(String fileName, String chatId) async {
    try {
      print('🔔 Downloading file: $fileName from chat: $chatId');
      // TODO: Implement actual file download logic
      // This would integrate with your file handling system

      print('🔔 File download initiated');
    } catch (e) {
      print('❌ File download failed: $e');
    }
  }

  // Enhanced navigation to chat
  static Future<void> _navigateToChat(String chatId) async {
    try {
      print('🔔 Navigating to chat: $chatId');

      // Get user token
      final token = await NavigationService.getCurrentUserToken();
      if (token != null && token.isNotEmpty) {
        NavigationService.navigateToChat(token);
      } else {
        print('⚠️ No user token available for chat navigation');
        // Show notification about requiring login
        NavigationService.showNotificationActionDialog(
          title: 'Chat Message Received',
          message: 'Please login to view and respond to chat messages.',
          token: '',
        );
      }

      print('🔔 Navigation initiated');
    } catch (e) {
      print('❌ Navigation failed: $e');
    }
  }

  // Navigate to notifications list page
  static Future<void> _navigateToNotifications(String notificationId) async {
    try {
      print('🔔 Navigating to notifications page for ID: $notificationId');

      // Get user token from secure storage
      final token = await NavigationService.getCurrentUserToken();
      if (token != null && token.isNotEmpty) {
        await NavigationService.navigateToNotifications(token);
      } else {
        print('⚠️ No user token available for navigation');
        // Show a dialog explaining the notification
        await NavigationService.showNotificationActionDialog(
          title: 'Notification Received',
          message: 'Please login to view your notifications.',
          token: '',
        );
      }

      print('🔔 Notifications page navigation initiated');
    } catch (e) {
      print('❌ Notifications navigation failed: $e');
    }
  }

  // Navigate to specific notification detail
  static Future<void> _navigateToNotificationDetail(
      String notificationId) async {
    try {
      print('🔔 Navigating to notification detail for ID: $notificationId');

      // Get user token
      final token = await NavigationService.getCurrentUserToken();
      if (token != null && token.isNotEmpty) {
        // Navigate to notifications list - the list will handle showing details
        await NavigationService.navigateToNotifications(token);
      } else {
        print('⚠️ No user token available for navigation');
        // Show notification content in dialog since we can't navigate to app
        await NavigationService.showNotificationActionDialog(
          title: 'Important Notification',
          message: 'Please login to view full notification details.',
          token: '',
        );
      }

      print('🔔 Notification detail navigation initiated');
    } catch (e) {
      print('❌ Notification detail navigation failed: $e');
    }
  }

  // Mark in-app notification as read
  static Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      print('🔔 Marking notification as read: $notificationId');
      // TODO: Implement actual API call to mark notification as read

      // Clear the specific notification
      final id = int.tryParse(notificationId);
      if (id != null) {
        await AwesomeNotifications().cancel(id);
      }

      print('🔔 Notification marked as read successfully');
    } catch (e) {
      print('❌ Mark notification as read failed: $e');
    }
  }

  // Show in-app notification (for backend admin notifications)
  Future<void> showInAppNotification({
    required String title,
    required String message,
    required int notificationId,
    Map<String, dynamic>? payload,
    String? category,
    bool isUrgent = false,
  }) async {
    if (!_isInitialized) {
      print('🔔 NotificationService not initialized, initializing now...');
      await initialize();
    }

    print('🔔 Creating in-app notification:');
    print('   Title: $title');
    print('   Message: "$message"');
    print('   Notification ID: $notificationId');
    print('   Is Urgent: $isUrgent');

    // Check permissions first
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      print('❌ Notifications not allowed - requesting permissions');
      isAllowed =
          await AwesomeNotifications().requestPermissionToSendNotifications();
      if (!isAllowed) {
        print('❌ User denied notification permissions');
        return;
      }
    }

    // Determine channel and importance based on content
    String channelKey = isUrgent ? 'admin_alerts' : 'chat_messages';

    // Create enhanced message formatting
    String displayMessage = message;
    if (displayMessage.length > 150) {
      displayMessage = '${displayMessage.substring(0, 147)}...';
    }

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: channelKey,
          groupKey: 'real_estate_notifications',
          title: title,
          body: displayMessage,
          summary: category ?? 'Real Estate Update',
          notificationLayout: NotificationLayout.BigText,
          largeIcon: 'asset://assets/logo.png',
          icon: 'resource://mipmap/ic_launcher',
          color: isUrgent ? const Color(0xFFFF5722) : const Color(0xFF075E54),
          backgroundColor:
              isUrgent ? const Color(0xFFFF5722) : const Color(0xFF075E54),
          payload: {
            'type': 'in_app_notification',
            'notification_id': notificationId.toString(),
            'title': title,
            'message': message,
            'category': category ?? '',
            'timestamp': DateTime.now().toIso8601String(),
            ...?payload, // Merge additional payload data
          },
          autoDismissible: true,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          wakeUpScreen: isUrgent,
          customSound:
              _soundEnabled ? 'resource://raw/notification_sound' : null,
          category: NotificationCategory.Social,
          actionType: ActionType.Default,
          locked: false,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'view_notification',
            label: 'View',
            icon: 'resource://drawable/ic_visibility',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'mark_read',
            label: 'Mark Read',
            icon: 'resource://drawable/ic_check',
            actionType: ActionType.SilentAction,
          ),
          if (isUrgent)
            NotificationActionButton(
              key: 'urgent_action',
              label: 'Take Action',
              icon: 'resource://drawable/ic_priority_high',
              actionType: ActionType.Default,
            ),
        ],
      );

      print(
          '🔔 In-app notification created successfully with ID: $notificationId');

      // Update badge count
      await _updateBadgeCount();

      // Trigger haptic feedback for urgent notifications
      if (isUrgent && _vibrationEnabled) {
        await _triggerHapticFeedback();
      }
    } catch (e) {
      print('❌ Failed to create in-app notification: $e');

      // Fallback to simple notification
      try {
        await _showFallbackNotification(
          notificationId: notificationId,
          title: title,
          body: displayMessage,
          sound: _soundEnabled,
          vibration: _vibrationEnabled,
        );
        print('🔔 Fallback in-app notification sent successfully');
      } catch (fallbackError) {
        print('❌ Fallback in-app notification also failed: $fallbackError');
        rethrow;
      }
    }
  }

  // Schedule notification for testing
  Future<void> scheduleTestNotification() async {
    await showChatMessageNotification(
      senderName: 'Admin Support',
      message:
          'Welcome to Real Estate Chat! Your notifications are working perfectly! 🏠✨',
      chatId: 'admin_chat',
      senderAvatar: 'asset://assets/logo.png',
      forceShow: true,
    );
  }

  // Simple test notification for debugging
  Future<void> showSimpleTestNotification() async {
    print('🔔 Creating simple test notification...');

    try {
      // Check if awesome notifications is initialized
      bool isInitialized = await AwesomeNotifications().isNotificationAllowed();
      print('🔔 Awesome Notifications status: $isInitialized');

      if (!isInitialized) {
        print('🔔 Requesting permissions...');
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      // Create the simplest possible notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999999,
          channelKey: 'chat_messages',
          title: 'Test Notification 🔔',
          body: 'If you see this, notifications are working!',
          notificationLayout: NotificationLayout.Default,
          icon: 'resource://drawable/ic_launcher',
          showWhen: true,
          wakeUpScreen: true,
          autoDismissible: true,
          displayOnForeground: true,
          displayOnBackground: true,
          category: NotificationCategory.Message,
        ),
      );
      print('✅ Simple test notification created successfully!');

      // Also try with flutter_local_notifications as fallback
      print('🔔 Also testing with flutter_local_notifications...');
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'test_channel',
        'Test Channel',
        channelDescription: 'Test notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _flutterLocalNotificationsPlugin.show(
        999998,
        'Flutter Local Notification',
        'This is a fallback test notification',
        platformChannelSpecifics,
      );
      print('✅ Flutter local notification also sent!');
    } catch (e, stackTrace) {
      print('❌ Error creating simple test notification: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  // Public getters for settings
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get ledEnabled => _ledEnabled;
  bool get popupEnabled => _popupEnabled;
}
