import 'package:flutter/material.dart';
import 'admin_support_dashboard.dart';
import 'admin_support_chat_page.dart';
import 'admin_support_birthdays_page.dart';
import 'admin_support_client_marketer_chat.dart';
import 'admin_support_special_days_page.dart';

Map<String, WidgetBuilder> buildAdminSupportRoutes() {
  return {
    '/admin-support-dashboard': (context) {
      final token = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return AdminSupportDashboardPage(token: token);
    },
    '/admin-support-chat': (context) {
      final token = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return AdminSupportChatPage(token: token);
    },
    '/admin-support-chat-thread': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;

      String token = '';
      String role = 'client';
      String participantId = '';
      String? participantName;

      if (args is Map<String, dynamic>) {
        token = args['token']?.toString() ?? '';
        role = args['role']?.toString() ?? 'client';
        participantId = args['participantId']?.toString() ?? '';
        participantName = args['participantName']?.toString();
      } else if (args is String) {
        token = args;
      }

      return AdminSupportChatThreadPage(
        token: token,
        role: role,
        participantId: participantId,
        participantName: participantName,
      );
    },
    '/admin-support-birthdays': (context) {
      final token = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return AdminSupportBirthdaysPage(token: token);
    },
    '/admin-support-special-days': (context) {
      final token = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      return AdminSupportSpecialDaysPage(token: token);
    },
  };
}
