// lib/demo/chatpanel_demo_page.dart
import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'client_form_panel.dart';

class ChatPanelDemoPage extends StatelessWidget {
  const ChatPanelDemoPage({super.key, required this.user, required this.token});
  final User user;
  final Token token;

  @override
  Widget build(BuildContext context) {
    final ctrl = DualPaneController();
    // Apri la chat dopo il primo frame, così si vede subito
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.openChat());

    return DualPaneWrapper(
      controller: ctrl,
      user: user,
      token: token,
      leftChild: ClientFormPanel(), // ⬅️ implementa ChatBotExtensions
    );
  }
}
