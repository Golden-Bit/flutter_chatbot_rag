import 'package:flutter/material.dart';

import 'admin_console_access_view.dart';
import 'admin_console_controller.dart';
import 'admin_console_shell.dart';
import 'admin_console_storage.dart';

/// Entry point della Admin Console.
///
/// - Non usa JWT utente.
/// - Richiede Admin Token (X-API-Key) inserito nella schermata di accesso.
class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  late final AdminConsoleController _controller;

  @override
  void initState() {
    super.initState();
    final settings = AdminConsoleStorage.load();
    _controller = AdminConsoleController(settings);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.unlocked) {
          return AdminConsoleAccessView(controller: _controller);
        }
        return AdminConsoleShell(controller: _controller);
      },
    );
  }
}
