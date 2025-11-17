import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/shared/header.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/client/client_sidebar.dart';
import 'package:real_estate_app/marketer/marketer_sidebar.dart';
import 'package:real_estate_app/admin_support/admin_support_sidebar.dart';
import 'package:real_estate_app/services/navigation_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String pageTitle;
  final String token;
  final AppSide side;

  const AppLayout({
    Key? key,
    required this.child,
    required this.pageTitle,
    required this.token,
    required this.side,
  }) : super(key: key);

  static AppLayoutController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_AppLayoutScope>();
    return scope?.controller;
  }

  static AppLayoutController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'AppLayout.of() called with a context that does not contain AppLayout.');
    return controller!;
  }

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class AppLayoutController {
  AppLayoutController({
    required this.headerController,
    required int initialNotifications,
    required int initialMessages,
    required this.refreshCounts,
  })  : _notifications = initialNotifications,
        _messages = initialMessages;

  final SharedHeaderController headerController;
  int _notifications;
  int _messages;
  final Future<void> Function() refreshCounts;

  int get unreadNotifications => _notifications;
  int get unreadMessages => _messages;

  void updateCounts({int? notifications, int? messages}) {
    final nextNotifications = notifications ?? _notifications;
    final nextMessages = messages ?? _messages;
    _notifications = nextNotifications;
    _messages = nextMessages;
    headerController.updateCounts(nextNotifications, nextMessages);
  }

  void setInternalCounts(int notifications, int messages) {
    _notifications = notifications;
    _messages = messages;
  }

  ValueNotifier<Map<String, int>> get countsNotifier => headerController.countsNotifier;
}

class _AppLayoutScope extends InheritedWidget {
  const _AppLayoutScope({required this.controller, required Widget child, super.key}) : super(child: child);

  final AppLayoutController controller;

  @override
  bool updateShouldNotify(covariant _AppLayoutScope oldWidget) =>
      oldWidget.controller.headerController != controller.headerController;
}

class _AppLayoutState extends State<AppLayout> with WidgetsBindingObserver {
  static const _kClientCacheKey = 'cache_client_profile_v1';
  static const _kMarketerCacheKey = 'cache_marketer_profile_v1';

  bool _isSidebarVisible = false;

  Map<String, dynamic>? clientData;
  bool _loadingClient = false;

  Map<String, dynamic>? marketerData;
  bool _loadingMarketer = false;

  // Shared state for notification and message counts (authoritative in AppLayout)
  int _unreadNotificationsCount = 0;
  int _unreadMessagesCount = 0;

  // Controller to push counts into the SharedHeader
  final SharedHeaderController _headerController = SharedHeaderController();
  late AppLayoutController _controller;

  // Timer for periodic refresh
  Timer? _refreshTimer;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;

