// --- ADD: _ClientFormPane ----------------------------------------------------
import 'dart:async';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';

class ClientFormPane extends StatefulWidget with ChatBotExtensions {
  const ClientFormPane({super.key});

  @override
  State<ClientFormPane> createState() => ClientFormPaneState();

  // ── ToolSpecs (un parametro per ciascun campo + typing_ms) ─────────────
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillClientFormWidget',
    description: 'Compila il form cliente con digitazione simulata. Ogni parametro è opzionale: se assente, il campo non viene toccato.',
    params: const [
      ToolParamSpec(name: 'name',  paramType: ParamType.string, description: 'Ragione sociale', example: 'ACME S.p.A.'),
      ToolParamSpec(name: 'address', paramType: ParamType.string, description: 'Indirizzo', example: 'Via Roma 1'),
      ToolParamSpec(name: 'tax_code', paramType: ParamType.string, description: 'Codice fiscale', example: 'RSSMRA85H09H501Z'),
      ToolParamSpec(name: 'vat', paramType: ParamType.string, description: 'Partita IVA', example: 'IT01234567890'),
      ToolParamSpec(name: 'phone', paramType: ParamType.string, description: 'Telefono', example: '+39 333 1234567'),
      ToolParamSpec(name: 'email', paramType: ParamType.string, description: 'Email', example: 'info@acme.com'),
      ToolParamSpec(name: 'sector', paramType: ParamType.string, description: 'Settore / ATECO', example: '62.01'),
      ToolParamSpec(name: 'legal_rep', paramType: ParamType.string, description: 'Legale rappresentante', example: 'Mario Rossi'),
      ToolParamSpec(name: 'legal_rep_tax_code', paramType: ParamType.string, description: 'CF legale rappresentante', example: 'RSSMRA85H09H501Z'),
      // digitazione
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata). Default 22.',
        example: 18,
        defaultValue: 22,
        minValue: 0, maxValue: 200,
      ),
    ],
  );

  static final ToolSpec setTool = ToolSpec(
    toolName: 'SetClientFieldWidget',
    description: 'Imposta un singolo campo con digitazione simulata.',
    params: const [
      ToolParamSpec(
        name: 'field',
        paramType: ParamType.string,
        description: 'Nome del campo',
        allowedValues: ['name','address','tax_code','vat','phone','email','sector','legal_rep','legal_rep_tax_code'],
        example: 'email',
      ),
      ToolParamSpec(
        name: 'value',
        paramType: ParamType.string,
        description: 'Valore da impostare',
        example: 'hello@acme.com',
      ),
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata).',
        example: 20,
        defaultValue: 22,
        minValue: 0, maxValue: 200,
      ),
    ],
  );

  @override
  List<ToolSpec> get toolSpecs => [fillTool, setTool];

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
    // widget di “esecuzione” dei tool: leggono i parametri e chiamano i callbacks host
    'FillClientFormWidget': (json, onR, pCbs, hCbs) => _FillClientFormExec(json: json, host: hCbs as _ClientFormHostCbs),
    'SetClientFieldWidget': (json, onR, pCbs, hCbs) => _SetClientFieldExec(json: json, host: hCbs as _ClientFormHostCbs),
  };

  @override
  ChatBotHostCallbacks get hostCallbacks => const _ClientFormHostCbs();
}

class ClientFormPaneState extends State<ClientFormPane> {
  @override
  void initState() {
    super.initState();
    _ClientFormHostCbs.bind(this);          // ⬅️ BIND qui
  }

  @override
  void dispose() {
    _ClientFormHostCbs.unbind(this);        // ⬅️ UNBIND qui
    super.dispose();
  }
  
  // Controllers + Focus
  final _c = <String, TextEditingController>{
    'name': TextEditingController(),
    'address': TextEditingController(),
    'tax_code': TextEditingController(),
    'vat': TextEditingController(),
    'phone': TextEditingController(),
    'email': TextEditingController(),
    'sector': TextEditingController(),
    'legal_rep': TextEditingController(),
    'legal_rep_tax_code': TextEditingController(),
  };
  final _f = { for (final k in ['name','address','tax_code','vat','phone','email','sector','legal_rep','legal_rep_tax_code']) k: FocusNode() };

  // tracking digitazione per campo
  final _gen = <String,int>{};
  static const _kDefaultTypingMs = 22;

