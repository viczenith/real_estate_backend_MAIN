// lib/client/client_sidebar.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:real_estate_app/shared/profile_avatar.dart';
import 'package:real_estate_app/shared/header.dart'; // <-- import controller

class ClientSidebar extends StatefulWidget {
  final bool isExpanded;
  final Function(String) onMenuItemTap;
  final VoidCallback onToggle;

  final String? currentRoute;

  final String? profileImageUrl;
  final String clientName;
  final String? clientRank;

  // Keep backward-compatible props for initial values
  final int notificationCount;
  final int messageCount;

  // NEW: optional header controller to listen for live updates
  final SharedHeaderController? headerController;

  const ClientSidebar({
    Key? key,
    required this.isExpanded,
    required this.onMenuItemTap,
    required this.onToggle,
    this.currentRoute,
    required this.profileImageUrl,
    required this.clientName,
    this.clientRank,
    this.notificationCount = 0,
    this.messageCount = 0,
    this.headerController,
  }) : super(key: key);

  @override
  State<ClientSidebar> createState() => _ClientSidebarState();
}

class _ClientSidebarState extends State<ClientSidebar> with SingleTickerProviderStateMixin {
  // Define rank styling based on rank tier
  Map<String, dynamic> _getRankStyle(String rank) {
    switch (rank) {
      case 'Royal Elite':
        return {
          'icon': Icons.diamond,
          'gradient': [const Color(0xFF6a11cb), const Color(0xFF2575fc)],
          'shadowColor': const Color(0xFF2575fc).withOpacity(0.25),
        };
      case 'Estate Ambassador':
        return {
          'icon': Icons.military_tech,
          'gradient': [const Color(0xFFfbbf24), const Color(0xFFf59e0b)],
          'shadowColor': const Color(0xFFf59e0b).withOpacity(0.25),
        };
      case 'Prime Investor':
        return {
          'icon': Icons.trending_up,
          'gradient': [const Color(0xFF3b82f6), const Color(0xFF06b6d4)],
          'shadowColor': const Color(0xFF06b6d4).withOpacity(0.25),
        };
      case 'Smart Owner':
        return {
          'icon': Icons.lightbulb,
          'gradient': [const Color(0xFF10b981), const Color(0xFF34d399)],
          'shadowColor': const Color(0xFF10b981).withOpacity(0.25),
        };
      case 'First-Time Investor':
      default:
        return {
          'icon': Icons.emoji_events,
          'gradient': [const Color(0xFF8b5cf6), const Color(0xFFa78bfa)],
          'shadowColor': const Color(0xFF8b5cf6).withOpacity(0.25),
        };
    }
  }

  Widget _buildRankBadge(BuildContext context, String rank) {
    final style = _getRankStyle(rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: style['shadowColor'] as Color,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style['icon'] as IconData,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            rank,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex = 0;
  int _hoverIndex = -1;

  static const Color primaryColor = Color(0xFF5E35B1);

  late final AnimationController _pulseController;

  late List<SidebarItem> _menuItems;

  // Live counts from header controller (or props as fallback)
  late int _liveNotificationCount;
  late int _liveMessageCount;
  VoidCallback? _headerListener;

  List<SidebarItem> _buildMenuItems() {
    return [
      SidebarItem(icon: Icons.dashboard_rounded, title: "Dashboard", route: '/client-dashboard'),
      SidebarItem(icon: Icons.person_rounded, title: "Profile", route: '/client-profile'),
      SidebarItem(
        icon: Icons.notifications_active,
        title: "Notifications",
        route: '/client-notification',
        notificationCount: _liveNotificationCount,
      ),
      SidebarItem(
        icon: Icons.chat_rounded,
        title: "Chat Admin",
        route: '/client-chat-admin',
        notificationCount: _liveMessageCount,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();

    // initialize live counts with widget props
    _liveNotificationCount = widget.notificationCount;
    _liveMessageCount = widget.messageCount;

    // setup header controller listener if provided
    if (widget.headerController != null) {
      // apply current controller values immediately (if any)
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

  void _selectRoute(String? route) {
    if (route == null) return;
    final idx = _menuItems.indexWhere((m) => m.route == route);
    if (idx >= 0) {
      if (mounted) setState(() => _selectedIndex = idx);
    } else {
      if (mounted) setState(() => _selectedIndex = -1);
    }
  }

  void _onTapItem(int index, SidebarItem item) {
    setState(() => _selectedIndex = index);
    widget.onMenuItemTap(item.route);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeName = widget.currentRoute ?? ModalRoute.of(context)?.settings.name;
    _selectRoute(routeName);
  }

  @override
  void didUpdateWidget(covariant ClientSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Controller swapped: remove old listener, add new
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
        // fallback to props if controller removed
        setState(() {
          _liveNotificationCount = widget.notificationCount;
          _liveMessageCount = widget.messageCount;
          _menuItems = _buildMenuItems();
        });
      }
    }

    // If props changed and no controller is present, reflect props
    if (widget.headerController == null) {
      if (widget.notificationCount != oldWidget.notificationCount || widget.messageCount != oldWidget.messageCount) {
        setState(() {
          _liveNotificationCount = widget.notificationCount;
          _liveMessageCount = widget.messageCount;
          _menuItems = _buildMenuItems();
        });
      }
    }

    // Update selected route if it changed
    if (widget.currentRoute != oldWidget.currentRoute) {
      _selectRoute(widget.currentRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
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
  }

  Widget _buildHeader(double sidebarWidth) {
    final avatarRadius = widget.isExpanded ? (sidebarWidth * 0.09).clamp(16.0, 30.0) : 16.0;

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
                      fallbackInitial: widget.clientName,
                      radius: avatarRadius,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, ${widget.clientName}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        _buildRankBadge(context, widget.clientRank ?? 'Member'),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ProfileAvatar(
              imageUrl: widget.profileImageUrl,
              fallbackInitial: widget.clientName,
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
                        onTap: () {
                          widget.onMenuItemTap('/client-settings');
                          _selectRoute('/client-settings');
                        },
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
                          onPressed: () {
                            widget.onMenuItemTap('/client-support');
                            _selectRoute('/client-support');
                          },
                          icon: Icon(Icons.support_agent_rounded, color: primaryColor)),
                    ],
                  ),
                )
              else
                IconButton(
                    onPressed: () {
                      widget.onMenuItemTap('/client-settings');
                      _selectRoute('/client-settings');
                    },
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
              onPressed: () {
                widget.onMenuItemTap('/login');
                _selectRoute('/login');
              },
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
