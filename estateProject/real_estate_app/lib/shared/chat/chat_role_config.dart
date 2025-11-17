import 'package:flutter/material.dart';

/// High-level roles that the shared chat interface can serve.
///
/// * [ChatRole.client] — end users chatting with administrators.
/// * [ChatRole.marketer] — marketers chatting with administrators.
/// * [ChatRole.adminSupport] — admin/support staff chatting with clients or marketers.
enum ChatRole {
  client,
  marketer,
  adminSupport,
}

typedef ChatHeaderBuilder = PreferredSizeWidget? Function(
  BuildContext context,
  ChatParticipantContext? participant,
);

typedef ChatBodyPaddingBuilder = EdgeInsets Function(BuildContext context);

/// Runtime context about the current chat participant (beyond the signed-in user).
///
/// Admin/support conversations are participant-centric, while client/marketer
/// chats are between the signed-in user and support. The shared widget receives
/// this structure so it can render titles, avatars, and pass identifiers to the
/// backend when required.
class ChatParticipantContext {
  const ChatParticipantContext({
    this.id,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.role,
  });

  final String? id;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final String? role;

  ChatParticipantContext copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? role,
  }) {
    return ChatParticipantContext(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }
}

/// Lightweight descriptor used by each role to customise the shared chat
/// implementation. Each role provides the actions required to talk to the
/// backend plus any UI overrides (header widgets, colours, etc.).
class ChatRoleConfig {
  const ChatRoleConfig({
    required this.role,
    required this.downloadNamespaceBuilder,
    required this.pushChannelMatcher,
    required this.headerBuilder,
    required this.messageAvatarBuilder,
    required this.isOwnMessage,
    required this.normalizeBackendMessage,
    required this.loadInitialMessages,
    required this.pollForMessages,
    required this.sendMessage,
    required this.deleteMessage,
    required this.markMessagesAsRead,
    this.loadCurrentUserAvatar,
    this.bodyPaddingBuilder,
  });

  final ChatRole role;

  final String Function(ChatParticipantContext? participant)
      downloadNamespaceBuilder;

  final bool Function(Map<String, dynamic> payload) pushChannelMatcher;

  final ChatHeaderBuilder headerBuilder;

  final ChatBodyPaddingBuilder? bodyPaddingBuilder;

  final String? Function(Map<String, dynamic> message, String? currentUserAvatar)
      messageAvatarBuilder;

  final bool Function(Map<String, dynamic> message) isOwnMessage;

  final Map<String, dynamic> Function(Map<String, dynamic> message)
      normalizeBackendMessage;


  final Future<ChatThreadLoadResult> Function({
    required String token,
    required ChatParticipantContext? participant,
    required int? lastMessageId,
  }) loadInitialMessages;

  /// Polls the backend for messages after [lastMessageId].
  final Future<ChatPollResult> Function({
    required String token,
    required ChatParticipantContext? participant,
    required int lastMessageId,
  }) pollForMessages;

  /// Sends a message (optional text + optional file).
  final Future<ChatSendResult> Function({
    required String token,
    required ChatParticipantContext? participant,
    required String? content,
    required String? messageType,
    required String? replyToMessageId,
    required Object? attachment,
  }) sendMessage;

  /// Deletes (or marks as deleted) the given message ID.
  final Future<Map<String, dynamic>> Function({
    required String token,
    required int messageId,
    required ChatParticipantContext? participant,
  }) deleteMessage;

  /// Marks messages as read. Roles can choose to mark all or specific IDs using
  /// the provided information.
  final Future<void> Function({
    required String token,
    required List<int>? messageIds,
    required ChatParticipantContext? participant,
  }) markMessagesAsRead;

  /// Optionally load the signed-in user's avatar so outgoing bubbles can render
  /// the correct profile image. When `null`, the shared widget falls back to a
  /// default glyph.
  final Future<String?> Function({
    required String token,
    required ChatParticipantContext? participant,
  })? loadCurrentUserAvatar;
}

/// Result container for [ChatRoleConfig.loadInitialMessages].
class ChatThreadLoadResult {
  const ChatThreadLoadResult({
    required this.messages,
    this.participant,
    this.lastMessageId,
  });

  final List<Map<String, dynamic>> messages;
  final ChatParticipantContext? participant;
  final int? lastMessageId;
}

/// Result container for [ChatRoleConfig.pollForMessages].
class ChatPollResult {
  const ChatPollResult({
    required this.newMessages,
    required this.lastMessageId,
  });

  final List<Map<String, dynamic>> newMessages;
  final int lastMessageId;
}

/// Result container for [ChatRoleConfig.sendMessage].
class ChatSendResult {
  const ChatSendResult({
    required this.message,
    this.lastMessageId,
  });

  final Map<String, dynamic> message;
  final int? lastMessageId;
}
