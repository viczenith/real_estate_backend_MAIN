import 'package:flutter/material.dart';

import '../shared/chat/chat_role_config.dart';
import '../shared/chat/chat_role_configurations.dart';
import '../shared/chat/shared_chat_thread_page.dart';
import 'admin_support_layout.dart';

class AdminSupportChatThreadPage extends StatelessWidget {
  const AdminSupportChatThreadPage({
    super.key,
    required this.token,
    required this.role,
    required this.participantId,
    this.participantName,
    this.participantEmail,
    this.participantAvatar,
  });

  final String token;
  final String role;
  final String participantId;
  final String? participantName;
  final String? participantEmail;
  final String? participantAvatar;

  @override
  Widget build(BuildContext context) {
    final initialParticipant = ChatParticipantContext(
      id: participantId,
      displayName: participantName,
      email: participantEmail,
      avatarUrl: participantAvatar,
      role: role,
    );

    final pageTitle = role.toLowerCase() == 'marketer'
        ? 'Marketer Conversation'
        : 'Client Conversation';

    return AdminSupportLayout(
      token: token,
      pageTitle: pageTitle,
      child: SharedChatThreadPage(
        token: token,
        participant: initialParticipant,
        config: buildSupportChatConfig(role, participantId),
      ),
    );
  }
}
