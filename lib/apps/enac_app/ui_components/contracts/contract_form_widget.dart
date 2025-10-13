// lib/apps/enac_app/ui_components/contract_form_pane.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

class ContractFormPane extends StatefulWidget with ChatBotExtensions {
  const ContractFormPane({super.key,this.initialValues});

  @override
  State<ContractFormPane> createState() => ContractFormPaneState();
  final Map<String, String>? initialValues;
  /*───────────────────────────────────────────────────────────────────────*/
  /* ToolSpec: COMPILA TUTTO (ogni parametro è opzionale)                  */
  /*───────────────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillContractFormWidget',
    description:
        'Compila il form contratto con digitazione simulata. Ogni parametro è opzionale: se assente, il campo non viene toccato.',
    params: const [
      // Identificativi
      ToolParamSpec(name: 'tipo',      paramType: ParamType.string,  description: 'Tipo',            example: 'Auto'),
      ToolParamSpec(name: 'tpCar',     paramType: ParamType.string,  description: 'TpCar',           example: 'Autovettura'),
      ToolParamSpec(name: 'ramo',      paramType: ParamType.string,  description: 'Ramo',            example: 'RCA'),
      ToolParamSpec(name: 'compagnia', paramType: ParamType.string,  description: 'Compagnia',       example: 'ACME Assicurazioni'),
      ToolParamSpec(name: 'numero',    paramType: ParamType.string,  description: 'Numero polizza',  example: 'POL123456'),

      // Date (formato dd/MM/yyyy)
      ToolParamSpec(name: 'effetto',        paramType: ParamType.string, description: 'Data effetto (dd/MM/yyyy)',        example: '01/01/2026'),
      ToolParamSpec(name: 'scadenza',       paramType: ParamType.string, description: 'Data scadenza (dd/MM/yyyy)',       example: '01/01/2027'),
      ToolParamSpec(name: 'data_emissione', paramType: ParamType.string, description: 'Data emissione (dd/MM/yyyy)',      example: '01/01/2026'),

      // Amministrativi base
      ToolParamSpec(name: 'fraz',       paramType: ParamType.string,  description: 'Frazionamento',                 example: 'Annuale'),
      ToolParamSpec(name: 'modIncasso', paramType: ParamType.string,  description: 'Modalità incasso',              example: 'Bonifico'),

      // Amministrativi opzionali/extra (SDK nuovo)
      ToolParamSpec(name: 'compresoFirma',        paramType: ParamType.boolean, description: 'Flag “Compreso firma”',                  example: true),
      ToolParamSpec(name: 'scadenza_originaria',  paramType: ParamType.string,  description: 'Scadenza originaria (dd/MM/yyyy)',       example: '01/01/2027'),
      ToolParamSpec(name: 'ultima_rata_pagata',   paramType: ParamType.string,  description: 'Ultima rata pagata (dd/MM/yyyy)',        example: '15/01/2026'),
      ToolParamSpec(name: 'scadenza_mora',        paramType: ParamType.string,  description: 'Scadenza Mora (dd/MM/yyyy)',             example: '01/02/2026'),
      ToolParamSpec(name: 'numeroProposta',       paramType: ParamType.string,  description: 'Numero proposta',                         example: 'PR123'),
      ToolParamSpec(name: 'codConvenzione',       paramType: ParamType.string,  description: 'Codice convenzione',                      example: 'CONV01'),
      ToolParamSpec(name: 'scadenza_vincolo',     paramType: ParamType.string,  description: 'Scadenza vincolo (dd/MM/yyyy)',           example: '01/03/2026'),
      ToolParamSpec(name: 'scadenza_copertura',   paramType: ParamType.string,  description: 'Scadenza copertura (dd/MM/yyyy)',         example: '01/04/2026'),
      ToolParamSpec(name: 'fine_copertura_proroga', paramType: ParamType.string, description: 'Fine copertura proroga (dd/MM/yyyy)',   example: '15/04/2026'),

      // Premi (numeri)
      ToolParamSpec(name: 'premio',    paramType: ParamType.number, description: 'Premio',    example: 1200.0, minValue: 0),
      ToolParamSpec(name: 'netto',     paramType: ParamType.number, description: 'Netto',     example: 1000.0, minValue: 0),
      ToolParamSpec(name: 'accessori', paramType: ParamType.number, description: 'Accessori', example: 10.0,   minValue: 0),
      ToolParamSpec(name: 'diritti',   paramType: ParamType.number, description: 'Diritti',   example: 5.0,    minValue: 0),
      ToolParamSpec(name: 'imposte',   paramType: ParamType.number, description: 'Imposte',   example: 200.0,  minValue: 0),
      ToolParamSpec(name: 'spese',     paramType: ParamType.number, description: 'Spese',     example: 15.0,   minValue: 0),
      ToolParamSpec(name: 'fondo',     paramType: ParamType.number, description: 'Fondo',     example: 0.0,    minValue: 0),
      ToolParamSpec(name: 'sconto',    paramType: ParamType.number, description: 'Sconto (può essere omesso)', example: 0.0),

      // Unità vendita
      ToolParamSpec(name: 'pv1',           paramType: ParamType.string, description: 'Punto vendita',   example: 'PV Milano 1'),
      ToolParamSpec(name: 'pv2',           paramType: ParamType.string, description: 'Punto vendita 2', example: 'PV Milano 2'),
      ToolParamSpec(name: 'account',       paramType: ParamType.string, description: 'Account',         example: 'Marco Bianchi'),
      ToolParamSpec(name: 'intermediario', paramType: ParamType.string, description: 'Intermediario',   example: 'INT01'),

      // Rinnovo
      ToolParamSpec(name: 'rinnovo',  paramType: ParamType.string, description: 'Rinnovo',     example: 'Tacito'),
      ToolParamSpec(name: 'disdetta', paramType: ParamType.string, description: 'Disdetta',    example: '30gg'),
      ToolParamSpec(name: 'gMora',    paramType: ParamType.string, description: 'Giorni Mora', example: '15'),
      ToolParamSpec(name: 'proroga',  paramType: ParamType.string, description: 'Proroga',     example: '15gg'),

      // Operatività / Regolazione
      ToolParamSpec(name: 'regolazione', paramType: ParamType.boolean, description: 'Abilita regolazione',                       example: true),
      ToolParamSpec(name: 'inizio_reg',  paramType: ParamType.string,  description: 'Inizio regolazione (dd/MM/yyyy)',           example: '01/01/2026'),
      ToolParamSpec(name: 'fine_reg',    paramType: ParamType.string,  description: 'Fine regolazione (dd/MM/yyyy)',             example: '31/12/2026'),
      ToolParamSpec(name: 'ultima_reg',  paramType: ParamType.string,  description: 'Ultima regolazione emessa (dd/MM/yyyy)',    example: '01/10/2026'),
      ToolParamSpec(name: 'gInvio',      paramType: ParamType.integer, description: 'Giorni invio dati',                         example: 15, minValue: 0),
      ToolParamSpec(name: 'gPag',        paramType: ParamType.integer, description: 'Giorni pagamento reg.',                     example: 30, minValue: 0),
      ToolParamSpec(name: 'gMoraReg',    paramType: ParamType.integer, description: 'Giorni mora regolazione',                   example: 10, minValue: 0),
      ToolParamSpec(name: 'cadReg',      paramType: ParamType.string,  description: 'Cadenza regolazione',                       example: 'Mensile'),

      // Rischio / Prodotto
      ToolParamSpec(name: 'ramiDesc', paramType: ParamType.string, description: 'Descrizione rischio/prodotto', example: 'RCA + Furto/Incendio'),

      // Digitazione
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata). Default 22.',
        example: 18, defaultValue: 22, minValue: 0, maxValue: 200,
      ),
    ],
  );

  /*───────────────────────────────────────────────────────────────────────*/
  /* ToolSpec: SET SINGOLO CAMPO                                          */
  /*───────────────────────────────────────────────────────────────────────*/
  static final List<String> _allFields = [
    // Identificativi
    'tipo','tpCar','ramo','compagnia','numero',

    // Amministrativi base
    'effetto','scadenza','data_emissione','fraz','modIncasso',

    // Amministrativi opz./extra (SDK)
    'compresoFirma','scadenza_originaria','ultima_rata_pagata',
    'scadenza_mora','numeroProposta','codConvenzione',
    'scadenza_vincolo','scadenza_copertura','fine_copertura_proroga',

    // Premi
    'premio','netto','accessori','diritti','imposte','spese','fondo','sconto',

    // Unità vendita
    'pv1','pv2','account','intermediario',

    // Rinnovo
    'rinnovo','disdetta','gMora','proroga',

    // Operatività / Regolazione
    'regolazione','inizio_reg','fine_reg','ultima_reg','gInvio','gPag','gMoraReg','cadReg',

    // Rischio / Prodotto
    'ramiDesc',
  ];

