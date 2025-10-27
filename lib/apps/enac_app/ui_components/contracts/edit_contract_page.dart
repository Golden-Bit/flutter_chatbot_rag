// lib/apps/enac_app/ui_components/edit_contract_page.dart
import 'dart:async';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // Esponiamo i tool del nuovo ContractFormPane
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

  /* ───────────────────── Helpers di normalizzazione ───────────────────── */
  String _d(DateTime? x) => (x == null) ? '' : _fmt.format(x);
  String _num(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty) return '';
    // normalizza eventuale formato 1.234,56 → 1234.56
    final norm = s.replaceAll('.', '').replaceAll(',', '.');
    return norm;
  }

  String _normTipo(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'COND';
    final s = raw.trim().toUpperCase();
    if (s.startsWith('COND')) return 'COND';
    if (s == 'APP0' || s.contains('NULLO')) return 'APP0';
    if (s == 'APP€' || s.contains('PREMIO')) return 'APP€';
    return (['COND', 'APP0', 'APP€'].contains(s)) ? s : 'COND';
    }

  String _normSiNoFromRinnovo(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    const yes = {'sì','si','yes','y','1','true','t','tacito','tacito rinnovo'};
    const no  = {'no','n','0','false','f','non tacito'};
    if (yes.contains(s)) return 'Sì';
    if (no.contains(s))  return 'No';
    // fallback: stringa non riconosciuta ⇒ lascio vuoto (verrà richiesto)
    return (s.isEmpty) ? '' : 'Sì';
  }

  /* ───────────── mapping ContrattoOmnia8 → initialValues per il form ───────────── */
  Map<String, String> _contractToInitialMap(ContrattoOmnia8 c) {
    final id  = c.identificativi;
    final amm = c.amministrativi;
    final prem = c.premi;
    final rin = c.rinnovo;
    final uv  = c.unitaVendita;
    final op  = c.operativita;

    // Preferisco il rischio da ramiEl.descrizione; fallback a identificativi.tipo
    final rischio = (c.ramiEl?.descrizione?.trim().isNotEmpty ?? false)
        ? c.ramiEl!.descrizione!
        : (id.tipo);

    return {
      // Identificativi
      'tipo'              : _normTipo(id.tpCar),
      'rischio'           : rischio,
      'compagnia'         : id.compagnia,
      'numero'            : id.numeroPolizza,

      // Importi
      'premio_imponibile' : _num(prem?.netto),
      'imposte'           : _num(prem?.imposte),
      'premio_lordo'      : _num(prem?.premio),

      // Amministrativi / date
      'fraz'              : (amm?.frazionamento ?? '').toString(),
      'effetto'           : _d(amm?.effetto),
      'scadenza'          : _d(amm?.scadenza),
      'scadenza_copertura': _d(amm?.scadenzaCopertura),
      'data_emissione'    : _d(amm?.dataEmissione),

      // Varie
      'giorni_mora'       : (rin?.giorniMora ?? '').toString(),

      // Broker
      'broker'            : (uv?.intermediario ?? '').toString(),
      'broker_indirizzo'  : (uv?.puntoVendita ?? '').toString(),

      // Rinnovo
      'tacito_rinnovo'    : _normSiNoFromRinnovo(rin?.rinnovo),
      'disdetta'          : (rin?.disdetta ?? '').toString(),
      'proroga'           : (rin?.proroga ?? '').toString(),

      // Regolazione al termine del periodo (Sì/No)
      'regolazione_fine_periodo': (op?.regolazione ?? false) ? 'Sì' : 'No',
    };
  }

  @override
  Widget build(BuildContext context) {
    final initial = _contractToInitialMap(widget.initialContract);

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
                    onPressed: _onSavePressed,
                    style: _saveStyle,
                    child: const Text('Salva'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ───────────────── FORM (precompilato) ────────────────
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
              child: ContractFormPane(
                key: _paneKey,
                initialValues: initial,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /* ───────────────────────── Salvataggio ───────────────────────── */
  Future<void> _onSavePressed() async {
    final pane = _paneKey.currentState; if (pane == null) return;
    final m = pane.model;

    String t(String k) => (m[k] ?? '').trim();
    DateTime? pd(String k) {
      final s = t(k); if (s.isEmpty) return null;
      try { return _fmt.parseStrict(s); } catch (_) { return null; }
    }
    String moneyStr(String k) {
      final s = t(k);
      if (s.isEmpty) return '0.00';
      final d = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ??
          double.tryParse(s) ?? 0.0;
      return d.toStringAsFixed(2);
    }
    bool yesNo(String k) {
      final s = t(k).toLowerCase();
      return s == 'sì' || s == 'si' || s == 'true' || s == '1';
    }

    // Validazioni: SOLO campi del capitolato
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

    final updated = ContrattoOmnia8(
      identificativi: Identificativi(
        // “Rischio” nel campo tipo per compatibilità con le view
        tipo          : t('rischio'),
        // “Tipo” (COND | APP0 | APP€) nel tpCar
        tpCar         : t('tipo'),
        ramo          : '', // non richiesto
        compagnia     : t('compagnia'),
        numeroPolizza : t('numero'),
      ),
      // Broker & indirizzo
      unitaVendita: UnitaVendita(
        intermediario : t('broker'),
        puntoVendita  : t('broker_indirizzo'),
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
        parametriRegolazione: ParametriRegolazione(
          inizio: effetto,
          fine  : scadenza,
        ),
      ),
      ramiEl: RamiEl(descrizione: t('rischio')),
    );

    try {
      final resp = await widget.sdk.updateContract(
        widget.user.username, // userId
        widget.entityId,      // entityId
        widget.contractId,    // contractId
        updated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contratto aggiornato.')));
      await widget.onUpdated(resp);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore aggiornamento contratto: $e')));
    }
  }
}
