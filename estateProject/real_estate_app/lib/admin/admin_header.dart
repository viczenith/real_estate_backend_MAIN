import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;

class AdminHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuToggle;

  const AdminHeader({Key? key, required this.title, this.onMenuToggle})
      : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AdminHeader> createState() => _AdminHeaderState();
}

class _AdminHeaderState extends State<AdminHeader> {
  final List<Message> _messages = [
    Message(
      clientName: 'John Doe',
      message: 'Need help with plot allocation...',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    Message(
      clientName: 'Jane Smith',
      message: 'Payment confirmation received?',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Message(
      clientName: 'Mike Johnson',
      message: 'Regarding estate documents...',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  int _unreadCount = 3;
  OverlayEntry? _overlayEntry;
  final GlobalKey _messageIconKey = GlobalKey();

  /// Toggle the dropdown overlay:
  void _toggleMessages() {
    if (_overlayEntry == null) {
      _showMessagesOverlay();
      setState(() {
        _unreadCount = 0;
      });
    } else {
      _removeMessagesOverlay();
    }
  }

  /// Creates and shows the overlay positioned below the message icon.
  void _showMessagesOverlay() {
    final RenderBox renderBox =
        _messageIconKey.currentContext!.findRenderObject() as RenderBox;
    final Size iconSize = renderBox.size;
    final Offset iconPosition = renderBox.localToGlobal(Offset.zero);

    // Position the overlay just below the message icon.
    double topOffset = iconPosition.dy + iconSize.height + 5.0;
    // Adjust the right offset so that the dropdown aligns with the right side of the icon.
    double rightOffset =
        MediaQuery.of(context).size.width - iconPosition.dx - iconSize.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          // Tapping outside will dismiss the overlay.
          onTap: _removeMessagesOverlay,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned(
                top: topOffset,
                right: rightOffset,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 320,
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
                      border:
                          Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header of the dropdown
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.markunread_rounded,
                                  color: Colors.deepPurple, size: 24),
                              const SizedBox(width: 12),
                              Text('Unread Messages',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        // List of messages in a constrained box
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            shrinkWrap: true,
                            itemCount: _messages.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.deepPurple.shade100,
                                  child: Text(
                                    message.clientName[0],
                                    style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  message.clientName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  message.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.grey.shade600),
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(timeAgo(message.timestamp)),
                                    if (!message.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.deepPurple,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                onTap: _removeMessagesOverlay,
                              );
                            },
                          ),
                        ),
                        // Footer with a button (you can navigate to history)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextButton.icon(
                            icon: const Icon(Icons.message_rounded),
                            label: const Text('View Message History'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: _removeMessagesOverlay,
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
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeMessagesOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Row(
        children: [
          if (widget.onMenuToggle != null)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: widget.onMenuToggle,
            ),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.deepPurple.shade800,
      elevation: 4,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: badges.Badge(
            position: badges.BadgePosition.topEnd(top: -5, end: -5),
            badgeStyle: const badges.BadgeStyle(
              badgeColor: Colors.redAccent,
              padding: EdgeInsets.all(6),
            ),
            showBadge: _unreadCount > 0,
            badgeContent: Text(
              '$_unreadCount',
              style:
                  const TextStyle(color: Colors.white, fontSize: 12),
            ),
            child: Container(
              key: _messageIconKey,
              child: IconButton(
                icon: const Icon(
                    Icons.markunread_mailbox_rounded, size: 26),
                color: Colors.white,
                onPressed: _toggleMessages,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  String timeAgo(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inDays > 365)
      return '${(duration.inDays / 365).floor()}y ago';
    if (duration.inDays > 30)
      return '${(duration.inDays / 30).floor()}mo ago';
    if (duration.inDays > 0)
      return '${duration.inDays}d ago';
    if (duration.inHours > 0)
      return '${duration.inHours}h ago';
    if (duration.inMinutes > 0)
      return '${duration.inMinutes}m ago';
    return 'Just now';
  }
}

class Message {
  final String clientName;
  final String message;
  final DateTime timestamp;
  bool isRead;

  Message({
    required this.clientName,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}
