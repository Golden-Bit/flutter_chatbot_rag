import 'dart:async';
import 'package:flutter/material.dart';

import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';

/// Pane di form per SINISTRO (nuovo schema) con estensioni ChatBot.
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
  /*  ⚠️ NON include la selezione CONTRATTO (dropdown)!              */
  /*  ⚠️ NON include: compagnia, numero_contratto, rischio           */
  /*     (derivati dal contratto scelto; non autocompilabili)       */
  /*───────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
  toolName: 'FillClaimFormWidget',
  description:
        '''Compila il form sinistro. Ogni parametro è opzionale: se assente, il campo non viene toccato.
Se ti viene chiesto di compilare un sinistro, o anche se non viene specificato alcun tipo di form specifico 
(ma ti viene solo cheisto di compialr eun form generico), dovrai impiegare tale tool ui per compilare form.'''
      'Compila il form sinistro (nuovo schema) con digitazione simulata. '
      'Tutti i parametri sono opzionali. '
      '⚠️ Il contratto NON è autocompilabile e i campi compagnia/numero_contratto/rischio sono derivati dal contratto selezionato '
      '(se la polizza non è caricata l’UI mostrerà “POLIZZA NON TROVATA”). '
      'Linee guida: '
      '• “esercizio” è l’anno ricavato da data_accadimento, altrimenti anno corrente; '
      '• “data_denuncia” se omessa viene impostata alla data odierna (giorno di apertura); '
      '• “stato” parte da “In Valutazione” e potrà evolvere in Aperto/Senza Seguito/Chiuso; '
      '• “importo_riservato” inizialmente = “danno_stimato”; “importo_liquidato” iniziale = 0.00; '
      '• “descrizione_evento” corrisponde alla “Modalità di Accadimento”; '
      '• indirizzo/città: prelevare da “Località”/“prov” quando presenti nel modulo.'
,
  params: const [
    // ▼ Campo non visibile in UI: valorizzato da data_accadimento o anno corrente
    ToolParamSpec(
      name: 'esercizio',
      paramType: ParamType.integer,
      description:
          'Anno esercizio (1900+). Se mancante, viene ricavato dall’anno di data_accadimento; in assenza, anno corrente.',
      example: 2025,
      minValue: 1900,
    ),

    // ▼ Campi VISIBILI/COMPILABILI (esclusi quelli derivati dal contratto)
    ToolParamSpec(
      name: 'numero_sinistro',
      paramType: ParamType.string,
      description:
          'Numero interno di sinistro. Può essere fornito (es. “ENACSX001/2025”) o lasciato al sistema per l’assegnazione.',
      example: 'ENACSX001/2025',
    ),
    ToolParamSpec(
      name: 'descrizione_evento',
      paramType: ParamType.string,
      description:
          'Descrizione dell’evento / modalità di accadimento così come nel modulo di denuncia.',
      example: 'Tamponamento in colonna su tangenziale.',
    ),
    ToolParamSpec(
      name: 'data_accadimento',
      paramType: ParamType.string,
      description:
          'Data dell’evento nel formato dd/MM/yyyy. Deve essere ≤ oggi ed è obbligatoria per l’apertura.',
      example: '15/05/2025',
    ),
    ToolParamSpec(
      name: 'data_denuncia',
      paramType: ParamType.string,
      description:
          'Data di denuncia nel formato dd/MM/yyyy. Se omessa, viene impostata alla data odierna (giorno di apertura). '
          'Deve essere ≥ data_accadimento e ≤ oggi.',
      example: '16/05/2025',
    ),
    ToolParamSpec(
      name: 'danno_stimato',
      paramType: ParamType.string,
      description:
          'Danno preventivamente stimato (stringa numerica con punto decimale). Fonte: “Entità Approssimativa” del modulo.',
      example: '1500.00',
    ),
    ToolParamSpec(
      name: 'importo_riservato',
      paramType: ParamType.string,
      description:
          'Importo riservato (stringa numerica). Se omesso, inizialmente = danno_stimato; sarà poi aggiornato dal Broker.',
      example: '1500.00',
    ),
    ToolParamSpec(
      name: 'importo_liquidato',
      paramType: ParamType.string,
      description:
          'Importo liquidato (stringa numerica). Di norma iniziale 0.00; viene valorizzato successivamente dal Broker.',
      example: '0.00',
      defaultValue: '0.00',
    ),
    ToolParamSpec(
      name: 'stato',
      paramType: ParamType.string,
      description:
          'Stato del sinistro alla creazione. Flusso tipico: In Valutazione → Aperto | Senza Seguito → Chiuso.',
      example: 'In Valutazione',
      defaultValue: 'In Valutazione',
      allowedValues: [
        'Aperto',
        'Chiuso',
        'Senza Seguito',
        'In Valutazione',
      ],
    ),
    ToolParamSpec(
      name: 'indirizzo_evento',
      paramType: ParamType.string,
      description:
          'Indirizzo/località dell’evento (dal campo “Località” del modulo).',
      example: 'Via Roma 10',
    ),
    ToolParamSpec(
      name: 'cap',
      paramType: ParamType.string,
      description: 'CAP dell’evento (5 cifre ove applicabile).',
      example: '20100',
    ),
    ToolParamSpec(
      name: 'citta',
      paramType: ParamType.string,
      description:
          'Città dell’evento. In assenza esplicita nel modulo, può essere ricavata dalla voce “prov” come approssimazione.',
      example: 'Milano',
    ),

    // Digitazione simulata
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
/* Tool: set SINGOLO campo (⚠️ niente selezione contratto)         */
/*  ⚠️ allowedValues ESCLUDONO: compagnia, numero_contratto, rischio */
/*     perché derivati dal contratto scelto (o “POLIZZA NON TROVATA”).*/
/*───────────────────────────────────────────────────────────────*/
static final List<String> _allFields = [
  'esercizio', // non visibile ma settabile via tool
  'numero_sinistro',
  'descrizione_evento',
  'data_accadimento',
  'data_denuncia',
  'danno_stimato',
  'importo_riservato',
  'importo_liquidato',
  'stato', // dropdown
  'indirizzo_evento',
  'cap',
  'citta',
];

