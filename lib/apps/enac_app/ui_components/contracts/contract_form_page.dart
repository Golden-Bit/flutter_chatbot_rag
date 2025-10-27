// lib/apps/enac_app/ui_components/create_contract_page.dart
import 'dart:async';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

class CreateContractPage extends StatefulWidget with ChatBotExtensions {
  const CreateContractPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.clientId,
    required this.onCancel,
    required this.onCreated,
    this.title = 'Nuovo contratto',
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final String clientId;

  final VoidCallback onCancel;
  final FutureOr<void> Function(String contractId) onCreated;

  final String title;

  // ── ChatBotExtensions: re-esponiamo i tool del nuovo ContractFormPane ──
  static const _delegate = ContractFormPane();

  @override
  List<ToolSpec> get toolSpecs => [ContractFormPane.fillTool, ContractFormPane.setTool];

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => _delegate.extraWidgetBuilders;

  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate.hostCallbacks;

  @override
  State<CreateContractPage> createState() => _CreateContractPageState();
}

class _CreateContractPageState extends State<CreateContractPage> {
  static const _kBrandGreen = Color(0xFF00A651);
  static const double _kFormMaxWidth = 600;

  final _paneKey = GlobalKey<ContractFormPaneState>();
  final _fmt = DateFormat('dd/MM/yyyy');

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

  Map<String, String> get model => _paneKey.currentState?.model ?? {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───────────────── HEADER ─────────────────
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

        // ───────────────── FORM ────────────────
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: ContractFormPane(key: _paneKey),
            ),
          ),
        ),
      ],
    );
  }

  /*───────────────────────────────────────────────────────────────────*/
  /*  Salvataggio                                                       */
  /*───────────────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final m = model;

    String t(String k) => (m[k] ?? '').trim();
    String? nn(String k) => t(k).isEmpty ? null : t(k);

    DateTime? pd(String k) {
      final s = t(k);
      if (s.isEmpty) return null;
      try { return _fmt.parseStrict(s); } catch (_) { return null; }
    }

    String moneyStr(String k) {
      final s = t(k);
      if (s.isEmpty) return '0.00';
      // virgola o punto come separatore decimale
      final d = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ??
          double.tryParse(s) ?? 0.0;
      return d.toStringAsFixed(2);
    }

    bool yesNo(String k) {
      final s = t(k).toLowerCase();
      return s == 'sì' || s == 'si' || s == 'true' || s == '1';
    }

    // ── Validazione: SOLO i campi del capitolato ──
    final requiredFields = {
      'tipo'               : t('tipo'),
      'rischio'            : t('rischio'),
      'compagnia'          : t('compagnia'),
      'numero'             : t('numero'),
      'premio_imponibile'  : t('premio_imponibile'),
      'imposte'            : t('imposte'),
      'premio_lordo'       : t('premio_lordo'),
      'fraz'               : t('fraz'),
      'effetto'            : t('effetto'),
      'scadenza'           : t('scadenza'),
      'scadenza_copertura' : t('scadenza_copertura'),
      'data_emissione'     : t('data_emissione'),
      'tacito_rinnovo'     : t('tacito_rinnovo'),
    };

    final missing = requiredFields.entries
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compila i campi obbligatori: ${missing.join(', ')}')),
      );
      return;
    }

    final effetto  = pd('effetto');
    final scadenza = pd('scadenza');
    final scCop    = pd('scadenza_copertura');
    final emesso   = pd('data_emissione');

    if (effetto == null || scadenza == null || scCop == null || emesso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifica il formato delle date (gg/mm/aaaa).')),
      );
      return;
    }

    // ── Mapping ai modelli SDK (usando SOLO i campi richiesti) ──
    // Nota: per compatibilità UI correnti:
    // - usiamo Identificativi.tipo per mostrare il “Rischio” nel dettaglio,
    // - conserviamo il "Tipo (COND/APP0/APP€)" in Identificativi.tpCar.
    final contratto = ContrattoOmnia8(
      identificativi: Identificativi(
        tipo          : t('rischio'),      // mostrato come "RISCHIO" nelle view esistenti
        tpCar         : t('tipo'),         // COND | APP0 | APP€
        ramo          : '',                // non richiesto ora
        compagnia     : t('compagnia'),
        numeroPolizza : t('numero'),
      ),
      // Usiamo "intermediario" come Broker e "puntoVendita" per l'indirizzo
      unitaVendita: UnitaVendita(
        puntoVendita  : t('broker_indirizzo'),
        intermediario : t('broker'),
      ),
      amministrativi: Amministrativi(
        effetto           : effetto,
        scadenza          : scadenza,
        dataEmissione     : emesso,
        frazionamento     : t('fraz'),
        scadenzaCopertura : scCop,
      ),
      premi: Premi(
        netto   : moneyStr('premio_imponibile'),
        imposte : moneyStr('imposte'),
        premio  : moneyStr('premio_lordo'),
      ),
      rinnovo: Rinnovo(
        rinnovo    : t('tacito_rinnovo'), // "Sì" | "No"
        disdetta   : t('disdetta'),
        proroga    : t('proroga'),
        giorniMora : t('giorni_mora'),
      ),
      operativita: Operativita(
        regolazione: yesNo('regolazione_fine_periodo'),
        // opzionale: diamo comunque inizio/fine per coerenza report
        parametriRegolazione: ParametriRegolazione(
          inizio: effetto,
          fine  : scadenza,
        ),
      ),
      // Per tabelle/ricerche che leggono il rischio da qui
      ramiEl: RamiEl(descrizione: t('rischio')),
    );

    try {
      final resp = await widget.sdk.createContract(
        widget.user.username, // userId
        widget.clientId,      // entityId
        contratto,
      );
      await widget.onCreated(resp.contractId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione contratto: $e')),
      );
    }
  }
}
