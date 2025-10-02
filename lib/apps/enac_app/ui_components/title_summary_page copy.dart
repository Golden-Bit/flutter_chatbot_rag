import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../logic_components/backend_sdk.dart';

/// ───────────────────────────────────────────────────────────────
/// Utils: date & money (fix ×100)
/// ───────────────────────────────────────────────────────────────
final _dateFmt = DateFormat('dd/MM/yyyy');
final _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String _fmtDate(DateTime? dt) => (dt == null) ? '—' : _dateFmt.format(dt);

double? _parseMoney(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s0 = v.toString().trim();
  if (s0.isEmpty) return null;

  if (s0.contains(',') && s0.contains('.')) {
    final lastDot = s0.lastIndexOf('.');
    final lastComma = s0.lastIndexOf(',');
    if (lastDot > lastComma) {
      final norm = s0.replaceAll(',', '');
      return double.tryParse(norm);
    } else {
      final norm = s0.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(norm);
    }
  }
  if (s0.contains(',') && !s0.contains('.')) {
    return double.tryParse(s0.replaceAll(',', '.'));
  }
  return double.tryParse(s0);
}

String _fmtMoney(dynamic v) {
  final parsed = _parseMoney(v);
  if (parsed == null) return '—';
  return _currencyFmt.format(parsed);
}

/// ───────────────────────────────────────────────────────────────
/// Base widgets (KV + grid)
/// ───────────────────────────────────────────────────────────────
class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.3)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.rows, super.key});
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final colW = math.max(180.0, (c.maxWidth - 24) / 2); // 2 colonne
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/// ───────────────────────────────────────────────────────────────
/// SUMMARY TITOLO (con Dual-Pane Chat a destra)
/// Solo i campi richiesti dal brief (come nell’immagine): 
///  COMPAGNIA, NUM CONTRATTO, RISCHIO, SCADENZA TITOLO, STATO, PV, PV2, PREMIO
/// ───────────────────────────────────────────────────────────────
class TitleSummaryPage extends StatefulWidget {
  const TitleSummaryPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.titolo,
    required this.viewRow,
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final String entityId;

  /// Dato del titolo (pieno o ricostruito da viewRow)
  final Titolo titolo;

  /// Riga della view (denormalizzata) usata per mostrare campi extra
  final Map<String, dynamic> viewRow;

  /// Helper per ricostruire un Titolo minimale dalla view (se manca l’oggetto pieno)
  static Titolo titleFromViewRow(Map<String, dynamic> v) {
    DateTime _d(String k1, [String? k2]) {
      final raw = (v[k1] ?? (k2 != null ? v[k2] : null))?.toString();
      if (raw == null || raw.isEmpty) return DateTime.now();
      try { return DateTime.parse(raw); } catch (_) { return DateTime.now(); }
    }

    String _s(String k1, [String? k2, String def = '']) {
      return (v[k1] ?? (k2 != null ? v[k2] : null) ?? def).toString();
    }

    int _i(String k1, [String? k2]) {
      final s = (v[k1] ?? (k2 != null ? v[k2] : null))?.toString();
      return int.tryParse(s ?? '') ?? 0;
    }

    return Titolo(
      tipo: _s('tipo', 'Tipo', 'RATA'),
      effettoTitolo: _d('effetto_titolo', 'EffettoTitolo'),
      scadenzaTitolo: _d('scadenza_titolo', 'ScadenzaTitolo'),
      descrizione: _s('descrizione', 'Descrizione', ''),
      progressivo: _s('progressivo', 'Progressivo', ''),
      stato: _s('stato', 'Stato', 'DA_PAGARE'),
      imponibile: _s('imponibile', 'Imponibile', '0.00'),
      premioLordo: _s('premio_lordo', 'PremioLordo', '0.00'),
      imposte: _s('imposte', 'Imposte', '0.00'),
      accessori: _s('accessori', 'Accessori', '0.00'),
      diritti: _s('diritti', 'Diritti', '0.00'),
      spese: _s('spese', 'Spese', '0.00'),
      frazionamento: _s('frazionamento', 'Frazionamento', 'ANNUALE'),
      giorniMora: _i('giorni_mora', 'GiorniMora'),
      cig: _s('cig', 'CIG', null ?? ''),
      pv: _s('pv', 'PV', null ?? ''),
      pv2: _s('pv2', 'PV2', null ?? ''),
      quietanzaNumero: _s('quietanza_numero', 'QuietanzaNumero', ''),
      dataPagamento: (() {
        final raw = (v['data_pagamento'] ?? v['DataPagamento'])?.toString();
        if (raw == null || raw.isEmpty) return null;
        try { return DateTime.parse(raw); } catch (_) { return null; }
      })(),
      metodoIncasso: _s('metodo_incasso', 'MetodoIncasso', ''),
      numeroPolizza: _s('numero_polizza', 'NumeroPolizza', ''),
      entityId: _s('entity_id', 'EntityId', ''),
    );
  }