static final ToolSpec setTool = ToolSpec(
  toolName: 'SetClaimFieldWidget',
  description:
      'Imposta un singolo campo del sinistro (nuovo schema) con digitazione simulata. '
      'Il contratto e i campi derivati (compagnia/numero_contratto/rischio) NON sono impostabili via tool. '
      'Regole: data_accadimento ≤ oggi; data_denuncia se omessa = oggi e deve essere ≥ data_accadimento; '
      'importi come stringhe numeriche con punto decimale; stato iniziale suggerito: “In Valutazione”.'
      'VALGONO LE STESSE INFO E DESCRIZIONI DEI CAMPI FORNITE PER [FillContractFormWidget].',
  params: [
    ToolParamSpec(
      name: 'field',
      paramType: ParamType.string,
      description: 'Nome del campo da impostare.',
      allowedValues: _allFields,
      example: 'numero_sinistro',
    ),
    ToolParamSpec(
      name: 'value',
      paramType: ParamType.string,
      description:
          'Valore del campo. Date in formato dd/MM/yyyy; importi come stringhe numeriche (es. 1000.00); '
          'per "stato" usare uno tra: Aperto, Chiuso, Senza Seguito, In Valutazione.',
      example: 'ENACSX001/2025',
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
  static const _kDefaultTypingMs = 22;
  static const _kStati = <String>[
    'Aperto',
    'Chiuso',
    'Senza Seguito',
    'In Valutazione',
  ];

  @override
  void initState() {
    super.initState();
    _ClaimFormHostCbs.bind(this);
    _loadContracts();

    // Pre-compila se passati initialValues
    if (widget.initialValues != null && widget.initialValues!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialValues(widget.initialValues!);
      });
    }
    _selectedContractId = widget.initialContractId;
  }

  @override
  void dispose() {
    _ClaimFormHostCbs.unbind(this);
    super.dispose();
  }

  // ▼▼▼ CONTRATTI — caricamento per il selettore ▼▼▼
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

      // se già selezionato un contratto, prova a precompilare i 3 campi derivati
      if (_selectedContractId != null &&
          _contractsLabel.containsKey(_selectedContractId)) {
        _applyContractDefaults(_selectedContractId!);
      }
    } catch (e) {
      _loadError = 'Errore nel caricamento delle Polizze: $e';
    } finally {
      if (mounted) setState(() => _loadingContracts = false);
    }
  }

  // Espone l’id contratto selezionato al dialog
  String? get selectedContractId => _selectedContractId;

  // ▼▼▼ MODELLO CAMPI (nuovo schema) ▼▼▼
  Map<String, String> get model {
    // esercizio NON visibile: se non impostato, prova da data_accadimento, altrimenti anno corrente
    final dataAcc = _c['data_accadimento']?.text.trim();
    String esercizio;
    if (dataAcc != null && dataAcc.isNotEmpty) {
      final parts = dataAcc.split('/');
      esercizio = (parts.length == 3) ? parts[2] : DateTime.now().year.toString();
    } else {
      esercizio = DateTime.now().year.toString();
    }

    return {
      'esercizio': _c['esercizio']?.text.trim().isNotEmpty == true
          ? _c['esercizio']!.text.trim()
          : esercizio,

      'numero_sinistro': _c['numero_sinistro']?.text.trim() ?? '',
      // derivati (non editabili): restano nel payload BE
      'compagnia': (_c['compagnia']?.text ?? '').trim(),
      'numero_contratto': (_c['numero_contratto']?.text ?? '').trim(),
      'rischio': (_c['rischio']?.text ?? '').trim(),

      'descrizione_evento': (_c['descrizione_evento']?.text ?? '').trim(),
      'data_accadimento': (_c['data_accadimento']?.text ?? '').trim(),
      'data_denuncia': (_c['data_denuncia']?.text ?? '').trim(),
      'danno_stimato': (_c['danno_stimato']?.text ?? '').trim(),
      'importo_riservato': (_c['importo_riservato']?.text ?? '').trim(),
      'importo_liquidato': (_c['importo_liquidato']?.text ?? '').trim(),
      'stato': _stato ?? '',
      'indirizzo_evento': (_c['indirizzo_evento']?.text ?? '').trim(),
      'cap': (_c['cap']?.text ?? '').trim(),
      'citta': (_c['citta']?.text ?? '').trim(),
    };
  }

  // Controllers (inclusi i 3 derivati, ma saranno read-only in UI)
  final _c = <String, TextEditingController>{
    'esercizio': TextEditingController(), // non mostrato
    'numero_sinistro': TextEditingController(),
    'compagnia': TextEditingController(),          // RO
    'numero_contratto': TextEditingController(),   // RO
    'rischio': TextEditingController(),            // RO
    'descrizione_evento': TextEditingController(),
    'data_accadimento': TextEditingController(),
    'data_denuncia': TextEditingController(),
    'danno_stimato': TextEditingController(),
    'importo_riservato': TextEditingController(),
    'importo_liquidato': TextEditingController(),
    'indirizzo_evento': TextEditingController(),
    'cap': TextEditingController(),
    'citta': TextEditingController(),
  };

  // Stato (dropdown)
  String? _stato;

  // Focus (solo per i campi visibili + 'esercizio' invisibile per set via tool)
  final _f = <String, FocusNode>{
    'esercizio': FocusNode(),
    'numero_sinistro': FocusNode(),
    'compagnia': FocusNode(),
    'numero_contratto': FocusNode(),
    'rischio': FocusNode(),
    'descrizione_evento': FocusNode(),
    'data_accadimento': FocusNode(),
    'data_denuncia': FocusNode(),
    'danno_stimato': FocusNode(),
    'importo_riservato': FocusNode(),
    'importo_liquidato': FocusNode(),
    'indirizzo_evento': FocusNode(),
    'cap': FocusNode(),
    'citta': FocusNode(),
  };

  // typing engine
  final _gen = <String, int>{};

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

  // Host API (no selezione contratto! + no autocompilazione campi derivati)
  static const _forbiddenByBot = {'compagnia', 'numero_contratto', 'rischio'};

  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    // Blocca i campi derivati dal contratto
    if (_forbiddenByBot.contains(field)) {
      debugPrint('[ClaimHost] setField IGNORED for derived field: $field');
      return;
    }
    final ms = typingMs ?? _kDefaultTypingMs;
    if (field == 'stato') {
      setState(() => _stato = (value?.toString().trim().isEmpty ?? true) ? null : value.toString());
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

    // ordine di compilazione “umano” (ESCLUSI i derivati)
    final order = [
      'numero_sinistro',
      'descrizione_evento',
      'data_accadimento',
      'data_denuncia',
      'danno_stimato',
      'importo_riservato',
      'importo_liquidato',
      'stato',
      'indirizzo_evento',
      'cap',
      'citta',
      'esercizio', // per ultimo (invisibile)
    ];

    final keys = [
      ...order.where(m.containsKey),
      ...m.keys.where((k) => !order.contains(k)),
    ];

    for (final k in keys) {
      if (_forbiddenByBot.contains(k)) {
        debugPrint('[ClaimHost] fill IGNORED derived key: $k');
        continue;
      }
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

  // Read-only (derivati dal contratto selezionato)
  Widget _tRO(String key, String label) => TextField(
        controller: _c[key],
        focusNode: _f[key],
        readOnly: true,
        enabled: false,
        decoration: _dec(label).copyWith(
          helperText: 'Derivato dal contratto selezionato',
        ),
      );

  Future<void> _applyContractDefaults(String contractId) async {
    try {
      final c = await widget.sdk.getContract(widget.user.username, widget.entityId, contractId);
      final compagnia = c.identificativi.compagnia;
      final numPolizza = c.identificativi.numeroPolizza;
      final rischio = c.ramiEl?.descrizione ?? c.identificativi.ramo;

      // scrivi i derivati (UI read-only)
      _c['compagnia']!.text = compagnia;
      _c['numero_contratto']!.text = numPolizza;
      _c['rischio']!.text = rischio;
    } catch (_) {
      // ignora errori di prefilling
    }
  }

  @override
  void didUpdateWidget(covariant ClaimFormPane old) {
    super.didUpdateWidget(old);
    if (widget.initialValues != old.initialValues &&
        widget.initialValues != null) {
      _setInitialValues(widget.initialValues!);
    }
    if (widget.initialContractId != old.initialContractId) {
      setState(() => _selectedContractId = widget.initialContractId);
      if (_selectedContractId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _applyContractDefaults(_selectedContractId!);
        });
      }
    }
  }

  // Prefill “immediato” dei controller (accetta anche alias legacy)
  void _setInitialValues(Map<String, String> m) {
    // mappa alias legacy -> nuovi
    final mapped = <String, String>{}
      ..addAll(m)
      ..addAll({
        if (m['numero_polizza'] != null) 'numero_contratto': m['numero_polizza']!,
        if (m['descrizione_assicurato'] != null)
          'descrizione_evento': m['descrizione_assicurato']!,
        if (m['data_avvenimento'] != null)
          'data_accadimento': m['data_avvenimento']!,
        if (m['data_apertura'] != null) 'data_denuncia': m['data_apertura']!,
        if (m['città'] != null) 'citta': m['città']!,
        if (m['indirizzo'] != null) 'indirizzo_evento': m['indirizzo']!,
      });

    for (final e in mapped.entries) {
      final k = e.key;
      final v = e.value;
      if (_c.containsKey(k)) {
        _c[k]!.text = v;
        _c[k]!.selection = TextSelection.collapsed(offset: _c[k]!.text.length);
      } else if (k == 'stato') {
        _stato = v;
      }
    }
    setState(() {}); // refresh per dropdown stato
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, // full width
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
                Text('Carico Polizze...'),
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
                  ? null
                  : (v) async {
                      setState(() => _selectedContractId = v);
                      if (v != null) await _applyContractDefaults(v);
                    },
            ),

          const SizedBox(height: 12),

          // ────────────────────── Dati Sinistro (solo campi richiesti) ─────────
          _t('numero_sinistro', 'Numero sinistro *'),
          const SizedBox(height: 12),

          // Derivati dal contratto: RO
          _tRO('compagnia', 'Compagnia (derivata)'),
          const SizedBox(height: 12),

          _tRO('numero_contratto', 'Numero contratto (derivato)'),
          const SizedBox(height: 12),

          _tRO('rischio', 'Rischio (derivato)'),
          const SizedBox(height: 12),

          _t('descrizione_evento', 'Descrizione evento'),
          const SizedBox(height: 12),

          _t('data_accadimento', 'Data accadimento *', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),

          _t('data_denuncia', 'Data di denuncia', hint: 'gg/mm/aaaa'),
          const SizedBox(height: 12),

          _t('danno_stimato', 'Danno preventivamente stimato'),
          const SizedBox(height: 12),

          _t('importo_riservato', 'Importo riservato'),
          const SizedBox(height: 12),

          _t('importo_liquidato', 'Importo liquidato'),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _stato,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              labelText: 'Stato',
            ),
            items: _kStati
                .map((s) => DropdownMenuItem<String>(
                      value: s,
                      child: Text(s),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _stato = v),
          ),

          const SizedBox(height: 12),

          _t('indirizzo_evento', 'Indirizzo evento'),
          const SizedBox(height: 12),

          _t('cap', 'CAP'),
          const SizedBox(height: 12),

          _t('citta', 'Città'),
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

  // ⚠️ Nessun metodo per impostare la SELEZIONE del contratto via tool
  // ⚠️ Campi derivati (compagnia/numero_contratto/rischio) non impostabili via tool
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

    // estrai solo i campi previsti dal nuovo schema (esclusi derivati)
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