  static final ToolSpec setTool = ToolSpec(
    toolName: 'SetContractFieldWidget',
    description: 'Imposta un singolo campo del contratto con digitazione simulata.',
    params: [
      ToolParamSpec(
        name: 'field', paramType: ParamType.string,
        description: 'Nome del campo',
        allowedValues: _allFields, example: 'numero',
      ),
      ToolParamSpec(
        name: 'value', paramType: ParamType.string,
        description: 'Valore (per boolean usare "true"/"false"; per date dd/MM/yyyy; i numeri sono accettati come stringa).',
        example: 'POL123456',
      ),
      ToolParamSpec(
        name: 'typing_ms', paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata).',
        example: 20, defaultValue: 22, minValue: 0, maxValue: 200,
      ),
    ],
  );

  @override
  List<ToolSpec> get toolSpecs => [fillTool, setTool];

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'FillContractFormWidget': (json, onR, pCbs, hCbs) =>
            _FillContractFormExec(json: json, host: hCbs as _ContractFormHostCbs),
        'SetContractFieldWidget': (json, onR, pCbs, hCbs) =>
            _SetContractFieldExec(json: json, host: hCbs as _ContractFormHostCbs),
      };

  @override
  ChatBotHostCallbacks get hostCallbacks => const _ContractFormHostCbs();
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  STATE: controllers, digitazione, UI, export modello                    */
/*─────────────────────────────────────────────────────────────────────────*/
class ContractFormPaneState extends State<ContractFormPane> {

