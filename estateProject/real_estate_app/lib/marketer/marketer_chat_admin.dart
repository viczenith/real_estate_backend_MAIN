import 'package:flutter/material.dart';

import '../shared/app_layout.dart';
import '../shared/app_side.dart';
import '../shared/chat/chat_role_configurations.dart';
import '../shared/chat/shared_chat_thread_page.dart';

class MarketerChatAdmin extends StatelessWidget {
  final String token;
  const MarketerChatAdmin({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      token: token,
      side: AppSide.marketer,
      pageTitle: 'Admin Support',
      child: SharedChatThreadPage(
        token: token,
        config: buildMarketerChatConfig(),
      ),
    );
  }
}
