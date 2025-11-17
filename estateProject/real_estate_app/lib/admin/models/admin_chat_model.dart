class Chat {
  final String id;
  final String clientName;
  final String? lastMessage;
  final String? lastAttachmentName;
  final int unreadCount;
  final DateTime? timestamp;
  final String? avatarUrl;
  final bool hasConversation;

  const Chat({
    required this.id,
    required this.clientName,
    this.lastMessage,
    this.lastAttachmentName,
    this.unreadCount = 0,
    this.timestamp,
    this.avatarUrl,
    this.hasConversation = true,
  });

  bool get hasAttachment => (lastAttachmentName != null && lastAttachmentName!.isNotEmpty);

  factory Chat.fromJson(Map<String, dynamic> json) {
    final fullNameCandidates = <String?>[
      json['full_name']?.toString(),
      json['client_name']?.toString(),
      json['name']?.toString(),
      [json['first_name'], json['last_name']]
          .whereType<String>()
          .where((part) => part.trim().isNotEmpty)
          .join(' ')
          .trim(),
    ];

    final resolvedName = fullNameCandidates.firstWhere(
      (value) => value != null && value.trim().isNotEmpty,
      orElse: () => 'Unnamed',
    )!;

    final unread = json['unread_count'];
    final timestampRaw = json['timestamp'] ?? json['last_message_timestamp'];
    DateTime? parsedTimestamp;
    if (timestampRaw != null) {
      final tsString = timestampRaw.toString();
      parsedTimestamp = DateTime.tryParse(tsString);
    }

    return Chat(
      id: json['id']?.toString() ?? '',
      clientName: resolvedName.trim().isEmpty ? 'Unnamed' : resolvedName.trim(),
      lastMessage: json['last_message']?.toString() ?? json['last_content']?.toString(),
      lastAttachmentName: json['last_file']?.toString(),
      unreadCount: unread is int
          ? unread
          : int.tryParse(unread?.toString() ?? '0') ?? 0,
      timestamp: parsedTimestamp,
      avatarUrl: json['profile_image']?.toString(),
      hasConversation: (json['has_conversation'] as bool?) ?? true,
    );
  }

  factory Chat.directoryEntry(Map<String, dynamic> json) {
    final resolvedName = (json['full_name'] ??
            ((json['first_name'] ?? '') + ' ' + (json['last_name'] ?? '')))
        .toString()
        .trim();

    return Chat(
      id: json['id']?.toString() ?? '',
      clientName: resolvedName.isEmpty ? 'Unnamed' : resolvedName,
      avatarUrl: json['profile_image']?.toString(),
      hasConversation: false,
    );
  }

  Chat copyWith({
    String? clientName,
    String? lastMessage,
    String? lastAttachmentName,
    int? unreadCount,
    DateTime? timestamp,
    String? avatarUrl,
    bool? hasConversation,
  }) {
    return Chat(
      id: id,
      clientName: clientName ?? this.clientName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastAttachmentName: lastAttachmentName ?? this.lastAttachmentName,
      unreadCount: unreadCount ?? this.unreadCount,
      timestamp: timestamp ?? this.timestamp,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasConversation: hasConversation ?? this.hasConversation,
    );
  }
}

class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isRead;
  final String messageType;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.isRead,
    required this.messageType,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      content: json['content'],
      senderId: json['sender'].toString(),
      senderName: json['sender_name'] ?? 'Unknown',
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      messageType: json['message_type'] ?? 'enquiry',
    );
  }
}


