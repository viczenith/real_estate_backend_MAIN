import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:real_estate_app/admin/admin_add_estate_plot_size.dart';
import 'package:real_estate_app/admin/admin_add_estate_plot_number.dart';
import 'package:real_estate_app/client/client_notification.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'admin/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/navigation_service.dart';
import 'firebase_options.dart';

// Shared pages
import 'shared/onboarding.dart';
import 'shared/login.dart';
import 'shared/choose_role.dart';

// Admin side
import 'admin/admin_dashboard.dart';
import 'admin/admin_clients.dart';
import 'admin/admin_marketers.dart';
import 'admin/allocate_plot.dart';
import 'admin/add_estate.dart';
import 'admin/view_estate.dart';
import 'admin/add_estate_plots.dart';
import 'admin/register_client_marketer.dart';
// ignore: unused_import
import 'admin/admin_chat.dart';
import 'admin/admin_chat_list.dart';
import 'admin/send_notification.dart';
import 'admin/settings.dart';

// Others
import 'admin/others/estate_allocation_details.dart';
// import 'admin/others/edit_estate_plot.dart';

// Client side
import 'client/client_dashboard.dart';
import 'client/client_profile.dart';
import 'client/client_property_list.dart';
import 'client/client_request_property.dart';
import 'client/client_view_requests.dart';
import 'client/client_chat_admin.dart';
import 'client/property_details.dart';
import 'client/client_plot_details.dart';
import 'client/client_notification_details.dart';

// Marketer side
import 'marketer/marketer_dashboard.dart';
import 'marketer/marketer_clients.dart';
import 'marketer/marketer_notifications.dart';
import 'marketer/marketer_chat_admin.dart';
import 'package:real_estate_app/marketer/marketer_profile.dart';
import 'test_notifications.dart'; // Add test page import

// Admin Support Side
import 'admin_support/admin_support_dashboard.dart';
import 'admin_support/admin_support_chat_page.dart';
import 'admin_support/admin_support_birthdays_page.dart';
import 'admin_support/admin_support_client_marketer_chat.dart';
import 'admin_support/admin_support_special_days_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase with options from google-services.json
    await Firebase.initializeApp(
      options: await DefaultFirebaseOptions.currentPlatform,
    );
    
    // Handle the message
    await PushNotificationService().handleBackgroundMessage(message);
  } catch (e) {
    debugPrint('Error in background message handler: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with options from google-services.json
    await Firebase.initializeApp(
      options: await DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notifications
    await _initializeNotifications();
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('Error during initialization: $e');
    // Run the app anyway with error state
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app. Please restart.'),
          ),
        ),
      ),
    );
  }
}