  int _parseCount(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse('$value') ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadingClient = false;
    _loadingMarketer = false;

    // Listen to header controller notifier so AppLayout can stay in sync
    _headerController.countsNotifier.addListener(_onHeaderCountsChanged);

    _controller = AppLayoutController(
      headerController: _headerController,
      initialNotifications: _unreadNotificationsCount,
      initialMessages: _unreadMessagesCount,
      refreshCounts: _refreshCountsBasedOnSide,
    );

    NavigationService.registerCountsRefreshCallback(_refreshCountsBasedOnSide);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedThenRefresh();
    });

    _startRefreshTimer();
    _subscribeToPushCounts();
  }

  // Listener callback for header counts notifier
  void _onHeaderCountsChanged() {
    try {
      final data = _headerController.countsNotifier.value;
      final int notifs = _parseCount(data['notifications'], _unreadNotificationsCount);
      final int msgs = _parseCount(data['messages'], _unreadMessagesCount);

      _controller.setInternalCounts(notifs, msgs);

      if (clientData != null) {
        clientData!['unread_notifications_count'] = notifs;
        clientData!['unread_messages_count'] = msgs;
        _updateClientCache();
      }

      if (marketerData != null) {
        marketerData!['unread_notifications_count'] = notifs;
        marketerData!['unread_messages_count'] = msgs;
        _updateMarketerCache();
      }

      if (!mounted) return;
      if (_unreadNotificationsCount == notifs && _unreadMessagesCount == msgs) {
        return;
      }

      setState(() {
        _unreadNotificationsCount = notifs;
        _unreadMessagesCount = msgs;
      });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AppLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.side != oldWidget.side || widget.token != oldWidget.token) {
      _loadCachedThenRefresh();
      _startRefreshTimer();
      _refreshCountsBasedOnSide();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // remove header listener
    try {
      _headerController.countsNotifier.removeListener(_onHeaderCountsChanged);
    } catch (_) {}
    NavigationService.clearCountsRefreshCallback();
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedThenRefresh() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.side == AppSide.client) {
      final cached = prefs.getString(_kClientCacheKey);
      if (cached != null) {
        try {
          clientData = json.decode(cached) as Map<String, dynamic>;
        } catch (_) {
          clientData = null;
        }
        if (mounted) setState(() {});
        // Populate counts from cache immediately
        if (clientData != null) {
          // use safe parsing to avoid cast errors
          final rawMsgs = clientData!['unread_messages_count'] ?? clientData!['unread_messages'] ?? 0;
          final rawNotifs = clientData!['unread_notifications_count'] ?? clientData!['unread_notifications'] ?? 0;
          _unreadMessagesCount = rawMsgs is int ? rawMsgs : int.tryParse('$rawMsgs') ?? 0;
          _unreadNotificationsCount = rawNotifs is int ? rawNotifs : int.tryParse('$rawNotifs') ?? 0;
          try {
            _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
          } catch (_) {}
        }
        _fetchClientAndCache();
      } else {
        if (mounted) setState(() => _loadingClient = true);
        _fetchClientAndCache();
      }
    }

    if (widget.side == AppSide.marketer) {
      final cached = prefs.getString(_kMarketerCacheKey);
      if (cached != null) {
        try {
          marketerData = json.decode(cached) as Map<String, dynamic>;
        } catch (_) {
          marketerData = null;
        }
        if (mounted) setState(() {});
        if (marketerData != null) {
          final notifCount = _parseCount(marketerData!['unread_notifications_count'] ??
              marketerData!['notification_unread_count'] ??
              marketerData!['unread_count']);
          final msgCount = _parseCount(marketerData!['unread_messages_count'] ??
              marketerData!['global_message_count'] ??
              marketerData!['unread_messages']);
          if (mounted) {
            setState(() {
              _unreadNotificationsCount = notifCount;
              _unreadMessagesCount = msgCount;
            });
          } else {
            _unreadNotificationsCount = notifCount;
            _unreadMessagesCount = msgCount;
          }
          try {
            _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
          } catch (_) {}
        }
        _fetchMarketerAndCache();
      } else {
        if (mounted) setState(() => _loadingMarketer = true);
        _fetchMarketerAndCache();
      }
      _refreshMarketerCounts();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshCountsBasedOnSide();
    });
  }

  void _subscribeToPushCounts() {
    if (widget.side != AppSide.client) return;
    _pushSubscription = PushNotificationService()
        .incomingPushEvents
        .listen((payload) {
      final data = payload['data'] as Map<String, dynamic>?;
      if (data == null) return;

      int? _parseCount(dynamic raw) {
        if (raw == null) return null;
        if (raw is int) return raw;
        return int.tryParse('$raw');
      }

      final meta = data['meta'] as Map<String, dynamic>?;
      final type = ((payload['type'] ?? data['type']) as String?)?.toLowerCase() ?? '';

      int? unreadMessages = _parseCount(
        data['global_message_count'] ??
            data['unread_messages_count'] ??
            data['total_unread_count'] ??
            meta?['global_message_count'],
      );

      int? unreadNotifications = _parseCount(
        data['unread_notifications_count'] ??
            data['notification_unread_count'] ??
            data['unread_count'] ??
            meta?['unread_notifications_count'],
      );

      final counts = _headerController.countsNotifier.value;
      final currentMessages = counts['messages'] ?? _unreadMessagesCount;
      final currentNotifications = counts['notifications'] ?? _unreadNotificationsCount;

      if (type == 'chat_message' && unreadMessages == null) {
        unreadMessages = currentMessages + 1;
      }

      if ((type.contains('notification') || type == 'new_notification') && unreadNotifications == null) {
        unreadNotifications = currentNotifications + 1;
      }

      if (unreadMessages == null && unreadNotifications == null) {
        return;
      }

      final nextMessages = unreadMessages ?? currentMessages;
      final nextNotifications = unreadNotifications ?? currentNotifications;

      if (nextMessages != currentMessages || nextNotifications != currentNotifications) {
        if (mounted) {
          setState(() {
            _unreadMessagesCount = nextMessages;
            _unreadNotificationsCount = nextNotifications;
            if (clientData != null) {
              clientData!['unread_messages_count'] = nextMessages;
              clientData!['unread_notifications_count'] = nextNotifications;
            }
          });
          // Persist cache asynchronously (fire and forget)
          _updateClientCache();
        }

        _headerController.updateCounts(nextNotifications, nextMessages);
      }
    });
  }

  Future<void> _refreshAllCounts() async {
    if (widget.side != AppSide.client) return;
    final api = ApiService();
    try {
      final counts = await api.getChatUnreadCountShared(token: widget.token);
      final unreadMessages = (counts['global_message_count'] ?? counts['total_unread_count'] ?? 0) as int;

      final headerData = await api.getHeaderDataShared(token: widget.token);
      int unreadNotifications = 0;
      final dynamic headerCount = headerData['unread_notifications_count'];
      if (headerCount is int) {
        unreadNotifications = headerCount;
      } else if (headerCount != null) {
        unreadNotifications = int.tryParse('$headerCount') ?? 0;
      } else {
        final notifications = (headerData['unread_notifications'] as List?) ?? [];
        unreadNotifications = notifications.length;
      }

      if (mounted) {
        setState(() {
          _unreadMessagesCount = unreadMessages;
          _unreadNotificationsCount = unreadNotifications;
          if (clientData != null) {
            clientData!['unread_messages_count'] = unreadMessages;
            clientData!['unread_notifications_count'] = unreadNotifications;
            _updateClientCache();
          }
        });

        // push to header controller so header and sidebar stay in sync
        try {
          _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
        } catch (_) {}
      }

      if (kDebugMode) debugPrint('AppLayout refreshed counts -> notifs:$unreadNotifications msgs:$unreadMessages');
    } catch (e, st) {
      debugPrint('Failed to refresh counts: $e\n$st');
    }
  }

  Future<void> _refreshMarketerCounts() async {
    if (widget.side != AppSide.marketer) return;
    final api = ApiService();
    try {
      final counts = await api.getMarketerUnreadCounts(widget.token);
      final unreadNotifications = _parseCount(counts['unread']);
      final unreadMessages = _parseCount(
        counts['messages'] ??
            counts['unread_messages'] ??
            counts['global_message_count'] ??
            counts['chat_unread'],
      );

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadNotifications;
          _unreadMessagesCount = unreadMessages;
          marketerData ??= {};
          marketerData!['unread_notifications_count'] = _unreadNotificationsCount;
          marketerData!['unread_messages_count'] = _unreadMessagesCount;
        });
      } else {
        _unreadNotificationsCount = unreadNotifications;
        _unreadMessagesCount = unreadMessages;
        marketerData ??= {};
        marketerData!['unread_notifications_count'] = _unreadNotificationsCount;
        marketerData!['unread_messages_count'] = _unreadMessagesCount;
      }

      try {
        _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
      } catch (_) {}

      await _updateMarketerCache();
    } catch (e, st) {
      debugPrint('Failed to refresh marketer counts: $e\n$st');
    }
  }

  Future<void> _refreshCountsBasedOnSide() async {
    if (!mounted) return;
    if (widget.side == AppSide.client) {
      await _refreshAllCounts();
    } else if (widget.side == AppSide.marketer) {
      await _refreshMarketerCounts();
    }
  }

  Future<void> _updateClientCache() async {
    if (clientData != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kClientCacheKey, json.encode(clientData));
    }
  }

  Future<void> _updateMarketerCache() async {
    if (marketerData != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMarketerCacheKey, json.encode(marketerData));
    }
  }

  Future<void> _fetchClientAndCache() async {
    final api = ApiService();
    try {
      final data = await api.getClientDetailByToken(token: widget.token).timeout(const Duration(seconds: 10));
      clientData = Map<String, dynamic>.from(data);

      final rawMsgs = clientData!['unread_messages_count'] ?? clientData!['unread_messages'] ?? 0;
      final dynamic rawNotifCount = clientData!['unread_notifications_count'];
      final rawNotifs = rawNotifCount ?? clientData!['unread_notifications'] ?? 0;
      final unreadMessages = rawMsgs is int ? rawMsgs : int.tryParse('$rawMsgs') ?? 0;
      int unreadNotifications;
      if (rawNotifs is int) {
        unreadNotifications = rawNotifs;
      } else {
        unreadNotifications = int.tryParse('$rawNotifs') ?? 0;
      }

      if (mounted) {
        setState(() {
          _unreadMessagesCount = unreadMessages;
          _unreadNotificationsCount = unreadNotifications;
        });
      }

      try {
        _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
      } catch (_) {}

      clientData!['unread_notifications_count'] = unreadNotifications;
      await _updateClientCache();
    } catch (e, st) {
      debugPrint('Client refresh failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingClient = false);
    }
  }

  Future<void> _fetchMarketerAndCache() async {
    final api = ApiService();
    try {
      final data = await api.getMarketerProfileByToken(token: widget.token).timeout(const Duration(seconds: 10));
      marketerData = Map<String, dynamic>.from(data);
      final notifCount = _parseCount(marketerData!['unread_notifications_count'] ??
          marketerData!['notification_unread_count'] ??
          marketerData!['unread_count']);
      final msgCount = _parseCount(marketerData!['unread_messages_count'] ??
          marketerData!['global_message_count'] ??
          marketerData!['unread_messages']);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = notifCount;
          _unreadMessagesCount = msgCount;
        });
      } else {
        _unreadNotificationsCount = notifCount;
        _unreadMessagesCount = msgCount;
      }

      marketerData!['unread_notifications_count'] = _unreadNotificationsCount;
      marketerData!['unread_messages_count'] = _unreadMessagesCount;
      await _updateMarketerCache();

      try {
        _headerController.updateCounts(_unreadNotificationsCount, _unreadMessagesCount);
      } catch (_) {}

      await _refreshMarketerCounts();
    } catch (e, st) {
      debugPrint('Marketer refresh failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingMarketer = false);
    }
  }

  Future<void> refreshProfile() async {
    if (widget.side == AppSide.client) {
      if (mounted) setState(() => _loadingClient = true);
      await _fetchClientAndCache();
    } else if (widget.side == AppSide.marketer) {
      if (mounted) setState(() => _loadingMarketer = true);
      await _fetchMarketerAndCache();
    }
  }

  void toggleSidebar(AppSide side) {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  void handleMenuItemTap(String route) {
    debugPrint('handleMenuItemTap -> $route');
    setState(() => _isSidebarVisible = false);

    final tokenRequired = {
      '/admin-dashboard',
      '/admin-clients',
      '/client-dashboard',
      '/client-profile',
      '/client-chat-admin',
      '/client-property-details',
      '/client-notification',
      '/marketer-dashboard',
      '/marketer-clients',
      '/marketer-profile',
      '/marketer-notifications',
      '/marketer-chat-admin',
      '/admin-support-dashboard',
      '/admin-support-chat',
      '/admin-support-birthdays',
      '/admin-support-special-days',
    };

    if (tokenRequired.contains(route)) {
      Navigator.pushNamed(context, route, arguments: widget.token);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  Widget _buildSidebar({required bool isExpanded}) {
    switch (widget.side) {
      case AppSide.client:
        return ClientSidebar(
          isExpanded: isExpanded,
          onMenuItemTap: handleMenuItemTap,
          onToggle: () => toggleSidebar(widget.side),
          profileImageUrl: clientData?['profile_image'],
          clientName: clientData?['full_name'] ?? "Client",
          clientRank: clientData?['rank_tag'],
          notificationCount: _unreadNotificationsCount,
          messageCount: _unreadMessagesCount,
          headerController: _headerController, // <-- pass controller here for real-time updates
        );

      case AppSide.marketer:
        return MarketerSidebar(
          isExpanded: isExpanded,
          onMenuItemTap: handleMenuItemTap,
          onToggle: () => toggleSidebar(widget.side),
          profileImageUrl: marketerData?['profile_image'],
          marketerName: marketerData?['full_name'] ?? "Marketer",
          notificationCount: _unreadNotificationsCount,
          messageCount: _unreadMessagesCount,
          headerController: _headerController,
        );

      case AppSide.admin:
        return PlaceholderSidebar(
          title: 'Admin',
          isExpanded: isExpanded,
          onMenuItemTap: handleMenuItemTap,
          onToggle: () => toggleSidebar(widget.side),
        );

      case AppSide.adminSupport:
        return AdminSupportSidebar(
          isExpanded: isExpanded,
          onMenuItemTap: handleMenuItemTap,
          onToggle: () => toggleSidebar(widget.side),
          headerController: _headerController,
          supportName: clientData?['full_name'] ?? 'Admin Support',
          notificationCount: _unreadNotificationsCount,
          messageCount: _unreadMessagesCount,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.side == AppSide.client && _loadingClient) || (widget.side == AppSide.marketer && _loadingMarketer)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;

    PreferredSizeWidget _buildHeader() {
      return SharedHeader(
        title: widget.pageTitle,
        side: widget.side,
        token: widget.token,
        onMenuToggle: (side) => toggleSidebar(side),
        showNotifications: true,
        showMessages: true,
        messages: const [],
        notifications: const [],
        controller: _headerController,
        initialUnreadCount: _unreadNotificationsCount,
        initialUnreadMessagesCount: _unreadMessagesCount,
      );
    }

    return _AppLayoutScope(
      controller: _controller,
      child: Scaffold(
        appBar: _buildHeader(),
        body: Row(
          children: [
            if (isLargeScreen) SizedBox(width: 250, child: _buildSidebar(isExpanded: true)),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF5F3FF)]),
                    ),
                    child: widget.child,
                  ),
                  if (!isLargeScreen)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      left: _isSidebarVisible ? 0 : -250,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(width: 250, child: _buildSidebar(isExpanded: true)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderSidebar extends StatelessWidget {
  final bool isExpanded;
  final ValueChanged<String> onMenuItemTap;
  final VoidCallback onToggle;
  final String title;

  const PlaceholderSidebar({
    Key? key,
    required this.isExpanded,
    required this.onMenuItemTap,
    required this.onToggle,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double width = isExpanded ? 240 : 72;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(4, 6))
        ],
        borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                vertical: 20, horizontal: isExpanded ? 16 : 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.blueAccent.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(0)),
            ),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (isExpanded)
                  Row(
                    children: [
                      CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white24,
                          child: Text(title[0],
                              style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Hello, $title!",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Welcome back 👋",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70)),
                          ]),
                    ],
                  )
                else
                  CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Text(title[0],
                          style: const TextStyle(color: Colors.white))),
                IconButton(
                    icon: Icon(
                        isExpanded
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        color: Colors.white),
                    onPressed: onToggle),
              ],
            ),
          ),
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                _menuTile(Icons.dashboard_rounded, "$title Dashboard",
                    '/${title.toLowerCase()}-dashboard'),
                _menuTile(Icons.people_rounded, "$title Clients",
                    '/${title.toLowerCase()}-clients'),
                _menuTile(Icons.notifications_rounded, "$title Notifications",
                    '/${title.toLowerCase()}-notifications'),
              ])),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 8 : 4, vertical: 6),
            child: Column(children: [
              ListTile(
                  leading: const Icon(Icons.settings_rounded,
                      color: Colors.blueAccent),
                  title: isExpanded
                      ? const Text("Settings",
                          style: TextStyle(fontWeight: FontWeight.bold))
                      : null,
                  onTap: () =>
                      onMenuItemTap('/${title.toLowerCase()}-settings')),
              ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: isExpanded
                      ? const Text("Logout",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent))
                      : null,
                  onTap: () => onMenuItemTap('/login')),
              const SizedBox(height: 12),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, String route) {
    return ListTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: isExpanded
            ? Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
            : null,
        onTap: () => onMenuItemTap(route));
  }
}
