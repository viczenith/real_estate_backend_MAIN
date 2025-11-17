import 'dart:math';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:real_estate_app/shared/profile_avatar.dart';
import 'package:real_estate_app/shared/header.dart';

class MarketerSidebar extends StatefulWidget {
  final bool isExpanded;
  final Function(String) onMenuItemTap;
  final VoidCallback onToggle;

  /// Optional: parent can provide the current active route so the sidebar highlights correctly
  final String? currentRoute;

  final String? profileImageUrl;
  final String marketerName;

  final int notificationCount;
  final int messageCount;
  final SharedHeaderController? headerController;

  const MarketerSidebar({
    Key? key,
    required this.isExpanded,
    required this.onMenuItemTap,
    required this.onToggle,
    this.currentRoute,
    required this.profileImageUrl,
    required this.marketerName,
    this.notificationCount = 0,
    this.messageCount = 0,
    this.headerController,
  }) : super(key: key);

  @override
  State<MarketerSidebar> createState() => _MarketerSidebarState();
}

class _MarketerSidebarState extends State<MarketerSidebar> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _hoverIndex = -1;

  static const Color primaryColor = Color(0xFF5E35B1);

  late final AnimationController _pulseController;

  late List<SidebarItem> _menuItems;

  late int _liveNotificationCount;
  late int _liveMessageCount;
  VoidCallback? _headerListener;

  List<SidebarItem> _buildMenuItems() {
    return [
      SidebarItem(icon: Icons.dashboard_rounded, title: "Dashboard", route: '/marketer-dashboard'),
      SidebarItem(icon: Icons.person_rounded, title: "Profile", route: '/marketer-profile'),
      SidebarItem(icon: Icons.list_alt_rounded, title: "Client Records", route: '/marketer-clients'),
      SidebarItem(
        icon: Icons.notifications_active,
        title: "Notifications",
        route: '/marketer-notifications',
        notificationCount: _liveNotificationCount,
      ),
      SidebarItem(
        icon: Icons.chat_rounded,
        title: "Chat Admin",
        route: '/marketer-chat-admin',
        notificationCount: _liveMessageCount,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _liveNotificationCount = widget.notificationCount;
    _liveMessageCount = widget.messageCount;

    if (widget.headerController != null) {
      try {
        final current = widget.headerController!.countsNotifier.value;
        _liveNotificationCount = current['notifications'] ?? _liveNotificationCount;
        _liveMessageCount = current['messages'] ?? _liveMessageCount;
      } catch (_) {}

      _headerListener = () {
        try {
          final data = widget.headerController!.countsNotifier.value;
          final n = data['notifications'] ?? 0;
          final m = data['messages'] ?? 0;
          if (mounted) {
            setState(() {
              _liveNotificationCount = n;
              _liveMessageCount = m;
              _menuItems = _buildMenuItems();
            });
          }
        } catch (_) {}
      };
      widget.headerController!.countsNotifier.addListener(_headerListener!);
    }

    _menuItems = _buildMenuItems();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    // initial sync with provided route or current ModalRoute if available
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSelectedIndexIfNeeded());
  }

  @override
  void didUpdateWidget(covariant MarketerSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent supplied a different currentRoute, resync selected index
    if (oldWidget.currentRoute != widget.currentRoute) {
      _syncSelectedIndexIfNeeded();
    }

    if (oldWidget.headerController != widget.headerController) {
      if (oldWidget.headerController != null && _headerListener != null) {
        try {
          oldWidget.headerController!.countsNotifier.removeListener(_headerListener!);
        } catch (_) {}
      }
      _headerListener = null;

      _liveNotificationCount = widget.notificationCount;
      _liveMessageCount = widget.messageCount;

      if (widget.headerController != null) {
        try {
          final current = widget.headerController!.countsNotifier.value;
          _liveNotificationCount = current['notifications'] ?? _liveNotificationCount;
          _liveMessageCount = current['messages'] ?? _liveMessageCount;
        } catch (_) {}
        _headerListener = () {
          try {
            final data = widget.headerController!.countsNotifier.value;
            final n = data['notifications'] ?? 0;
            final m = data['messages'] ?? 0;
            if (mounted) {
              setState(() {
                _liveNotificationCount = n;
                _liveMessageCount = m;
                _menuItems = _buildMenuItems();
              });
            }
          } catch (_) {}
        };
        widget.headerController!.countsNotifier.addListener(_headerListener!);
      } else {
        setState(() {
          _menuItems = _buildMenuItems();
        });
      }
    } else if (widget.headerController == null &&
        (widget.notificationCount != oldWidget.notificationCount || widget.messageCount != oldWidget.messageCount)) {
      setState(() {
        _liveNotificationCount = widget.notificationCount;
        _liveMessageCount = widget.messageCount;
        _menuItems = _buildMenuItems();
      });
    }
  }

  @override
  void dispose() {
    if (widget.headerController != null && _headerListener != null) {
      try {
        widget.headerController!.countsNotifier.removeListener(_headerListener!);
      } catch (_) {}
    }
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapItem(int index, SidebarItem item) {
    setState(() => _selectedIndex = index);
    widget.onMenuItemTap(item.route);
    debugPrint('Sidebar tap -> ${item.route}');
  }

  int _indexForRoute(String? route) {
    if (route == null || route.isEmpty) return -1;
    // exact match first
    for (var i = 0; i < _menuItems.length; i++) {
      if (_menuItems[i].route == route) return i;
    }
    // fallback: startsWith (handles subroutes like /marketer-clients/123)
    for (var i = 0; i < _menuItems.length; i++) {
      if (route.startsWith(_menuItems[i].route)) return i;
    }
    return -1;
  }

  void _syncSelectedIndexIfNeeded() {
    // Prefer explicit currentRoute prop from parent; if null, try ModalRoute
    final routeFromParent = widget.currentRoute;
    final routeFromContext = ModalRoute.of(context)?.settings.name;
    final chosenRoute = routeFromParent ?? routeFromContext;
    final newIndex = _indexForRoute(chosenRoute);
    if (newIndex >= 0 && newIndex != _selectedIndex) {
      setState(() => _selectedIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder + MediaQuery to compute a responsive width
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final double collapsedWidth = 64;
        final double expandedWidth = screenWidth < 420 ? max(180, screenWidth * 0.7) : 260;
        final double width = widget.isExpanded ? expandedWidth : collapsedWidth;

        return SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: width.clamp(56.0, min(360.0, screenWidth)),
            constraints: BoxConstraints(minWidth: 56, maxWidth: min(360, screenWidth)),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(6, 4))
              ],
              borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomRight: Radius.circular(18)),
            ),
            child: Column(
              children: [
                _buildHeader(width),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: widget.isExpanded ? 8 : 6),
                    child: Scrollbar(
                      radius: const Radius.circular(8),
                      thickness: 6,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _menuItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) => _buildMenuTile(index, _menuItems[index], width),
                      ),
                    ),
                  ),
                ),
                _buildFooter(width),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double sidebarWidth) {
    final avatarRadius = widget.isExpanded ? (sidebarWidth * 0.09).clamp(16.0, 34.0) : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: widget.isExpanded ? 12 : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.98), primaryColor.withOpacity(0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: widget.isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
        children: [
          if (widget.isExpanded)
            Flexible(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: ProfileAvatar(
                      imageUrl: widget.profileImageUrl,
                      fallbackInitial: widget.marketerName,
                      radius: avatarRadius,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.marketerName}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text("Classic", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ProfileAvatar(
              imageUrl: widget.profileImageUrl,
              fallbackInitial: widget.marketerName,
              radius: avatarRadius,
            ),
          const SizedBox(width: 6),
          // Toggle button
          IconButton(
            onPressed: widget.onToggle,
            splashRadius: 20,
            padding: const EdgeInsets.all(6),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.isExpanded ? Icons.chevron_left_rounded : Icons.menu,
                key: ValueKey<bool>(widget.isExpanded),
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(int index, SidebarItem item, double sidebarWidth) {
    final bool isSelected = _selectedIndex == index;
    final bool isHovered = _hoverIndex == index;

    final bgColor = isSelected
        ? primaryColor.withOpacity(0.08)
        : (isHovered ? Colors.grey.withOpacity(0.06) : null);
    final iconColor = isSelected ? primaryColor : Colors.grey.shade700;
    final textColor = isSelected ? primaryColor : Colors.grey.shade800;

    const tileHeight = 48.0;

    if (!widget.isExpanded) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hoverIndex = index),
        onExit: (_) => setState(() => _hoverIndex = -1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Tooltip(
            message: item.title,
            waitDuration: const Duration(milliseconds: 300),
            child: Material(
              color: bgColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _onTapItem(index, item),
                child: Container(
                  height: tileHeight,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: badges.Badge(
                    showBadge: item.notificationCount > 0,
                    badgeStyle:
                        const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(6)),
                    badgeContent: Text('${item.notificationCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                    child: Icon(item.icon, color: iconColor, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverIndex = index),
      onExit: (_) => setState(() => _hoverIndex = -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTapItem(index, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: isSelected
                        ? Tween<double>(begin: 0.98, end: 1.03).animate(_pulseController)
                        : const AlwaysStoppedAnimation(1.0),
                    child: badges.Badge(
                      position: badges.BadgePosition.topEnd(top: -6, end: -6),
                      showBadge: item.notificationCount > 0,
                      badgeStyle:
                          const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(6)),
                      badgeContent: Text('${item.notificationCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                      child: Icon(item.icon, color: iconColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14),
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 28,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 3))
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(double sidebarWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 12 : 6, vertical: 8),
          child: Row(
            children: [
              if (widget.isExpanded)
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => widget.onMenuItemTap('/marketer-settings'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Settings', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Preferences & account', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                          onPressed: () => widget.onMenuItemTap('/marketer-support'),
                          icon: Icon(Icons.support_agent_rounded, color: primaryColor)),
                    ],
                  ),
                )
              else
                IconButton(
                    onPressed: () => widget.onMenuItemTap('/marketer-settings'),
                    icon: Icon(Icons.settings, color: Colors.grey.shade700)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 12 : 6, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 44),
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
                crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
              ),
              onPressed: () => widget.onMenuItemTap('/login'),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class SidebarItem {
  final IconData icon;
  final String title;
  final String route;
  final int notificationCount;

  SidebarItem({
    required this.icon,
    required this.title,
    required this.route,
    this.notificationCount = 0,
  });
}
