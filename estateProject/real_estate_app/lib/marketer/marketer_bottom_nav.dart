import 'package:flutter/material.dart';

class MarketerBottomNav extends StatefulWidget {
  final int currentIndex;
  final String? token;
  final int chatBadge;

  const MarketerBottomNav({
    super.key,
    required this.currentIndex,
    this.token,
    this.chatBadge = 0,
  });

  @override
  _MarketerBottomNavState createState() => _MarketerBottomNavState();
}

class _MarketerBottomNavState extends State<MarketerBottomNav> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
  }


  @override
  void didUpdateWidget(covariant MarketerBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && widget.currentIndex != _index) {
      setState(() {
        _index = widget.currentIndex;
      });
    }
  }

  void _navigateToIndex(int i) {
    setState(() {
      _index = i;
    });

    if (i == 2) {
      _navigateToChat();
      return;
    }

    final routeName = i == 0 ? '/marketer-dashboard' : '/marketer-profile';

    try {
      Navigator.of(context).pushReplacementNamed(routeName, arguments: widget.token ?? '');
    } catch (e) {
      debugPrint('Navigation to $routeName failed: $e');
    }
  }

  void _navigateToChat() {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open chat – missing session token.')),
      );
      return;
    }

    try {
      Navigator.of(context).pushReplacementNamed('/marketer-chat-admin', arguments: token);
    } catch (e) {
      debugPrint('Navigation to /marketer-chat-admin failed: $e');
    }
  }

  Widget _buildIconWithBadge(IconData icon, String label,
      {int badge = 0, required bool active}) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.grey[600];
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
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
                child: Center(
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final bg = Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white;
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
                    _buildIconWithBadge(Icons.dashboard, 'Dashboard', active: _index == 0),
                    const SizedBox(height: 4),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _index == 0 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 0 ? Theme.of(context).colorScheme.primary : Colors.grey[600],
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
                    _buildIconWithBadge(Icons.person, 'Profile', active: _index == 1),
                    const SizedBox(height: 4),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _index == 1 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 1 ? Theme.of(context).colorScheme.primary : Colors.grey[600],
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
                    _buildIconWithBadge(Icons.chat, 'Chat', badge: widget.chatBadge, active: _index == 2),
                    const SizedBox(height: 4),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _index == 2 ? FontWeight.bold : FontWeight.w500,
                        color: _index == 2 ? Theme.of(context).colorScheme.primary : Colors.grey[600],
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
        const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
        const NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Profile')),
        NavigationRailDestination(
          icon: Stack(children: [const Icon(Icons.chat_bubble_outline), if (widget.chatBadge > 0) Positioned(right: -2, top: -2, child: CircleAvatar(radius: 6, backgroundColor: Colors.redAccent, child: Text('${widget.chatBadge}', style: const TextStyle(fontSize: 8, color: Colors.white))))]),
          selectedIcon: const Icon(Icons.chat_bubble),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
          child: _buildNavigationRail(),
        ),
      );
    }
    return _buildBottomBar();
  }
}
