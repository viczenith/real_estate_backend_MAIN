import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:real_estate_app/admin_support/admin_support_bottom_nav.dart';
import 'package:real_estate_app/admin_support/admin_support_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';
import 'package:real_estate_app/shared/models/support_chat_model.dart';

class AdminSupportChatPage extends StatefulWidget {
  final String token;

  const AdminSupportChatPage({super.key, required this.token});

  @override
  State<AdminSupportChatPage> createState() => _AdminSupportChatPageState();
}

class _AdminSupportChatPageState extends State<AdminSupportChatPage> {
  final ApiService _api = ApiService();

  late final ValueNotifier<bool> _clientsExpanded;
  late final ValueNotifier<bool> _marketersExpanded;

  final TextEditingController _clientSearchCtrl = TextEditingController();
  final TextEditingController _marketerSearchCtrl = TextEditingController();

  final ValueNotifier<List<Chat>> _clientChats = ValueNotifier<List<Chat>>(<Chat>[]);
  final ValueNotifier<List<Chat>> _marketerChats = ValueNotifier<List<Chat>>(<Chat>[]);
  final ValueNotifier<int> _marketerUnreadTotal = ValueNotifier<int>(0);
  List<Chat> _allClientChats = <Chat>[];
  List<Chat> _allMarketerChats = <Chat>[];
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(true);
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _clientSearchLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _marketerSearchLoading = ValueNotifier<bool>(false);

