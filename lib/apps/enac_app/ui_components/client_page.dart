// lib/apps/enac_app/ui_components/client_page.dart
import 'package:flutter/material.dart';

class ClientPage extends StatelessWidget {
  final String userId;
  final String clientId;

  const ClientPage({
    super.key,
    required this.userId,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '☕  Dettaglio CLIENTE\n\n'
        'userId  : $userId\n'
        'clientId: $clientId\n\n'
        '(placeholder – contenuto reale in arrivo)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
