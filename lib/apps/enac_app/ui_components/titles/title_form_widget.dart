// lib/apps/enac_app/ui_components/title_form_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';

/// Pane di form per TITOLO con estensioni ChatBot.
/// PRIMO campo: selezione Contratto (OBBLIGATORIO, NON autocompilabile).
/// Espone `selectedContractId` e `model` al dialog.
class TitleFormPane extends StatefulWidget with ChatBotExtensions {
  const TitleFormPane({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final String entityId;

  @override
  State<TitleFormPane> createState() => TitleFormPaneState();

  /*───────────────────────────────────────────────────────────────*/
  /* Tool: riempi TUTTI i campi (tutti opzionali)                   */
  /*  ⚠️ NON include il contratto!                                  */
  /*───────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillTitleFormWidget',
    description:
        'Compila il form titolo con digitazione simulata. Tutti i parametri sono opzionali. Il contratto NON è autocompilabile.',
    params: const [
      // Obbligatori modello
      ToolParamSpec(
          name: 'tipo',
          paramType: ParamType.string,
          description: 'Tipo (RATA/QUIETANZA/APPENDICE/VARIAZIONE)',
          example: 'RATA'),
      ToolParamSpec(
          name: 'effetto_titolo',
          paramType: ParamType.string,
          description: 'Data effetto (dd/MM/yyyy)',
          example: '01/02/2026'),
      ToolParamSpec(
          name: 'scadenza_titolo',
          paramType: ParamType.string,
          description: 'Data scadenza (dd/MM/yyyy)',
          example: '01/03/2026'),

      // Opzionali
      ToolParamSpec(
          name: 'descrizione',
          paramType: ParamType.string,
          description: 'Descrizione',
          example: 'Prima rata'),
      ToolParamSpec(
          name: 'progressivo',
          paramType: ParamType.string,
          description: 'Progressivo',
          example: '001'),
      ToolParamSpec(
          name: 'stato',
          paramType: ParamType.string,
          description: 'Stato (DA_PAGARE/PAGATO/ANNULLATO/INSOLUTO)',
          example: 'DA_PAGARE'),
      ToolParamSpec(
          name: 'imponibile',
          paramType: ParamType.number,
          description: 'Imponibile',
          example: 1000.0,
          minValue: 0),
      ToolParamSpec(
          name: 'premio_lordo',
          paramType: ParamType.number,
          description: 'Premio lordo',
          example: 1200.0,
          minValue: 0),
      ToolParamSpec(
          name: 'imposte',
          paramType: ParamType.number,
          description: 'Imposte',
          example: 200.0,
          minValue: 0),
      ToolParamSpec(
          name: 'accessori',
          paramType: ParamType.number,
          description: 'Accessori',
          example: 10.0,
          minValue: 0),
      ToolParamSpec(
          name: 'diritti',
          paramType: ParamType.number,
          description: 'Diritti',
          example: 5.0,
          minValue: 0),
      ToolParamSpec(
          name: 'spese',
          paramType: ParamType.number,
          description: 'Spese',
          example: 5.0,
          minValue: 0),
      ToolParamSpec(
          name: 'frazionamento',
          paramType: ParamType.string,
          description:
              'Frazionamento (ANNUALE/SEMESTRALE/TRIMESTRALE/MENSILE)',
          example: 'ANNUALE'),
      ToolParamSpec(
          name: 'giorni_mora',
          paramType: ParamType.integer,
          description: 'Giorni di mora',
          example: 0,
          minValue: 0),
      ToolParamSpec(
          name: 'cig',
          paramType: ParamType.string,
          description: 'CIG',
          example: 'CIG123'),
      ToolParamSpec(
          name: 'pv',
          paramType: ParamType.string,
          description: 'Punto Vendita',
          example: 'PV Milano 1'),
      ToolParamSpec(
          name: 'pv2',
          paramType: ParamType.string,
          description: 'Punto Vendita 2',
          example: 'PV Milano 2'),
      ToolParamSpec(
          name: 'quietanza_numero',
          paramType: ParamType.string,
          description: 'Numero quietanza',
          example: 'Q123'),
      ToolParamSpec(
          name: 'data_pagamento',
          paramType: ParamType.string,
          description: 'Data pagamento (dd/MM/yyyy)',
          example: '10/03/2026'),
      ToolParamSpec(
          name: 'metodo_incasso',
          paramType: ParamType.string,
          description: 'Metodo incasso',
          example: 'Bonifico'),
      ToolParamSpec(
          name: 'numero_polizza',
          paramType: ParamType.string,
          description: 'Numero polizza (denormalizzato)',
          example: 'POL123'),

      // Digitazione
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description:
            'Millisecondi per carattere (digitazione simulata). Default 22.',
        example: 18,
        defaultValue: 22,
        minValue: 0,
        maxValue: 200,
      ),
    ],
  );

  /*───────────────────────────────────────────────────────────────*/
  /* Tool: set SINGOLO campo (⚠️ niente contratto)                   */
  /*───────────────────────────────────────────────────────────────*/
  static final List<String> _allFields = [
    'tipo',
    'effetto_titolo',
    'scadenza_titolo',
    'descrizione',
    'progressivo',
    'stato',
    'imponibile',
    'premio_lordo',
    'imposte',
    'accessori',
    'diritti',
    'spese',
    'frazionamento',
    'giorni_mora',
    'cig',
    'pv',
    'pv2',
    'quietanza_numero',
    'data_pagamento',
    'metodo_incasso',
    'numero_polizza',
  ];

  static final ToolSpec setTool = ToolSpec(
    toolName: 'SetTitleFieldWidget',
    description:
        'Imposta un singolo campo del titolo con digitazione simulata. Il contratto NON è impostabile via tool.',
    params: [
      ToolParamSpec(
        name: 'field',
        paramType: ParamType.string,
        description: 'Nome del campo',
        allowedValues: _allFields,
        example: 'premio_lordo',
      ),
      ToolParamSpec(
        name: 'value',
        paramType: ParamType.string,
        description:
            'Valore (date dd/MM/yyyy; numeri come stringa; per interi usa cifre).',
        example: '1200.00',
      ),
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata).',
        example: 20,
        defaultValue: 22,
        minValue: 0,
        maxValue: 200,
      ),
    ],
  );