  Timer? _refreshTimer;
  Timer? _clientSearchDebounce;
  Timer? _marketerSearchDebounce;
  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _clientsExpanded = ValueNotifier<bool>(true);
    _marketersExpanded = ValueNotifier<bool>(false);
    _marketerChats.addListener(_recomputeMarketerUnread);
    _loadChats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadChats());
    _pushSubscription = PushNotificationService()
        .incomingPushEvents
        .listen((event) {
      final type = (event['type'] ?? '').toString().toLowerCase();
      final data = event['data'];
      if (type.contains('chat')) {
        _loadChats(showSpinner: false);
        return;
      }

      if (data is Map<String, dynamic>) {
        final category = data['category']?.toString().toLowerCase() ?? '';
        if (category.contains('chat')) {
          _loadChats(showSpinner: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clientSearchDebounce?.cancel();
    _marketerSearchDebounce?.cancel();
    _pushSubscription?.cancel();
    _clientSearchCtrl.dispose();
    _marketerSearchCtrl.dispose();
    _clientChats.dispose();
    _marketerChats.removeListener(_recomputeMarketerUnread);
    _marketerChats.dispose();
    _marketerUnreadTotal.dispose();
    _clientsExpanded.dispose();
    _marketersExpanded.dispose();
    _clientSearchLoading.dispose();
    _marketerSearchLoading.dispose();
    super.dispose();
  }

  Future<void> _loadChats({bool showSpinner = true}) async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      if (showSpinner) {
        _loading.value = true;
      }
      _error.value = null;

      final clientChats = await _api.fetchClientChats(widget.token);
      List<Chat> marketerChats = <Chat>[];

      try {
        marketerChats = await _api.fetchMarketerChats(widget.token);
      } catch (e) {
        if (!mounted) return;
        _error.value = 'Unable to load marketer conversations right now.';
      }

      if (!mounted) return;

      _allClientChats = clientChats;
      _allMarketerChats = marketerChats;
      _clientChats.value = List<Chat>.from(clientChats);
      _marketerChats.value = List<Chat>.from(marketerChats);
    } catch (e) {
      if (!mounted) return;
      _error.value = 'We couldn\'t refresh chats. Pull down to retry.';
    } finally {
      if (mounted && showSpinner) {
        _loading.value = false;
      }
      _isFetching = false;
    }
  }

  String? _resolveAvatarUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('asset://')) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final base = Uri.parse(_api.baseUrl);
    final origin = base.hasPort
        ? '${base.scheme}://${base.host}:${base.port}'
        : '${base.scheme}://${base.host}';
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$origin$normalized';
  }

  @override
  Widget build(BuildContext context) {
    return AdminSupportLayout(
      token: widget.token,
      pageTitle: 'Admin Support • Chat',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: RefreshIndicator(
            onRefresh: _loadChats,
            child: ValueListenableBuilder<bool>(
              valueListenable: _loading,
              builder: (context, loading, _) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildPageHeader(context, loading)),
                    SliverToBoxAdapter(child: const SizedBox(height: 12)),
                    SliverToBoxAdapter(
                      child: _AccordionSection(
                        title: 'Client Conversations',
                        description: 'Manage and respond to client messages',
                        icon: Icons.groups_rounded,
                        gradientColors: const [Color(0xFF7F53AC), Color(0xFF647DEE)],
                        expandedListenable: _clientsExpanded,
                        unreadCountListenable: _clientChats,
                        searchController: _clientSearchCtrl,
                        onSearchChanged: (term) => _filterChats(term, isClient: true),
                        onResetSearch: () => _resetSearch(isClient: true),
                        searchLoadingListenable: _clientSearchLoading,
                        child: ValueListenableBuilder<List<Chat>>(
                          valueListenable: _clientChats,
                          builder: (context, chats, _) {
                            return _ChatListView(
                              chats: chats,
                              emptyTitle: 'No client conversations yet',
                              emptySubtitle: 'Once clients reach out, their threads will appear right here.',
                              token: widget.token,
                              role: _ChatRole.client,
                              resolveAvatarUrl: _resolveAvatarUrl,
                            );
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 18)),
                    SliverToBoxAdapter(
                      child: _AccordionSection(
                        title: 'Marketer Conversations',
                        description: 'Manage and respond to marketer messages',
                        icon: Icons.groups_rounded,
                        gradientColors: const [Color(0xFFFF5F6D), Color(0xFFFFC371)],
                        expandedListenable: _marketersExpanded,
                        unreadCountListenable: _marketerChats,
                        badgeCountListenable: _marketerUnreadTotal,
                        searchController: _marketerSearchCtrl,
                        onSearchChanged: (term) => _filterChats(term, isClient: false),
                        onResetSearch: () => _resetSearch(isClient: false),
                        searchLoadingListenable: _marketerSearchLoading,
                        child: ValueListenableBuilder<List<Chat>>(
                          valueListenable: _marketerChats,
                          builder: (context, chats, _) {
                            return _ChatListView(
                              chats: chats,
                              emptyTitle: 'No marketer conversations yet',
                              emptySubtitle: 'Collaborate with marketers to keep marketing conversations documented.',
                              token: widget.token,
                              role: _ChatRole.marketer,
                              resolveAvatarUrl: _resolveAvatarUrl,
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: AdminSupportBottomNav(currentIndex: 1, token: widget.token),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, bool loading) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7F53AC), Color(0xFF647DEE)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.28)),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat List',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Text(
                    //   'Check on active conversations, follow up on marketers, and deliver superstar service.',
                    //   style: GoogleFonts.inter(color: Colors.white.withOpacity(0.82)),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, {required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  void _filterChats(String term, {required bool isClient}) {
    final query = term.trim();
    if (query.length < 2) {
      _cancelSearchDebounce(isClient: isClient);
      _restoreCachedChats(isClient: isClient);
      return;
    }

    _scheduleSearch(query, isClient: isClient);
  }

  Future<void> _resetSearch({required bool isClient}) async {
    if (isClient) {
      _clientSearchCtrl.clear();
    } else {
      _marketerSearchCtrl.clear();
    }
    _restoreCachedChats(isClient: isClient);
  }

  void _restoreCachedChats({required bool isClient}) {
    if (isClient) {
      _clientSearchLoading.value = false;
      _clientChats.value = List<Chat>.from(_allClientChats);
    } else {
      _marketerSearchLoading.value = false;
      _marketerChats.value = List<Chat>.from(_allMarketerChats);
    }
  }

  void _cancelSearchDebounce({required bool isClient}) {
    if (isClient) {
      _clientSearchDebounce?.cancel();
      _clientSearchDebounce = null;
    } else {
      _marketerSearchDebounce?.cancel();
      _marketerSearchDebounce = null;
    }
  }

  void _scheduleSearch(String query, {required bool isClient}) {
    final debounceDuration = const Duration(milliseconds: 350);

    _cancelSearchDebounce(isClient: isClient);

    final timer = Timer(debounceDuration, () async {
      final loadingNotifier = isClient ? _clientSearchLoading : _marketerSearchLoading;
      loadingNotifier.value = true;

      try {
        final results = await _api.searchSupportParticipants(
          token: widget.token,
          isClient: isClient,
          query: query,
        );

        if (!mounted) return;

        if (isClient) {
          _clientChats.value = List<Chat>.from(results);
        } else {
          _marketerChats.value = List<Chat>.from(results);
        }
      } catch (e) {
        if (!mounted) return;
        _error.value = 'Search failed. Please try again.';
      } finally {
        if (mounted) {
          loadingNotifier.value = false;
        }
      }
    });

    if (isClient) {
      _clientSearchDebounce = timer;
    } else {
      _marketerSearchDebounce = timer;
    }
  }

  void _recomputeMarketerUnread() {
    _marketerUnreadTotal.value = _sumUnread(_marketerChats.value);
  }

  int _sumUnread(List<Chat> chats) {
    return chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
  }
}

enum _ChatRole { client, marketer }

class _AccordionSection extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final ValueListenable<bool> expandedListenable;
  final ValueListenable<List<Chat>> unreadCountListenable;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onResetSearch;
  final Widget child;
  final ValueListenable<bool>? searchLoadingListenable;
  final ValueListenable<int>? badgeCountListenable;

  const _AccordionSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.expandedListenable,
    required this.unreadCountListenable,
    required this.searchController,
    required this.onSearchChanged,
    required this.onResetSearch,
    required this.child,
    this.searchLoadingListenable,
    this.badgeCountListenable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: expandedListenable,
      builder: (context, expanded, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: gradientColors.first.withOpacity(0.12), blurRadius: 25, offset: const Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                InkWell(
                  onTap: () => expandedListenable is ValueNotifier<bool> ? (expandedListenable as ValueNotifier<bool>).value = !expanded : null,
                  splashColor: Colors.white.withOpacity(0.08),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: GoogleFonts.manrope(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(description, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.82), fontSize: 13)),
                            ],
                          ),
                        ),
                        if (badgeCountListenable != null)
                          ValueListenableBuilder<int>(
                            valueListenable: badgeCountListenable!,
                            builder: (context, unread, _) {
                              return AnimatedOpacity(
                                opacity: unread > 0 ? 1 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                                  child: Text('$unread new', style: GoogleFonts.inter(color: gradientColors.first, fontWeight: FontWeight.w700)),
                                ),
                              );
                            },
                          )
                        else
                          ValueListenableBuilder<List<Chat>>(
                            valueListenable: unreadCountListenable,
                            builder: (context, chats, _) {
                              final unread = chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);
                              return AnimatedOpacity(
                                opacity: unread > 0 ? 1 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                                  child: Text('$unread new', style: GoogleFonts.inter(color: gradientColors.first, fontWeight: FontWeight.w700)),
                                ),
                              );
                            },
                          ),
                        const SizedBox(width: 12),
                        AnimatedRotation(
                          turns: expanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    color: theme.cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    child: Column(
                      children: [
                        _ChatSearchBar(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          onClearTapped: onResetSearch,
                        ),
                        if (searchLoadingListenable != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: searchLoadingListenable!,
                            builder: (context, loading, _) {
                              return loading
                                  ? const Padding(
                                      padding: EdgeInsets.only(top: 12.0),
                                      child: LinearProgressIndicator(minHeight: 2),
                                    )
                                  : const SizedBox(height: 12);
                            },
                          )
                        else
                          const SizedBox(height: 12),
                        child,
                      ],
                    ),
                  ),
                  crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                  sizeCurve: Curves.easeInOut,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearTapped;

  const _ChatSearchBar({required this.controller, required this.onChanged, required this.onClearTapped});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded),
                color: theme.colorScheme.primary,
                onPressed: onClearTapped,
              );
            },
          ),
          hintText: 'Search conversations…',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}

