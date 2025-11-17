import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:badges/badges.dart' as badges;
import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/services/navigation_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:real_estate_app/shared/header_notification_detail.dart';
import 'package:real_estate_app/client/client_notification_details.dart';

/// Controller to control a SharedHeader from its parent.
class SharedHeaderController {
  SharedHeaderController();

  _SharedHeaderState? _state;
  int _lastNotifications = 0;
  int _lastMessages = 0;
  bool _hasPendingCounts = false;
  Map<String, int>? _pendingNotifierValue;
  bool _notifierUpdateScheduled = false;

  // Notifier that broadcasts a small counts map:
  // {'notifications': int, 'messages': int}
  final ValueNotifier<Map<String, int>> countsNotifier =
      ValueNotifier<Map<String, int>>({'notifications': 0, 'messages': 0});

  void _attach(_SharedHeaderState s) {
    _state = s;
    if (_hasPendingCounts) {
      s.updateCounts(_lastNotifications, _lastMessages);
    } else {
      _updateFromState(s.unreadNotificationsCount, s.unreadMessagesCount);
    }
  }

  void _detach() => _state = null;

  Future<void> refreshCounts() async => _state?._maybeFetchSharedHeader(force: true);

  void updateCounts(int unreadNotifications, int unreadMessages) {
    _lastNotifications = unreadNotifications;
    _lastMessages = unreadMessages;
    _hasPendingCounts = true;

    if (_state != null) {
      _state!.updateCounts(unreadNotifications, unreadMessages);
    } else {
      _dispatchCounts({
        'notifications': _lastNotifications,
        'messages': _lastMessages,
      });
    }
  }

  void addRealtimeNotification(NotificationItem item) =>
      _state?._addRealtimeNotification(item);

  void boostMessageCount([int boost = 1]) => _state?.boostMessageCount(boost);

  void markAllAsRead() => _state?._markAllAsRead();

  /// Update the visible title dynamically
  void setTitle(String title) => _state?._setTitle(title);

  bool get isAttached => _state != null;

  void _updateFromState(int notifications, int messages) {
    _lastNotifications = notifications;
    _lastMessages = messages;
    _hasPendingCounts = false;
    try {
      _dispatchCounts({
        'notifications': notifications,
        'messages': messages,
      });
      for (final listener in _localMessageListeners) {
        listener(messages);
      }
    } catch (_) {}
  }

  final List<void Function(int)> _localMessageListeners = [];

  void registerLocalMessageCallback(void Function(int) callback) {
    if (!_localMessageListeners.contains(callback)) {
      _localMessageListeners.add(callback);
    }
  }

  void unregisterLocalMessageCallback(void Function(int) callback) {
    _localMessageListeners.remove(callback);
  }

  void dispose() {
    countsNotifier.dispose();
    _localMessageListeners.clear();
  }

  void _dispatchCounts(Map<String, int> value) {
    _pendingNotifierValue = Map<String, int>.from(value);
    if (_notifierUpdateScheduled) return;
    _notifierUpdateScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingNotifierValue != null) {
        countsNotifier.value = Map<String, int>.from(_pendingNotifierValue!);
      }
      _pendingNotifierValue = null;
      _notifierUpdateScheduled = false;
    });
  }
}

/// Message model for chat messages
class Message {
  final String clientName;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const Message({
    required this.clientName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

/// Notification model for system notifications
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final int? id;
  final int? notificationId;
  final Map<String, dynamic>? payload;

  const NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.id,
    this.notificationId,
    this.payload,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      title: title,
      body: body,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      id: id,
      notificationId: notificationId,
      payload: payload,
    );
  }
}

