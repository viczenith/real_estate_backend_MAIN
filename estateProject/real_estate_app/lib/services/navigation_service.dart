import 'package:flutter/material.dart';
import '../core/credential_storage.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static Future<void> Function()? _refreshCountsCallback;

  static void registerCountsRefreshCallback(Future<void> Function() callback) {
    _refreshCountsCallback = callback;
  }

  static void clearCountsRefreshCallback() {
    _refreshCountsCallback = null;
  }

  static Future<void> triggerCountsRefresh() async {
    final callback = _refreshCountsCallback;
    if (callback == null) return;
    try {
      await callback();
    } catch (_) {}
  }

  // Navigate to client notifications list
  static Future<void> navigateToNotifications(String token) async {
    try {

      await navigator?.pushNamed(
        '/client-notification',
        arguments: token,
      );
    } catch (e) {

    }
  }

  // Navigate to specific notification detail
  static Future<void> navigateToNotificationDetail({
    required String token,
    required Map<String, dynamic> userNotification,
  }) async {
    try {

      // First navigate to notifications list, then to detail
      // This ensures proper navigation stack
      await navigator?.pushNamed(
        '/client-notification',
        arguments: token,
      );

      // You can add a specific detail route if needed
      // For now, the notification list will handle showing details
    } catch (e) {

    }
  }

  // Navigate to chat
  static Future<void> navigateToChat(String token) async {
    try {

      await navigator?.pushNamed(
        '/client-chat-admin',
        arguments: token,
      );
    } catch (e) {

    }
  }

  // Navigate to client dashboard
  static Future<void> navigateToClientDashboard(String token) async {
    try {

      await navigator?.pushNamedAndRemoveUntil(
        '/client-dashboard',
        (route) => false, // Clear navigation stack
        arguments: token,
      );
    } catch (e) {

    }
  }

  // Show dialog with navigation options
  static Future<void> showNotificationActionDialog({
    required String title,
    required String message,
    required String token,
    Map<String, dynamic>? notificationData,
  }) async {
    try {
      final context = navigator?.context;
      if (context == null) return;

      await showDialog(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFF075E54)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notification')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigateToNotifications(token);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
              ),
              child:
                  const Text('View All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {

    }
  }

  // Extract token from stored credentials
  static Future<String?> _extractTokenFromApp() async {
    try {
      // Try different possible token keys used by the app
      const possibleKeys = [
        'client_token',
        'user_token',
        'auth_token',
        'access_token',
        'token'
      ];

      for (final key in possibleKeys) {
        final token = await CredentialStorage.read(key);
        if (token != null && token.trim().isNotEmpty) {

          return token.trim();
        }
      }

      return null;
    } catch (e) {

      return null;
    }
  }

  // Get current user token (helper method)
  static Future<String?> getCurrentUserToken() async {
    return await _extractTokenFromApp();
  }

  // Store user token for notifications
  static Future<void> storeUserToken(String token) async {
    try {
      await CredentialStorage.write('user_token', token);

    } catch (e) {

    }
  }
}
