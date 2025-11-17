import 'package:flutter/material.dart';

class AdminSupportBottomNav extends StatefulWidget {
  final int currentIndex;
  final String token;

  const AdminSupportBottomNav({
    super.key,
    required this.currentIndex,
    required this.token,
  });

  @override
  State<AdminSupportBottomNav> createState() => _AdminSupportBottomNavState();
}

class _AdminSupportBottomNavState extends State<AdminSupportBottomNav> {
  late int _index;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      route: '/admin-support-dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
    ),
    _NavDestination(
      route: '/admin-support-chat',
      icon: Icons.chat_bubble_outline,
      label: 'Chat',
    ),
    _NavDestination(
      route: '/admin-support-birthdays',
      icon: Icons.cake_outlined,
      label: 'Birthdays',
    ),
    _NavDestination(
      route: '/admin-support-special-days',
      icon: Icons.flag_outlined,
      label: 'Special Days',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant AdminSupportBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && widget.currentIndex != _index) {
      setState(() => _index = widget.currentIndex);
    }
  }

  void _navigateTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    final destination = _destinations[index];
    Navigator.of(context).pushReplacementNamed(destination.route, arguments: widget.token);
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final destination = _destinations[index];
    final bool isSelected = index == _index;
    final Color activeColor = theme.colorScheme.primary;
    final Color inactiveColor =
        theme.colorScheme.onSurface.withOpacity(theme.brightness == Brightness.dark ? 0.7 : 0.55);
    final Color iconColor = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: () => _navigateTo(index),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: iconColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color surfaceColor = theme.colorScheme.surface;
    final bool isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? surfaceColor.withOpacity(0.9) : surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                _destinations.length,
                (index) => Expanded(
                  child: _buildNavItem(context, index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  final String route;
  final IconData icon;
  final String label;

  const _NavDestination({
    required this.route,
    required this.icon,
    required this.label,
  });
}