  @override
  List<ToolSpec> get toolSpecs => [fillTool, setTool];

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'FillTitleFormWidget': (json, onR, pCbs, hCbs) =>
            _FillTitleFormExec(json: json, host: hCbs as _TitleFormHostCbs),
        'SetTitleFieldWidget': (json, onR, pCbs, hCbs) =>
            _SetTitleFieldExec(json: json, host: hCbs as _TitleFormHostCbs),
      };

  @override
  ChatBotHostCallbacks get hostCallbacks => const _TitleFormHostCbs();
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  STATE                                                                  */
/*─────────────────────────────────────────────────────────────────────────*/
class TitleFormPaneState extends State<TitleFormPane> {
  @override
  void initState() {
    super.initState();
    _TitleFormHostCbs.bind(this);
    _loadContracts();
  }

  @override
  void dispose() {
    _TitleFormHostCbs.unbind(this);
    super.dispose();
  }

  // ▼▼▼ CONTRATTI — caricamento per il selettore (manuale) ▼▼▼
  bool _loadingContracts = true;
  String? _loadError;
  String? _selectedContractId; // scelto manualmente
  final Map<String, String> _contractsLabel = {}; // id -> label

  Future<void> _loadContracts() async {
    setState(() {
      _loadingContracts = true;
      _loadError = null;
    });
    try {
      final userId = widget.user.username;
      final ids = await widget.sdk.listContracts(userId, widget.entityId);

      for (final id in ids) {
        try {
          final c = await widget.sdk.getContract(userId, widget.entityId, id);
          final lab =
              '${c.identificativi.compagnia} – ${c.identificativi.numeroPolizza} (${c.identificativi.ramo})';
          _contractsLabel[id] = lab;
        } catch (_) {
          _contractsLabel[id] = id; // fallback
        }
      }
    } catch (e) {
      _loadError = 'Errore nel caricamento dei contratti: $e';
    } finally {
      if (mounted) setState(() => _loadingContracts = false);
    }
  }

  // Espone l’id contratto selezionato al dialog
  String? get selectedContractId => _selectedContractId;

