// lib/apps/enac_app/ui_components/claim/claim_form_page.dart
import 'dart:async';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';
import 'claim_form_widget.dart';

class CreateClaimPage extends StatefulWidget with ChatBotExtensions {
  const CreateClaimPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.onCancel,
    required this.onCreated,
    this.title = 'Denuncia sinistro',
  });

  final User user;     // username = userId (user.username)
  final Token token;   // auth token
  final Omnia8Sdk sdk;
  final String entityId; // id cliente

  final VoidCallback onCancel;
  final FutureOr<void> Function(String claimId) onCreated;

  final String title;

  // Espone i tool del ClaimFormPane (nuovo schema)
  @override
  List<ToolSpec> get toolSpecs => [ClaimFormPane.fillTool, ClaimFormPane.setTool];

  // “delegate” per widgetBuilders/hostCallbacks
  ClaimFormPane _delegate() =>
      ClaimFormPane(user: user, token: token, sdk: sdk, entityId: entityId);

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders =>
      _delegate().extraWidgetBuilders;

  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate().hostCallbacks;

  @override
  State<CreateClaimPage> createState() => _CreateClaimPageState();
}

class _CreateClaimPageState extends State<CreateClaimPage> {
  static const _kBrandGreen = Color(0xFF00A651);
  static const double _kFormMaxWidth = 600;

  final _paneKey = GlobalKey<ClaimFormPaneState>();
  final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  // Stati ammessi (per validazione opzionale)
  static const _kStatiAmmessi = <String>{
    'Aperto',
    'Chiuso',
    'Senza Seguito',
    'In Valutazione',
  };

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
              child: ClaimFormPane(
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
  /*  Salvataggio (nuovo schema)                                  */
  /*──────────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final pane = _paneKey.currentState;
    if (pane == null) return;

    // Selettore contratto OBBLIGATORIO (primo campo nel form)
    final selectedContractId = pane.selectedContractId;
    if (selectedContractId == null || selectedContractId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un contratto.')),
      );
      return;
    }

    final m = pane.model; // Map<String,String> dal ClaimFormPane (nuovo schema)

    // Minimi obbligatori del nuovo schema
    final requiredFields = {
      'esercizio'       : m['esercizio'] ?? '',
      'numero_sinistro' : m['numero_sinistro'] ?? '',
      'data_accadimento': m['data_accadimento'] ?? '',
    };
    final missing = requiredFields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compila i campi obbligatori: ${missing.join(', ')}'),
        ),
      );
      return;
    }

    final esercizio = _parseInt(m['esercizio'] ?? '');
    final dataAccadimento = _parseDate(m['data_accadimento'] ?? '');
    final dataDenuncia = _parseDate(m['data_denuncia'] ?? '');

    if (esercizio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esercizio non valido. Usa cifre intere.')),
      );
      return;
    }
    if (dataAccadimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data accadimento non valida. Usa gg/mm/aaaa.')));
      return;
    }

    // Stato (se presente) deve essere tra i 4 ammessi
    final stato = (m['stato'] ?? '').trim();
    if (stato.isNotEmpty && !_kStatiAmmessi.contains(stato)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona uno stato valido.')),
      );
      return;
    }

    // utility: null se stringa vuota
    String? nn(String k) {
      final v = (m[k] ?? '').trim();
      return v.isEmpty ? null : v;
    }

    try {
      final sinistro = Sinistro(
        esercizio: esercizio,
        numeroSinistro: (m['numero_sinistro'] ?? '').trim(),
        dataAccadimento: dataAccadimento,           // obbligatoria
        // opzionali denorm/contesto
        numeroContratto: nn('numero_contratto'),
        compagnia: nn('compagnia'),
        rischio: nn('rischio'),
        // evento/descrizione
        descrizioneEvento: nn('descrizione_evento'),
        dataDenuncia: dataDenuncia,
        indirizzoEvento: nn('indirizzo_evento'),
        cap: nn('cap'),
        citta: nn('citta'),
        // economici
        dannoStimato: nn('danno_stimato'),
        importoRiservato: nn('importo_riservato'),
        importoLiquidato: nn('importo_liquidato'),
        // stato
        stato: nn('stato'),
      );

      final userId = widget.user.username;
      final resp = await widget.sdk.createClaim(
        userId,
        widget.entityId,
        selectedContractId,
        sinistro,
      );

      await widget.onCreated(resp.claimId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione sinistro: $e')),
      );
    }
  }
}