// Global notification initialization
Future<void> _initializeNotifications() async {
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();

    await PushNotificationService().initialize();

    // Set up notification action listeners
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: NotificationService.onActionReceivedMethod,
      onNotificationCreatedMethod:
          (ReceivedNotification receivedNotification) async {
        // Handle notification creation if needed
      },
      onNotificationDisplayedMethod:
          (ReceivedNotification receivedNotification) async {
        // Handle notification display if needed
      },
      onDismissActionReceivedMethod: (ReceivedAction receivedAction) async {
        // Handle notification dismissal if needed
      },
    );

  } catch (e) {
    // Failed to initialize global notifications (production: log to crash analytics)
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Real Estate Management System',

      // Global navigation key for deep linking from notifications
      navigatorKey: NavigationService.navigatorKey,

      // Default Light Theme (Muted Theme Mode)
      theme: ThemeData(
        fontFamily: '.SF Pro Text',
        brightness: Brightness.light,
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const DynamicLandingPage(),
        // '/': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/choose-role': (context) => const ChooseRoleScreen(),

        // Client side routes
        '/client-dashboard': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientDashboard(token: token ?? '');
        },
        '/client-profile': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientProfile(token: token ?? '');
        },

        '/client-property-list': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientPropertyList(token: token ?? '');
        },
        '/client-request-property': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientRequestProperty(token: token ?? '');
        },
        '/client-view-requests': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientViewRequests(token: token ?? '');
        },

        '/client-chat-admin': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientChatAdmin(token: token ?? '');
        },
        '/client-property-details': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return PropertyDetailsPage(token: token ?? '');
        },
        '/client-notification': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return ClientNotification(token: token ?? '');
        },
        '/client-notification-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          if (args == null) return const ErrorScreen();
          final token = args['token']?.toString() ?? '';
          final userNotificationId = args['userNotificationId'] as int? ?? 0;
          if (token.isEmpty || userNotificationId <= 0)
            return const ErrorScreen();
          return NotificationDetailPage(
            token: token,
            userNotificationId: userNotificationId,
          );
        },
        // Internal bridge route used by SharedHeader to open plot details without circular deps
        '/client-plot-details-from-header': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          if (args == null) return const ErrorScreen();
          final estateId = args['estateId'] is int
              ? args['estateId'] as int
              : int.tryParse(args['estateId']?.toString() ?? '');
          final plotSizeId = args['plotSizeId'] == null
              ? null
              : (args['plotSizeId'] is int
                  ? args['plotSizeId'] as int
                  : int.tryParse(args['plotSizeId'].toString()));
          final token = (args['token'] ?? '').toString();
          final title = args['title']?.toString();
          if (estateId == null || token.isEmpty) return const ErrorScreen();
          return ClientEstatePlotDetailsPage(
            estateId: estateId,
            plotSizeId: plotSizeId,
            token: token,
            title: title,
          );
        },

        // Admin side routes
        '/admin-dashboard': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return token != null && token.isNotEmpty
              ? AdminDashboard(token: token)
              : const ErrorScreen();
        },
        '/admin-clients': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AdminClients(token: token ?? '');
        },
        '/admin-marketers': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AdminMarketers(token: token ?? '');
        },
        '/allocate-plot': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AllocatePlot(token: token ?? '');
        },
        '/add-plot-size': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AddEstatePlotSize(token: token ?? '');
        },
        '/add-plot-number': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AddEstatePlotNumber(token: token ?? '');
        },
        '/add-estate': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AddEstate(token: token ?? '');
        },
        '/view-estate': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return token != null && token.isNotEmpty
              ? ViewEstate(token: token)
              : const ErrorScreen();
        },
        '/add-estate-plots': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AddEstatePlots(token: token ?? '');
        },
        '/register-client-marketer': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return RegisterClientMarketer(token: token ?? '');
        },
        '/admin-chat-list': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AdminChatListScreen(token: token ?? '');
        },
        '/send-notification': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return SendNotification(token: token ?? '');
        },
        '/admin-settings': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return AdminSettings(token: token ?? '');
        },
        '/estate-allocation-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, String>?;
          return EstateAllocationDetails(
            token: args?['token'] ?? '',
            estateId: args?['estateId'] ?? '',
            estatePlot: args?['estatePlot'] ?? '',
          );
        },
        // '/edit-estate-plot': (context) {
        //   final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        //   if (args == null) {
        //     return const ErrorScreen();
        //   }
        //   return EditEstatePlotScreen(
        //     estatePlot: args['estatePlot'],
        //     token: args['token'] as String,
        //   );
        // },

        // Marketer side routes
        '/marketer-dashboard': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return MarketerDashboard(token: token ?? '');
        },
        '/marketer-clients': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return MarketerClients(token: token ?? '');
        },

        '/marketer-profile': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return MarketerProfile(token: token ?? '');
        },
        '/marketer-chat-admin': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return MarketerChatAdmin(token: token ?? '');
        },
        '/marketer-notifications': (context) {
          final token = ModalRoute.of(context)?.settings.arguments as String?;
          return MarketerNotifications(token: token ?? '');
        },

        // Admin Support routes
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

          if (args is Map) {
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

        // Test page for debugging notifications
        '/test-notifications': (context) => const NotificationTestPage(),
      },
    );
  }
}

// Error screen for missing tokens
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Error: No token provided. Please log in.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
