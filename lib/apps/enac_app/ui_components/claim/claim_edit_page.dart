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

  // Tool del ClaimFormPane (nuovo schema)
  @override
  List<ToolSpec> get toolSpecs => [ClaimFormPane.fillTool, ClaimFormPane.setTool];

  // Delegate per widgetBuilders/hostCallbacks
  ClaimFormPane _delegate() =>
      ClaimFormPane(user: user, token: token, sdk: sdk, entityId: entityId);

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

  // Formatter dd/MM/yyyy
  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  DateTime? _parseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final p = t.split('/');
    if (p.length == 3) {
      try {
        final d = int.parse(p[0]), m = int.parse(p[1]), y = int.parse(p[2]);
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
    try {
      return DateTime.parse(t);
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  // Mappa Sinistro (nuovo schema) -> initialValues del form (nuove chiavi)
  Map<String, String> _claimToInitialMap(Sinistro s) {
    return {
      'esercizio'          : s.esercizio.toString(),
      'numero_sinistro'    : s.numeroSinistro,
      'compagnia'          : s.compagnia ?? '',
      'numero_contratto'   : s.numeroContratto ?? '',
      'rischio'            : s.rischio ?? '',
      'descrizione_evento' : s.descrizioneEvento ?? '',
      'data_accadimento'   : _fmtDate(s.dataAccadimento),
      'data_denuncia'      : _fmtDate(s.dataDenuncia),
      'danno_stimato'      : s.dannoStimato ?? '',
      'importo_riservato'  : s.importoRiservato ?? '',
      'importo_liquidato'  : s.importoLiquidato ?? '',
      'stato'              : s.stato ?? '',
      'indirizzo_evento'   : s.indirizzoEvento ?? '',
      'cap'                : s.cap ?? '',
      'citta'              : s.citta ?? '',
    };
  }

  Future<void> _onSavePressed() async {
    final pane = _paneKey.currentState;
    if (pane == null) return;

    final m = pane.model; // chiavi del nuovo schema

    // Obbligatori minimi (coerenti con Create)
    final esercizioStr = (m['esercizio'] ?? '').trim();
    final numeroSinistro = (m['numero_sinistro'] ?? '').trim();
    final dataAccStr = (m['data_accadimento'] ?? '').trim();

    if (esercizioStr.isEmpty || numeroSinistro.isEmpty || dataAccStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila i campi obbligatori (*).')),
      );
      return;
    }

    final esercizio = _parseInt(esercizioStr);
    final dataAccadimento = _parseDate(dataAccStr);
    final dataDenuncia = _parseDate(m['data_denuncia'] ?? '');

    if (esercizio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esercizio non valido (usa cifre intere).')),
      );
      return;
    }
    if (dataAccadimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data accadimento non valida (gg/mm/aaaa).')),
      );
      return;
    }

    // Stato: se presente, deve essere tra i 4 ammessi
    const statiAmmessi = {
      'Aperto',
      'Chiuso',
      'Senza Seguito',
      'In Valutazione',
    };
    final stato = (m['stato'] ?? '').trim();
    if (stato.isNotEmpty && !statiAmmessi.contains(stato)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona uno stato valido.')),
      );
      return;
    }

    String? nn(String k) {
      final v = (m[k] ?? '').trim();
      return v.isEmpty ? null : v;
    }

    // Costruisci Sinistro con SOLO i campi del nuovo schema
    final updated = Sinistro(
      esercizio: esercizio,
      numeroSinistro: numeroSinistro,
      dataAccadimento: dataAccadimento,
      // denormalizzazioni/contesto
      compagnia: nn('compagnia'),
      numeroContratto: nn('numero_contratto'),
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

    try {
      await widget.sdk.updateClaim(
        widget.user.username,
        widget.entityId,
        widget.contractId,
        widget.claimId,
        updated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinistro aggiornato.')),
      );
      await widget.onUpdated(widget.claimId, updated);
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
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
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
                initialValues: initial,               // prefill con nuove chiavi
                initialContractId: widget.contractId, // contratto preselezionato
                lockContract: true,                   // contratto non modificabile
              ),
            ),
          ),
        ),
      ],
    );
  }
}
