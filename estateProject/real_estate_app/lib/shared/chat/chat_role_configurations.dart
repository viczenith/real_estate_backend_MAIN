import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/navigation_service.dart';
import 'chat_role_config.dart';

const _headerHeight = kToolbarHeight + 8;

PreferredSizeWidget _buildDefaultHeader(
  BuildContext context,
  String title,
  String subtitle,
  String? avatarUrl,
) {
  final theme = Theme.of(context);
  ImageProvider? avatarImage;
  if (avatarUrl?.isNotEmpty == true) {
    if (avatarUrl!.startsWith('asset://')) {
      avatarImage = AssetImage(avatarUrl.substring('asset://'.length));
    } else {
      avatarImage = NetworkImage(avatarUrl);
    }
  }
  return PreferredSize(
    preferredSize: const Size.fromHeight(_headerHeight),
    child: AppBar(
      elevation: 2,
      shadowColor: Colors.black12,
      backgroundColor: Colors.white,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF128C7E)),
        onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
            return;
          }

          final rootNavigator = Navigator.of(context, rootNavigator: true);
          if (rootNavigator.canPop()) {
            rootNavigator.pop();
            return;
          }

          final globalNavigator = NavigationService.navigator;
          if (globalNavigator?.canPop() ?? false) {
            globalNavigator!.pop();
            return;
          }
        },
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: avatarImage,
            child: avatarImage != null
                ? null
                : const Icon(Icons.support_agent_rounded,
                    color: Color(0xFF128C7E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF303030),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

PushNotificationService get _pushService => PushNotificationService();

final ApiService _api = ApiService();
final ApiService _supportProfileApi = ApiService();

ChatRoleConfig buildClientChatConfig() {
  String? marketerOrAdminAvatar(Map<String, dynamic> message, String? current) {
    if (message['is_sender'] == true) {
      return current;
    }
    final otherAvatar = message['sender_avatar']?.toString();
    if (otherAvatar != null && otherAvatar.isNotEmpty) {
      return otherAvatar;
    }
    return 'asset://assets/logo.png';
  }

  return ChatRoleConfig(
    role: ChatRole.client,
    downloadNamespaceBuilder: (_) => 'client_chat',
    pushChannelMatcher: (payload) {
      final data = payload['data'] as Map<String, dynamic>?;
      final type = payload['type']?.toString().toLowerCase() ??
          data?['type']?.toString().toLowerCase() ?? '';
      final chatId = data?['chat_id']?.toString() ?? '';
      return type.contains('chat') &&
          (chatId == 'admin_chat' || chatId.isEmpty);
    },
    headerBuilder: (context, participant) {
      return _buildDefaultHeader(
        context,
        'Admin Support',
        'Chat with me for enquiry and assistance',
        'asset://assets/logo.png',
      );
    },
    messageAvatarBuilder: marketerOrAdminAvatar,
    isOwnMessage: (msg) => msg['is_sender'] == true,
    normalizeBackendMessage: (message) {
      final normalized = Map<String, dynamic>.from(message);
      normalized['id'] = normalized['id'] ?? normalized['message_id'];
      normalized['file_url'] = normalized['file_url'];
      return normalized;
    },
    loadInitialMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int? lastMessageId,
    }) async {
      final data = await _api.getClientChatMessages(token: token);
      final messages = (data['messages'] ?? data['results'] ?? [])
          .cast<Map<String, dynamic>>();
      return ChatThreadLoadResult(
        messages: messages,
        lastMessageId: messages.isNotEmpty ? messages.last['id'] as int? : null,
      );
    },
    pollForMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int lastMessageId,
    }) async {
      final result = await _api.pollClientChatMessages(
        token: token,
        lastMsgId: lastMessageId,
      );
      final newMessages =
          (result['new_messages'] ?? result['messages'] ?? [])
              .cast<Map<String, dynamic>>();
      return ChatPollResult(
        newMessages: newMessages,
        lastMessageId: result['last_message_id'] as int? ?? lastMessageId,
      );
    },
    sendMessage: ({
      required String token,
      required ChatParticipantContext? participant,
      required String? content,
      required String? messageType,
      required String? replyToMessageId,
      required Object? attachment,
    }) async {
      final File? file = attachment is File ? attachment : null;
      final data = await _api.sendClientChatMessage(
        token: token,
        content: content,
        file: file,
        replyToId: replyToMessageId != null
            ? int.tryParse(replyToMessageId)
            : null,
        messageType: messageType ?? 'enquiry',
      );
      final message = data['message'] as Map<String, dynamic>;
      return ChatSendResult(
        message: message,
        lastMessageId: message['id'] as int?,
      );
    },
    deleteMessage: ({
      required String token,
      required int messageId,
      required ChatParticipantContext? participant,
    }) async {
      final success = await _api.deleteClientChatMessage(
        token: token,
        messageId: messageId,
      );
      if (!success) {
        throw Exception('Failed to delete client message');
      }
      return {
        'id': messageId,
        'content': '🚫 This message was deleted',
        '_deleted_for_everyone': true,
      };
    },
    markMessagesAsRead: ({
      required String token,
      required List<int>? messageIds,
      required ChatParticipantContext? participant,
    }) async {
      await _api.markClientChatMessagesAsRead(
        token: token,
        messageIds: messageIds,
        markAll: messageIds == null,
      );
    },
    loadCurrentUserAvatar: ({
      required String token,
      required ChatParticipantContext? participant,
    }) async {
      final profile = await _api.getClientProfile(token: token);
      final image = profile['profile_image']?.toString();
      return image?.isNotEmpty == true ? image : null;
    },
  );
}

