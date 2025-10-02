/* ──────────────────────────────────────────────────────────────────────────
 *  DIALOG “NUOVO TITOLO” — versione Dual-Pane (form + ChatBot)
 *  ▸ Colonna sinistra: form completo del titolo
 *  ▸ Colonna destra  : ChatBot (pre-caricato, di default nascosto)
 *  ▸ Selettore contratto OBBLIGATORIO e DENTRO IL FORM (primo campo)
 *  ▸ Il selettore contratto NON è autocompilabile dai Tool
 * ────────────────────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/dual_pane_wrapper.dart';

import '../logic_components/backend_sdk.dart';
import 'title_form_widget.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

class CreateTitleDialog extends StatefulWidget {
  const CreateTitleDialog({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
  });

  final User user;   // username = userId
  final Token token; // auth token
  final Omnia8Sdk sdk;
  final String entityId; // id cliente

  static Future<bool?> show(
    BuildContext context, {
    required User user,
    required Token token,
    required Omnia8Sdk sdk,
    required String entityId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTitleDialog(
        user: user,
        token: token,
        sdk: sdk,
        entityId: entityId,
      ),
    );
  }

  @override
  State<CreateTitleDialog> createState() => _CreateTitleDialogState();
}

class _CreateTitleDialogState extends State<CreateTitleDialog> {
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;

  final _titlePaneKey = GlobalKey<TitleFormPaneState>();

  /*─────────────────────────────────────────────────────────
   *  Helpers parsing & normalizzazione
   *────────────────────────────────────────────────────────*/
  final DateFormat _fmt = DateFormat('dd/MM/yyyy');

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

  /*─────────────────────────────────────────────────────────
   *  Salvataggio
   *────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final pane = _titlePaneKey.currentState;
    if (pane == null) return;

    final selectedContractId = pane.selectedContractId;
    if (selectedContractId == null || selectedContractId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un contratto.')),
      );
      return;
    }

    final m = pane.model; // Map<String,String>
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
            content:
                Text('Compila i campi obbligatori: ${missing.join(', ')}')),
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
        selectedContractId, // ← scelto dall’utente nel form
        titolo,
      );
      debugPrint('[CreateTitleDialog] creato titleId=${resp.titleId}');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione titolo: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // chat pre-caricata ma chiusa
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          Text('Nuovo titolo',
              style:
                  GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip: _chatOpen ? 'Chiudi chat' : 'Apri chat',
            icon: Icon(
                _chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () {
              setState(() {
                _chatOpen ? _paneCtrl.closeChat() : _paneCtrl.openChat();
                _chatOpen = !_chatOpen;
              });
            },
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 1000,
        height: 640,
        child: DualPaneWrapper(
          controller: _paneCtrl,
          user: widget.user,
          token: widget.token,
          // ⬇️ Il form contiene il selettore contratto come PRIMO campo
          leftChild: TitleFormPane(
            key: _titlePaneKey,
            user: widget.user,
            token: widget.token,
            sdk: widget.sdk,
            entityId: widget.entityId,
          ),
          autoStartMessage:
              "Da ora in poi dovrai aiutarmi con la compilazione dei titoli usando l'apposito Tool UI; rispondi solo 'OK' a questo messaggio iniziale. ",
          autoStartInvisible: false,
          openChatOnMount: false,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        TextButton(onPressed: _onCreatePressed, child: const Text('Crea')),
      ],
    );
  }
}