  static const double _kFormMaxWidth = 600; // ⬅️ nuovo
void _setInitialValues(Map<String, String> m) {
  // campi testo
  for (final e in m.entries) {
    final k = e.key;
    final v = e.value;
    if (_c.containsKey(k)) {
      _c[k]!.text = v;
      _c[k]!.selection = TextSelection.collapsed(offset: _c[k]!.text.length);
    }
  }
  // booleani
  if (m.containsKey('regolazione')) {
    setState(() => _regolazione = (m['regolazione']!.toLowerCase() == 'true'));
  }
  if (m.containsKey('compresoFirma')) {
    setState(() => _compresoFirma = (m['compresoFirma']!.toLowerCase() == 'true'));
  }
}

@override
void initState() {
  super.initState();
  _ContractFormHostCbs.bind(this);
  // ⬇️ prefill iniziale
  if (widget.initialValues != null && widget.initialValues!.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setInitialValues(widget.initialValues!);
    });
  }
}

@override
void didUpdateWidget(covariant ContractFormPane oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.initialValues != oldWidget.initialValues &&
      widget.initialValues != null) {
    _setInitialValues(widget.initialValues!);
  }
}
  @override
  void dispose() { _ContractFormHostCbs.unbind(this); super.dispose(); }

  // Espone la mappa con le CHIAVI attese dal dialog (_onCreatePressed)
  Map<String, String> get model => {
    // Identificativi
    'tipo'        : _c['tipo']?.text.trim() ?? '',
    'tpCar'       : _c['tpCar']?.text.trim() ?? '',
    'ramo'        : _c['ramo']?.text.trim() ?? '',
    'compagnia'   : _c['compagnia']?.text.trim() ?? '',
    'numero'      : _c['numero']?.text.trim() ?? '',

    // Amministrativi base
    'effetto'     : _c['effetto']?.text.trim() ?? '',
    'scadenza'    : _c['scadenza']?.text.trim() ?? '',
    'emissione'   : _c['data_emissione']?.text.trim() ?? '',
    'fraz'        : _c['fraz']?.text.trim() ?? '',
    'modIncasso'  : _c['modIncasso']?.text.trim() ?? '',

    // Amministrativi opz./extra (chiavi attese dal dialog)
    'compresoFirma'      : _compresoFirma ? 'true' : 'false', // stringa che il dialogo convertirà
    'scadenza_originaria': _c['scadenza_originaria']?.text.trim() ?? '',
    'ultima_rata_pagata' : _c['ultima_rata_pagata']?.text.trim() ?? '',
    'sc_mora'            : _c['scadenza_mora']?.text.trim() ?? '',
    'numeroProposta'     : _c['numeroProposta']?.text.trim() ?? '',
    'codConvenzione'     : _c['codConvenzione']?.text.trim() ?? '',
    'sc_vincolo'         : _c['scadenza_vincolo']?.text.trim() ?? '',
    'sc_copertura'       : _c['scadenza_copertura']?.text.trim() ?? '',
    'fine_proroga'       : _c['fine_copertura_proroga']?.text.trim() ?? '',

    // Premi
    'premio'     : _c['premio']?.text.trim() ?? '',
    'netto'      : _c['netto']?.text.trim() ?? '',
    'accessori'  : _c['accessori']?.text.trim() ?? '',
    'diritti'    : _c['diritti']?.text.trim() ?? '',
    'imposte'    : _c['imposte']?.text.trim() ?? '',
    'spese'      : _c['spese']?.text.trim() ?? '',
    'fondo'      : _c['fondo']?.text.trim() ?? '',
    'sconto'     : _c['sconto']?.text.trim() ?? '',

    // Unità vendita
    'pv1'         : _c['pv1']?.text.trim() ?? '',
    'pv2'         : _c['pv2']?.text.trim() ?? '',
    'account'     : _c['account']?.text.trim() ?? '',
    'intermediario': _c['intermediario']?.text.trim() ?? '',

    // Rinnovo
    'rinnovo'    : _c['rinnovo']?.text.trim() ?? '',
    'disdetta'   : _c['disdetta']?.text.trim() ?? '',
    'gMora'      : _c['gMora']?.text.trim() ?? '',
    'proroga'    : _c['proroga']?.text.trim() ?? '',

    // Operatività / Regolazione
    'inizioReg'  : _c['inizio_reg']?.text.trim() ?? '',
    'fineReg'    : _c['fine_reg']?.text.trim() ?? '',
    'ultReg'     : _c['ultima_reg']?.text.trim() ?? '',
    'gInvio'     : _c['gInvio']?.text.trim() ?? '',
    'gPag'       : _c['gPag']?.text.trim() ?? '',
    'gMoraReg'   : _c['gMoraReg']?.text.trim() ?? '',
    'cadReg'     : _c['cadReg']?.text.trim() ?? '',

    // Rischio / Prodotto
    'rami_desc'  : _c['ramiDesc']?.text.trim() ?? '',
  };

  // Controllers di TUTTI i campi
  final _c = <String, TextEditingController>{
    // Identificativi
    'tipo': TextEditingController(),
    'tpCar': TextEditingController(),
    'ramo': TextEditingController(),
    'compagnia': TextEditingController(),
    'numero': TextEditingController(),

    // Amministrativi base
    'effetto': TextEditingController(),
    'scadenza': TextEditingController(),
    'data_emissione': TextEditingController(),
    'fraz': TextEditingController(text: 'Annuale'),
    'modIncasso': TextEditingController(text: 'Bonifico'),

    // Amministrativi opz./extra
    'scadenza_mora': TextEditingController(),
    'numeroProposta': TextEditingController(),
    'codConvenzione': TextEditingController(),
    'scadenza_vincolo': TextEditingController(),
    'scadenza_copertura': TextEditingController(),
    'fine_copertura_proroga': TextEditingController(),
    'scadenza_originaria': TextEditingController(),
    'ultima_rata_pagata': TextEditingController(),

    // Premi
    'premio': TextEditingController(text: '0'),
    'netto': TextEditingController(text: '0'),
    'accessori': TextEditingController(text: '0'),
    'diritti': TextEditingController(text: '0'),
    'imposte': TextEditingController(text: '0'),
    'spese': TextEditingController(text: '0'),
    'fondo': TextEditingController(text: '0'),
    'sconto': TextEditingController(text: '0'),

    // Unità vendita
    'pv1': TextEditingController(),
    'pv2': TextEditingController(),
    'account': TextEditingController(),
    'intermediario': TextEditingController(),

    // Rinnovo
    'rinnovo': TextEditingController(),
    'disdetta': TextEditingController(),
    'gMora': TextEditingController(),
    'proroga': TextEditingController(),

    // Operatività / Regolazione
    'inizio_reg': TextEditingController(),
    'fine_reg': TextEditingController(),
    'ultima_reg': TextEditingController(),
    'gInvio': TextEditingController(),
    'gPag': TextEditingController(),
    'gMoraReg': TextEditingController(),
    'cadReg': TextEditingController(),

    // Rischio / Prodotto
    'ramiDesc': TextEditingController(),
  };

  // Focus nodes
  final _f = { for (final k in ContractFormPane._allFields) k: FocusNode() };

  // Checkbox / flag
  bool _regolazione = false;
  bool _compresoFirma = false; // ⬅️ nuovo flag allineato al SDK
  bool get regolazione => _regolazione;

  // typing
  final _gen = <String,int>{};
  static const _kDefaultTypingMs = 22;

  Future<void> _typeInto(String key, String target, {required int ms}) async {
    final ctrl = _c[key]; if (ctrl == null) return;
    final id = (_gen[key] ?? 0) + 1; _gen[key] = id;

    final cur = ctrl.text;
    final keep = _commonPrefixLen(cur, target);

    for (int i = cur.length; i > keep; i--) {
      if (_gen[key] != id) return;
      ctrl.text = cur.substring(0, i - 1);
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      await Future.delayed(Duration(milliseconds: ms));
    }
    for (int i = keep; i < target.length; i++) {
      if (_gen[key] != id) return;
      ctrl.text = target.substring(0, i + 1);
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  int _commonPrefixLen(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0; while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) i++;
    return i;
  }

  // UI helper
  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());
  Widget _t(String key, String label, {String? hint}) =>
      TextField(controller: _c[key], focusNode: _f[key], decoration: _dec(label).copyWith(hintText: hint));

  // Esposizione "raw" (facoltativa)
  Map<String,String> get values => { for (final e in _c.entries) e.key: e.value.text.trim() };

  // Host API (gestisce anche i booleani)
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    if (field == 'regolazione' || field == 'compresoFirma') {
      final v = (value is bool) ? value : (value.toString().toLowerCase() == 'true');
      setState(() {
        if (field == 'regolazione') _regolazione = v;
        if (field == 'compresoFirma') _compresoFirma = v;
      });
      return;
    }

    await _typeInto(field, value?.toString() ?? '', ms: ms);
    final node = _f[field];
    if (node != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
    }
  }

  Future<void> fill(Map<String, dynamic> m, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    // ordine “umano”: mettiamo i nuovi campi vicino agli omologhi
    final order = [
      // Identificativi
      'tipo','ramo','compagnia','numero',

      // Amministrativi base
      'effetto','scadenza','data_emissione','fraz','modIncasso',

      // Amministrativi extra
      'scadenza_originaria','ultima_rata_pagata','compresoFirma',
      'scadenza_mora','numeroProposta','codConvenzione',
      'scadenza_vincolo','scadenza_copertura','fine_copertura_proroga',

      // Premi
      'premio','netto','imposte','accessori','diritti','spese','fondo','sconto',

      // Unità vendita
      'pv1','pv2','account','intermediario',

      // Rinnovo
      'rinnovo','disdetta','gMora','proroga',

      // Operatività / Regolazione
      'regolazione','inizio_reg','fine_reg','ultima_reg','gInvio','gPag','gMoraReg','cadReg',

      // Extra identificativi
      'tpCar',

      // Rischio / Prodotto
      'ramiDesc',
    ];

    final keys = [...order.where(m.containsKey), ...m.keys.where((k) => !order.contains(k))];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      await setField(k, v, typingMs: ms);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identificativi
          Text('Identificativi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _t('tipo', 'Tipo *')),
            const SizedBox(width: 8),
            Expanded(child: _t('tpCar', 'TpCar')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _t('ramo', 'Ramo *')),
            const SizedBox(width: 8),
            Expanded(child: _t('compagnia', 'Compagnia *')),
          ]),
          const SizedBox(height: 8),
          _t('numero', 'Numero polizza *'),

          const Divider(height: 24),
          Text('Amministrativi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _t('effetto',   'Effetto *',  hint: 'gg/mm/aaaa')),
            const SizedBox(width: 8),
            Expanded(child: _t('scadenza',  'Scadenza *', hint: 'gg/mm/aaaa')),
          ]),
          const SizedBox(height: 8),
          _t('data_emissione', 'Data emissione *', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 8),

          // Nuovi campi SDK
          Row(children: [
            Expanded(child: _t('scadenza_originaria', 'Scadenza originaria *', hint: 'gg/mm/aaaa')),
            const SizedBox(width: 8),
            Expanded(child: _t('ultima_rata_pagata',  'Ultima rata pagata *',   hint: 'gg/mm/aaaa')),
          ]),
          const SizedBox(height: 8),

          // Compreso firma (checkbox)
          Row(children: [
            Checkbox(
              value: _compresoFirma,
              onChanged: (v) => setState(() => _compresoFirma = v ?? false),
            ),
            const Text('Compreso firma'),
          ]),
          const SizedBox(height: 8),

          _t('fraz', 'Frazionamento *'),
          const SizedBox(height: 8),
          _t('modIncasso', 'Modalità incasso *'),

          const Divider(height: 24),
          Text('Altri dati Amministrativi (facoltativi)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _t('scadenza_mora', 'Scadenza Mora', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 8),
          _t('numeroProposta', 'Numero proposta'),
          const SizedBox(height: 8),
          _t('codConvenzione', 'Codice convenzione'),
          const SizedBox(height: 8),
          _t('scadenza_vincolo', 'Scadenza Vincolo', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 8),
          _t('scadenza_copertura', 'Scadenza Copertura', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 8),
          _t('fine_copertura_proroga', 'Fine copertura proroga', hint: 'gg/mm/aaaa'),

          const Divider(height: 24),
          Text('Premi', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width:110, child: _t('premio',    'Premio *')),
            SizedBox(width:110, child: _t('netto',     'Netto *')),
            SizedBox(width:110, child: _t('accessori', 'Accessori')),
            SizedBox(width:110, child: _t('diritti',   'Diritti')),
            SizedBox(width:110, child: _t('imposte',   'Imposte')),
            SizedBox(width:110, child: _t('spese',     'Spese')),
            SizedBox(width:110, child: _t('fondo',     'Fondo')),
            SizedBox(width:110, child: _t('sconto',    'Sconto')),
          ]),

          const Divider(height: 24),
          Text('Unità vendita', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _t('pv1', 'Punto vendita *'),
          const SizedBox(height: 8),
          _t('pv2', 'Punto vendita 2'),
          const SizedBox(height: 8),
          _t('account', 'Account *'),
          const SizedBox(height: 8),
          _t('intermediario', 'Intermediario *'),

          const Divider(height: 24),
          Text('Rinnovo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _t('rinnovo', 'Rinnovo'),
          const SizedBox(height: 8),
          _t('disdetta', 'Disdetta'),
          const SizedBox(height: 8),
          _t('gMora', 'Giorni Mora'),
          const SizedBox(height: 8),
          _t('proroga', 'Proroga'),

          const Divider(height: 24),
          Text('Operatività', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(
              value: _regolazione,
              onChanged: (v) => setState(() => _regolazione = v ?? false),
            ),
            const Text('Regolazione'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _t('inizio_reg', 'Inizio *', hint: 'gg/mm/aaaa')),
            const SizedBox(width: 8),
            Expanded(child: _t('fine_reg',   'Fine *',   hint: 'gg/mm/aaaa')),
          ]),
          const SizedBox(height: 8),
          _t('ultima_reg', 'Ultima reg. emessa', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: SizedBox(width:110, child: _t('gInvio', 'Giorni invio dati'))),
            const SizedBox(width: 8),
            Expanded(child: SizedBox(width:110, child: _t('gPag',  'Giorni pag. reg.'))),
          ]),
          const SizedBox(height: 8),
          SizedBox(width:110, child: _t('gMoraReg', 'Giorni mora regolaz.')),
          const SizedBox(height: 8),
          _t('cadReg', 'Cadenza regolazione'),

          const Divider(height: 24),
          Text('Rischio / Prodotto', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _t('ramiDesc', 'Descrizione *'),
          const SizedBox(height: 8),
        ],
      ),
    )));
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/* HostCallbacks: binding esplicito allo State                             */
/*─────────────────────────────────────────────────────────────────────────*/
class _ContractFormHostCbs extends ChatBotHostCallbacks {
  const _ContractFormHostCbs();

