// lib/apps/enac_app/ui_components/contract_form_pane.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

class ContractFormPane extends StatefulWidget with ChatBotExtensions {
  const ContractFormPane({super.key, this.initialValues});

  @override
  State<ContractFormPane> createState() => ContractFormPaneState();
  final Map<String, String>? initialValues;

  /*───────────────────────────────────────────────────────────────────────*/
  /* ToolSpec: COMPILA TUTTO (ogni parametro è opzionale)                  */
  /*───────────────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillContractFormWidget',
    description:
        'Compila il form contratto (solo campi richiesti). Ogni parametro è opzionale: se assente, il campo non viene toccato.',
    params: const [
      // Identificativi
      ToolParamSpec(name: 'tipo',                paramType: ParamType.string,  description: 'Tipo (COND | APP0 | APP€)', example: 'COND'),
      ToolParamSpec(name: 'rischio',             paramType: ParamType.string,  description: 'Rischio',                   example: 'Responsabilità Civile Auto'),
      ToolParamSpec(name: 'compagnia',           paramType: ParamType.string,  description: 'Compagnia',                 example: 'ACME Assicurazioni'),
      ToolParamSpec(name: 'numero',              paramType: ParamType.string,  description: 'Numero di Polizza/Appendice', example: 'POL-2025-001'),

      // Importi
      ToolParamSpec(name: 'premio_imponibile',   paramType: ParamType.number,  description: 'Premio Annuo Imponibile',   example: 1000.0, minValue: 0),
      ToolParamSpec(name: 'imposte',             paramType: ParamType.number,  description: 'Imposte',                   example: 220.0,  minValue: 0),
      ToolParamSpec(name: 'premio_lordo',        paramType: ParamType.number,  description: 'Premio Annuo Lordo',        example: 1220.0, minValue: 0),

      // Amministrativi / date
      ToolParamSpec(name: 'fraz',                paramType: ParamType.string,  description: 'Frazionamento',             example: 'Annuale'),
      ToolParamSpec(name: 'effetto',             paramType: ParamType.string,  description: 'Effetto (dd/MM/yyyy)',      example: '01/01/2026'),
      ToolParamSpec(name: 'scadenza',            paramType: ParamType.string,  description: 'Scadenza (dd/MM/yyyy)',     example: '01/01/2027'),
      ToolParamSpec(name: 'scadenza_copertura',  paramType: ParamType.string,  description: 'Scadenza Copertura (dd/MM/yyyy)', example: '31/01/2027'),
      ToolParamSpec(name: 'data_emissione',      paramType: ParamType.string,  description: 'Data di Emissione (dd/MM/yyyy)', example: '01/01/2026'),
      ToolParamSpec(name: 'giorni_mora',         paramType: ParamType.string,  description: 'Giorni di Mora',            example: '15'),

      // Broker
      ToolParamSpec(name: 'broker',              paramType: ParamType.string,  description: 'Broker',                    example: 'Intermediario ABC'),
      ToolParamSpec(name: 'broker_indirizzo',    paramType: ParamType.string,  description: 'Indirizzo del Broker',      example: 'Via Roma 1, Milano'),

      // Rinnovo / opzionali a scelta
      ToolParamSpec(name: 'tacito_rinnovo',            paramType: ParamType.string,  description: 'Tacito Rinnovo (Sì | No)', example: 'Sì'),
      ToolParamSpec(name: 'disdetta',                  paramType: ParamType.string,  description: 'Disdetta',                  example: '30 gg prima'),
      ToolParamSpec(name: 'proroga',                   paramType: ParamType.string,  description: 'Facoltà di Proroga',        example: '15 gg'),
      ToolParamSpec(name: 'regolazione_fine_periodo',  paramType: ParamType.boolean, description: 'Regolazione al termine del periodo', example: true),

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
    'tipo','rischio','compagnia','numero',
    // Importi
    'premio_imponibile','imposte','premio_lordo',
    // Amministrativi / date
    'fraz','effetto','scadenza','scadenza_copertura','data_emissione','giorni_mora',
    // Broker
    'broker','broker_indirizzo',
    // Rinnovo
    'tacito_rinnovo','disdetta','proroga','regolazione_fine_periodo',
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
        example: 'POL-2025-001',
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
  static const double _kFormMaxWidth = 600;

  // Selettori a scelta vincolata
  static const List<String> _tipoOptions = ['COND', 'APP0', 'APP€'];
  static const List<String> _siNoOptions = ['Sì', 'No'];

  String _tipo = _tipoOptions.first;
  String _tacito = _siNoOptions.first;
  bool _regolazioneFinePeriodo = false;

  // Controllers
  final _c = <String, TextEditingController>{
    // Identificativi
    'rischio': TextEditingController(),
    'compagnia': TextEditingController(),
    'numero': TextEditingController(),

    // Importi
    'premio_imponibile': TextEditingController(text: '0'),
    'imposte': TextEditingController(text: '0'),
    'premio_lordo': TextEditingController(text: '0'),

    // Amministrativi / date
    'fraz': TextEditingController(text: 'Annuale'),
    'effetto': TextEditingController(),
    'scadenza': TextEditingController(),
    'scadenza_copertura': TextEditingController(),
    'data_emissione': TextEditingController(),
    'giorni_mora': TextEditingController(),

    // Broker
    'broker': TextEditingController(),
    'broker_indirizzo': TextEditingController(),

    // Rinnovo
    'disdetta': TextEditingController(),
    'proroga': TextEditingController(),
  };

  // Focus nodes
  final _f = { for (final k in ContractFormPane._allFields) k: FocusNode() };

  // typing
  final _gen = <String,int>{};
  static const _kDefaultTypingMs = 22;

  /* -------------------- Helpers -------------------- */
  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());
  Widget _t(String key, String label, {String? hint}) =>
      TextField(controller: _c[key], focusNode: _f[key], decoration: _dec(label).copyWith(hintText: hint));

  static String _normSiNo(dynamic v) {
    if (v == null) return 'Sì';
    final s = v.toString().trim().toLowerCase();
    const yes = {'si','sì','true','1','y','yes'};
    const no  = {'no','false','0','n'};
    if (yes.contains(s)) return 'Sì';
    if (no.contains(s))  return 'No';
    return (s == 'app€' || s == 'app0' || s == 'cond') ? 'Sì' : (s.isEmpty ? 'Sì' : (v.toString())); // fallback
  }

  static String _normTipo(dynamic v) {
    if (v == null) return 'COND';
    final s = v.toString().trim().toUpperCase();
    if (s.startsWith('COND')) return 'COND';
    if (s == 'APP0' || s.contains('PREMIO NULLO')) return 'APP0';
    if (s == 'APP€' || s.contains('CON PREMIO'))  return 'APP€';
    return _tipoOptions.contains(s) ? s : 'COND';
  }

  // Digitazione simulata
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

  /* -------------------- Initial values -------------------- */
  void _setInitialValues(Map<String, String> m) {
    // testi
    for (final e in m.entries) {
      final k = e.key;
      final v = e.value;
      if (_c.containsKey(k)) {
        _c[k]!.text = v;
        _c[k]!.selection = TextSelection.collapsed(offset: _c[k]!.text.length);
      }
    }
    // select / booleani
    if (m.containsKey('tipo')) setState(() => _tipo = _normTipo(m['tipo']));
    if (m.containsKey('tacito_rinnovo')) setState(() => _tacito = _normSiNo(m['tacito_rinnovo']));
    if (m.containsKey('regolazione_fine_periodo')) {
      final v = m['regolazione_fine_periodo']!;
      setState(() => _regolazioneFinePeriodo =
          (v.toLowerCase() == 'true') || (v.toLowerCase() == 'sì') || (v.toLowerCase() == 'si') || (v == '1'));
    }
  }

  @override
  void initState() {
    super.initState();
    _ContractFormHostCbs.bind(this);
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

  // Modello (chiavi "pulite" per il dialog utilizzatore)
  Map<String, String> get model => {
    'tipo'                 : _tipo,
    'rischio'              : _c['rischio']?.text.trim() ?? '',
    'compagnia'            : _c['compagnia']?.text.trim() ?? '',
    'numero'               : _c['numero']?.text.trim() ?? '',
    'premio_imponibile'    : _c['premio_imponibile']?.text.trim() ?? '',
    'imposte'              : _c['imposte']?.text.trim() ?? '',
    'premio_lordo'         : _c['premio_lordo']?.text.trim() ?? '',
    'fraz'                 : _c['fraz']?.text.trim() ?? '',
    'effetto'              : _c['effetto']?.text.trim() ?? '',
    'scadenza'             : _c['scadenza']?.text.trim() ?? '',
    'scadenza_copertura'   : _c['scadenza_copertura']?.text.trim() ?? '',
    'data_emissione'       : _c['data_emissione']?.text.trim() ?? '',
    'giorni_mora'          : _c['giorni_mora']?.text.trim() ?? '',
    'broker'               : _c['broker']?.text.trim() ?? '',
    'broker_indirizzo'     : _c['broker_indirizzo']?.text.trim() ?? '',
    'tacito_rinnovo'       : _tacito,
    'disdetta'             : _c['disdetta']?.text.trim() ?? '',
    'proroga'              : _c['proroga']?.text.trim() ?? '',
    'regolazione_fine_periodo' : _regolazioneFinePeriodo ? 'Sì' : 'No',
  };

  // Esposizione "raw" (debug)
  Map<String,String> get values =>
      { for (final e in _c.entries) e.key: e.value.text.trim() }
        ..addAll({
          'tipo': _tipo,
          'tacito_rinnovo': _tacito,
          'regolazione_fine_periodo': _regolazioneFinePeriodo ? 'Sì' : 'No',
        });

  // Host API (gestisce select/booleani)
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    if (field == 'tipo') {
      setState(() => _tipo = _normTipo(value));
      return;
    }
    if (field == 'tacito_rinnovo') {
      setState(() => _tacito = _normSiNo(value));
      return;
    }
    if (field == 'regolazione_fine_periodo') {
      final v = (value is bool)
          ? value
          : (value.toString().toLowerCase() == 'true' ||
             value.toString().toLowerCase() == 'sì' ||
             value.toString().toLowerCase() == 'si'  ||
             value.toString() == '1');
      setState(() => _regolazioneFinePeriodo = v);
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

    // ordine “umano”
    final order = [
      'tipo','rischio','compagnia','numero',
      'premio_imponibile','imposte','premio_lordo',
      'fraz','effetto','scadenza','scadenza_copertura','data_emissione','giorni_mora',
      'broker','broker_indirizzo',
      'tacito_rinnovo','disdetta','proroga','regolazione_fine_periodo',
    ];

    final keys = [...order.where(m.containsKey), ...m.keys.where((k) => !order.contains(k))];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      await setField(k, v, typingMs: ms);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /* ---------------------------- UI ---------------------------- */
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

              // Tipo (dropdown vincolato)
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: _dec('Tipo *'),
                items: const [
                  DropdownMenuItem(value: 'COND', child: Text('Condizioni di Polizza (COND)')),
                  DropdownMenuItem(value: 'APP0', child: Text('Appendice a premio nullo (APP0)')),
                  DropdownMenuItem(value: 'APP€', child: Text('Appendice con premio (APP€)')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'COND'),
              ),
              const SizedBox(height: 8),

              _t('rischio', 'Rischio *'),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: _t('compagnia', 'Compagnia *')),
                const SizedBox(width: 8),
                Expanded(child: _t('numero', 'Numero di Polizza/Appendice *')),
              ]),

              const Divider(height: 24),
              Text('Importi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('premio_imponibile', 'Premio Annuo Imponibile *')),
                const SizedBox(width: 8),
                Expanded(child: _t('imposte', 'Imposte *')),
              ]),
              const SizedBox(height: 8),
              _t('premio_lordo', 'Premio Annuo Lordo *'),

              const Divider(height: 24),
              Text('Amministrativi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _t('fraz', 'Frazionamento *'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('effetto',   'Effetto *',  hint: 'gg/mm/aaaa')),
                const SizedBox(width: 8),
                Expanded(child: _t('scadenza',  'Scadenza *', hint: 'gg/mm/aaaa')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('scadenza_copertura', 'Scadenza Copertura *', hint: 'gg/mm/aaaa')),
                const SizedBox(width: 8),
                Expanded(child: _t('data_emissione', 'Data di Emissione *', hint: 'gg/mm/aaaa')),
              ]),
              const SizedBox(height: 8),
              _t('giorni_mora', 'Giorni di Mora'),

              const Divider(height: 24),
              Text('Broker & Rinnovo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _t('broker', 'Broker *'),
              const SizedBox(height: 8),
              _t('broker_indirizzo', 'Indirizzo del Broker *'),
              const SizedBox(height: 8),
              Row(children: [
                // Tacito Rinnovo (dropdown Sì/No)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tacito,
                    decoration: _dec('Tacito Rinnovo *'),
                    items: _siNoOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _tacito = v ?? 'Sì'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _t('disdetta', 'Disdetta')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('proroga', 'Facoltà di Proroga')),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _regolazioneFinePeriodo ? 'Sì' : 'No',
                    decoration: _dec('Regolazione al termine del periodo *'),
                    items: _siNoOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _regolazioneFinePeriodo = (v == 'Sì')),
                  ),
                ),
              ]),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
