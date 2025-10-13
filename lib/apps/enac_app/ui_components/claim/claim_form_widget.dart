import 'dart:async';
import 'package:flutter/material.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';

/// Pane di form per SINISTRO con estensioni ChatBot.
/// PRIMO campo: selezione Contratto (OBBLIGATORIO, NON autocompilabile).
/// Espone `selectedContractId` e `model` al dialog.
class ClaimFormPane extends StatefulWidget with ChatBotExtensions {
  const ClaimFormPane({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
    this.initialValues,
    this.initialContractId,
    this.lockContract = false,
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final String entityId;
  final Map<String, String>? initialValues;
  final String? initialContractId;
  final bool lockContract;
  @override
  State<ClaimFormPane> createState() => ClaimFormPaneState();

  /*───────────────────────────────────────────────────────────────*/
  /* Tool: riempi TUTTI i campi (tutti opzionali)                   */
  /*  ⚠️ NON include il contratto!                                  */
  /*───────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillClaimFormWidget',
    description:
        'Compila il form sinistro con digitazione simulata. Tutti i parametri sono opzionali. Il contratto NON è autocompilabile.',
    params: const [
      // Obbligatori del modello Sinistro
      ToolParamSpec(
          name: 'esercizio',
          paramType: ParamType.integer,
          description: 'Esercizio (anno intero)',
          example: 2025,
          minValue: 1900),
      ToolParamSpec(
          name: 'numero_sinistro',
          paramType: ParamType.string,
          description: 'Numero sinistro',
          example: 'SIN-000123'),
      ToolParamSpec(
          name: 'data_avvenimento',
          paramType: ParamType.string,
          description: 'Data avvenimento (dd/MM/yyyy)',
          example: '15/05/2025'),

      // Opzionali
      ToolParamSpec(
          name: 'numero_sinistro_compagnia',
          paramType: ParamType.string,
          description: 'Numero sinistro compagnia',
          example: 'C-99123'),
      ToolParamSpec(
          name: 'numero_polizza',
          paramType: ParamType.string,
          description: 'Numero polizza (denormalizzato)',
          example: 'POL123'),
      ToolParamSpec(
          name: 'compagnia',
          paramType: ParamType.string,
          description: 'Compagnia',
          example: 'Allianz'),
      ToolParamSpec(
          name: 'rischio',
          paramType: ParamType.string,
          description: 'Rischio',
          example: 'RCA'),
      ToolParamSpec(
          name: 'intermediario',
          paramType: ParamType.string,
          description: 'Intermediario',
          example: 'Intermediario S.p.A.'),
      ToolParamSpec(
          name: 'descrizione_assicurato',
          paramType: ParamType.string,
          description: 'Descrizione assicurato',
          example: 'Parco mezzi aziendale'),
      ToolParamSpec(
          name: 'citta',
          paramType: ParamType.string,
          description: 'Città avvenimento',
          example: 'Milano'),
      ToolParamSpec(
          name: 'indirizzo',
          paramType: ParamType.string,
          description: 'Indirizzo avvenimento',
          example: 'Via Roma 10'),
      ToolParamSpec(
          name: 'cap',
          paramType: ParamType.string,
          description: 'CAP avvenimento',
          example: '20100'),
      ToolParamSpec(
          name: 'provincia',
          paramType: ParamType.string,
          description: 'Provincia',
          example: 'MI'),
      ToolParamSpec(
          name: 'codice_stato',
          paramType: ParamType.string,
          description: 'Codice stato sinistro',
          example: 'APERTO'),
      ToolParamSpec(
          name: 'targa',
          paramType: ParamType.string,
          description: 'Targa veicolo',
          example: 'AB123CD'),
      ToolParamSpec(
          name: 'dinamica',
          paramType: ParamType.string,
          description: 'Dinamica del sinistro',
          example: 'Tamponamento al semaforo'),
      ToolParamSpec(
          name: 'stato_compagnia',
          paramType: ParamType.string,
          description: 'Stato presso compagnia',
          example: 'Istruttoria'),

      // Date opzionali aggiuntive
      ToolParamSpec(
          name: 'data_apertura',
          paramType: ParamType.string,
          description: 'Data apertura (dd/MM/yyyy)',
          example: '16/05/2025'),
      ToolParamSpec(
          name: 'data_chiusura',
          paramType: ParamType.string,
          description: 'Data chiusura (dd/MM/yyyy)',
          example: '30/06/2025'),

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
    'esercizio',
    'numero_sinistro',
    'numero_sinistro_compagnia',
    'numero_polizza',
    'compagnia',
    'rischio',
    'intermediario',
    'descrizione_assicurato',
    'data_avvenimento',
    'citta',
    'indirizzo',
    'cap',
    'provincia',
    'codice_stato',
    'targa',
    'dinamica',
    'stato_compagnia',
    'data_apertura',
    'data_chiusura',
  ];

  static final ToolSpec setTool = ToolSpec(
    toolName: 'SetClaimFieldWidget',
    description:
        'Imposta un singolo campo del sinistro con digitazione simulata. Il contratto NON è impostabile via tool.',
    params: [
      ToolParamSpec(
        name: 'field',
        paramType: ParamType.string,
        description: 'Nome del campo',
        allowedValues: _allFields,
        example: 'numero_sinistro',
      ),
      ToolParamSpec(
        name: 'value',
        paramType: ParamType.string,
        description:
            'Valore (date dd/MM/yyyy; numeri come stringa; per interi usa cifre).',
        example: 'SIN-000123',
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
        'FillClaimFormWidget': (json, onR, pCbs, hCbs) =>
            _FillClaimFormExec(json: json, host: hCbs as _ClaimFormHostCbs),
        'SetClaimFieldWidget': (json, onR, pCbs, hCbs) =>
            _SetClaimFieldExec(json: json, host: hCbs as _ClaimFormHostCbs),
      };

  @override
  ChatBotHostCallbacks get hostCallbacks => const _ClaimFormHostCbs();
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  STATE                                                                  */
/*─────────────────────────────────────────────────────────────────────────*/
class ClaimFormPaneState extends State<ClaimFormPane> {
  @override
  void initState() {
    super.initState();
    _ClaimFormHostCbs.bind(this);
    _loadContracts();

        // ⬇️ NEW: precompila campi e selezione contratto se passati
    if (widget.initialValues != null && widget.initialValues!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialValues(widget.initialValues!);
      });
    }
    _selectedContractId = widget.initialContractId; // ⬅️ NEW
  }

  @override
  void dispose() {
    _ClaimFormHostCbs.unbind(this);
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
        'esercizio': _c['esercizio']?.text.trim() ?? '',
        'numero_sinistro': _c['numero_sinistro']?.text.trim() ?? '',
        'numero_sinistro_compagnia': _c['numero_sinistro_compagnia']?.text.trim() ?? '',
        'numero_polizza': _c['numero_polizza']?.text.trim() ?? '',
        'compagnia': _c['compagnia']?.text.trim() ?? '',
        'rischio': _c['rischio']?.text.trim() ?? '',
        'intermediario': _c['intermediario']?.text.trim() ?? '',
        'descrizione_assicurato': _c['descrizione_assicurato']?.text.trim() ?? '',
        'data_avvenimento': _c['data_avvenimento']?.text.trim() ?? '',
        'citta': _c['citta']?.text.trim() ?? '',
        'indirizzo': _c['indirizzo']?.text.trim() ?? '',
        'cap': _c['cap']?.text.trim() ?? '',
        'provincia': _c['provincia']?.text.trim() ?? '',
        'codice_stato': _c['codice_stato']?.text.trim() ?? '',
        'targa': _c['targa']?.text.trim() ?? '',
        'dinamica': _c['dinamica']?.text.trim() ?? '',
        'stato_compagnia': _c['stato_compagnia']?.text.trim() ?? '',
        'data_apertura': _c['data_apertura']?.text.trim() ?? '',
        'data_chiusura': _c['data_chiusura']?.text.trim() ?? '',
      };

  // Controllers
  final _c = <String, TextEditingController>{
    'esercizio': TextEditingController(),
    'numero_sinistro': TextEditingController(),
    'numero_sinistro_compagnia': TextEditingController(),
    'numero_polizza': TextEditingController(),
    'compagnia': TextEditingController(),
    'rischio': TextEditingController(),
    'intermediario': TextEditingController(),
    'descrizione_assicurato': TextEditingController(),
    'data_avvenimento': TextEditingController(),
    'citta': TextEditingController(),
    'indirizzo': TextEditingController(),
    'cap': TextEditingController(),
    'provincia': TextEditingController(),
    'codice_stato': TextEditingController(),
    'targa': TextEditingController(),
    'dinamica': TextEditingController(),
    'stato_compagnia': TextEditingController(),
    'data_apertura': TextEditingController(),
    'data_chiusura': TextEditingController(),
  };

  // Focus
  final _f = {
    for (final k in ClaimFormPane._allFields) k: FocusNode(),
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
      WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
    }
  }

