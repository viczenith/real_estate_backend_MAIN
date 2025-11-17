import 'package:flutter/material.dart';
import 'package:real_estate_app/shared/profile_avatar.dart';
import 'package:real_estate_app/shared/header.dart';

/// Sidebar navigation for the Admin Support role.
class AdminSupportSidebar extends StatefulWidget {
  final bool isExpanded;
  final ValueChanged<String> onMenuItemTap;
  final VoidCallback onToggle;
  final String? currentRoute;
  final String supportName;
  final SharedHeaderController? headerController;
  final int notificationCount;
  final int messageCount;

  const AdminSupportSidebar({
    super.key,
    required this.isExpanded,
    required this.onMenuItemTap,
    required this.onToggle,
    this.currentRoute,
    this.supportName = 'Admin Support',
    this.headerController,
    this.notificationCount = 0,
    this.messageCount = 0,
  });

  @override
  State<AdminSupportSidebar> createState() => _AdminSupportSidebarState();
}

class _AdminSupportSidebarState extends State<AdminSupportSidebar> {
  late final ValueNotifier<Map<String, int>> _countsNotifier;
  bool _ownsNotifier = false;

  @override
  void initState() {
    super.initState();
    if (widget.headerController != null) {
      _countsNotifier = widget.headerController!.countsNotifier;
    } else {
      _countsNotifier = ValueNotifier<Map<String, int>>({
        'notifications': widget.notificationCount,
        'messages': widget.messageCount,
      });
      _ownsNotifier = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdminSupportSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.headerController != widget.headerController) {
      if (_ownsNotifier) {
        _countsNotifier.dispose();
      }
      if (widget.headerController != null) {
        _countsNotifier = widget.headerController!.countsNotifier;
        _ownsNotifier = false;
      } else {
        _countsNotifier = ValueNotifier<Map<String, int>>({
          'notifications': widget.notificationCount,
          'messages': widget.messageCount,
        });
        _ownsNotifier = true;
      }
    }
  }

  @override
  void dispose() {
    if (_ownsNotifier) {
      _countsNotifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_SidebarItem>[
      const _SidebarItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        route: '/admin-support-dashboard',
      ),
      const _SidebarItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Support Chat',
        route: '/admin-support-chat',
      ),
      const _SidebarItem(
        icon: Icons.cake_outlined,
        label: 'Birthday Celebrants',
        route: '/admin-support-birthdays',
      ),
      const _SidebarItem(
        icon: Icons.flag_outlined,
        label: 'Special Nigeria Days',
        route: '/admin-support-special-days',
      ),
    ];

    return Container(
      width: widget.isExpanded ? 260 : 80,
      color: const Color(0xFF1F1B3F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment:
              widget.isExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.isExpanded ? 20 : 0),
              child: Row(
                mainAxisAlignment:
                    widget.isExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                children: [
                  if (widget.isExpanded)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.supportName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Support Operations',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    onPressed: widget.onToggle,
                    icon: Icon(
                      widget.isExpanded ? Icons.chevron_left : Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ValueListenableBuilder<Map<String, int>>(
                valueListenable: _countsNotifier,
                builder: (context, counts, _) {
                  final notifications = counts['notifications'] ?? widget.notificationCount;
                  final messages = counts['messages'] ?? widget.messageCount;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isActive = widget.currentRoute == item.route;
                      final badgeCount = item.route == '/admin-support-chat'
                          ? messages
                          : item.route == '/admin-support-birthdays'
                              ? 0
                              : item.route == '/admin-support-special-days'
                                  ? 0
                                  : notifications;

                      return _SidebarTile(
                        isExpanded: widget.isExpanded,
                        item: item,
                        isActive: isActive,
                        badgeCount: badgeCount,
                        onTap: () => widget.onMenuItemTap(item.route),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.white70),
              title: widget.isExpanded
                  ? const Text(
                      'Settings',
                      style: TextStyle(color: Colors.white70),
                    )
                  : null,
              onTap: () => widget.onMenuItemTap('/admin-support-settings'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: widget.isExpanded
                  ? const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white70),
                    )
                  : null,
              onTap: () => widget.onMenuItemTap('/logout'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final String route;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _SidebarTile extends StatelessWidget {
  final bool isExpanded;
  final _SidebarItem item;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.isExpanded,
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = isActive ? Colors.white10 : Colors.transparent;
    final iconColor = isActive ? Colors.white : Colors.white70;

    Widget buildLabel() {
      if (!isExpanded) return const SizedBox.shrink();
      return Text(
        item.label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      );
    }

    Widget buildBadge(Widget child) {
      if (badgeCount <= 0) return child;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepOrangeAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 16 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment:
                  isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                buildBadge(Icon(item.icon, color: iconColor)),
                if (isExpanded) const SizedBox(width: 16),
                buildLabel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
