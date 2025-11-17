import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_service.dart';

class ClientBottomNav extends StatefulWidget {
  final int currentIndex;
  final String? token;
  final int chatBadge;
  final VoidCallback?
      onChatBadgeRefresh; // Callback to refresh chat badge counts

  const ClientBottomNav({
    super.key,
    required this.currentIndex,
    this.token,
    this.chatBadge = 0,
    this.onChatBadgeRefresh,
  });

  @override
  _ClientBottomNavState createState() => _ClientBottomNavState();
}

class _ClientBottomNavState extends State<ClientBottomNav>
    with WidgetsBindingObserver {
  late int _index;

  // Real-time chat badge state (same as header)
  int? _fetchedUnreadMessagesCount;
  int _localUnreadMessageBoost = 0;
  Timer? _poller;
  DateTime? _lastFetch;
  bool _fetching = false;
  static const Duration _pollInterval = Duration(
      milliseconds: 200); // Ultra-fast polling for real-time message detection

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
    WidgetsBinding.instance.addObserver(this);

    // Start real-time polling if token is available
    _startPollingIfNeeded();
  }

  @override
  void dispose() {
    _poller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On resume, refresh counts and restart polling
      _maybeFetchChatCounts(force: true);
      _startPollingIfNeeded();
    }
  }

  void _startPollingIfNeeded() {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) return;

    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      _maybeFetchChatCounts();
    });

    // Initial fetch
    _maybeFetchChatCounts(force: true);

    // Poll for any existing unread messages from the API
    if (kDebugMode) {
      debugPrint('BottomNav: Started polling for real-time message counts');
    }
  }

  Future<void> _maybeFetchChatCounts({bool force = false}) async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      if (kDebugMode) debugPrint('BottomNav: No token available for API calls');
      return;
    }

    // Avoid overlapping fetches but allow real-time updates
    if (_fetching) return;
    if (!force && _lastFetch != null) {
      final since = DateTime.now().difference(_lastFetch!);
      if (since < const Duration(milliseconds: 50)) {
        return;
      }
    }

    final api = ApiService();
    _fetching = true;
    try {
      if (kDebugMode)
        debugPrint(
            'BottomNav: Fetching chat counts with token: ${token.substring(0, 8)}...');
      final counts = await api.getChatUnreadCountShared(token: token);

      if (kDebugMode) {
        debugPrint('BottomNav: Raw API response: $counts');
      }

      // For clients: use global_message_count (messages from admin)
      int unreadMessages = (counts['global_message_count'] ?? 0) as int;

      if (kDebugMode) {
        debugPrint('BottomNav: Parsed unread messages = $unreadMessages');
      }

      if (mounted) {
        final previousCount = _fetchedUnreadMessagesCount ?? 0;
        setState(() {
          if (kDebugMode) {
            debugPrint(
                'BottomNav: Updating state - previous: $previousCount → new: $unreadMessages, boost preserved: $_localUnreadMessageBoost');
          }
          _fetchedUnreadMessagesCount = unreadMessages;
          // DON'T reset boost automatically - let it persist to show immediate feedback
          // Boost will be reset only when returning from chat or manually
        });

        if (kDebugMode) {
          debugPrint(
              'BottomNav: Updated state - previous: $previousCount, new: $unreadMessages, boost: $_localUnreadMessageBoost, display: $_realTimeUnreadCount');
        }
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('BottomNav fetch failed: $e\n$st');
    } finally {
      _fetching = false;
      _lastFetch = DateTime.now();
    }
  }

  // Get real-time unread count (same logic as header)
  int get _realTimeUnreadCount {
    if (_fetchedUnreadMessagesCount != null) {
      final total = (_fetchedUnreadMessagesCount! + _localUnreadMessageBoost)
          .clamp(0, 9999);
      if (kDebugMode) {
        debugPrint(
            'BottomNav: _realTimeUnreadCount = $total (fetched: $_fetchedUnreadMessagesCount, boost: $_localUnreadMessageBoost) [${DateTime.now().millisecondsSinceEpoch}]');
      }
      return total;
    }
    // Fallback to prop-based count if API not available
    final fallback = widget.chatBadge;
    if (kDebugMode) {
      debugPrint(
          'BottomNav: Using fallback count = $fallback [API not available]');
    }
    return fallback;
  }

  // Boost count for instant feedback (same as header)
  void boostMessageCount([int boost = 1]) {
    if (mounted) {
      if (kDebugMode) {
        debugPrint(
            'BottomNav: 🚀 BOOST TRIGGERED! Adding $boost (current boost: $_localUnreadMessageBoost, fetched: $_fetchedUnreadMessagesCount)');
      }
      setState(() {
        _localUnreadMessageBoost += boost;
      });
      if (kDebugMode) {
        debugPrint(
            'BottomNav: Boosted count by $boost, new boost total: $_localUnreadMessageBoost, display total: $_realTimeUnreadCount');
      }
      // DON'T trigger refresh immediately - let the boost show first
    } else {
      if (kDebugMode) {
        debugPrint('BottomNav: ⚠️ BOOST IGNORED - widget not mounted');
      }
    }
  }

  // Public method to refresh widget state for real-time updates
  void refreshState() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to show updated chat badge count
      });
    }
  }

  // Keep _index in sync if parent provides a different currentIndex later
  @override
  void didUpdateWidget(covariant ClientBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update index if changed
    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex != _index) {
      setState(() {
        _index = widget.currentIndex;
      });
    }

    // If token changed, restart polling
    if (oldWidget.token != widget.token) {
      _maybeFetchChatCounts(force: true);
      _startPollingIfNeeded();
    }

    // Rebuild if chat badge count changed for fallback updates
    if (widget.chatBadge != oldWidget.chatBadge) {
      setState(() {
        // Chat badge updated - trigger rebuild for visual update
      });
    }
  }

  void _navigateToIndex(int i) {
    // Special handling for chat navigation (index 2) to match header behavior
    if (i == 2) {
      _navigateToChat();
      return;
    }

    // Update local index first so the UI reflects the pressed item immediately
    setState(() {
      _index = i;
    });

    String routeName;
    switch (i) {
      case 0:
        routeName = '/client-dashboard';
        break;
      case 1:
      default:
        routeName = '/client-profile';
        break;
    }

    try {
      Navigator.of(context)
          .pushReplacementNamed(routeName, arguments: widget.token ?? '');
    } catch (e) {
      // Helpful debug info
      debugPrint('Navigation to $routeName failed: $e');
    }
  }

  void _navigateToChat() {
    // Immediate refresh before navigation for current counts (like header)
    _maybeFetchChatCounts(force: true);

    // Update local index for immediate visual feedback
    setState(() {
      _index = 2;
    });

    try {
      // Use pushNamed (not pushReplacementNamed) for chat to enable proper callback handling
      print(
          'BottomNav: Navigating to chat with token: "${widget.token}"'); // Debug log
      Navigator.of(context)
          .pushNamed('/client-chat-admin', arguments: widget.token ?? '')
          .then((_) {
        // Aggressive refresh when returning from chat to catch any read/unread changes
        _maybeFetchChatCounts(force: true);

        print(
            'BottomNav: Returned from chat - triggering real-time badge refresh'); // Debug log
      });
    } catch (e) {
      debugPrint('Navigation to chat failed: $e');
    }
  }

  Widget _buildIconWithBadge(IconData icon, String label,
      {int badge = 0, required bool active}) {
    final color =
        active ? Theme.of(context).colorScheme.primary : Colors.grey[600];
    return Tooltip(
      message: label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedScale(
            scale: active ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 180),
            child: Icon(icon, size: 26, color: color),
          ),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                child: Center(
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]
        : Colors.white;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _navigateToIndex(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconWithBadge(Icons.dashboard, 'Dashboard',
                        active: _index == 0),
                    const SizedBox(height: 4),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            _index == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _navigateToIndex(1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconWithBadge(Icons.person, 'Profile',
                        active: _index == 1),
                    const SizedBox(height: 4),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            _index == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _navigateToIndex(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconWithBadge(Icons.chat, 'Chat Admin',
                        badge: _realTimeUnreadCount, active: _index == 2),
                    const SizedBox(height: 4),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            _index == 2 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 2
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => _navigateToIndex(i),
      labelType: NavigationRailLabelType.selected,
      destinations: [
        const NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Dashboard')),
        const NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile')),
        NavigationRailDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline),
              if (_realTimeUnreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3)
                      ],
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        _realTimeUnreadCount > 999
                            ? '999+'
                            : '$_realTimeUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          selectedIcon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble),
              if (_realTimeUnreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3)
                      ],
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        _realTimeUnreadCount > 999
                            ? '999+'
                            : '$_realTimeUnreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          label: const Text('Chat'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 880) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 12, top: 24, bottom: 24),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8)
              ]),
          child: _buildNavigationRail(),
        ),
      );
    }
    return _buildBottomBar();
  }
}