ChatRoleConfig buildMarketerChatConfig() {
  String? marketerAvatar(Map<String, dynamic> message, String? current) {
    if (message['is_sender'] == true) return current;
    final otherAvatar = message['sender_avatar']?.toString();
    if (otherAvatar != null && otherAvatar.isNotEmpty) {
      return otherAvatar;
    }
    return 'asset://assets/logo.png';
  }

  return ChatRoleConfig(
    role: ChatRole.marketer,
    downloadNamespaceBuilder: (_) => 'marketer_chat',
    pushChannelMatcher: (payload) {
      final data = payload['data'] as Map<String, dynamic>?;
      final type = payload?['type']?.toString().toLowerCase() ??
          data?['type']?.toString().toLowerCase() ?? '';
      final chatId = data?['chat_id']?.toString().toLowerCase() ?? '';
      return type.contains('chat') &&
          (chatId == 'marketer_chat' || chatId.startsWith('marketer_chat_'));
    },
    headerBuilder: (context, participant) {
      return _buildDefaultHeader(
        context,
        'Admin Support',
        'Chat with me for enquiry and assistance',
        'asset://assets/logo.png',
      );
    },
    messageAvatarBuilder: marketerAvatar,
    isOwnMessage: (msg) => msg['is_sender'] == true,
    normalizeBackendMessage: (message) {
      final normalized = Map<String, dynamic>.from(message);
      normalized['id'] = normalized['id'] ?? normalized['message_id'];
      return normalized;
    },
    loadInitialMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int? lastMessageId,
    }) async {
      final data = await _api.getMarketerChatMessages(token: token);
      final messages = (data['messages'] ?? data['results'] ?? [])
          .cast<Map<String, dynamic>>();
      return ChatThreadLoadResult(
        messages: messages,
        lastMessageId: messages.isNotEmpty ? messages.last['id'] as int? : null,
      );
    },
    pollForMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int lastMessageId,
    }) async {
      final result = await _api.pollMarketerChatMessages(
        token: token,
        lastMsgId: lastMessageId,
      );
      final newMessages =
          (result['new_messages'] ?? result['messages'] ?? [])
              .cast<Map<String, dynamic>>();
      return ChatPollResult(
        newMessages: newMessages,
        lastMessageId: result['last_message_id'] as int? ?? lastMessageId,
      );
    },
    sendMessage: ({
      required String token,
      required ChatParticipantContext? participant,
      required String? content,
      required String? messageType,
      required String? replyToMessageId,
      required Object? attachment,
    }) async {
      final PlatformFile? file;
      if (attachment is File) {
        file = PlatformFile(name: p.basename(attachment.path), path: attachment.path, size: attachment.lengthSync());
      } else if (attachment is PlatformFile) {
        file = attachment;
      } else {
        file = null;
      }
      final data = await _api.sendMarketerChatMessage(
        token: token,
        content: content,
        file: file,
        replyToId:
            replyToMessageId != null ? int.tryParse(replyToMessageId) : null,
        messageType: messageType ?? 'enquiry',
      );
      final message = data['message'] as Map<String, dynamic>;
      return ChatSendResult(
        message: message,
        lastMessageId: message['id'] as int?,
      );
    },
    deleteMessage: ({
      required String token,
      required int messageId,
      required ChatParticipantContext? participant,
    }) async {
      final response = await _api.deleteMarketerChatMessage(
        token: token,
        messageId: messageId,
      );

      final normalized = Map<String, dynamic>.from(response['message'] as Map);
      normalized['id'] = normalized['id'] ?? normalized['message_id'] ?? messageId;
      normalized['_deleted_for_everyone'] = true;
      return normalized;
    },
    markMessagesAsRead: ({
      required String token,
      required List<int>? messageIds,
      required ChatParticipantContext? participant,
    }) async {
      await _api.markMarketerChatMessagesAsRead(
        token: token,
        messageIds: messageIds,
        markAll: messageIds == null,
      );
    },
    loadCurrentUserAvatar: ({
      required String token,
      required ChatParticipantContext? participant,
    }) async {
      final profile = await _api.getMarketerProfileByToken(token: token);
      final image = profile['profile_image']?.toString();
      return image?.isNotEmpty == true ? image : null;
    },
  );
}

