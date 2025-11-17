// import 'package:flutter/material.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart';
// import 'package:lottie/lottie.dart';

// class OnboardingScreen extends StatefulWidget {
//   const OnboardingScreen({super.key});

//   @override
//   _OnboardingScreenState createState() => _OnboardingScreenState();
// }

// class _OnboardingScreenState extends State<OnboardingScreen> {
//   final PageController _controller = PageController();
//   int _currentPage = 0;

//   final List<OnboardingPage> _pages = [
//     OnboardingPage(
//       title: "Discover Dream Homes",
//       description:
//           "Explore luxury properties with 360° virtual tours and AI-powered recommendations.",
//       lottieJson: "assets/animations/house.json",
//       color: const Color(0xFF2A2D3E),
//     ),
//     OnboardingPage(
//       title: "Smart Search & Filters",
//       description:
//           "Find your perfect home using advanced filters and machine learning suggestions.",
//       lottieJson: "assets/animations/house2.json",
//       color: const Color(0xFF1F212E),
//     ),
//     OnboardingPage(
//       title: "Virtual Reality Tours",
//       description:
//           "Experience properties in immersive VR with real-time agent collaboration.",
//       lottieJson: "assets/animations/house3.json",
//       color: const Color(0xFF252837),
//     ),
//   ];

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           PageView.builder(
//             controller: _controller,
//             itemCount: _pages.length,
//             onPageChanged: (index) => setState(() => _currentPage = index),
//             itemBuilder: (context, index) => _buildPage(_pages[index]),
//           ),
//           _buildAppBar(),
//           _buildFooter(),
//         ],
//       ),
//     );
//   }

//   /// Page Layout with Lottie Animation
//   Widget _buildPage(OnboardingPage page) {
//     return Container(
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [page.color, page.color.withOpacity(0.8)],
//         ),
//       ),
//       child: Column(
//         children: [
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.all(40.0),
//               child: Hero(
//                 tag: page.title,
//                 child: Lottie.asset(
//                   page.lottieJson,
//                   width: double.infinity,
//                   height: 300,
//                   fit: BoxFit.contain,
//                   repeat: true,
//                 ),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: _buildContent(page),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Content Section with Title and Description
//   Widget _buildContent(OnboardingPage page) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(
//             page.title,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontFamily: '.SF Pro Text',
//               fontSize: 28,
//               fontWeight: FontWeight.w700,
//               color: Colors.white,
//               letterSpacing: 0.5,
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             page.description,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontFamily: '.SF Pro Text',
//               fontSize: 16,
//               fontWeight: FontWeight.w400,
//               color: Colors.white70,
//               height: 1.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// App Bar with Skip Button
//   Widget _buildAppBar() {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             AnimatedOpacity(
//               opacity: _currentPage == _pages.length - 1 ? 0.0 : 1.0,
//               duration: const Duration(milliseconds: 300),
//               child: GestureDetector(
//                 onTap: () => _controller.animateToPage(
//                   _pages.length - 1,
//                   duration: const Duration(milliseconds: 500),
//                   curve: Curves.easeInOut,
//                 ),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: const Text(
//                     "Skip",
//                     style: TextStyle(
//                       fontFamily: '.SF Pro Text',
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Footer with Page Indicator and Navigation Button
//   Widget _buildFooter() {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         padding: const EdgeInsets.all(32),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
//           ),
//         ),
//         child: Column(
//           children: [
//             SmoothPageIndicator(
//               controller: _controller,
//               count: _pages.length,
//               effect: const ExpandingDotsEffect(
//                 dotWidth: 12,
//                 dotHeight: 12,
//                 expansionFactor: 3,
//                 spacing: 8,
//                 activeDotColor: Color(0xFF6C5CE7),
//                 dotColor: Colors.white30,
//               ),
//             ),
//             const SizedBox(height: 30),
//             AnimatedSwitcher(
//               duration: const Duration(milliseconds: 400),
//               transitionBuilder: (child, animation) => ScaleTransition(
//                 scale: animation,
//                 child: child,
//               ),
//               child: _currentPage == _pages.length - 1
//                   ? _buildGetStartedButton()
//                   : _buildNextButton(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   /// Next Button
//   Widget _buildNextButton() {
//     return FloatingActionButton(
//       key: const ValueKey('Next'),
//       onPressed: () => _controller.nextPage(
//         duration: const Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//       ),
//       backgroundColor: const Color(0xFF6C5CE7),
//       elevation: 8,
//       child: const Icon(Icons.arrow_forward, size: 28, color: Colors.white),
//     );
//   }

//   /// Get Started Button
//   Widget _buildGetStartedButton() {
//     return SizedBox(
//       key: const ValueKey('GetStarted'),
//       width: double.infinity,
//       child: ElevatedButton(
//         onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
//         style: ElevatedButton.styleFrom(
//           padding: const EdgeInsets.symmetric(vertical: 18),
//           backgroundColor: const Color(0xFF6C5CE7),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(30),
//           ),
//           elevation: 10,
//           shadowColor: const Color(0xFF6C5CE7).withOpacity(0.5),
//         ),
//         child: const Text(
//           "Get Started",
//           style: TextStyle(
//             fontFamily: '.SF Pro Text',
//             fontSize: 18,
//             fontWeight: FontWeight.w700,
//             color: Colors.white,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class OnboardingPage {
//   final String title;
//   final String description;
//   final String lottieJson;
//   final Color color;

//   OnboardingPage({
//     required this.title,
//     required this.description,
//     required this.lottieJson,
//     required this.color,
//   });
// }



import 'dart:math';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:real_estate_app/shared/app_side.dart';

class SharedHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final AppSide side;
  final ValueChanged<AppSide>? onMenuToggle;

  final bool showNotifications;
  final bool showMessages;

  final List<Message> messages;
  final List<NotificationItem> notifications;

  final Widget? companyLogo;
  final VoidCallback? onCompanyLogoTap;

  final VoidCallback? onMessagesOpened;
  final VoidCallback? onNotificationsOpened;
  final VoidCallback? onViewMessageHistory;
  final VoidCallback? onViewNotificationHistory;

  const SharedHeader({
    Key? key,
    required this.title,
    required this.side,
    this.onMenuToggle,
    this.showNotifications = false,
    this.showMessages = false,
    this.messages = const <Message>[],
    this.notifications = const <NotificationItem>[],
    this.companyLogo,
    this.onCompanyLogoTap,
    this.onMessagesOpened,
    this.onNotificationsOpened,
    this.onViewMessageHistory,
    this.onViewNotificationHistory,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SharedHeader> createState() => _SharedHeaderState();
}

class _SharedHeaderState extends State<SharedHeader> {
  OverlayEntry? _messagesOverlay;
  OverlayEntry? _notificationsOverlay;

  final GlobalKey _messageIconKey = GlobalKey();
  final GlobalKey _notifIconKey = GlobalKey();

  final List<Message> _mockMessages = [
    Message(clientName: 'John Doe', message: 'Payment confirmation received for plot A-21.', timestamp: DateTime.now().subtract(const Duration(minutes: 15))),
    Message(clientName: 'Jane Smith', message: 'Can you reserve the corner plot for me?', timestamp: DateTime.now().subtract(const Duration(hours: 2))),
    Message(clientName: 'Mike Johnson', message: 'Documents uploaded to your dashboard.', timestamp: DateTime.now().subtract(const Duration(days: 1))),
  ];

  final List<NotificationItem> _mockNotifications = [
    NotificationItem(title: 'Payment Received', body: 'Payment for plot B-12 has been confirmed.', timestamp: DateTime.now().subtract(const Duration(minutes: 36))),
    NotificationItem(title: 'New Property Added', body: 'Starlight II Estate - 6 new plots available.', timestamp: DateTime.now().subtract(const Duration(hours: 4))),
    NotificationItem(title: 'System Notice', body: 'Maintenance scheduled for Aug 20, 2:00 AM.', timestamp: DateTime.now().subtract(const Duration(days: 2))),
  ];

  List<Message> get _messages => widget.messages.isEmpty ? _mockMessages : widget.messages;
  List<NotificationItem> get _notifications => widget.notifications.isEmpty ? _mockNotifications : widget.notifications;

  int get _unreadMessagesCount => _messages.where((m) => !m.isRead).length;
  int get _unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  @override
  void dispose() {
    _removeMessagesOverlay();
    _removeNotificationsOverlay();
    super.dispose();
  }

  void _toggleMessages() {
    if (_messagesOverlay == null) {
      _showListOverlay(
        key: _messageIconKey,
        title: 'Unread Messages',
        icon: Icons.chat,
        itemsHeight: 220,
        contentBuilder: _buildMessagesList,
        setOverlay: (entry) => _messagesOverlay = entry,
        removeOtherOverlay: _removeNotificationsOverlay,
      );
      widget.onMessagesOpened?.call();
    } else {
      _removeMessagesOverlay();
    }
  }

  void _toggleNotifications() {
    if (_notificationsOverlay == null) {
      _showListOverlay(
        key: _notifIconKey,
        title: 'Notifications',
        icon: Icons.notifications_rounded,
        itemsHeight: 240,
        contentBuilder: _buildNotificationsList,
        setOverlay: (entry) => _notificationsOverlay = entry,
        removeOtherOverlay: _removeMessagesOverlay,
      );
      widget.onNotificationsOpened?.call();
    } else {
      _removeNotificationsOverlay();
    }
  }

  void _removeMessagesOverlay() {
    _messagesOverlay?.remove();
    _messagesOverlay = null;
  }

  void _removeNotificationsOverlay() {
    _notificationsOverlay?.remove();
    _notificationsOverlay = null;
  }

  void _showListOverlay({
    required GlobalKey key,
    required String title,
    required IconData icon,
    required double itemsHeight,
    required WidgetBuilder contentBuilder,
    required void Function(OverlayEntry) setOverlay,
    required VoidCallback removeOtherOverlay,
  }) {
    removeOtherOverlay();

    if (key.currentContext == null) return;

    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final Size iconSize = renderBox.size;
    final Offset iconPosition = renderBox.localToGlobal(Offset.zero);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double safeMargin = 8.0;
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    double overlayMaxWidth = min(360.0, screenWidth - (safeMargin * 2));
    double overlayWidth = min(340.0, overlayMaxWidth);

    double estimatedHeaderFooter = 120.0;
    double overlayDesiredHeight = min(440.0, itemsHeight + estimatedHeaderFooter);

    double availableBelow = screenHeight - (iconPosition.dy + iconSize.height) - bottomPadding - safeMargin;
    double availableAbove = iconPosition.dy - topPadding - safeMargin;

    bool placeAbove = false;
    double overlayHeight = overlayDesiredHeight;

    if (availableBelow >= overlayDesiredHeight) {
      placeAbove = false;
      overlayHeight = overlayDesiredHeight;
    } else if (availableAbove >= overlayDesiredHeight) {
      placeAbove = true;
      overlayHeight = overlayDesiredHeight;
    } else {
      placeAbove = availableAbove > availableBelow;
      overlayHeight = max(min(overlayDesiredHeight, max(availableBelow, availableAbove)), 120.0);
    }

    double availableRight = screenWidth - (iconPosition.dx + iconSize.width) - safeMargin;
    double availableLeft = iconPosition.dx - safeMargin;

    double? leftPos;
    double? rightPos;

    if (availableRight >= overlayWidth) {
      rightPos = screenWidth - (iconPosition.dx + iconSize.width) + safeMargin;
      leftPos = null;
    } else if (availableLeft >= overlayWidth) {
      leftPos = iconPosition.dx - safeMargin;
      rightPos = null;
    } else {
      leftPos = (iconPosition.dx + iconSize.width / 2) - (overlayWidth / 2);
      leftPos = leftPos.clamp(safeMargin, screenWidth - overlayWidth - safeMargin);
      rightPos = null;
    }

    double topOffset = 0.0;
    if (!placeAbove) {
      topOffset = iconPosition.dy + iconSize.height + 8.0;
      final double maxTop = screenHeight - overlayHeight - bottomPadding - safeMargin;
      topOffset = min(topOffset, maxTop);
      if (topOffset + overlayHeight + bottomPadding + safeMargin > screenHeight) {
        placeAbove = true;
        topOffset = iconPosition.dy - overlayHeight - 8.0;
        final double minTop = topPadding + safeMargin;
        topOffset = max(topOffset, minTop);
      }
    } else {
      topOffset = iconPosition.dy - overlayHeight - 8.0;
      final double minTop = topPadding + safeMargin;
      topOffset = max(topOffset, minTop);
    }

    final overlayEntry = OverlayEntry(builder: (context) {
      return GestureDetector(
        onTap: () {
          _removeMessagesOverlay();
          _removeNotificationsOverlay();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              top: topOffset,
              left: leftPos,
              right: rightPos,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: overlayWidth,
                  constraints: BoxConstraints(
                    maxHeight: overlayHeight,
                    minWidth: 200,
                    maxWidth: overlayMaxWidth,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.deepPurple.shade50,
                        Colors.blue.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(icon, color: Colors.deepPurple, size: 24),
                            const SizedBox(width: 12),
                            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: overlayHeight - 120),
                        child: contentBuilder(context),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.history_rounded),
                              label: Text(title.contains('Message') ? 'View Message History' : 'View Notifications'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () {
                                if (title.contains('Message')) {
                                  widget.onViewMessageHistory?.call();
                                  _removeMessagesOverlay();
                                } else {
                                  widget.onViewNotificationHistory?.call();
                                  _removeNotificationsOverlay();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });

    setOverlay(overlayEntry);
    Overlay.of(context)?.insert(overlayEntry);
  }

  Widget _buildMessagesList(BuildContext context) {
    final list = _messages;
    if (list.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No messages'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final message = list[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepPurple.shade100,
            child: Text(
              message.clientName.isNotEmpty ? message.clientName[0] : '?',
              style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(message.clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            message.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_timeAgo(message.timestamp)),
              if (!message.isRead)
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle)),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: () {
            setState(() => message.isRead = true);
            _removeMessagesOverlay();
          },
        );
      },
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    final list = _notifications;
    if (list.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No notifications'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final n = list[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.notification_important_rounded, color: Colors.blue.shade800),
          ),
          title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            n.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_timeAgo(n.timestamp)),
              if (!n.isRead)
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
            ],
          ),
          onTap: () {
            setState(() => n.isRead = true);
            _removeNotificationsOverlay();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool notificationsVisible = widget.showNotifications || widget.side == AppSide.client || widget.side == AppSide.marketer;
    final bool messagesVisible = widget.showMessages || widget.side == AppSide.client || widget.side == AppSide.admin;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          if (widget.onMenuToggle != null)
            IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => widget.onMenuToggle?.call(widget.side)),
          const SizedBox(width: 8),
          Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
      backgroundColor: Colors.deepPurple.shade800,
      elevation: 4,
      actions: [
        if (notificationsVisible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: badges.Badge(
              position: badges.BadgePosition.topEnd(top: -5, end: -5),
              badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(6)),
              showBadge: _unreadNotificationsCount > 0,
              badgeContent: Text('$_unreadNotificationsCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
              child: Container(key: _notifIconKey, child: IconButton(icon: const Icon(Icons.notifications_rounded, size: 26), color: Colors.white, onPressed: _toggleNotifications)),
            ),
          ),
        if (messagesVisible)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: badges.Badge(
              position: badges.BadgePosition.topEnd(top: -5, end: -5),
              badgeStyle: const badges.BadgeStyle(badgeColor: Colors.redAccent, padding: EdgeInsets.all(6)),
              showBadge: _unreadMessagesCount > 0,
              badgeContent: Text('$_unreadMessagesCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
              child: Container(key: _messageIconKey, child: IconButton(icon: const Icon(Icons.markunread_mailbox_rounded, size: 26), color: Colors.white, onPressed: _toggleMessages)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: GestureDetector(
            onTap: widget.onCompanyLogoTap,
            child: widget.companyLogo ??
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
                    image: const DecorationImage(image: AssetImage('assets/logo.png'), fit: BoxFit.cover),
                  ),
                ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _timeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 365) return '${(duration.inDays / 365).floor()}y ago';
    if (duration.inDays > 30) return '${(duration.inDays / 30).floor()}mo ago';
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }
}

/// Message model
class Message {
  final String clientName;
  final String message;
  final DateTime timestamp;
  bool isRead;
  Message({required this.clientName, required this.message, required this.timestamp, this.isRead = false});
}

/// Notification model
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  NotificationItem({required this.title, required this.body, required this.timestamp, this.isRead = false});
}
