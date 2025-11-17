import 'dart:async';

import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:intl/intl.dart';
import 'package:real_estate_app/admin/admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/shared/models/support_chat_model.dart';

String _previewText(Chat chat) {
  final message = chat.lastMessage?.trim();
  if (message != null && message.isNotEmpty) return message;
  if (chat.hasAttachment) {
    return chat.lastAttachmentName?.isNotEmpty == true ? chat.lastAttachmentName! : 'Attachment shared';
  }
  return chat.hasConversation ? 'Open to view conversation' : 'Start a conversation';
}

String _formatTime(DateTime? timestamp) {
  if (timestamp == null) return '--';
  return DateFormat('HH:mm').format(timestamp);
}
//
// legacy widgets retained for reference (commented out)
//

class AdminChatListScreen extends StatelessWidget {
  final String token;
  const AdminChatListScreen({required this.token, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Client Chats',
      token: token,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Client Chats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchDialog(context),
            ),
          ],
        ),
        body: _ChatList(token: token),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Clients'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Search by client name...'),
          onChanged: (value) {
            // Implement search functionality
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Execute search
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

class _ChatList extends StatefulWidget {
  final String token;
  const _ChatList({required this.token});

  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  final ApiService _api = ApiService();
  List<Chat> _chats = [];
  bool _loading = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadChats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final chats = await _api.fetchClientChats(widget.token);
      if (mounted) {
        setState(() {
          _chats = chats;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _error != null 
                ? 'Error loading chats'
                : 'No active conversations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadChats,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: _chats.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: _buildEmptyState(),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _chats.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, idx) => _ChatListItem(
                chat: _chats[idx],
                token: widget.token,
              ),
            ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final Chat chat;
  final String token;
  
  const _ChatListItem({required this.chat, required this.token});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.clientName.isNotEmpty ? chat.clientName : 'Unknown Client',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: chat.unreadCount > 0 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          _previewText(chat),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: chat.unreadCount > 0
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                    : Colors.grey.shade600,
              ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          if (chat.unreadCount > 0)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => Navigator.pushNamed(
        context,
        '/admin-chat',
        arguments: {
          'clientId': chat.id,
          'token': token,
          'clientName': chat.clientName,
        },
      ),
    );
  }
}