  // ▼▼▼ MODELLO CAMPI ▼▼▼
  Map<String, String> get model => {
        'tipo': _c['tipo']?.text.trim() ?? '',
        'effetto_titolo': _c['effetto_titolo']?.text.trim() ?? '',
        'scadenza_titolo': _c['scadenza_titolo']?.text.trim() ?? '',
        'descrizione': _c['descrizione']?.text.trim() ?? '',
        'progressivo': _c['progressivo']?.text.trim() ?? '',
        'stato': _c['stato']?.text.trim() ?? '',
        'imponibile': _c['imponibile']?.text.trim() ?? '',
        'premio_lordo': _c['premio_lordo']?.text.trim() ?? '',
        'imposte': _c['imposte']?.text.trim() ?? '',
        'accessori': _c['accessori']?.text.trim() ?? '',
        'diritti': _c['diritti']?.text.trim() ?? '',
        'spese': _c['spese']?.text.trim() ?? '',
        'frazionamento': _c['frazionamento']?.text.trim() ?? '',
        'giorni_mora': _c['giorni_mora']?.text.trim() ?? '',
        'cig': _c['cig']?.text.trim() ?? '',
        'pv': _c['pv']?.text.trim() ?? '',
        'pv2': _c['pv2']?.text.trim() ?? '',
        'quietanza_numero': _c['quietanza_numero']?.text.trim() ?? '',
        'data_pagamento': _c['data_pagamento']?.text.trim() ?? '',
        'metodo_incasso': _c['metodo_incasso']?.text.trim() ?? '',
        'numero_polizza': _c['numero_polizza']?.text.trim() ?? '',
      };

  // Controllers
  final _c = <String, TextEditingController>{
    'tipo': TextEditingController(),
    'effetto_titolo': TextEditingController(),
    'scadenza_titolo': TextEditingController(),
    'descrizione': TextEditingController(),
    'progressivo': TextEditingController(),
    'stato': TextEditingController(text: 'DA_PAGARE'),
    'imponibile': TextEditingController(text: '0'),
    'premio_lordo': TextEditingController(text: '0'),
    'imposte': TextEditingController(text: '0'),
    'accessori': TextEditingController(text: '0'),
    'diritti': TextEditingController(text: '0'),
    'spese': TextEditingController(text: '0'),
    'frazionamento': TextEditingController(text: 'ANNUALE'),
    'giorni_mora': TextEditingController(text: '0'),
    'cig': TextEditingController(),
    'pv': TextEditingController(),
    'pv2': TextEditingController(),
    'quietanza_numero': TextEditingController(),
    'data_pagamento': TextEditingController(),
    'metodo_incasso': TextEditingController(text: 'Bonifico'),
    'numero_polizza': TextEditingController(),
  };

  // Focus
  final _f = {
    for (final k in TitleFormPane._allFields) k: FocusNode(),
  };

  // typing engine
  final _gen = <String, int>{};
  static const _kDefaultTypingMs = 22;

  Future<void> _typeInto(String key, String target, {required int ms}) async {
    final ctrl = _c[key];
    if (ctrl == null) return;
    final id = (_gen[key] ?? 0) + 1;
    _gen[key] = id;

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
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) i++;
    return i;
  }

  // Host API (no contratto!)
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;
    await _typeInto(field, value?.toString() ?? '', ms: ms);
    final node = _f[field];
    if (node != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => node.requestFocus());
    }
  }

  Future<void> fill(Map<String, dynamic> m, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    // ordine umano (verticale, full-width)
    final order = [
      'tipo',
      'effetto_titolo',
      'scadenza_titolo',
      'descrizione',
      'progressivo',
      'stato',
      'imponibile',
      'premio_lordo',
      'imposte',
      'accessori',
      'diritti',
      'spese',
      'frazionamento',
      'giorni_mora',
      'cig',
      'pv',
      'pv2',
      'quietanza_numero',
      'data_pagamento',
      'metodo_incasso',
      'numero_polizza',
    ];

    final keys = [
      ...order.where(m.containsKey),
      ...m.keys.where((k) => !order.contains(k))
    ];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      await setField(k, v, typingMs: ms);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // UI helpers
  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        isDense: true,
        border: const OutlineInputBorder(),
      );
  Widget _t(String key, String label, {String? hint}) => TextField(
        controller: _c[key],
        focusNode: _f[key],
        decoration: _dec(label).copyWith(hintText: hint),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // ⬅️ full width
        children: [
          // ────────────────────── CONTRATTO (PRIMO CAMPO) ──────────────────────
          if (_loadingContracts)
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Carico polizze...'),
              ],
            )
          else if (_loadError != null)
            Text(_loadError!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error))
          else
            DropdownButtonFormField<String>(
              value: _selectedContractId,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'Contratto *',
              ),
              items: _contractsLabel.entries
                  .map((e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedContractId = v),
            ),

          const SizedBox(height: 12),

          // ────────────────────── Dati Titolo (full-width) ─────────────────────
          _t('tipo', 'Tipo *', hint: 'RATA / QUIETANZA / ...'),
          const SizedBox(height: 12),
          _t('effetto_titolo', 'Effetto *', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),
          _t('scadenza_titolo', 'Scadenza *', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),
          _t('descrizione', 'Descrizione'),
          const SizedBox(height: 12),
          _t('progressivo', 'Progressivo'),
          const SizedBox(height: 12),
          _t('stato', 'Stato', hint: 'DA_PAGARE/PAGATO/...'),

          const SizedBox(height: 12),
          _t('imponibile', 'Imponibile'),
          const SizedBox(height: 12),
          _t('premio_lordo', 'Premio lordo'),
          const SizedBox(height: 12),
          _t('imposte', 'Imposte'),
          const SizedBox(height: 12),
          _t('accessori', 'Accessori'),
          const SizedBox(height: 12),
          _t('diritti', 'Diritti'),
          const SizedBox(height: 12),
          _t('spese', 'Spese'),

          const SizedBox(height: 12),
          _t('frazionamento',
              'Frazionamento', // ANNUALE/SEMESTRALE/...
              hint: 'ANNUALE / ...'),
          const SizedBox(height: 12),
          _t('giorni_mora', 'Giorni mora'),
          const SizedBox(height: 12),
          _t('cig', 'CIG'),
          const SizedBox(height: 12),
          _t('pv', 'Punto vendita'),
          const SizedBox(height: 12),
          _t('pv2', 'Punto vendita 2'),

          const SizedBox(height: 12),
          _t('metodo_incasso', 'Metodo incasso', hint: 'Bonifico'),
          const SizedBox(height: 12),
          _t('data_pagamento', 'Data pagamento', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),
          _t('numero_polizza', 'Numero polizza (denorm.)'),
        ],
      ),
    );
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/* HostCallbacks: binding esplicito allo State                             */
/*─────────────────────────────────────────────────────────────────────────*/
class _TitleFormHostCbs extends ChatBotHostCallbacks {
  const _TitleFormHostCbs();