  Future<void> fill(Map<String, dynamic> m, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    // ordine umano (verticale, full-width)
    final order = [
      'esercizio',
      'numero_sinistro',
      'numero_sinistro_compagnia',
      'numero_polizza',
      'compagnia',
      'rischio',
      'intermediario',
      'descrizione_assicurato',
      'data_avvenimento',
      'citta',
      'indirizzo',
      'cap',
      'provincia',
      'codice_stato',
      'targa',
      'dinamica',
      'stato_compagnia',
      'data_apertura',
      'data_chiusura',
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
  InputDecoration _dec(String l) => const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ).copyWith(labelText: l);

  Widget _t(String key, String label, {String? hint}) => TextField(
        controller: _c[key],
        focusNode: _f[key],
        decoration: _dec(label).copyWith(hintText: hint),
      );


  @override
  void didUpdateWidget(covariant ClaimFormPane old) {
    super.didUpdateWidget(old);
    if (widget.initialValues != old.initialValues &&
        widget.initialValues != null) {
      _setInitialValues(widget.initialValues!);            // ⬅️ NEW
    }
    if (widget.initialContractId != old.initialContractId) {
      setState(() => _selectedContractId = widget.initialContractId); // ⬅️ NEW
    }
  }

  // ⬇️ NEW: prefill “immediato” dei controller
  void _setInitialValues(Map<String, String> m) {
    for (final e in m.entries) {
      final k = e.key;
      final v = e.value;
      if (_c.containsKey(k)) {
        _c[k]!.text = v;
        _c[k]!.selection =
            TextSelection.collapsed(offset: _c[k]!.text.length);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                Text('Carico contratti...'),
              ],
            )
          else if (_loadError != null)
            Text(
              _loadError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
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
                        child: Text(
                          e.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
                            onChanged: widget.lockContract
                  ? null                                   // ⬅️ NEW: blocca in edit
                  : (v) => setState(() => _selectedContractId = v),
            ),

          const SizedBox(height: 12),

          // ────────────────────── Dati Sinistro (full-width) ───────────────────
          _t('esercizio', 'Esercizio *', hint: 'AAAA'),
          const SizedBox(height: 12),
          _t('numero_sinistro', 'Numero sinistro *'),
          const SizedBox(height: 12),
          _t('data_avvenimento', 'Data avvenimento *', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),

          _t('numero_sinistro_compagnia', 'Numero sinistro compagnia'),
          const SizedBox(height: 12),
          _t('numero_polizza', 'Numero polizza (denorm.)'),
          const SizedBox(height: 12),
          _t('compagnia', 'Compagnia'),
          const SizedBox(height: 12),
          _t('rischio', 'Rischio'),
          const SizedBox(height: 12),
          _t('intermediario', 'Intermediario'),
          const SizedBox(height: 12),
          _t('descrizione_assicurato', 'Descrizione assicurato'),

          const SizedBox(height: 12),
          _t('citta', 'Città avvenimento'),
          const SizedBox(height: 12),
          _t('indirizzo', 'Indirizzo avvenimento'),
          const SizedBox(height: 12),
          _t('cap', 'CAP avvenimento'),
          const SizedBox(height: 12),
          _t('provincia', 'Provincia'),

          const SizedBox(height: 12),
          _t('codice_stato', 'Codice stato'),
          const SizedBox(height: 12),
          _t('stato_compagnia', 'Stato presso compagnia'),

          const SizedBox(height: 12),
          _t('targa', 'Targa veicolo'),
          const SizedBox(height: 12),
          _t('dinamica', 'Dinamica del sinistro'),

          const SizedBox(height: 12),
          _t('data_apertura', 'Data apertura', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),
          _t('data_chiusura', 'Data chiusura', hint: 'gg/mm/aaaa'),
        ],
      ),
    );
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/* HostCallbacks: binding esplicito allo State                             */
/*─────────────────────────────────────────────────────────────────────────*/
class _ClaimFormHostCbs extends ChatBotHostCallbacks {
  const _ClaimFormHostCbs();

