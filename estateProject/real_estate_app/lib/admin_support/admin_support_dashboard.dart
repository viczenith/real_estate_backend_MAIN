import 'dart:async';

import 'package:flutter/material.dart';
import 'package:real_estate_app/admin_support/admin_support_bottom_nav.dart';
import 'package:real_estate_app/admin_support/admin_support_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';
import 'package:real_estate_app/shared/models/support_chat_model.dart';

class AdminSupportDashboardPage extends StatefulWidget {
  final String token;

  const AdminSupportDashboardPage({super.key, required this.token});

  @override
  State<AdminSupportDashboardPage> createState() => _AdminSupportDashboardPageState();
}

class _AdminSupportDashboardPageState extends State<AdminSupportDashboardPage> {
  final ApiService _api = ApiService();
  int _pendingChats = 0;
  bool _loading = true;
  Timer? _pollTimer;
  bool _isFetching = false;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  bool _highlightsLoading = true;
  bool _highlightsFetching = false;
  int? _birthdaysTodayCount;
  int? _birthdaysWeekCount;
  String? _specialDayTodayName;
  String? _specialDayNextName;
  String? _highlightsError;

  @override
  void initState() {
    super.initState();
    _loadCounts(showSpinner: true);
    _loadHighlights(showSpinner: true);
    _startPolling();
    _subscribeToPushes();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadCounts();
      _loadHighlights();
    });
  }

  void _subscribeToPushes() {
    _pushSubscription?.cancel();
    _pushSubscription = PushNotificationService()
        .incomingPushEvents
        .listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      final data = event['data'];
      if (type.contains('chat')) {
        // New chat activity for support staff – refresh counts immediately.
        _loadCounts();
        return;
      }

      if (data is Map<String, dynamic>) {
        final category = data['category']?.toString().toLowerCase() ?? '';
        if (category.contains('chat')) {
          _loadCounts();
        }
      }
    });
  }

  Future<void> _loadCounts({bool showSpinner = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    try {
      final clientChats = await _api.fetchClientChats(widget.token);
      final marketerChats = await _api.fetchMarketerChats(widget.token);
      final totalUnread = _sumUnread(clientChats) + _sumUnread(marketerChats);
      setState(() {
        _pendingChats = totalUnread;
      });
    } catch (_) {
      // keep previous value; optionally log
    } finally {
      if (showSpinner && mounted) {
        setState(() => _loading = false);
      }
      _isFetching = false;
    }
  }

  Future<void> _loadHighlights({bool showSpinner = false}) async {
    if (_highlightsFetching) return;
    _highlightsFetching = true;
    if (showSpinner && mounted) {
      setState(() {
        _highlightsLoading = true;
        _highlightsError = null;
      });
    }

    String? _extractName(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) {
        final name = raw['name'] ?? raw['title'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim();
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      return null;
    }

    int? _parseCount(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed;
      }
      return null;
    }

    try {
      final birthdayCounts = await _api.fetchSupportBirthdayCounts(widget.token);
      final specialCounts = await _api.fetchSupportSpecialDayCounts(widget.token);

      if (!mounted) return;

      setState(() {
        _birthdaysTodayCount = _parseCount(birthdayCounts['today']);
        _birthdaysWeekCount = _parseCount(birthdayCounts['thisWeek']);
        _specialDayTodayName = _extractName(specialCounts['today']);
        _specialDayNextName = _extractName(specialCounts['next']);
        _highlightsLoading = false;
        _highlightsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _highlightsLoading = false;
        _highlightsError = 'Tap refresh';
      });
    } finally {
      _highlightsFetching = false;
    }
  }

  int _sumUnread(List<Chat> chats) {
    return chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
  }

  void _openChats(BuildContext context) {
    Navigator.of(context).pushNamed('/admin-support-chat', arguments: widget.token);
  }

  void _openBirthdays(BuildContext context) {
    Navigator.of(context).pushNamed('/admin-support-birthdays', arguments: widget.token);
  }

  void _openSpecialDays(BuildContext context) {
    Navigator.of(context).pushNamed('/admin-support-special-days', arguments: widget.token);
  }

  String _birthdaysMetricText() {
    if (_highlightsLoading) {
      return 'Loading…';
    }
    if (_highlightsError != null) {
      return _highlightsError!;
    }
    final today = _birthdaysTodayCount ?? 0;
    final week = _birthdaysWeekCount ?? 0;
    final todayLabel = today == 1 ? '1 birthday today' : '$today birthdays today';
    final weekLabel = week == 1 ? '1 this week' : '$week this week';
    return '$todayLabel · $weekLabel';
  }

  String _specialDayMetricText() {
    if (_highlightsLoading) {
      return 'Loading…';
    }
    if (_highlightsError != null) {
      return _highlightsError!;
    }

    final todayName = _specialDayTodayName;
    final nextName = _specialDayNextName;

    if (todayName == null && nextName == null) {
      return 'No special day this month';
    }

    final todayPart = todayName != null ? 'Today: $todayName' : 'Today: —';
    if (nextName == null) {
      return '$todayPart · No upcoming';
    }
    return '$todayPart · Next: $nextName';
  }

  @override
  Widget build(BuildContext context) {
    return AdminSupportLayout(
      token: widget.token,
      pageTitle: 'Admin Support • Dashboard',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome back, Support Hero!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor operations, jump into chats, and prepare celebrations today.',
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 3 : 1,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.4,
                  children: [
                    _DashboardCard(
                      color: Color(0xFF8E24AA),
                      icon: Icons.chat_bubble_outline,
                      title: 'Active Conversations',
                      subtitle: 'Keep an eye on live chat sessions in real time.',
                      metric: _loading ? 'Loading…' : '${_pendingChats > 0 ? _pendingChats : 0} unread chats',
                      onTap: () => _openChats(context),
                      onRefresh: _loadCounts,
                    ),
                    _DashboardCard(
                      color: Color(0xFF3949AB),
                      icon: Icons.cake_outlined,
                      title: 'Birthday Celebrants',
                      subtitle: 'Ensure celebrants feel special today.',
                      metric: _birthdaysMetricText(),
                      onTap: () => _openBirthdays(context),
                      onRefresh: _loadHighlights,
                    ),
                    _DashboardCard(
                      color: Color(0xFF00897B),
                      icon: Icons.flag_circle_outlined,
                      title: 'Special Nigeria Days',
                      subtitle: 'Prepare campaigns for upcoming national events.',
                      metric: _specialDayMetricText(),
                      onTap: () => _openSpecialDays(context),
                      onRefresh: _loadHighlights,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AdminSupportBottomNav(currentIndex: 0, token: widget.token),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }
}

class _DashboardCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String metric;
  final VoidCallback? onTap;
  final Future<void> Function()? onRefresh;

  const _DashboardCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metric,
    this.onTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  metric,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh_rounded, color: color),
                  tooltip: 'Refresh',
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) {
      return cardContent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: cardContent,
    );
  }
}