class _ChatListView extends StatelessWidget {
  final List<Chat> chats;
  final String emptyTitle;
  final String emptySubtitle;
  final String token;
  final _ChatRole role;
  final String? Function(String?) resolveAvatarUrl;

  const _ChatListView({required this.chats, required this.emptyTitle, required this.emptySubtitle, required this.token, required this.role, required this.resolveAvatarUrl});

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return _EmptyChatState(title: emptyTitle, subtitle: emptySubtitle);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _ChatCard(chat: chat, token: token, role: role, resolveAvatarUrl: resolveAvatarUrl);
      },
    );
  }
}

class _ChatCard extends StatelessWidget {
  final Chat chat;
  final String token;
  final _ChatRole role;
  final String? Function(String?) resolveAvatarUrl;

  const _ChatCard({required this.chat, required this.token, required this.role, required this.resolveAvatarUrl});

  String _previewText() {
    final content = chat.lastMessage?.trim();
    if (content != null && content.isNotEmpty) {
      return content;
    }
    if (chat.hasAttachment) {
      return chat.lastAttachmentName?.isNotEmpty == true ? chat.lastAttachmentName! : 'Attachment shared';
    }
    return chat.hasConversation ? 'Open to view conversation' : 'Start a conversation';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = chat.unreadCount > 0;

    return InkWell(
      onTap: () => _openChat(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AvatarGlyph(
              name: chat.clientName,
              imageUrl: resolveAvatarUrl(chat.avatarUrl),
              highlight: unread,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.clientName.isEmpty ? 'Unnamed contact' : chat.clientName,
                          style: GoogleFonts.manrope(
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(chat.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: unread ? theme.colorScheme.primary : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _previewText(),
                    style: GoogleFonts.inter(
                      color: unread ? theme.colorScheme.primary : Colors.grey.shade600,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (unread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    final participantRole = role == _ChatRole.client ? 'client' : 'marketer';

    Navigator.of(context).pushNamed(
      '/admin-support-chat-thread',
      arguments: <String, dynamic>{
        'token': token,
        'role': participantRole,
        'participantId': chat.id,
        'participantName': chat.clientName,
      },
    );
  }

  String _relativeTime(DateTime? timestamp) {
    if (timestamp == null) return '--';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _AvatarGlyph extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool highlight;

  const _AvatarGlyph({required this.name, required this.imageUrl, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl?.trim();
    final borderColor = highlight
        ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
        : Colors.transparent;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: ClipOval(
        child: resolvedUrl != null && resolvedUrl.isNotEmpty
            ? Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsAvatar(name: name, highlight: highlight),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: highlight
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                        : Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                },
              )
            : _InitialsAvatar(name: name, highlight: highlight),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final bool highlight;

  const _InitialsAvatar({required this.name, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty
        ? '?'
        : name
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part.characters.first.toUpperCase())
            .join();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight ? Theme.of(context).colorScheme.primary.withOpacity(0.18) : Colors.grey.shade200,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.manrope(
          color: highlight ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyChatState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