  // ————— helpers “host” —————
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
    var i = 0; while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) i++; return i;
  }

  // ————— UI del form (riuso il tuo stile) —————
  InputDecoration _dec(String l) => InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());
  Widget _t(String key, String label, {String? hint}) => TextFormField(
    controller: _c[key], focusNode: _f[key],
    decoration: _dec(label).copyWith(hintText: hint),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _t('name','Ragione sociale *', hint: 'ACME S.p.A.'),
        const SizedBox(height: 12),
        _t('address','Indirizzo', hint: 'Via Roma 1'),
        const SizedBox(height: 12),
        _t('phone','Telefono', hint: '+39 333 1234567'),
        const SizedBox(height: 12),
        _t('email','Email', hint: 'info@acme.com'),
        const SizedBox(height: 12),
        _t('vat','Partita IVA', hint: 'IT01234567890'),
        const SizedBox(height: 12),
        _t('tax_code','Codice fiscale', hint: 'RSSMRA85H09H501Z'),
        const SizedBox(height: 12),
        _t('sector','Settore / ATECO', hint: '62.01'),
        const SizedBox(height: 12),
        _t('legal_rep','Legale rappresentante'),
        const SizedBox(height: 12),
        _t('legal_rep_tax_code','CF legale rappresentante'),
      ]),
    );
  }

  // ———— HostCallbacks implementation ————
  Future<void> setField(String field, String value, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;
    unawaited(_typeInto(field, value, ms: ms));
    final node = _f[field];
    if (node != null) WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
  }
  Future<void> fill(Map<String, dynamic> m, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;
    // ordine “umano”
    final order = ['name','email','phone','vat','tax_code','address','sector','legal_rep','legal_rep_tax_code'];
    final keys = [...order.where(m.containsKey), ...m.keys.where((k) => !order.contains(k))];
    for (final k in keys) {
      final v = m[k]; if (v == null) continue;
      await setField(k, v.toString(), typingMs: ms);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // esporto il modello (se vuoi recuperarlo dal dialog)
  Map<String,String> get model => { for (final e in _c.entries) e.key: e.value.text.trim() };
}

// ——— host callbacks adapter ———
class _ClientFormHostCbs extends ChatBotHostCallbacks {
  const _ClientFormHostCbs();

  static ClientFormPaneState? _bound;
  static void bind(ClientFormPaneState s) {
    _bound = s;
    debugPrint('[HostCbs] bound to ${s.hashCode}');
  }
  static void unbind(ClientFormPaneState s) {
    if (_bound == s) {
      _bound = null;
      debugPrint('[HostCbs] unbound');
    }
  }

  // helper interno
  ClientFormPaneState? get _s => _bound;

  // chiamate dal widget-tool
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    debugPrint('[HostCbs] setField field=$field value=$value typingMs=$typingMs bound=${_s!=null}');
    await _s?.setField(field, value?.toString() ?? '', typingMs: typingMs);
  }

  Future<void> fillAll(Map<String, dynamic> payload, {int? typingMs}) async {
    debugPrint('[HostCbs] fillAll keys=${payload.keys.toList()} typingMs=$typingMs bound=${_s!=null}');
    await _s?.fill(payload, typingMs: typingMs);
  }

  Future<void> focusField(String field) async {
    debugPrint('[HostCbs] focusField field=$field bound=${_s!=null}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _s?._f[field]?.requestFocus());
  }
}


// ——— tool “executor” (legge i parametri e invoca host) ———
class _FillClientFormExec extends StatefulWidget {
  const _FillClientFormExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ClientFormHostCbs host;
  @override State<_FillClientFormExec> createState() => _FillClientFormExecState();
}
class _FillClientFormExecState extends State<_FillClientFormExec> {
  @override void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    if (!first) return;
    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;
    final keys = ['name','address','tax_code','vat','phone','email','sector','legal_rep','legal_rep_tax_code'];
    final map = <String,dynamic>{ for (final k in keys) if (widget.json.containsKey(k)) k: widget.json[k] };
    if (map.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.fillAll(map, typingMs: ms));
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}

class _SetClientFieldExec extends StatefulWidget {
  const _SetClientFieldExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ClientFormHostCbs host;
  @override State<_SetClientFieldExec> createState() => _SetClientFieldExecState();
}
class _SetClientFieldExecState extends State<_SetClientFieldExec> {
  @override void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    if (!first) return;
    final field = (widget.json['field'] ?? '').toString();
    final value = widget.json['value']?.toString() ?? '';
    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;
    if (field.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.setField(field, value, typingMs: ms));
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}