  static TitleFormPaneState? _bound;
  static void bind(TitleFormPaneState s) {
    _bound = s;
    debugPrint('[TitleHost] bound to ${s.hashCode}');
  }

  static void unbind(TitleFormPaneState s) {
    if (_bound == s) {
      _bound = null;
      debugPrint('[TitleHost] unbound');
    }
  }

  TitleFormPaneState? get _s => _bound;

  // ⚠️ Nessun metodo per impostare il contratto via tool
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    debugPrint(
        '[TitleHost] setField $field="$value" typingMs=$typingMs bound=${_s != null}');
    await _s?.setField(field, value, typingMs: typingMs);
  }

  Future<void> fillAll(Map<String, dynamic> payload, {int? typingMs}) async {
    debugPrint(
        '[TitleHost] fillAll keys=${payload.keys} typingMs=$typingMs bound=${_s != null}');
    await _s?.fill(payload, typingMs: typingMs);
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  Tool executors                                                         */
/*─────────────────────────────────────────────────────────────────────────*/
class _FillTitleFormExec extends StatefulWidget {
  const _FillTitleFormExec({required this.json, required this.host});
  final Map<String, dynamic> json;
  final _TitleFormHostCbs host;
  @override
  State<_FillTitleFormExec> createState() => _FillTitleFormExecState();
}

class _FillTitleFormExecState extends State<_FillTitleFormExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[FillTitleExec] json=${widget.json} first=$first');
    if (!first) return;

    final ms = (widget.json['typing_ms'] is int)
        ? widget.json['typing_ms'] as int
        : null;
    final keys = TitleFormPane._allFields;
    final map = <String, dynamic>{
      for (final k in keys)
        if (widget.json.containsKey(k)) k: widget.json[k]
    };

    if (map.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.host.fillAll(map, typingMs: ms));
    }
  }

  @override
  Widget build(BuildContext _) => const SizedBox.shrink();
}

class _SetTitleFieldExec extends StatefulWidget {
  const _SetTitleFieldExec({required this.json, required this.host});
  final Map<String, dynamic> json;
  final _TitleFormHostCbs host;
  @override
  State<_SetTitleFieldExec> createState() => _SetTitleFieldExecState();
}

class _SetTitleFieldExecState extends State<_SetTitleFieldExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[SetTitleExec] json=${widget.json} first=$first');
    if (!first) return;
    final field = (widget.json['field'] ?? '').toString();
    final value = widget.json['value'];
    final ms = (widget.json['typing_ms'] is int)
        ? widget.json['typing_ms'] as int
        : null;

    if (field.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.host.setField(field, value, typingMs: ms));
    }
  }

  @override
  Widget build(BuildContext _) => const SizedBox.shrink();
}
