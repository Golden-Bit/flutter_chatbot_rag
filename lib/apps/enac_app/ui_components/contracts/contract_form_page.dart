import 'dart:async';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_form_widget.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // ── ChatBotExtensions: *ri-esponiamo* i tool del ContractFormPane ──
  static const _delegate = ContractFormPane(); // per accedere ai suoi builders

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

  // Espone gli stessi getter del pane (se ti servono altrove)
  Map<String,String> get model        => _paneKey.currentState?.model ?? {};
  bool get regolazione                => _paneKey.currentState?.regolazione ?? false;

@override
Widget build(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ───────────────── HEADER allineato come il form ─────────────────
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
                  onPressed: _onCreatePressed,
                  style: _saveStyle,
                  child: const Text('Crea'),
                ),
              ],
            ),
          ),
        ),
      ),

      // ───────────────── CONTENUTO: form allineato a sinistra ───────────
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
  /*  Salvataggio (portato dal vecchio dialog)                         */
  /*───────────────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final pane = _paneKey.currentState;
    if (pane == null) return;

    final m   = pane.model;         // Map<String,String> esposta dal pane
    final reg = pane.regolazione;   // bool esposto dal pane

    String t(String k) => (m[k] ?? '').trim();
    String? nn(String k) => t(k).isEmpty ? null : t(k);

    DateTime? pd(String k) {
      final s = t(k);
      if (s.isEmpty) return null;
      try { return _fmt.parseStrict(s); } catch (_) { return null; }
    }
    int? pint(String k) => (t(k).isEmpty) ? null : int.tryParse(t(k));
    String pstr(String k) {
      final s = t(k);
      if (s.isEmpty) return '0.00';
      final d = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
      return d.toStringAsFixed(2);
    }

    // Obbligatori minimi (come prima)
    final requiredFields = {
      'tipo'        : t('tipo'),
      'ramo'        : t('ramo'),
      'compagnia'   : t('compagnia'),
      'numero'      : t('numero'),
      'effetto'     : t('effetto'),
      'scadenza'    : t('scadenza'),
      'fraz'        : t('fraz'),
      'modIncasso'  : t('modIncasso'),
      'pv1'         : t('pv1'),
      'account'     : t('account'),
      'intermediario': t('intermediario'),
      'premio'      : t('premio'),
      'netto'       : t('netto'),
      'rami_desc'   : t('rami_desc'),
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
    if (effetto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato data Effetto non valido (gg/mm/aaaa).')),
      );
      return;
    }
    if (scadenza == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato data Scadenza non valido (gg/mm/aaaa).')),
      );
      return;
    }

    // Build payload (stesso del dialog)
    final contratto = ContrattoOmnia8(
      identificativi: Identificativi(
        tipo          : t('tipo'),
        tpCar         : nn('tpCar'),
        ramo          : t('ramo'),
        compagnia     : t('compagnia'),
        numeroPolizza : t('numero'),
      ),
      unitaVendita: UnitaVendita(
        puntoVendita  : t('pv1'),
        puntoVendita2 : t('pv2'),
        account       : t('account'),
        intermediario : t('intermediario'),
      ),
      amministrativi: Amministrativi(
        effetto            : effetto,
        scadenza           : scadenza,
        dataEmissione      : pd('emissione') ?? effetto,
        ultimaRataPagata   : pd('ultima_rata_pagata') ?? pd('emissione') ?? effetto,
        frazionamento      : t('fraz').toLowerCase(),
        modalitaIncasso    : t('modIncasso'),
        compresoFirma      : t('compresoFirma').toLowerCase() == 'true',
        scadenzaOriginaria : pd('scadenza_originaria') ?? scadenza,
        scadenzaMora       : pd('sc_mora'),
        numeroProposta     : nn('numeroProposta'),
        codConvenzione     : nn('codConvenzione'),
        scadenzaVincolo    : pd('sc_vincolo'),
        scadenzaCopertura  : pd('sc_copertura'),
        fineCoperturaProroga: pd('fine_proroga'),
      ),
      premi: Premi(
        premio    : pstr('premio'),
        netto     : pstr('netto'),
        accessori : pstr('accessori'),
        diritti   : pstr('diritti'),
        imposte   : pstr('imposte'),
        spese     : pstr('spese'),
        fondo     : pstr('fondo'),
        sconto    : t('sconto').isEmpty ? null : pstr('sconto'),
      ),
      rinnovo: Rinnovo(
        rinnovo    : t('rinnovo'),
        disdetta   : t('disdetta'),
        giorniMora : t('gMora'),
        proroga    : t('proroga'),
      ),
      operativita: Operativita(
        regolazione: reg,
        parametriRegolazione: ParametriRegolazione(
          inizio                : pd('inizioReg') ?? effetto,
          fine                  : pd('fineReg')   ?? scadenza,
          ultimaRegEmessa       : pd('ultReg'),
          giorniInvioDati       : pint('gInvio'),
          giorniPagReg          : pint('gPag'),
          giorniMoraRegolazione : pint('gMoraReg'),
          cadenzaRegolazione    : (nn('cadReg')?.toLowerCase() ?? 'annuale'),
        ),
      ),
      ramiEl: RamiEl(descrizione: t('rami_desc')),
    );

    try {
      final resp = await widget.sdk.createContract(
        widget.user.username,     // userId
        widget.clientId,          // entityId
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

// piccola estensione per assegnare una GlobalKey a un const widget
extension on ContractFormPane {
  Widget withKey(GlobalKey<ContractFormPaneState> key) =>
      KeyedSubtree(key: key, child: this);
}
