import 'dart:async';
import 'package:flutter/material.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';
import 'claim_form_widget.dart';

class EditClaimPage extends StatefulWidget with ChatBotExtensions {
  const EditClaimPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.contractId,
    required this.claimId,
    required this.initialClaim,
    required this.onCancel,
    required this.onUpdated,
    this.title = 'Modifica sinistro',
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;

  final String entityId;
  final String contractId;
  final String claimId;
  final Sinistro initialClaim;

  final VoidCallback onCancel;
  final FutureOr<void> Function(String claimId, Sinistro updated) onUpdated;

  final String title;

  // tool del ClaimFormPane (come nel Create)
  @override
  List<ToolSpec> get toolSpecs => [ClaimFormPane.fillTool, ClaimFormPane.setTool];

  ClaimFormPane _delegate() => ClaimFormPane(
        user: user, token: token, sdk: sdk, entityId: entityId);

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders =>
      _delegate().extraWidgetBuilders;

  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate().hostCallbacks;

  @override
  State<EditClaimPage> createState() => _EditClaimPageState();
}

class _EditClaimPageState extends State<EditClaimPage> {
  static const double _kFormMaxWidth = 720;
  static const _kBrandGreen = Color(0xFF00A651);

  final _paneKey = GlobalKey<ClaimFormPaneState>();

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

  // mapping Sinistro -> initialValues del form
  Map<String, String> _claimToInitialMap(Sinistro s) {
    String _fmt(DateTime? d) =>
        (d == null) ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return {
      'esercizio'                : s.esercizio.toString(),
      'numero_sinistro'          : s.numeroSinistro,
      'numero_sinistro_compagnia': s.numeroSinistroCompagnia ?? '',
      'numero_polizza'           : s.numeroPolizza ?? '',
      'compagnia'                : s.compagnia ?? '',
      'rischio'                  : s.rischio ?? '',
      'intermediario'            : s.intermediario ?? '',
      'descrizione_assicurato'   : s.descrizioneAssicurato ?? '',
      'data_avvenimento'         : _fmt(s.dataAvvenimento),
      'citta'                    : s.citta ?? '',
      'indirizzo'                : s.indirizzo ?? '',
      'cap'                      : s.cap ?? '',
      'provincia'                : s.provincia ?? '',
      'codice_stato'             : s.codiceStato ?? '',
      'targa'                    : s.targa ?? '',
      'dinamica'                 : s.dinamica ?? '',
      'stato_compagnia'          : s.statoCompagnia ?? '',
      'data_apertura'            : _fmt(s.dataApertura),
      'data_chiusura'            : _fmt(s.dataChiusura),
    };
  }

  DateTime? _parseIt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    // dd/MM/yyyy
    final p = t.split('/');
    if (p.length == 3) {
      try {
        final d = int.parse(p[0]), m = int.parse(p[1]), y = int.parse(p[2]);
        return DateTime(y, m, d);
      } catch (_) {}
    }
    // fallback ISO
    try { return DateTime.parse(t); } catch (_) { return null; }
  }

  Future<void> _onSavePressed() async {
    final s = _paneKey.currentState;
    if (s == null) return;

    final m = s.model;
    if ((m['esercizio'] ?? '').trim().isEmpty ||
        (m['numero_sinistro'] ?? '').trim().isEmpty ||
        (m['data_avvenimento'] ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila i campi obbligatori (*).')),
      );
      return;
    }

    final upd = Sinistro(
      esercizio: int.tryParse((m['esercizio'] ?? '').trim()) ?? 0,
      numeroSinistro: (m['numero_sinistro'] ?? '').trim(),
      numeroSinistroCompagnia: (m['numero_sinistro_compagnia'] ?? '').trim().isEmpty
          ? null : m['numero_sinistro_compagnia']!.trim(),
      numeroPolizza: (m['numero_polizza'] ?? '').trim().isEmpty
          ? null : m['numero_polizza']!.trim(),
      compagnia: (m['compagnia'] ?? '').trim().isEmpty ? null : m['compagnia']!.trim(),
      rischio: (m['rischio'] ?? '').trim().isEmpty ? null : m['rischio']!.trim(),
      intermediario: (m['intermediario'] ?? '').trim().isEmpty ? null : m['intermediario']!.trim(),
      descrizioneAssicurato: (m['descrizione_assicurato'] ?? '').trim().isEmpty
          ? null : m['descrizione_assicurato']!.trim(),
      dataAvvenimento: _parseIt(m['data_avvenimento'] ?? '') ?? DateTime.now(),
      citta: (m['citta'] ?? '').trim().isEmpty ? null : m['citta']!.trim(),
      indirizzo: (m['indirizzo'] ?? '').trim().isEmpty ? null : m['indirizzo']!.trim(),
      cap: (m['cap'] ?? '').trim().isEmpty ? null : m['cap']!.trim(),
      provincia: (m['provincia'] ?? '').trim().isEmpty ? null : m['provincia']!.trim(),
      codiceStato: (m['codice_stato'] ?? '').trim().isEmpty ? null : m['codice_stato']!.trim(),
      targa: (m['targa'] ?? '').trim().isEmpty ? null : m['targa']!.trim(),
      dinamica: (m['dinamica'] ?? '').trim().isEmpty ? null : m['dinamica']!.trim(),
      statoCompagnia: (m['stato_compagnia'] ?? '').trim().isEmpty ? null : m['stato_compagnia']!.trim(),
      dataApertura: _parseIt(m['data_apertura'] ?? ''),
      dataChiusura: _parseIt(m['data_chiusura'] ?? ''),
    );

    try {
      await widget.sdk.updateClaim(
        widget.user.username,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        upd,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinistro aggiornato.')),
      );
      await widget.onUpdated(widget.claimId, upd);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore aggiornamento sinistro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _claimToInitialMap(widget.initialClaim);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton(onPressed: widget.onCancel, style: _cancelStyle, child: const Text('Annulla')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _onSavePressed, style: _saveStyle, child: const Text('Salva')),
                ],
              ),
            ),
          ),
        ),

        // CONTENUTO (form con prefill + contratto bloccato)
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
                initialValues: initial,                      // ⬅️ prefill campi
                initialContractId: widget.contractId,        // ⬅️ contratto preselezionato
                lockContract: true,                          // ⬅️ non modificabile
              ),
            ),
          ),
        ),
      ],
    );
  }
}
