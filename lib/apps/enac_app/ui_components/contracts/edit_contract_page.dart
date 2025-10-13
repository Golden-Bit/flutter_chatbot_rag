import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_form_widget.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

class EditContractPage extends StatefulWidget with ChatBotExtensions {
  const EditContractPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    required this.contractId,
    required this.initialContract,
    required this.onCancel,
    required this.onUpdated,
    this.title = 'Modifica contratto',
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final String entityId;
  final String contractId;

  final ContrattoOmnia8 initialContract;

  final VoidCallback onCancel;
  final FutureOr<void> Function(ContrattoOmnia8 updated) onUpdated;

  final String title;

  // esponiamo gli stessi tool del pane
  static const _delegate = ContractFormPane();
  @override
  List<ToolSpec> get toolSpecs => [ContractFormPane.fillTool, ContractFormPane.setTool];
  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => _delegate.extraWidgetBuilders;
  @override
  ChatBotHostCallbacks get hostCallbacks => _delegate.hostCallbacks;

  @override
  State<EditContractPage> createState() => _EditContractPageState();
}

class _EditContractPageState extends State<EditContractPage> {
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

  // mapping ContrattoOmnia8 -> initialValues per ContractFormPane
  Map<String, String> _contractToInitialMap(ContrattoOmnia8 c) {
    String d(DateTime? x) => (x == null) ? '' : _fmt.format(x);
    String n(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.isEmpty) return '';
      // numeri: normalizziamo al punto decimale
      return s.replaceAll(',', '.');
    }

    final id   = c.identificativi;
    final amm  = c.amministrativi;
    final prem = c.premi;
    final rin  = c.rinnovo;
    final op   = c.operativita;
    final pr   = op?.parametriRegolazione;
    final ram  = c.ramiEl;

