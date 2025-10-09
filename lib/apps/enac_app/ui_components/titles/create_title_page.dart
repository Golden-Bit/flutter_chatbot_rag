// lib/apps/enac_app/ui_components/titles/title_form_page.dart
import 'dart:async';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';
import 'title_form_widget.dart';

class CreateTitlePage extends StatefulWidget with ChatBotExtensions {
  const CreateTitlePage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.onCancel,
    required this.onCreated,
    this.title = 'Nuovo titolo',
  });

  final User user;           // username = userId (user.username)
  final Token token;         // auth token
  final Omnia8Sdk sdk;
  final String entityId;     // id cliente

  final VoidCallback onCancel;
  final FutureOr<void> Function(String titleId) onCreated;

  final String title;

  // ── ChatBotExtensions: ri-esponiamo i tool del TitleFormPane ──
  @override
  List<ToolSpec> get toolSpecs => [TitleFormPane.fillTool, TitleFormPane.setTool];

  // Usiamo un'istanza “di servizio” del pane solo per esporre builders/hostCallbacks
  TitleFormPane _delegate() =>
      TitleFormPane(user: user, token: token, sdk: sdk, entityId: entityId);

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders =>
      _delegate().extraWidgetBuilders;

  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate().hostCallbacks;

  @override
  State<CreateTitlePage> createState() => _CreateTitlePageState();
}

class _CreateTitlePageState extends State<CreateTitlePage> {
  static const _kBrandGreen = Color(0xFF00A651);
  static const double _kFormMaxWidth = 600;

  final _paneKey = GlobalKey<TitleFormPaneState>();
  final DateFormat _fmt = DateFormat('dd/MM/yyyy');

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

  // Helpers parsing
  DateTime? _parseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    try {
      return _fmt.parseStrict(t);
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String _moneyStr(String s) {
    final t = s.trim();
    if (t.isEmpty) return '0.00';
    final v = double.tryParse(t.replaceAll('.', '').replaceAll(',', '.')) ??
        double.tryParse(t) ??
        0.0;
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────────── HEADER allineato come il form ─────────────
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
                    onPressed: _onCreatePressed,
                    style: _saveStyle,
                    child: const Text('Crea'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ───────────── CONTENUTO: form allineato a sinistra ─────────────
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: TitleFormPane(
                key: _paneKey,
                user: widget.user,
                token: widget.token,
                sdk: widget.sdk,
                entityId: widget.entityId,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /*──────────────────────────────────────────────────────────────*/
  /*  Salvataggio                                                 */
  /*──────────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final pane = _paneKey.currentState;
    if (pane == null) return;

    // Selettore contratto OBBLIGATORIO (scelto manualmente nel form)
    final selectedContractId = pane.selectedContractId;
    if (selectedContractId == null || selectedContractId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un contratto.')),
      );
      return;
    }

    final m = pane.model; // Map<String,String>

    // Minimi obbligatori
    final requiredFields = {
      'tipo': m['tipo'] ?? '',
      'effetto_titolo': m['effetto_titolo'] ?? '',
      'scadenza_titolo': m['scadenza_titolo'] ?? '',
    };
    final missing = requiredFields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Compila i campi obbligatori: ${missing.join(', ')}'),
        ),
      );
      return;
    }

    final effetto = _parseDate(m['effetto_titolo'] ?? '');
    final scadenza = _parseDate(m['scadenza_titolo'] ?? '');
    if (effetto == null || scadenza == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Date non valide. Usa il formato gg/mm/aaaa per effetto/scadenza.')));
      return;
    }

    String? nn(String k) {
      final v = (m[k] ?? '').trim();
      return v.isEmpty ? null : v;
    }

    final titolo = Titolo(
      tipo: (m['tipo'] ?? '').trim(),
      effettoTitolo: effetto,
      scadenzaTitolo: scadenza,
      descrizione: nn('descrizione'),
      progressivo: nn('progressivo'),
      stato: (m['stato']?.trim().isEmpty ?? true)
          ? 'DA_PAGARE'
          : (m['stato']!.trim()),
      imponibile: _moneyStr(m['imponibile'] ?? ''),
      premioLordo: _moneyStr(m['premio_lordo'] ?? ''),
      imposte: _moneyStr(m['imposte'] ?? ''),
      accessori: _moneyStr(m['accessori'] ?? ''),
      diritti: _moneyStr(m['diritti'] ?? ''),
      spese: _moneyStr(m['spese'] ?? ''),
      frazionamento: (m['frazionamento']?.trim().isEmpty ?? true)
          ? 'ANNUALE'
          : m['frazionamento']!.trim().toUpperCase(),
      giorniMora: _parseInt(m['giorni_mora'] ?? '') ?? 0,
      cig: nn('cig'),
      pv: nn('pv'),
      pv2: nn('pv2'),
      quietanzaNumero: nn('quietanza_numero'),
      dataPagamento: _parseDate(m['data_pagamento'] ?? ''),
      metodoIncasso: nn('metodo_incasso'),
      numeroPolizza: nn('numero_polizza'),
    );

    try {
      final userId = widget.user.username;
      final resp = await widget.sdk.createTitle(
        userId,
        widget.entityId,
        selectedContractId,
        titolo,
      );
      await widget.onCreated(resp.titleId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione titolo: $e')),
      );
    }
  }
}