ChatRoleConfig buildSupportChatConfig(String participantRole, String participantId) {
  String namesFromParticipant(ChatParticipantContext? ctx) {
    if (ctx == null) return 'Conversation';
    return ctx.displayName ?? ctx.email ?? 'Conversation';
  }

  String? supportAvatar(Map<String, dynamic> message, String? current) {
    if (message['is_support_sender'] == true) {
      return current ?? 'asset://assets/logo.png';
    }
    final otherAvatar = message['sender_avatar']?.toString();
    if (otherAvatar != null && otherAvatar.isNotEmpty) {
      return otherAvatar;
    }
    return null;
  }

  return ChatRoleConfig(
    role: ChatRole.adminSupport,
    downloadNamespaceBuilder: (participant) {
      final id = participant?.id ?? participantId;
      final role = participant?.role ?? participantRole;
      return 'support_chat_${role}_$id';
    },
    pushChannelMatcher: (payload) {
      final data = payload['data'] as Map<String, dynamic>?;
      final chatId = data?['chat_id']?.toString() ?? '';
      final type = payload['type']?.toString().toLowerCase() ??
          data?['type']?.toString().toLowerCase() ?? '';
      if (!type.contains('chat')) return false;
      if (chatId.isEmpty) return false;
      if (participantRole == 'client') {
        return chatId == 'admin_chat' || chatId == 'client_chat';
      }
      return chatId.startsWith('marketer_chat_') || chatId == 'marketer_chat';
    },
    headerBuilder: (context, participant) {
      final title = namesFromParticipant(participant);
      return _buildDefaultHeader(
        context,
        title,
        participant?.role == 'client'
            ? 'Client conversation'
            : 'Marketer conversation',
        'asset://assets/logo.png',
      );
    },
    messageAvatarBuilder: supportAvatar,
    isOwnMessage: (msg) => msg['is_support_sender'] == true,
    normalizeBackendMessage: (message) {
      final normalized = Map<String, dynamic>.from(message);
      normalized['id'] = normalized['id'] ?? normalized['message_id'];
      normalized['_deleted_for_everyone'] =
          normalized['deleted_for_everyone'] == true;
      return normalized;
    },
    loadInitialMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int? lastMessageId,
    }) async {
      final response = await _api.fetchSupportChatThread(
        token: token,
        role: participantRole,
        participantId: participantId,
        lastMessageId: lastMessageId,
      );
      final messages =
          (response['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      final participantData =
          response['participant'] as Map<String, dynamic>? ?? const {};
      final context = ChatParticipantContext(
        id: participantId,
        displayName: participantData['name']?.toString(),
        email: participantData['email']?.toString(),
        avatarUrl: participantData['avatar']?.toString(),
        role: participantRole,
      );
      final lastId = messages.isNotEmpty ? messages.last['id'] as int? : null;
      return ChatThreadLoadResult(
        messages: messages,
        participant: context,
        lastMessageId: lastId,
      );
    },
    pollForMessages: ({
      required String token,
      required ChatParticipantContext? participant,
      required int lastMessageId,
    }) async {
      final response = await _api.pollSupportChat(
        token: token,
        role: participantRole,
        participantId: participantId,
        lastMessageId: lastMessageId,
      );
      final newMessages =
          (response['new_messages'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      return ChatPollResult(
        newMessages: newMessages,
        lastMessageId:
            response['last_message_id'] as int? ?? lastMessageId,
      );
    },
    sendMessage: ({
      required String token,
      required ChatParticipantContext? participant,
      required String? content,
      required String? messageType,
      required String? replyToMessageId,
      required Object? attachment,
    }) async {
      final File? file = attachment is File ? attachment : null;
      final response = await _api.sendSupportChatMessage(
        token: token,
        role: participantRole,
        participantId: participantId,
        content: content,
        file: file,
        messageType: messageType ?? 'enquiry',
        replyToId:
            replyToMessageId != null ? int.tryParse(replyToMessageId) : null,
      );
      final message = response['message'] as Map<String, dynamic>;
      return ChatSendResult(
        message: message,
        lastMessageId: message['id'] as int?,
      );
    },
    deleteMessage: ({
      required String token,
      required int messageId,
      required ChatParticipantContext? participant,
    }) async {
      final response = await _api.deleteSupportMessage(
        token: token,
        messageId: messageId,
      );
      return response['message'] as Map<String, dynamic>;
    },
    markMessagesAsRead: ({
      required String token,
      required List<int>? messageIds,
      required ChatParticipantContext? participant,
    }) async {
      await _api.markSupportMessagesRead(
        token: token,
        role: participantRole,
        participantId: participantId,
        messageIds: messageIds,
        markAll: messageIds == null,
      );
    },
    loadCurrentUserAvatar: ({
      required String token,
      required ChatParticipantContext? participant,
    }) async {
      return 'asset://assets/logo.png';
    },
  );
}
