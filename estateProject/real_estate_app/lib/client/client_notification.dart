import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/client/client_bottom_nav.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/services/notification_service.dart';
import 'package:real_estate_app/client/client_notification_details.dart';
import 'package:real_estate_app/services/websocket_service.dart';
import 'package:real_estate_app/shared/header.dart';

class ClientNotification extends StatefulWidget {
  final String token;
  final ApiService api;
  final int currentIndex;

  ClientNotification({
    Key? key,
    required this.token,
    ApiService? api,
    this.currentIndex = 3,
  })  : api = api ?? ApiService(),
        super(key: key);

  @override
  State<ClientNotification> createState() => _ClientNotificationState();
}

class _ClientNotificationState extends State<ClientNotification>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  int _unread = 0;
  int _total = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late AnimationController _animController;
  late AnimationController _headerAnimController;
  late AnimationController _pulseController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  // Real-time notification handling
  final NotificationService _notificationService = NotificationService();
  final WebSocketService _webSocketService = WebSocketService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _headerAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _headerAnimController, curve: Curves.easeOutCubic),
    );
    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeIn),
    );

    _scrollController.addListener(_onScroll);

    // Initialize notification service and start real-time monitoring
    _initializeNotificationSystem();

    _fetchCountsAndFirstPage();
    _headerAnimController.forward();
  }

  String _buildNotificationWebSocketUrl() {
    final baseUri = Uri.parse(widget.api.baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    final wsUri = Uri(
      scheme: scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: '/ws/notifications/',
      queryParameters: {'token': widget.token},
    );

    return wsUri.toString();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    _headerAnimController.dispose();
    _pulseController.dispose();
    _webSocketService.disconnect();
    super.dispose();
  }

  // Initialize notification system for real-time status bar notifications
  Future<void> _initializeNotificationSystem() async {
    try {
      // Initialize notification service
      await _notificationService.initialize();

      // Connect to WebSocket for real-time notifications
      final wsUrl = _buildNotificationWebSocketUrl();
      _webSocketService.connect(wsUrl);
      _webSocketService.messages.listen((message) {
        _handleWebSocketMessage(message);
      });

    } catch (e) {
      // Handle error
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    Map<String, dynamic>? payload;

    try {
      if (message is String) {
        payload = jsonDecode(message) as Map<String, dynamic>;
      } else if (message is List<int>) {
        payload = jsonDecode(utf8.decode(message)) as Map<String, dynamic>;
      } else if (message is Map) {
        payload = Map<String, dynamic>.from(message as Map);
      }
    } catch (e) {
      debugPrint('WS decode failed: $e');
      payload = null;
    }

    if (payload == null) return;

    final type = payload['type'];
    if (type != 'new_notification') return;

    final data = payload['data'];
    if (data is! Map) return;

    final notification = Map<String, dynamic>.from(data as Map);

    final notifData = notification['notification'] as Map<String, dynamic>?
        ?? notification['data'] as Map<String, dynamic>?
        ?? notification['payload'] as Map<String, dynamic>?
        ?? <String, dynamic>{};
    final title = notifData?['title']?.toString() ?? '';
    final body = notifData?['message']?.toString() ?? '';
    final createdAt = notification['created_at']?.toString();
    DateTime parsedTs;
    try {
      parsedTs = createdAt != null ? DateTime.parse(createdAt) : DateTime.now();
    } catch (_) {
      parsedTs = DateTime.now();
    }

    final rawUserNotificationId = notification['id'];
    final int? userNotificationId = rawUserNotificationId is int
        ? rawUserNotificationId
        : int.tryParse('$rawUserNotificationId');

    final rawNotificationId = notifData?['id'];
    final int? masterNotificationId = rawNotificationId is int
        ? rawNotificationId
        : int.tryParse('$rawNotificationId');

    setState(() {
      _items.insert(0, notification);
      _unread++;
      _total++;
      _sortNotifications();
    });

    try {
      final headerController = SharedHeader.of(context)?.widget.controller;
      final notificationItem = NotificationItem(
        title: title,
        body: body,
        timestamp: parsedTs,
        id: userNotificationId,
        notificationId: masterNotificationId,
        isRead: notification['read'] == true,
        payload: notification,
      );

      headerController?.addRealtimeNotification(notificationItem);

      if (headerController != null) {
        final countsValue = headerController.countsNotifier.value;
        final fallbackNotifications = countsValue['notifications'] ?? _unread;
        final fallbackMessages = countsValue['messages'] ?? 0;

        int? _parseCount(dynamic raw) {
          if (raw == null) return null;
          if (raw is int) return raw;
          return int.tryParse('$raw');
        }

        final meta = payload['meta'] as Map<String, dynamic>?;

        final unreadNotifications = _parseCount(notification['unread_notifications_count'])
            ?? _parseCount(notification['unread_count'])
            ?? _parseCount(meta?['unread_notifications_count']);

        final unreadMessages = _parseCount(notification['global_message_count'])
            ?? _parseCount(notification['unread_messages_count'])
            ?? _parseCount(meta?['global_message_count']);

        if (unreadNotifications != null || unreadMessages != null) {
          final nextNotifications = unreadNotifications ?? fallbackNotifications;
          final nextMessages = unreadMessages ?? fallbackMessages;
          headerController.updateCounts(nextNotifications, nextMessages);
          if (mounted && unreadNotifications != null) {
            setState(() {
              _unread = unreadNotifications;
            });
          }
        } else {
          headerController.updateCounts(_unread, fallbackMessages);
        }
      }
    } catch (e) {
      debugPrint('Header realtime inject failed: $e');
    }
  }

  Future<void> _fetchCountsAndFirstPage() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _hasMore = true;
      _items.clear();
    });
    await Future.wait([_fetchCounts(), _fetchPage(page: 1, reset: true)]);
    setState(() {
      _isLoading = false;
    });
  }

  void _syncHeaderCounts({int? unreadNotifications, int? unreadMessages}) {
    final headerState = SharedHeader.of(context);
    final controller = headerState?.widget.controller;
    if (controller == null) return;

    final current = controller.countsNotifier.value;
    final nextNotifications = unreadNotifications ?? current['notifications'] ?? _unread;
    final nextMessages = unreadMessages ?? current['messages'] ?? 0;
    controller.updateCounts(nextNotifications, nextMessages);
  }

  Future<void> _fetchCounts() async {
    try {
      final counts = await widget.api.getClientUnreadCounts(widget.token);
      setState(() {
        _unread = counts['unread'] ?? 0;
        _total = counts['total'] ?? 0;
      });

      int? unreadMessages;
      final rawMessages = counts['messages'] ?? counts['unread_messages'] ?? counts['global_message_count'];
      if (rawMessages is int) {
        unreadMessages = rawMessages;
      } else if (rawMessages != null) {
        unreadMessages = int.tryParse('$rawMessages');
      }

      _syncHeaderCounts(unreadNotifications: _unread, unreadMessages: unreadMessages);
    } catch (e) {
      // ignore - show subtle snackbar
      _showSnack('Failed to load counts');
    }
  }

  void _sortNotifications() {
    _items.sort((a, b) {
      // First, sort by read status (unread first)
      final aRead = a['read'] == true;
      final bRead = b['read'] == true;
      
      if (aRead != bRead) {
        return aRead ? 1 : -1; // unread (false) comes before read (true)
      }
      
      // Then sort by date (newest first)
      try {
        final aDate = DateTime.parse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.parse(b['created_at']?.toString() ?? '');
        return bDate.compareTo(aDate); // descending order (newest first)
      } catch (e) {
        return 0;
      }
    });
  }

  Future<void> _fetchPage({int page = 1, bool reset = false}) async {
    if (!_hasMore && !reset) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final dynamic resp = await widget.api.fetchClientNotifications(
          token: widget.token, page: page, filter: 'all', pageSize: 12);
      List<dynamic> results = [];
      bool nextExists = false;

      // support paginated DRF {count,next,previous,results}
      if (resp is Map<String, dynamic> && resp.containsKey('results')) {
        results = resp['results'] as List<dynamic>;
        nextExists = resp['next'] != null;
      } else if (resp is List<dynamic>) {
        results = resp;
        // If list length < pageSize -> no more
        nextExists = (results.length >= 12);
      } else {
        // fallback single object
        results = [];
      }

      if (reset) {
        _items.clear();
        _listKey.currentState?.setState(() {}); // ensure AnimatedList rebuild
      }

      final startIndex = _items.length;
      for (var i = 0; i < results.length; i++) {
        final map = Map<String, dynamic>.from(results[i] as Map);
        _items.add(map);
        _listKey.currentState?.insertItem(startIndex + i,
            duration: const Duration(milliseconds: 300));
      }

      // Sort notifications after adding them
      _sortNotifications();

      setState(() {
        _page = page;
        _hasMore = nextExists;
      });
    } catch (e) {
      _showSnack('Failed to load notifications');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            (_scrollController.position.maxScrollExtent - 120) &&
        !_isLoading &&
        _hasMore) {
      _fetchPage(page: _page + 1);
    }
  }

  Future<void> _onRefresh() async {
    await _fetchCountsAndFirstPage();
    _sortNotifications();
  }

  Future<void> _markReadInBackground(Map<String, dynamic> item) async {
    if (item['read'] == true) return;
    
    setState(() {
      _unread = (_unread - 1).clamp(0, _total);
    });
    _syncHeaderCounts(unreadNotifications: _unread);

    try {
      await widget.api.markClientNotificationRead(
          token: widget.token, userNotificationId: item['id'] as int);
      await _fetchCounts();
    } catch (e) {
      // If failed, add back to list
      setState(() {
        _items.add(item);
        _sortNotifications();
        _unread = (_unread + 1).clamp(0, _total);
      });
      _showSnack('Failed to mark read');
    }
  }

  Future<void> _markReadOptimistic(int index) async {
    final un = _items[index];
    if (un['read'] == true) return;
    // optimistic change
    setState(() {
      _items[index]['read'] = true;
      _unread = (_unread - 1).clamp(0, _total);
      _sortNotifications(); // Re-sort after marking read
    });
    _syncHeaderCounts(unreadNotifications: _unread);

    try {
      await widget.api.markClientNotificationRead(
          token: widget.token, userNotificationId: un['id'] as int);
      // success -> update counts by fetching exact counts
      await _fetchCounts();
    } catch (e) {
      // rollback
      setState(() {
        _items[index]['read'] = false;
        _sortNotifications(); // Re-sort after rollback
        _showSnack('Failed to mark read');
      });
      _syncHeaderCounts(unreadNotifications: _unread);
    }
  }

  Future<void> _markUnreadOptimistic(int index) async {
    final un = _items[index];
    if (un['read'] == false) return;
    setState(() {
      _items[index]['read'] = false;
      _unread = (_unread + 1).clamp(0, _total);
      _sortNotifications(); // Re-sort after marking unread
    });
    _syncHeaderCounts(unreadNotifications: _unread);
    try {
      await widget.api.markClientNotificationUnread(
          token: widget.token, userNotificationId: un['id'] as int);
      await _fetchCounts();
    } catch (e) {
      setState(() {
        _items[index]['read'] = true;
        _sortNotifications(); // Re-sort after rollback
        _showSnack('Failed to mark unread');
      });
      _syncHeaderCounts(unreadNotifications: _unread);
    }
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) {
      _showSnack('No unread notifications');
      return;
    }
    try {
      final resp =
          await widget.api.markClientAllNotificationsRead(token: widget.token);
      // optimistic: mark all locally
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i]['read'] = true;
        }
        _unread = 0;
        _sortNotifications(); // Re-sort after marking all read
      });
      _syncHeaderCounts(unreadNotifications: 0);
      _showSnack('Marked all as read (${resp['marked'] ?? 0})');
    } catch (e) {
      _showSnack('Failed to mark all read');
    }
  }

  Future<void> _openDetail(int index) async {
    final un = _items[index];
    final int id = un['id'] as int;
    try {
      // Navigate to detail page
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => NotificationDetailPage(
                token: widget.token,
                userNotificationId: id)),
      );
      
      // Refresh the notification data after returning
      await _fetchCounts();
      
      // Mark as read if it wasn't already
      if (un['read'] != true) {
        await _markReadOptimistic(index);
      }
    } catch (e) {
      _showSnack('Failed to load detail');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return raw;
    }
  }

  String _getRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d').format(dt);
    } catch (e) {
      return '';
    }
  }

  String _stripHtmlTags(String htmlText) {
    // Remove HTML tags for preview
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    String stripped = htmlText.replaceAll(exp, '');
    // Comprehensive HTML entity decoding for accurate symbol display
    stripped = stripped
        // Common entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        // Currency symbols
        .replaceAll('&euro;', '€')
        .replaceAll('&#8364;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&#163;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&#165;', '¥')
        .replaceAll('&cent;', '¢')
        .replaceAll('&#162;', '¢')
        .replaceAll('&#8358;', '₦') // Naira symbol
        // Math symbols
        .replaceAll('&times;', '×')
        .replaceAll('&#215;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&#247;', '÷')
        .replaceAll('&plusmn;', '±')
        .replaceAll('&#177;', '±')
        // Arrows
        .replaceAll('&rarr;', '→')
        .replaceAll('&#8594;', '→')
        .replaceAll('&larr;', '←')
        .replaceAll('&#8592;', '←')
        // Punctuation
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8212;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8211;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&#8230;', '…')
        .replaceAll('&bull;', '•')
        .replaceAll('&#8226;', '•')
        // Special symbols
        .replaceAll('&copy;', '©')
        .replaceAll('&#169;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&#174;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&#8482;', '™')
        .replaceAll('&deg;', '°')
        .replaceAll('&#176;', '°')
        // Whitespace normalization
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped;
  }

  Widget _buildNotificationTile(
      int index, Map<String, dynamic> item, Animation<double> animation) {
    final notif = item['notification'] as Map<String, dynamic>? ?? {};
    final title = notif['title']?.toString() ?? 'No title';
    final rawMsg = notif['message']?.toString() ?? '';
    final msg = _stripHtmlTags(rawMsg);
    final created =
        item['created_at']?.toString() ?? notif['created_at']?.toString();
    final read = item['read'] == true;

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      axisAlignment: 0.0,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16),
          child: Dismissible(
            key: Key('notif_${item['id']}'),
            direction:
                read ? DismissDirection.none : DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(left: 60),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.done_all_rounded,
                  color: Colors.white, size: 24),
            ),
            onDismissed: (_) {
              // Remove item from list immediately to prevent "still part of tree" error
              final dismissedItem = _items[index];
              setState(() {
                _items.removeAt(index);
              });
              // Then mark as read in background
              _markReadInBackground(dismissedItem);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;
                
                return GestureDetector(
                  onTap: () => _openDetail(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: read ? Colors.grey.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: read ? Colors.grey.shade100 : const Color(0xFF4154F1).withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clean minimal icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: read
                            ? Colors.grey.shade200
                            : const Color(0xFF4154F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        read ? Icons.check_circle_rounded : Icons.circle_notifications,
                        color: read ? Colors.grey.shade500 : const Color(0xFF4154F1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: read ? Colors.grey.shade700 : Colors.grey.shade900,
                                    fontFamily: 'Roboto',  // Supports emojis and special characters
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!read) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4154F1),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.5,
                              fontFamily: 'Roboto',  // Ensures emoji and special character support
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _getRelativeTime(created),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              if (!read)
                                InkWell(
                                  onTap: () => _markReadOptimistic(index),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: const Text(
                                      'Mark read',
                                      style: TextStyle(
                                        color: Color(0xFF4154F1),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF4154F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: Color(0xFF4154F1),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You’re all caught up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New notifications will appear here as soon as they arrive.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4154F1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text(
                'Refresh',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1a1a1a),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '$_total total',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4154F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$_unread new',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _markAllRead,
                        icon: Icon(Icons.done_all_rounded,
                            color: Colors.grey.shade700, size: 20),
                        tooltip: 'Mark all read',
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: _onRefresh,
                        icon: Icon(Icons.refresh_rounded,
                            color: Colors.grey.shade700, size: 20),
                        tooltip: 'Refresh',
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      token: widget.token,
      pageTitle: 'Notifications',
      side: AppSide.client,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        bottomNavigationBar: ClientBottomNav(
            currentIndex: widget.currentIndex,
            token: widget.token,
            chatBadge: 0),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF667eea),
            backgroundColor: Colors.white,
            child: LayoutBuilder(builder: (context, constraints) {
              return CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      child: Container(
                        color: const Color(0xFFF6F8FB),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: SlideTransition(
                          position: _headerSlideAnimation,
                          child: FadeTransition(
                            opacity: _headerFadeAnimation,
                            child: _buildHeader(),
                          ),
                        ),
                      ),
                      minHeight: 110,
                      maxHeight: 110,
                    ),
                  ),

                  // content list or empty state
                  if (_isLoading && _items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF4154F1),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading notifications...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _items[index];
                          // AnimatedList isn't used inside CustomScrollView easily, so we keep animation param from a simple animation controller
                          final animation = CurvedAnimation(
                              parent: _animController, curve: Curves.easeOut);
                          // trigger a small stagger when list first appears
                          _animController.forward();
                          return _buildNotificationTile(index, item, animation);
                        },
                        childCount: _items.length,
                      ),
                    ),

                  // loader footer
                  if (_isLoading && _items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Loading more...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}


class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
