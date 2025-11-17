import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

class AdminSidebar extends StatefulWidget {
  final bool isExpanded;
  final Function(String) onMenuItemTap;
  final VoidCallback onToggle;

  const AdminSidebar({
    super.key,
    required this.isExpanded,
    required this.onMenuItemTap,
    required this.onToggle,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  int _selectedIndex = 0;
  final List<SidebarItem> _menuItems = [
    SidebarItem(
      icon: Icons.dashboard_rounded,
      title: "Dashboard",
      route: '/admin-dashboard',
      notificationCount: 0,
    ),
    SidebarItem(
      icon: Icons.people_alt_rounded,
      title: "Clients",
      route: '/admin-clients',
      notificationCount: 3,
    ),
    SidebarItem(
      icon: Icons.business_center_rounded,
      title: "Marketers",
      route: '/admin-marketers',
      notificationCount: 1,
    ),
    SidebarItem(
      icon: Icons.assignment_rounded,
      title: "Allocate Plot",
      route: '/allocate-plot',
    ),
    SidebarItem(
      icon: Icons.add_box_sharp,
      title: "Add Estate Plot Sizes",
      route: '/add-plot-size',
    ),
    SidebarItem(
      icon: Icons.add_box_sharp,
      title: "Add Estate Plot Numbers",
      route: '/add-plot-number',
    ),
    SidebarItem(
      icon: Icons.add_home_rounded,
      title: "Add Estate",
      route: '/add-estate',
    ),
    SidebarItem(
      icon: Icons.apartment_rounded,
      title: "View Estate",
      route: '/view-estate',
    ),
    SidebarItem(
      icon: Icons.map_rounded,
      title: "Estate Plots",
      route: '/add-estate-plots',
    ),
    SidebarItem(
      icon: Icons.person_add_alt_rounded,
      title: "Register Users",
      route: '/register-client-marketer',
    ),
    SidebarItem(
      icon: Icons.chat_rounded,
      title: "Chat Support",
      route: '/admin-chat-list',
      notificationCount: 5,
    ),
    SidebarItem(
      icon: Icons.notifications_active_rounded,
      title: "Notifications",
      route: '/send-notification',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.isExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(4, 0))
        ],
        borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Sidebar header with toggle.
          Container(
            padding: EdgeInsets.symmetric(
                vertical: 24, horizontal: widget.isExpanded ? 16 : 10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade800,
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: widget.isExpanded
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (widget.isExpanded)
                  Text("Admin Panel",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                IconButton(
                  icon: Icon(
                      widget.isExpanded ? Icons.menu_open : Icons.menu,
                      color: Colors.white),
                  onPressed: widget.onToggle,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _menuItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildMenuItem(index),
            ),
          ),
          Divider(color: Colors.white54),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.deepPurple),
            title: widget.isExpanded
                ? const Text(
                    "Settings",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple),
                  )
                : null,
            onTap: () {
              Navigator.pushReplacementNamed(context, "/admin-settings");
            },
          ),
          Divider(color: Colors.white54),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: widget.isExpanded
                ? const Text(
                    "Logout",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent),
                  )
                : null,
            onTap: () {
              Navigator.pushReplacementNamed(context, "/login");
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _menuItems[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: badges.Badge(
          position: badges.BadgePosition.topEnd(top: -8, end: -8),
          showBadge: item.notificationCount > 0,
          badgeStyle: const badges.BadgeStyle(
              badgeColor: Colors.redAccent, padding: EdgeInsets.all(5)),
          badgeContent: Text('${item.notificationCount}',
              style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: Icon(item.icon,
              color: _selectedIndex == index
                  ? Colors.deepPurple
                  : Colors.grey.shade600),
        ),
        title: widget.isExpanded
            ? Text(item.title,
                style: TextStyle(
                    color: _selectedIndex == index
                        ? Colors.deepPurple
                        : Colors.grey.shade800,
                    fontWeight: _selectedIndex == index
                        ? FontWeight.w600
                        : FontWeight.normal))
            : null,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: _selectedIndex == index,
        selectedColor: Colors.deepPurple,
        tileColor: _selectedIndex == index
            ? Colors.deepPurple.withOpacity(0.1)
            : null,
        onTap: () {
          setState(() => _selectedIndex = index);
          // Call the callback with the route.
          widget.onMenuItemTap(item.route);
        },
      ),
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