  @override
  State<TitleSummaryPage> createState() => _TitleSummaryPageState();
}

class _TitleSummaryPageState extends State<TitleSummaryPage> {
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  Widget _header() {
    final compagnia = (widget.viewRow['compagnia'] ?? widget.viewRow['Compagnia'] ?? '').toString();
    final numeroPolizza = (widget.viewRow['numero_polizza'] ??
            widget.viewRow['NumeroPolizza'] ??
            widget.titolo.numeroPolizza ??
            '')
        .toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7E6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // placeholder logo
          Container(
            width: 56,
            height: 56,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          // titolo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A651),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('TITOLO',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    compagnia.isEmpty ? numeroPolizza : '$compagnia – $numeroPolizza',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Color(0xFF0082C8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // toggle chat
          IconButton(
            tooltip: _chatOpen ? 'Chiudi chat' : 'Apri chat',
            icon: Icon(_chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () {
              setState(() {
                _chatOpen ? _paneCtrl.closeChat() : _paneCtrl.openChat();
                _chatOpen = !_chatOpen;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Sezione "Summary" ristretta ai campi richiesti
  Widget _summaryCard() {
    final v = widget.viewRow;
    String _s(String a, [String? b]) =>
        (v[a] ?? (b != null ? v[b] : null) ?? '').toString();

    final compagnia = _s('compagnia', 'Compagnia');
    final numeroPolizza = _s('numero_polizza', 'NumeroPolizza');
    final rischio = _s('rischio', 'Rischio');
    final scadenza = v['scadenza_titolo'] ?? v['ScadenzaTitolo'] ?? widget.titolo.scadenzaTitolo;
    final stato = _s('stato', 'Stato');
    final pv = _s('pv', 'PV');
    final pv2 = _s('pv2', 'PV2');
    final premio = _s('premio_lordo', 'PremioLordo');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _SectionGrid(rows: [
            _KV('Compagnia', compagnia),
            _KV('Numero Contratto', numeroPolizza),
            _KV('Rischio', rischio),
            _KV('Scadenza Titolo', scadenza is DateTime ? _fmtDate(scadenza) : scadenza.toString().isEmpty ? '—' : _fmtDate(DateTime.tryParse(scadenza.toString()))),
            _KV('Stato', stato),
            _KV('P.V', pv),
            _KV('P.V 2', pv2),
            _KV('Premio', _fmtMoney(premio.isEmpty ? widget.titolo.premioLordo : premio)),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DualPaneWrapper(
        controller: _paneCtrl,
        user: widget.user,
        token: widget.token,
        leftChild: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            _summaryCard(),
          ],
        ),
        // Chat pre-caricata, ma chiusa (come da linea guida)
        autoStartMessage:
            "Da ora in poi aiutami a verificare i dati dei TITOLI. Quando te lo chiederò, usa l'apposito Tool UI che ti fornirò in seguito. Rispondi solo 'OK' a questo messaggio.",
        autoStartInvisible: false,
        openChatOnMount: false,
      ),
    );
  }
}
