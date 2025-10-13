import 'dart:async';
import 'package:boxed_ai/apps/enac_app/ui_components/clients/client_form_widget.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // (non serve, ma lasciato per simmetria col create)

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';

import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';

import 'client_form_page.dart' show ClientFormPane; // riusiamo il form pane

class EditClientPage extends StatefulWidget with ChatBotExtensions {
  const EditClientPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.initialEntity,
    required this.onCancel,
    required this.onUpdated,
    this.title = 'Modifica entità',
  });

  final User user;              // username = userId
  final Token token;            // auth token
  final Omnia8Sdk sdk;

  final String entityId;
  final Entity initialEntity;

  final VoidCallback onCancel;
  final FutureOr<void> Function(String entityId, Entity updated) onUpdated;

  final String title;

  // — ChatBotExtensions: espone i tool del ClientFormPane
  @override
  List<ToolSpec> get toolSpecs => [ClientFormPane.fillTool, ClientFormPane.setTool];

  ClientFormPane _delegate() => const ClientFormPane();

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders =>
      _delegate().extraWidgetBuilders;

  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate().hostCallbacks;

  @override
  State<EditClientPage> createState() => _EditClientPageState();
}

class _EditClientPageState extends State<EditClientPage> {
  static const double _kFormMaxWidth = 600;
  static const _kBrandGreen = Color(0xFF00A651);

  final _paneKey = GlobalKey<ClientFormPaneState>();

  ButtonStyle get _cancelStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );

  ButtonStyle get _saveStyle => ElevatedButton.styleFrom(
        backgroundColor: _kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  String? _nn(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  Map<String, String> _entityToInitialMap(Entity e) => {
        'name'             : e.name,
        'address'          : e.address ?? '',
        'tax_code'         : e.taxCode ?? '',
        'vat'              : e.vat ?? '',
        'phone'            : e.phone ?? '',
        'email'            : e.email ?? '',
        'sector'           : e.sector ?? '',
        'legal_rep'        : e.legalRep ?? '',
        'legal_rep_tax_code': e.legalRepTaxCode ?? '',
      };

  Future<void> _onSavePressed() async {
    final s = _paneKey.currentState;
    if (s == null) return;

    final m = s.model; // Map<String,String>

    if ((m['name'] ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la ragione sociale')),
      );
      return;
    }
    if ((m['email'] ?? '').isNotEmpty && !m['email']!.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email non valida')),
      );
      return;
    }

    final updated = Entity(
      name            : (m['name'] ?? '').trim(),
      address         : _nn(m['address']),
      taxCode         : _nn(m['tax_code']),
      vat             : _nn(m['vat']),
      phone           : _nn(m['phone']),
      email           : _nn(m['email']),
      sector          : _nn(m['sector']),
      legalRep        : _nn(m['legal_rep']),
      legalRepTaxCode : _nn(m['legal_rep_tax_code']),
    );

    try {
      final userId = widget.user.username;
      final res = await widget.sdk.updateEntity(userId, widget.entityId, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entità aggiornata')),
      );
      await widget.onUpdated(widget.entityId, res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore aggiornamento entità: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _entityToInitialMap(widget.initialEntity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER allineato a sinistra (come Create)
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: _cancelStyle,
                    child: const Text('Annulla'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onSavePressed,
                    style: _saveStyle,
                    child: const Text('Salva'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // CONTENUTO: form allineato a sinistra con valori preimpostati
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: ClientFormPane(
                key: _paneKey,
                initialValues: initial, // ⬅️ prefill
              ),
            ),
          ),
        ),
      ],
    );
  }
}