  static ClaimFormPaneState? _bound;
  static void bind(ClaimFormPaneState s) {
    _bound = s;
    debugPrint('[ClaimHost] bound to ${s.hashCode}');
  }

  static void unbind(ClaimFormPaneState s) {
    if (_bound == s) {
      _bound = null;
      debugPrint('[ClaimHost] unbound');
    }
  }

  ClaimFormPaneState? get _s => _bound;

  // ⚠️ Nessun metodo per impostare il contratto via tool
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    debugPrint(
        '[ClaimHost] setField $field="$value" typingMs=$typingMs bound=${_s != null}');
    await _s?.setField(field, value, typingMs: typingMs);
  }

  Future<void> fillAll(Map<String, dynamic> payload, {int? typingMs}) async {
    debugPrint(
        '[ClaimHost] fillAll keys=${payload.keys} typingMs=$typingMs bound=${_s != null}');
    await _s?.fill(payload, typingMs: typingMs);
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  Tool executors                                                         */
/*─────────────────────────────────────────────────────────────────────────*/
class _FillClaimFormExec extends StatefulWidget {
  const _FillClaimFormExec({required this.json, required this.host});
  final Map<String, dynamic> json;
  final _ClaimFormHostCbs host;
  @override
  State<_FillClaimFormExec> createState() => _FillClaimFormExecState();
}

class _FillClaimFormExecState extends State<_FillClaimFormExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[FillClaimExec] json=${widget.json} first=$first');
    if (!first) return;

    final ms = (widget.json['typing_ms'] is int)
        ? widget.json['typing_ms'] as int
        : null;
    final keys = ClaimFormPane._allFields;
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

class _SetClaimFieldExec extends StatefulWidget {
  const _SetClaimFieldExec({required this.json, required this.host});
  final Map<String, dynamic> json;
  final _ClaimFormHostCbs host;
  @override
  State<_SetClaimFieldExec> createState() => _SetClaimFieldExecState();
}

class _SetClaimFieldExecState extends State<_SetClaimFieldExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[SetClaimExec] json=${widget.json} first=$first');
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