/// Header widget that shows title, notifications, and messages
class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final AppSide side;
  final ValueChanged<AppSide>? onMenuToggle;
  final String? token;

  final bool showNotifications;
  final bool showMessages;

  final List<Message> messages;
  final List<NotificationItem> notifications;

  /// Initial counts from parent (AppLayout passes its counts here)
  final int initialUnreadCount;
  final int initialUnreadMessagesCount;

  final Widget? companyLogo;
  final VoidCallback? onCompanyLogoTap;

  final VoidCallback? onMessagesOpened;
  final VoidCallback? onNotificationsOpened;
  final VoidCallback? onViewMessageHistory;
  final VoidCallback? onViewNotificationHistory;

  /// Optional controller to control header externally
  final SharedHeaderController? controller;

  const SharedHeader({
    Key? key,
    required this.title,
    required this.side,
    this.token,
    this.onMenuToggle,
    this.showNotifications = false,
    this.showMessages = false,
    this.messages = const <Message>[],
    this.notifications = const <NotificationItem>[],
    this.companyLogo,
    this.onCompanyLogoTap,
    this.onMessagesOpened,
    this.onNotificationsOpened,
    this.onViewMessageHistory,
    this.onViewNotificationHistory,
    this.initialUnreadCount = 0,
    this.initialUnreadMessagesCount = 0,
    this.controller,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SharedHeader> createState() => _SharedHeaderState();

  /// Helper to access header state from BuildContext
  static _SharedHeaderState? of(BuildContext context) =>
      context.findAncestorStateOfType<_SharedHeaderState>();
}

class _SharedHeaderState extends State<SharedHeader>
    with WidgetsBindingObserver {
  OverlayEntry? _messagesOverlay;
  OverlayEntry? _notificationsOverlay;

  final GlobalKey _messageIconKey = GlobalKey();
  final GlobalKey _notifIconKey = GlobalKey();

  // fallback/mock notifications
  static List<NotificationItem> get _mockNotifications => [
        NotificationItem(
          title: 'New Message',
          body: 'You have a new message from support.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        NotificationItem(
          title: 'System Update',
          body: 'New features are available!',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        NotificationItem(
          title: 'New Property Added',
          body: 'Starlight II Estate - 6 new plots available.',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        NotificationItem(
          title: 'System Notice',
          body: 'Maintenance scheduled for Aug 20, 2:00 AM.',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  // fetched state
  List<NotificationItem>? _fetchedNotifications;
  int _unreadMessagesCount = 0;
  int _unreadNotificationsCount = 0;
  int _localUnreadMessageBoost = 0;
  DateTime? _lastFetch;
  bool _fetching = false;

  // nullable title to avoid LateInitializationError
  String? _title;

  List<Message> get _messages => widget.messages;

  List<NotificationItem> get _notifications {
    if (widget.side == AppSide.client || widget.side == AppSide.marketer) {
      return _fetchedNotifications ?? const <NotificationItem>[];
    }
    return widget.notifications.isNotEmpty ? widget.notifications : _mockNotifications;
  }

  // Exposed APIs
  void refreshCounts() => _maybeFetchSharedHeader(force: true);

  void boostMessageCount([int boost = 1]) {
    if (mounted) {
      if (kDebugMode) debugPrint('Header: BOOST +$boost (current boost: $_localUnreadMessageBoost)');
      final prevMessages = _unreadMessagesCount;
      setState(() {
        _localUnreadMessageBoost += boost;
        _unreadMessagesCount += boost;
      });
      if (_unreadMessagesCount > prevMessages && boost > 0) {
        _playAlertTone();
      }
      _pushCountsToController();
    }
  }

  void updateCounts(int unreadCount, int unreadMessagesCount) {
    if (mounted) {
      final prevNotifications = _unreadNotificationsCount;
      final prevMessages = _unreadMessagesCount;
      setState(() {
        _unreadNotificationsCount = unreadCount < 0 ? 0 : unreadCount;
        if (_localUnreadMessageBoost == 0) {
          _unreadMessagesCount = unreadMessagesCount < 0 ? 0 : unreadMessagesCount;
        } else {
          _unreadMessagesCount = (unreadMessagesCount < 0 ? 0 : unreadMessagesCount) + _localUnreadMessageBoost;
        }
      });
      if (_unreadNotificationsCount > prevNotifications) {
        _playAlertTone();
      } else if (_unreadMessagesCount > prevMessages) {
        _playAlertTone();
      }
      // push to controller notifier
      _pushCountsToController();
    }
  }

  int get unreadNotificationsCount => _unreadNotificationsCount;
  int get unreadMessagesCount => _unreadMessagesCount;

  // Set title programmatically
  void _setTitle(String title) {
    if (!mounted) return;
    setState(() => _title = title);
  }

  // helper to push current internal counts to controller notifier
  void _pushCountsToController() {
    widget.controller?._updateFromState(
      _unreadNotificationsCount,
      _unreadMessagesCount,
    );
  }

  void _playAlertTone() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Ignore if the platform cannot play system sounds.
    }
  }

  // Add a single realtime notification into the local list and increment count
  void _addRealtimeNotification(NotificationItem item) {
    if (!mounted) return;
    setState(() {
      _fetchedNotifications ??= <NotificationItem>[];
      final idx = _fetchedNotifications!.indexWhere(
        (n) => n.id != null && item.id != null && n.id == item.id,
      );
      if (idx >= 0) {
        _fetchedNotifications![idx] = item;
      } else {
        _fetchedNotifications!.insert(0, item);
        if (_fetchedNotifications!.length > 50) {
          _fetchedNotifications = _fetchedNotifications!.take(50).toList();
        }
      }

      if (!item.isRead) {
        _unreadNotificationsCount = (_unreadNotificationsCount + 1).clamp(0, 9999);
      }
    });
    _pushCountsToController();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Attach controller
    widget.controller?._attach(this);

    // Initialize title and counts
    _title ??= widget.title;
    _unreadMessagesCount = widget.initialUnreadMessagesCount;
    _unreadNotificationsCount = widget.initialUnreadCount;

    // If parent passed notifications for non-client/marketer, compute unread
    if (widget.notifications.isNotEmpty && !(widget.side == AppSide.client || widget.side == AppSide.marketer)) {
      _unreadNotificationsCount = widget.notifications.where((n) => n.isRead == false).length;
    }

    // Push initial counts to controller if present
    _pushCountsToController();

    // Fetch server data for client/marketer and start polling if applicable
    _maybeFetchSharedHeader(force: true);
  }

  @override
  void didUpdateWidget(covariant SharedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reattach controller if changed
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
      // push current state to new controller (if any)
      _pushCountsToController();
    }

    // If the title prop changed, update visible title (unless programmatic override desired)
    if (oldWidget.title != widget.title) {
      setState(() => _title = widget.title);
    }

    // If parent passes new initial counts (AppLayout refresh), reflect them here
    if (oldWidget.initialUnreadCount != widget.initialUnreadCount) {
      setState(() {
        _unreadNotificationsCount = widget.initialUnreadCount < 0 ? 0 : widget.initialUnreadCount;
      });
      _pushCountsToController();
    }
    if (oldWidget.initialUnreadMessagesCount != widget.initialUnreadMessagesCount) {
      setState(() {
        if (_localUnreadMessageBoost == 0) {
          _unreadMessagesCount = widget.initialUnreadMessagesCount < 0 ? 0 : widget.initialUnreadMessagesCount;
        } else {
          _unreadMessagesCount = (widget.initialUnreadMessagesCount < 0 ? 0 : widget.initialUnreadMessagesCount) + _localUnreadMessageBoost;
        }
      });
      _pushCountsToController();
    }

    // If notifications list prop changed for non-client/marketer, recalc unread
    if (!(widget.side == AppSide.client || widget.side == AppSide.marketer)) {
      if (oldWidget.notifications != widget.notifications) {
        setState(() {
          _unreadNotificationsCount = widget.notifications.where((n) => n.isRead == false).length;
        });
        _pushCountsToController();
      }
    }

    // If token changed, refetch
    if (oldWidget.token != widget.token) {
      _maybeFetchSharedHeader(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._detach();
    _removeMessagesOverlay();
    _removeNotificationsOverlay();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeFetchSharedHeader(force: true);
    }
  }

  Future<void> _maybeFetchSharedHeader({bool force = false}) async {
    if (!(widget.side == AppSide.client || widget.side == AppSide.marketer)) return;
    final token = widget.token;
    if (token == null || token.trim().isEmpty) return;

    if (_fetching) return;
    if (!force && _lastFetch != null) {
      final since = DateTime.now().difference(_lastFetch!);
      if (since < const Duration(milliseconds: 50)) return;
    }

    final api = ApiService();
    _fetching = true;
    try {
      List<NotificationItem> mapped;
      final header = await api.getHeaderDataShared(token: token);
      if (kDebugMode) debugPrint('SharedHeader header-data keys: ${header.keys}');
      final List<dynamic> rawNotifs = (header['unread_notifications'] is List)
          ? header['unread_notifications'] as List
          : const [];
      mapped = rawNotifs.map<NotificationItem>((e) {
        if (e is Map<String, dynamic>) {
          final m = Map<String, dynamic>.from(e);
          final String title =
              (m['title'] ?? m['notification']?['title'] ?? '').toString();
          final String body =
              (m['message'] ?? m['notification']?['message'] ?? '').toString();
          DateTime ts;
          try {
            final raw = (m['created_at'] ?? m['notification']?['created_at'])?.toString();
            ts = raw != null ? DateTime.parse(raw) : DateTime.now();
          } catch (_) {
            ts = DateTime.now();
          }
          final bool read = m['read'] == true || m['is_read'] == true;
          final int? userNotificationId =
              m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}');
          final int? notificationId = m['notification_id'] is int
              ? m['notification_id'] as int
              : int.tryParse('${m['notification_id']}');
          return NotificationItem(
            title: title,
            body: body,
            timestamp: ts,
            isRead: read,
            id: userNotificationId,
            notificationId: notificationId,
            payload: m,
          );
        }
        return NotificationItem(title: '', body: '', timestamp: DateTime.now());
      }).toList();

      final unreadNotificationsCount = header['unread_notifications_count'] is int
          ? header['unread_notifications_count'] as int
          : int.tryParse('${header['unread_notifications_count']}') ?? mapped.where((n) => !n.isRead).length;

      final unreadMessages = header['global_message_count'] is int
          ? header['global_message_count'] as int
          : int.tryParse('${header['global_message_count']}') ?? 0;

      if (mounted) {
        final previousCount = _unreadMessagesCount - _localUnreadMessageBoost;
        final countChanged = previousCount != unreadMessages;

        setState(() {
          _fetchedNotifications = mapped;
          _unreadNotificationsCount = unreadNotificationsCount;
          _unreadMessagesCount = unreadMessages + _localUnreadMessageBoost;
        });

        // push to controller notifier so other widgets (sidebar) update live
        _pushCountsToController();

        if (countChanged && unreadMessages > previousCount && kDebugMode) {
          debugPrint('Header: Message count increased from $previousCount to $unreadMessages');
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('SharedHeader fetch failed: $e\n$st');
    } finally {
      _fetching = false;
      _lastFetch = DateTime.now();
    }
  }

  Future<void> _toggleNotifications() async {
    await _maybeFetchSharedHeader(force: true);
    if (_notificationsOverlay == null) {
      _showListOverlay(
        key: _notifIconKey,
        title: 'Notifications',
        icon: Icons.notifications_rounded,
        itemsHeight: 240,
        contentBuilder: _buildNotificationsList,
        setOverlay: (entry) => _notificationsOverlay = entry,
        removeOtherOverlay: _removeMessagesOverlay,
      );
      widget.onNotificationsOpened?.call();
    } else {
      _removeNotificationsOverlay();
    }
  }

  void _removeMessagesOverlay() {
    _messagesOverlay?.remove();
    _messagesOverlay = null;
  }

  void _removeNotificationsOverlay() {
    _notificationsOverlay?.remove();
    _notificationsOverlay = null;
  }

  void _showListOverlay({
    required GlobalKey key,
    required String title,
    required IconData icon,
    required double itemsHeight,
    required WidgetBuilder contentBuilder,
    required void Function(OverlayEntry) setOverlay,
    required VoidCallback removeOtherOverlay,
  }) {
    removeOtherOverlay();

    if (key.currentContext == null) return;

    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final Size iconSize = renderBox.size;
    final Offset iconPosition = renderBox.localToGlobal(Offset.zero);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeMargin = 8.0;
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    double overlayMaxWidth = min(360.0, screenWidth - (safeMargin * 2));
    double overlayWidth = min(340.0, overlayMaxWidth);

    double estimatedHeaderFooter = 120.0;
    double overlayDesiredHeight = min(440.0, itemsHeight + estimatedHeaderFooter);

    double maxAvailableHeight = screenHeight - topPadding - bottomPadding - (safeMargin * 2);
    double overlayHeight = min(overlayDesiredHeight, maxAvailableHeight);

    double availableBelow = screenHeight - (iconPosition.dy + iconSize.height) - bottomPadding - safeMargin;
    double availableAbove = iconPosition.dy - topPadding - safeMargin;

    bool placeAbove = false;

    if (availableBelow >= overlayHeight) {
      placeAbove = false;
    } else if (availableAbove >= overlayHeight) {
      placeAbove = true;
    } else {
      placeAbove = availableAbove > availableBelow;
      overlayHeight = max(min(overlayHeight, max(availableBelow, availableAbove)), 120.0);
      overlayHeight = min(overlayHeight, maxAvailableHeight);
    }

    double availableRight = screenWidth - (iconPosition.dx + iconSize.width) - safeMargin;
    double availableLeft = iconPosition.dx - safeMargin;

    double? leftPos;
    double? rightPos;

    if (availableRight >= overlayWidth) {
      rightPos = screenWidth - (iconPosition.dx + iconSize.width) + safeMargin;
      leftPos = null;
    } else if (availableLeft >= overlayWidth) {
      leftPos = iconPosition.dx - safeMargin;
      rightPos = null;
    } else {
      leftPos = (iconPosition.dx + iconSize.width / 2) - (overlayWidth / 2);
      leftPos = leftPos.clamp(safeMargin, screenWidth - overlayWidth - safeMargin);
      rightPos = null;
    }

    double topOffset = 0.0;
    if (!placeAbove) {
      topOffset = iconPosition.dy + iconSize.height + 8.0;
      final double maxTop = screenHeight - overlayHeight - bottomPadding - safeMargin;
      topOffset = min(topOffset, maxTop);
      if (topOffset + overlayHeight + bottomPadding + safeMargin > screenHeight) {
        placeAbove = true;
      }
    }
    if (placeAbove) {
      topOffset = iconPosition.dy - overlayHeight - 8.0;
      final double minTop = topPadding + safeMargin;
      topOffset = max(topOffset, minTop);
    }

    // Correct clamp uses screenHeight (not screenWidth)
    topOffset = topOffset.clamp(topPadding + safeMargin, max(0.0, screenHeight - overlayHeight - bottomPadding - safeMargin));

    final overlayEntry = OverlayEntry(builder: (context) {
      return GestureDetector(
        onTap: () {
          _removeMessagesOverlay();
          _removeNotificationsOverlay();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              top: topOffset,
              left: leftPos,
              right: rightPos,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: overlayWidth,
                  constraints: BoxConstraints(
                    maxHeight: overlayHeight,
                    minWidth: 200,
                    maxWidth: overlayMaxWidth,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade50,
                        Colors.blue.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(icon, color: Colors.deepPurple, size: 24),
                            const SizedBox(width: 12),
                            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      Flexible(
                        fit: FlexFit.tight,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: contentBuilder(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _removeNotificationsOverlay();
                                try {
                                  if (widget.token != null) {
                                    Navigator.of(context).pushNamed(
                                      '/client-notification',
                                      arguments: widget.token,
                                    );
                                  } else {
                                    Navigator.of(context).pushNamed('/client-notification');
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('View all'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });

    Overlay.of(context)?.insert(overlayEntry);
    setOverlay(overlayEntry);
  }

  Widget _buildNotificationsList(BuildContext context) {
    final list = _notifications;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No notifications'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final n = list[index];
        final int? resolvedId = _resolveUserNotificationId(n);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.notification_important_rounded, color: Colors.blue.shade800),
          ),
          title: Text(
            _plainText(n.title),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _previewPlainText(n.body),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_timeAgo(n.timestamp)),
              if (!n.isRead)
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
            ],
          ),
          onTap: () async {
            _removeNotificationsOverlay();
            if (widget.token != null && resolvedId != null) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationDetailPage(
                    token: widget.token!,
                    userNotificationId: resolvedId,
                  ),
                ),
              );
              await PushNotificationService().syncTokenWithBackend();
              await NavigationService.triggerCountsRefresh();
              _maybeFetchSharedHeader(force: true);
            }
          },
        );
      },
    );
  }

  int? _resolveUserNotificationId(NotificationItem item) {
    if (item.id != null) return item.id;
    final payload = item.payload;
    if (payload == null) return null;
    final dynamic candidate = payload['id'] ??
        payload['user_notification_id'] ??
        payload['user_notification'] ??
        payload['pk'];
    if (candidate is int) return candidate;
    if (candidate is String) return int.tryParse(candidate);
    return null;
  }

  int? _extractEstateId(Map<String, dynamic> p) {
    try {
      final allocation = p['allocation'] ?? p['allocation_id'];
      if (allocation is Map) {
        final estate = allocation['estate'] ?? allocation['estate_id'] ?? allocation['estate_pk'];
        if (estate is Map) {
          final id = estate['id'] ?? estate['pk'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
        }
        final direct = allocation['estate_id'] ?? allocation['estate'];
        if (direct is int) return direct;
        if (direct is String) return int.tryParse(direct);
      }
    } catch (_) {}
    final cand = p['estate_id'] ?? p['estate'] ?? p['estateId'] ?? p['id'] ?? p['pk'];
    if (cand is int) return cand;
    if (cand is String) return int.tryParse(cand);
    return null;
  }

  int? _extractPlotSizeId(Map<String, dynamic> p) {
    try {
      final allocation = p['allocation'] ?? p['allocation_id'];
      if (allocation is Map) {
        final ps = allocation['plot_size'] ?? allocation['plotSize'] ?? allocation['plot_size_id'];
        if (ps is Map) {
          final id = ps['id'] ?? ps['pk'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
        }
        if (ps is int) return ps;
        if (ps is String) return int.tryParse(ps);
      }
    } catch (_) {}
    final cand = p['plot_size_id'] ?? p['plot_size'] ?? p['plotSize'] ?? p['plotSizeId'];
    if (cand is int) return cand;
    if (cand is String) return int.tryParse(cand);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool notificationsVisible = (widget.showNotifications || widget.side == AppSide.client || widget.side == AppSide.marketer);
    final bool messagesVisible = widget.showMessages || widget.side == AppSide.client || widget.side == AppSide.admin || widget.side == AppSide.marketer || widget.side == AppSide.adminSupport;

    final unreadNotifications = _unreadNotificationsCount > 0 ? _unreadNotificationsCount : 0;
    final unreadMessages = _unreadMessagesCount > 0 ? _unreadMessagesCount : 0;

    // Safe title fallback: use state title if set, otherwise widget.title
    final displayTitle = _title ?? widget.title;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          if (widget.onMenuToggle != null) {
            widget.onMenuToggle!.call(widget.side);
          } else {
            try {
              Scaffold.of(context).openDrawer();
            } catch (_) {}
          }
        },
        tooltip: 'Menu',
      ),
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () {
          _maybeFetchSharedHeader(force: true);
        },
        child: Row(
          children: [
            const SizedBox(width: 8),
            // dynamic title (from _title state or widget.title)
            Text(displayTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      backgroundColor: Colors.deepPurple.shade800,
      elevation: 4,
      actions: [
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notificationsVisible && widget.side != AppSide.adminSupport)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: badges.Badge(
                  position: badges.BadgePosition.topEnd(top: 2, end: 2),
                  badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(4)),
                  showBadge: unreadNotifications > 0,
                  badgeContent: Text(
                    unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                  ),
                  child: IconButton(
                    key: _notifIconKey,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.notifications_rounded, size: 24, color: Colors.white),
                    onPressed: _toggleNotifications,
                  ),
                ),
              ),
            if (messagesVisible)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: badges.Badge(
                  position: badges.BadgePosition.topEnd(top: 2, end: 2),
                  badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(4)),
                  showBadge: unreadMessages > 0,
                  badgeContent: Text(
                    unreadMessages > 9 ? '9+' : '$unreadMessages',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  child: IconButton(
                    key: _messageIconKey,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.message, size: 24, color: Colors.white),
                    onPressed: () {
                      _maybeFetchSharedHeader(force: true);
                      if (widget.side == AppSide.client) {
                        if (widget.onMessagesOpened != null) {
                          widget.onMessagesOpened!.call();
                          return;
                        }
                        Navigator.of(context).pushNamed('/client-chat-admin', arguments: widget.token).then((_) {
                          _maybeFetchSharedHeader(force: true);
                        });
                      } else if (widget.side == AppSide.admin) {
                        if (widget.onViewMessageHistory != null) {
                          widget.onViewMessageHistory!.call();
                          return;
                        }
                        final args = ModalRoute.of(context)?.settings.arguments;
                        Navigator.of(context).pushNamed('/messages', arguments: args);
                      } else if (widget.side == AppSide.marketer) {
                        if (widget.onMessagesOpened != null) {
                          widget.onMessagesOpened!.call();
                          return;
                        }
                        Navigator.of(context)
                            .pushNamed('/marketer-chat-admin', arguments: widget.token)
                            .then((_) => _maybeFetchSharedHeader(force: true));
                      } else if (widget.side == AppSide.adminSupport) {
                        if (widget.onMessagesOpened != null) {
                          widget.onMessagesOpened!.call();
                          return;
                        }
                        Navigator.of(context)
                            .pushNamed('/admin-support-chat', arguments: widget.token)
                            .then((_) => _maybeFetchSharedHeader(force: true));
                      } else {
                        if (widget.onViewMessageHistory != null) {
                          widget.onViewMessageHistory!.call();
                          return;
                        }
                        final args = ModalRoute.of(context)?.settings.arguments;
                        Navigator.of(context).pushNamed('/messages', arguments: args);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, right: 12.0),
          child: GestureDetector(
            onTap: widget.onCompanyLogoTap,
            child: widget.companyLogo ??
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                    image: const DecorationImage(image: AssetImage('assets/logo.png'), fit: BoxFit.cover),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 365) return '${(duration.inDays / 365).floor()}y ago';
    if (duration.inDays > 30) return '${(duration.inDays / 30).floor()}mo ago';
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }

  String _stripHtmlTags(String input) {
    if (input.isEmpty) return input;
    String s = input.replaceAll(RegExp(r'<\s*(script|style)[^>]*>.*?<\s*/\s*\1\s*>', caseSensitive: false, dotAll: true), ' ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'");
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        try {
          if (code <= 0xFFFF) {
            return String.fromCharCode(code);
          } else {
            return String.fromCharCodes([code]);
          }
        } catch (e) {
          return match.group(0) ?? '';
        }
      }
      return match.group(0) ?? '';
    });
    s = s.replaceAllMapped(RegExp(r'&#[xX]([0-9A-Fa-f]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null) {
        try {
          if (code <= 0xFFFF) {
            return String.fromCharCode(code);
          } else {
            return String.fromCharCodes([code]);
          }
        } catch (e) {
          return match.group(0) ?? '';
        }
      }
      return match.group(0) ?? '';
    });
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _plainText(String input) => _stripHtmlTags(input);

  String _previewPlainText(String input, {int maxLen = 160}) {
    final txt = _stripHtmlTags(input);
    if (txt.length <= maxLen) return txt;
    return txt.substring(0, maxLen - 1).trimRight() + '…';
  }

  void _markAllAsRead() {
    if (!mounted) return;
    setState(() {
      if (_fetchedNotifications != null) {
        _fetchedNotifications = _fetchedNotifications!.map((n) => n.copyWith(isRead: true)).toList();
      }
      _unreadNotificationsCount = 0;
    });
    _pushCountsToController();
  }
}