    return {
      // Identificativi
      'tipo'      : id.tipo,
      'tpCar'     : id.tpCar ?? '',
      'ramo'      : id.ramo,
      'compagnia' : id.compagnia,
      'numero'    : id.numeroPolizza,

      // Amministrativi base + extra
      'effetto'               : d(amm?.effetto),
      'scadenza'              : d(amm?.scadenza),
      'data_emissione'        : d(amm?.dataEmissione ?? amm?.effetto),
      'fraz'                  : (amm?.frazionamento ?? '').toString(),
      'modIncasso'            : (amm?.modalitaIncasso ?? '').toString(),
      'scadenza_originaria'   : d(amm?.scadenzaOriginaria ?? amm?.scadenza),
      'ultima_rata_pagata'    : d(amm?.ultimaRataPagata ?? amm?.dataEmissione),
      'scadenza_mora'         : d(amm?.scadenzaMora),
      'numeroProposta'        : (amm?.numeroProposta ?? '').toString(),
      'codConvenzione'        : (amm?.codConvenzione ?? '').toString(),
      'scadenza_vincolo'      : d(amm?.scadenzaVincolo),
      'scadenza_copertura'    : d(amm?.scadenzaCopertura),
      'fine_copertura_proroga': d(amm?.fineCoperturaProroga),
      'compresoFirma'         : (amm?.compresoFirma ?? false).toString(),

      // Premi
      'premio'     : n(prem?.premio),
      'netto'      : n(prem?.netto),
      'accessori'  : n(prem?.accessori),
      'diritti'    : n(prem?.diritti),
      'imposte'    : n(prem?.imposte),
      'spese'      : n(prem?.spese),
      'fondo'      : n(prem?.fondo),
      'sconto'     : prem?.sconto == null ? '' : n(prem?.sconto),

      // Unità vendita
      'pv1'          : (c.unitaVendita?.puntoVendita ?? '').toString(),
      'pv2'          : (c.unitaVendita?.puntoVendita2 ?? '').toString(),
      'account'      : (c.unitaVendita?.account ?? '').toString(),
      'intermediario': (c.unitaVendita?.intermediario ?? '').toString(),

      // Rinnovo
      'rinnovo'  : (rin?.rinnovo ?? '').toString(),
      'disdetta' : (rin?.disdetta ?? '').toString(),
      'gMora'    : (rin?.giorniMora ?? '').toString(),
      'proroga'  : (rin?.proroga ?? '').toString(),

      // Operatività / Regolazione
      'regolazione' : (op?.regolazione ?? false).toString(),
      'inizio_reg'  : d(pr?.inizio),
      'fine_reg'    : d(pr?.fine),
      'ultima_reg'  : d(pr?.ultimaRegEmessa),
      'gInvio'      : (pr?.giorniInvioDati ?? '').toString(),
      'gPag'        : (pr?.giorniPagReg ?? '').toString(),
      'gMoraReg'    : (pr?.giorniMoraRegolazione ?? '').toString(),
      'cadReg'      : (pr?.cadenzaRegolazione ?? '').toString(),

      // Rischio / Prodotto
      'ramiDesc' : (ram?.descrizione ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final initial = _contractToInitialMap(widget.initialContract);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER allineato al form
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton(onPressed: widget.onCancel, style: _cancelStyle, child: const Text('Annulla')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _onSavePressed, style: _saveStyle, child: const Text('Salva')),
                ],
              ),
            ),
          ),
        ),

        // FORM precompilato
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: ContractFormPane(
                key: _paneKey,
                initialValues: initial,   // ⬅️ prefill
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSavePressed() async {
    final pane = _paneKey.currentState; if (pane == null) return;

    final m   = pane.model;              // Map<String,String>
    final reg = pane.regolazione;        // bool

    String t(String k) => (m[k] ?? '').trim();
    String? nn(String k) => t(k).isEmpty ? null : t(k);
    DateTime? pd(String k) {
      final s = t(k); if (s.isEmpty) return null;
      try { return _fmt.parseStrict(s); } catch (_) { return null; }
    }
    int? pint(String k) => (t(k).isEmpty) ? null : int.tryParse(t(k));
    String pstr(String k) {
      final s = t(k);
      if (s.isEmpty) return '0.00';
      final d = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
      return d.toStringAsFixed(2);
    }

    // validazioni minime come Create
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
    final missing = requiredFields.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compila i campi obbligatori: ${missing.join(', ')}')),
      );
      return;
    }

    final effetto  = pd('effetto');
    final scadenza = pd('scadenza');
    if (effetto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato data Effetto non valido (gg/mm/aaaa).')));
      return;
    }
    if (scadenza == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formato data Scadenza non valido (gg/mm/aaaa).')));
      return;
    }

    final updated = ContrattoOmnia8(
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
        dataEmissione      : pd('emissione') ?? pd('data_emissione') ?? effetto,
        ultimaRataPagata   : pd('ultima_rata_pagata') ?? pd('data_emissione') ?? effetto,
        frazionamento      : t('fraz').toLowerCase(),
        modalitaIncasso    : t('modIncasso'),
        compresoFirma      : t('compresoFirma').toLowerCase() == 'true',
        scadenzaOriginaria : pd('scadenza_originaria') ?? scadenza,
        scadenzaMora       : pd('scadenza_mora'),
        numeroProposta     : nn('numeroProposta'),
        codConvenzione     : nn('codConvenzione'),
        scadenzaVincolo    : pd('scadenza_vincolo'),
        scadenzaCopertura  : pd('scadenza_copertura'),
        fineCoperturaProroga: pd('fine_copertura_proroga'),
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
          inizio                : pd('inizio_reg') ?? effetto,
          fine                  : pd('fine_reg')   ?? scadenza,
          ultimaRegEmessa       : pd('ultima_reg'),
          giorniInvioDati       : pint('gInvio'),
          giorniPagReg          : pint('gPag'),
          giorniMoraRegolazione : pint('gMoraReg'),
          cadenzaRegolazione    : (nn('cadReg')?.toLowerCase() ?? 'annuale'),
        ),
      ),
      ramiEl: RamiEl(descrizione: t('rami_desc')),
    );

    try {
      final resp = await widget.sdk.updateContract(
        widget.user.username,    // userId
        widget.entityId,         // entityId
        widget.contractId,       // contractId
        updated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contratto aggiornato.')));
      await widget.onUpdated(resp);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore aggiornamento contratto: $e')));
    }
  }
}