  static ContractFormPaneState? _bound;
  static void bind(ContractFormPaneState s) {
    _bound = s;
    debugPrint('[ContractHost] bound to ${s.hashCode}');
  }
  static void unbind(ContractFormPaneState s) {
    if (_bound == s) {
      _bound = null;
      debugPrint('[ContractHost] unbound');
    }
  }

  ContractFormPaneState? get _s => _bound;

  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    debugPrint('[ContractHost] setField $field="$value" typingMs=$typingMs bound=${_s!=null}');
    await _s?.setField(field, value, typingMs: typingMs);
  }

  Future<void> fillAll(Map<String, dynamic> payload, {int? typingMs}) async {
    debugPrint('[ContractHost] fillAll keys=${payload.keys} typingMs=$typingMs bound=${_s!=null}');
    await _s?.fill(payload, typingMs: typingMs);
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  Tool executors                                                         */
/*─────────────────────────────────────────────────────────────────────────*/
class _FillContractFormExec extends StatefulWidget {
  const _FillContractFormExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ContractFormHostCbs host;
  @override State<_FillContractFormExec> createState() => _FillContractFormExecState();
}
class _FillContractFormExecState extends State<_FillContractFormExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[FillContractExec] json=${widget.json} first=$first');
    if (!first) return;

    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;
    final keys = ContractFormPane._allFields;
    final map  = <String,dynamic>{
      for (final k in keys) if (widget.json.containsKey(k)) k: widget.json[k]
    };

    if (map.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.fillAll(map, typingMs: ms));
    }
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}

class _SetContractFieldExec extends StatefulWidget {
  const _SetContractFieldExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ContractFormHostCbs host;
  @override State<_SetContractFieldExec> createState() => _SetContractFieldExecState();
}
class _SetContractFieldExecState extends State<_SetContractFieldExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[SetContractExec] json=${widget.json} first=$first');
    if (!first) return;
    final field = (widget.json['field'] ?? '').toString();
    final value = widget.json['value'];
    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;

    if (field.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.setField(field, value, typingMs: ms));
    }
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}
