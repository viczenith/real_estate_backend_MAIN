// import 'package:flutter/material.dart';
// import 'admin_header.dart';
// import 'admin_sidebar.dart';


// class AdminLayout extends StatefulWidget {
//   final Widget child;
//   final String pageTitle;
//   final String token; // Added token parameter

//   const AdminLayout({
//     super.key,
//     required this.child,
//     required this.pageTitle,
//     required this.token,
//   });

//   @override
//   State<AdminLayout> createState() => _AdminLayoutState();
// }

// class _AdminLayoutState extends State<AdminLayout> {
//   bool _isSidebarVisible = false;

//   void toggleSidebar() {
//     setState(() {
//       _isSidebarVisible = !_isSidebarVisible;
//     });
//   }

//   // Updated to pass token as the route argument.
//   void handleMenuItemTap(String route) {
//     setState(() {
//       _isSidebarVisible = false;
//     });
//     Navigator.pushNamed(context, route, arguments: widget.token);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AdminHeader(
//         title: widget.pageTitle,
//         onMenuToggle: toggleSidebar,
//       ),
//       body: Stack(
//         children: [
//           // Main content with background gradient.
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Colors.white, Color(0xFFF5F3FF)],
//               ),
//             ),
//             child: widget.child,
//           ),
//           // Sidebar overlay.
//           AnimatedPositioned(
//             duration: const Duration(milliseconds: 300),
//             left: _isSidebarVisible ? 0 : -250,
//             top: 0,
//             bottom: 0,
//             child: SizedBox(
//               width: 250,
//               child: AdminSidebar(
//                 isExpanded: true,
//                 onMenuItemTap: handleMenuItemTap,
//                 onToggle: toggleSidebar,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'admin_header.dart';
import 'admin_sidebar.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String pageTitle;
  final String token; // auth token to pass along

  const AdminLayout({
    Key? key,
    required this.child,
    required this.pageTitle,
    required this.token,
  }) : super(key: key);

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _isSidebarVisible = false;

  void toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  void handleMenuItemTap(String route) {
    setState(() {
      _isSidebarVisible = false;
    });
    Navigator.pushNamed(context, route, arguments: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024; // adjust breakpoint as needed

    return Scaffold(
      appBar: AdminHeader(
        title: widget.pageTitle,
        // hide the menu button on large screens
        onMenuToggle: isLargeScreen ? null : toggleSidebar,
      ),
      body: Row(
        children: [
          // Permanent sidebar for desktop/tablet
          if (isLargeScreen)
            SizedBox(
              width: 250,
              child: AdminSidebar(
                isExpanded: true,
                onMenuItemTap: handleMenuItemTap,
                onToggle: toggleSidebar,
              ),
            ),

          // Main content area (and overlay sidebar on mobile)
          Expanded(
            child: Stack(
              children: [
                // Background + content
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF5F3FF)],
                    ),
                  ),
                  child: widget.child,
                ),

                // Slide-in sidebar for mobile
                if (!isLargeScreen)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    left: _isSidebarVisible ? 0 : -250,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 250,
                      child: AdminSidebar(
                        isExpanded: true,
                        onMenuItemTap: handleMenuItemTap,
                        onToggle: toggleSidebar,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
