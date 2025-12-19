// lib/demo/form_builder_panel.dart
import 'dart:async';
import 'dart:convert';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';

/// =======================================================
/// Callback host specifica per il Form Builder
///  - applySchema: applica lo schema
///  - fillFields:  compila i campi (con animazione opzionale)
/// =======================================================
class FormHostCallbacks extends ChatBotHostCallbacks {
  const FormHostCallbacks({
    required this.applySchema,
    required this.fillFields,
  });

  final void Function(FormSchema) applySchema;
  final void Function(FillCommand) fillFields;
}

/// Comando di compilazione (usato dal tool FillFormFieldsWidget -> host)
class FillCommand {
  FillCommand({
    required this.values,
    this.animate = true,
    this.charDelayMs = 18,
    this.fieldDelayMs = 60,
  });

  final Map<String, dynamic> values;
  final bool animate;
  final int charDelayMs;  // ritardo tra caratteri (typewriter)
  final int fieldDelayMs; // ritardo tra campi
}

num _readNum(dynamic v, num def) {
  if (v == null) return def;
  if (v is num) return v;
  if (v is String) {
    final parsed = num.tryParse(v.trim());
    if (parsed != null) return parsed;
  }
  return def;
}

bool _readBool(dynamic v, bool def) {
  if (v == null) return def;
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes' || s == 'si' || s == 'sì') {
      return true;
    }
    if (s == 'false' || s == '0' || s == 'no') {
      return false;
    }
  }
  return def;
}

/// =======================================================
/// Modello di schema form (campi, pulsanti, tema)
/// =======================================================
class FormSchema {
  final String? title;
  final List<FieldSpec> fields;
  final List<ButtonSpec> buttons;
  final Color? primaryColor; // colore accento degli elementi
  final Color? surfaceColor; // sfondo card/form
  final EdgeInsetsGeometry padding;

  FormSchema({
    this.title,
    required this.fields,
    required this.buttons,
    this.primaryColor,
    this.surfaceColor,
    this.padding = const EdgeInsets.all(16),
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    final colors = _ColorParser();
    return FormSchema(
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? null
          : json['title'].toString(),
      fields: (json['fields'] as List? ?? [])
          .map((e) => FieldSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      buttons: (json['buttons'] as List? ?? [])
          .map((e) => ButtonSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      primaryColor: colors.parse(json['primary_color']),
      surfaceColor: colors.parse(json['surface_color']),
      padding: _parsePadding(json['padding']) ?? const EdgeInsets.all(16),
    );
  }

  static EdgeInsets? _parsePadding(dynamic v) {
    if (v == null) return null;
    if (v is num) return EdgeInsets.all(v.toDouble());
    if (v is List && v.length == 4) {
      return EdgeInsets.fromLTRB(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );
    }
    return null;
  }
}

enum FieldType { text, number, textarea, dropdown, date, checkbox, switcher }

class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? placeholder;
  final List<String>? options; // dropdown
  final Color? color; // colore componente (bordo/label)
  final IconData? icon; // icona decorativa
  final double? width; // 0..1 (larghezza relativo riga)
  final String? hint; // helperText
  final dynamic defaultValue;

  FieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder,
    this.options,
    this.color,
    this.icon,
    this.width,
    this.hint,
    this.defaultValue,
  });

  factory FieldSpec.fromJson(Map<String, dynamic> json) {
    final t = (json['type'] ?? 'text').toString().toLowerCase();
    final type = switch (t) {
      'text' => FieldType.text,
      'number' => FieldType.number,
      'textarea' => FieldType.textarea,
      'dropdown' => FieldType.dropdown,
      'date' => FieldType.date,
      'checkbox' => FieldType.checkbox,
      'switch' || 'switcher' => FieldType.switcher,
      _ => FieldType.text,
    };
    final colors = _ColorParser();
    return FieldSpec(
      key: json['key']?.toString() ??
          json['name']?.toString() ??
          'field_${DateTime.now().millisecondsSinceEpoch}',
      label: json['label']?.toString() ?? 'Field',
      type: type,
      required: (json['required'] as bool?) ?? false,
      placeholder: json['placeholder']?.toString(),
      options: (json['options'] as List?)?.map((e) => e.toString()).toList(),
      color: colors.parse(json['color']),
      icon: _IconCatalog.parse(json['icon']),
      width: (json['width'] is num)
          ? (json['width'] as num).toDouble().clamp(0.2, 1.0)
          : null,
      hint: json['hint']?.toString(),
      defaultValue: json['default'],
    );
  }
}

class ButtonSpec {
  final String label;
  final String action; // identificatore (es. "submit", "reset", "save")
  final String variant; // "filled"|"outlined"|"text"
  final Color? color; // sfondo (filled) o bordo (outlined)
  final Color? textColor;

  ButtonSpec({
    required this.label,
    required this.action,
    this.variant = 'filled',
    this.color,
    this.textColor,
  });

  factory ButtonSpec.fromJson(Map<String, dynamic> json) {
    final colors = _ColorParser();
    return ButtonSpec(
      label: json['label']?.toString() ?? 'Submit',
      action: json['action']?.toString() ?? 'submit',
      variant: (json['variant'] ?? 'filled').toString().toLowerCase(),
      color: colors.parse(json['color']),
      textColor: colors.parse(json['text_color']),
    );
  }
}

/// =======================================================
/// Parser colore flessibile (HEX/ARGB/rgb()/rgba()/argb()/csv)
/// =======================================================
class _ColorParser {
  Color? parse(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    // argb(a,r,g,b)
    final argb = RegExp(
      r'^argb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$',
      caseSensitive: false,
    );
    final mArgb = argb.firstMatch(s);
    if (mArgb != null) {
      int a = int.parse(mArgb.group(1)!);
      int r = int.parse(mArgb.group(2)!);
      int g = int.parse(mArgb.group(3)!);
      int b = int.parse(mArgb.group(4)!);
      if (_inB(a) && _inB(r) && _inB(g) && _inB(b)) {
        return Color(
            ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF));
      }
      return null;
    }

    // rgba(r,g,b,a)
    final rgba = RegExp(
      r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*([0-9]*\.?[0-9]+)\s*\)$',
      caseSensitive: false,
    );
    final mRgba = rgba.firstMatch(s);
    if (mRgba != null) {
      final r = int.parse(mRgba.group(1)!);
      final g = int.parse(mRgba.group(2)!);
      final b = int.parse(mRgba.group(3)!);
      final aStr = mRgba.group(4)!;
      int a;
      if (aStr.contains('.')) {
        final d = double.tryParse(aStr);
        if (d == null) return null;
        a = (d.clamp(0.0, 1.0) * 255).round();
      } else {
        a = int.parse(aStr);
      }
      if (_inB(a) && _inB(r) && _inB(g) && _inB(b)) {
        return Color(
            ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF));
      }
      return null;
    }

    // rgb(r,g,b)
    final rgb = RegExp(
      r'^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$',
      caseSensitive: false,
    );
    final mRgb = rgb.firstMatch(s);
    if (mRgb != null) {
      final r = int.parse(mRgb.group(1)!);
      final g = int.parse(mRgb.group(2)!);
      final b = int.parse(mRgb.group(3)!);
      if (_inB(r) && _inB(g) && _inB(b)) {
        return Color(0xFF000000 | (r << 16) | (g << 8) | b);
      }
      return null;
    }

    // csv a,r,g,b
    final csv =
        RegExp(r'^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$');
    final mCsv = csv.firstMatch(s);
    if (mCsv != null) {
      final a = int.parse(mCsv.group(1)!);
      final r = int.parse(mCsv.group(2)!);
      final g = int.parse(mCsv.group(3)!);
      final b = int.parse(mCsv.group(4)!);
      if (_inB(a) && _inB(r) && _inB(g) && _inB(b)) {
        return Color(
            ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF));
      }
      return null;
    }

    // #AARRGGBB / 0xAARRGGBB / AARRGGBB
    final hex8 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{8})$');
    final m8 = hex8.firstMatch(s);
    if (m8 != null) {
      final v = int.parse(m8.group(1)!, radix: 16);
      return Color(v);
    }

    // #RRGGBB / 0xRRGGBB / RRGGBB
    final hex6 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{6})$');
    final m6 = hex6.firstMatch(s);
    if (m6 != null) {
      final v = int.parse(m6.group(1)!, radix: 16);
      return Color(0xFF000000 | v);
    }

    return null;
  }

  bool _inB(int v) => v >= 0 && v <= 255;
}

class _IconCatalog {
  static IconData? parse(dynamic v) {
    final s = v?.toString().toLowerCase();
    return switch (s) {
      'user' || 'person' => Icons.person_outline,
      'email' => Icons.alternate_email,
      'phone' => Icons.phone_outlined,
      'calendar' || 'date' => Icons.event_outlined,
      'dropdown' => Icons.arrow_drop_down_circle_outlined,
      'password' => Icons.lock_outline,
      'note' || 'textarea' => Icons.notes_outlined,
      _ => null,
    };
  }
}

/// =======================================================
/// Widget tool #1: imposta lo schema del form
/// Param: "schema" -> JSON string o oggetto Map serializzabile
/// =======================================================
class SetFormSchemaWidget extends StatefulWidget {
  const SetFormSchemaWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final FormHostCallbacks hostCbs;

  @override
  State<SetFormSchemaWidget> createState() => _SetFormSchemaWidgetState();
}

class _SetFormSchemaWidgetState extends State<SetFormSchemaWidget> {
  FormSchema? _schema;
  String? _error;

  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final (s, err) = _extractSchema(widget.jsonData);
    _schema = s;
    _error = err;

    if (firstTime && s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.applySchema(s);
      });
    }
  }

  (FormSchema?, String?) _extractSchema(Map<String, dynamic> data) {
    dynamic raw = data['schema'];
    Map<String, dynamic>? m;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        m = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    } else if (data.containsKey('fields') || data.containsKey('buttons')) {
      // accetta anche schema "flat" nel root
      m = Map<String, dynamic>.from(data);
    }
    if (m == null) return (null, 'Schema mancante o non valido.');
    try {
      return (FormSchema.fromJson(m), null);
    } catch (e) {
      return (null, 'Errore parsing schema: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _schema != null;
    return Card(
      color: ok ? Colors.green.withOpacity(.10) : Colors.red.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ok ? _buildOk() : _buildErr(),
      ),
    );
  }

  Widget _buildOk() {
    final s = _schema!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Form aggiornato: ${s.title ?? 'senza titolo'}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Campi: ${s.fields.length}  ·  Pulsanti: ${s.buttons.length}'),
        const SizedBox(height: 6),
        const Text('Il pannello a sinistra è stato aggiornato.'),
      ],
    );
  }

  Widget _buildErr() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Impossibile applicare lo schema.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_error ?? 'Schema non valido.'),
          const SizedBox(height: 8),
          const Text(
            'Esempio:\n'
            '{\n'
            '  "title":"Registrazione",\n'
            '  "primary_color":"#FF1E88E5",\n'
            '  "surface_color":"#FFF7F7F7",\n'
            '  "fields":[\n'
            '    {"key":"name","label":"Nome","type":"text","icon":"user","required":true},\n'
            '    {"key":"email","label":"Email","type":"text","icon":"email","hint":"nome@dominio.com"},\n'
            '    {"key":"dob","label":"Data di nascita","type":"date","icon":"calendar"},\n'
            '    {"key":"role","label":"Ruolo","type":"dropdown","options":["Admin","User","Guest"],"icon":"dropdown"},\n'
            '    {"key":"bio","label":"Note","type":"textarea","icon":"textarea"}\n'
            '  ],\n'
            '  "buttons":[\n'
            '    {"label":"Annulla","action":"reset","variant":"outlined","color":"#FF9E9E9E","text_color":"#FF333333"},\n'
            '    {"label":"Salva","action":"submit","variant":"filled","color":"#FF1E88E5","text_color":"#FFFFFFFF"}\n'
            '  ]\n'
            '}',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      );
}

/// =======================================================
/// Widget tool #2: compila i campi del form corrente
/// Parametri accettati (in jsonData):
///  - values: mappa key->valore (o stringa JSON)
///  - animate: bool (default true)
///  - char_delay_ms: int (ritardo per carattere, default 18)
///  - field_delay_ms: int (ritardo tra campi, default 60)
/// =======================================================
class FillFormFieldsWidget extends StatefulWidget {
  const FillFormFieldsWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final FormHostCallbacks hostCbs;

  @override
  State<FillFormFieldsWidget> createState() => _FillFormFieldsWidgetState();
}

class _FillFormFieldsWidgetState extends State<FillFormFieldsWidget> {
  Map<String, dynamic> _values = {};
  late bool _animate;
  late int _charDelay;
  late int _fieldDelay;
  String? _error;

  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final (vals, err) = _extractValues(widget.jsonData);
    _values = vals ?? {};
    _error = err;

_animate    = _readBool(widget.jsonData['animate'], true);
_charDelay  = _readNum(widget.jsonData['char_delay_ms'], 18)
                .clamp(1, 200)
                .toInt();
_fieldDelay = _readNum(widget.jsonData['field_delay_ms'], 60)
                .clamp(0, 800)
                .toInt();


    if (firstTime && _values.isNotEmpty && err == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.fillFields(
          FillCommand(
            values: _values,
            animate: _animate,
            charDelayMs: _charDelay,
            fieldDelayMs: _fieldDelay,
          ),
        );
      });
    }
  }

  (Map<String, dynamic>?, String?) _extractValues(Map<String, dynamic> data) {
    dynamic raw = data['values'];
    Map<String, dynamic>? m;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) m = Map<String, dynamic>.from(parsed);
      } catch (e) {
        return (null, 'values: JSON non valido ($e)');
      }
    } else if (raw is Map) {
      m = Map<String, dynamic>.from(raw);
    } else {
      // Accetta anche coppie singole 'key'+'value' nel root
      if (data.containsKey('key') && data.containsKey('value')) {
        m = {data['key'].toString(): data['value']};
      }
    }
    if (m == null || m.isEmpty) return (null, 'Nessun valore da compilare.');
    return (m, null);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _error == null && _values.isNotEmpty;
    return Card(
      color: ok ? Colors.blue.withOpacity(.08) : Colors.red.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ok ? _buildOk() : _buildErr(),
      ),
    );
  }

  Widget _buildOk() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compilazione avviata',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Campi: ${_values.keys.join(', ')}'),
          const SizedBox(height: 4),
          Text(
            _animate
                ? 'Modalità: streaming simulato  (char ${_charDelay}ms · field ${_fieldDelay}ms)'
                : 'Modalità: compilazione istantanea',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      );

  Widget _buildErr() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Impossibile avviare la compilazione',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_error ?? 'Dati mancanti o non validi.'),
        ],
      );
}

/// =======================================================
/// ToolSpec per l’LLM
///  - kSetFormSchemaTool   -> crea/aggiorna lo schema
///  - kFillFormFieldsTool  -> compila i campi del form
/// =======================================================
const ToolSpec kSetFormSchemaTool = ToolSpec(
  toolName: 'SetFormSchemaWidget',
  description:
      'Crea/aggiorna un form complesso (campi, tipi, dropdown, date-picker, pulsanti, colori). '
      'Passa "schema" come JSON con title, primary_color, surface_color, fields[], buttons[].',
  params: [
    ToolParamSpec(
      name: 'schema',
      paramType: ParamType.string,
      description: 'JSON string dello schema (oppure invia fields/buttons nel root).',
      example:
          '{"title":"Registrazione","primary_color":"#FF1E88E5","fields":[{"key":"name","label":"Nome","type":"text","required":true},{"key":"dob","label":"Data","type":"date"},{"key":"role","label":"Ruolo","type":"dropdown","options":["Admin","User"]}],"buttons":[{"label":"Salva","action":"submit","variant":"filled","color":"#FF1E88E5","text_color":"#FFFFFFFF"}]}',
    ),
  ],
);

const ToolSpec kFillFormFieldsTool = ToolSpec(
  toolName: 'FillFormFieldsWidget',
  description:
      'Compila i campi del form corrente. Supporta compilazione con animazione (typewriter) sui campi testuali.',
  params: [
    ToolParamSpec(
      name: 'values',
      paramType: ParamType.string,
      description:
          'Mappa key->value (JSON) o oggetto: es. {"name":"Mario","email":"mario@ex.com","role":"Admin","dob":"1999-05-10","tos":true}.',
      example:
          '{"name":"Mario Rossi","email":"mario.rossi@example.com","role":"Admin","bio":"Note di esempio"}',
    ),
    ToolParamSpec(
      name: 'animate',
      paramType: ParamType.boolean,
      description: 'Se true, i campi testuali vengono scritti con effetto streaming.',
      example: 'true',
    ),
    ToolParamSpec(
      name: 'char_delay_ms',
      paramType: ParamType.number,
      description: 'Ritardo per carattere in millisecondi (default 18).',
      example: '15',
    ),
    ToolParamSpec(
      name: 'field_delay_ms',
      paramType: ParamType.number,
      description: 'Ritardo tra campi in millisecondi (default 60).',
      example: '80',
    ),
  ],
);

/// =======================================================
/// Pannello sinistro: render del form in stile moderno
///  • Scrollabile se molto alto
///  • Costruzione graduale con animazione per ogni campo/pulsante
///  • Compilazione campi (tool) con effetto typewriter per text/textarea/number
/// =======================================================
class FormBuilderPanel extends StatefulWidget with ChatBotExtensions {
  FormBuilderPanel({super.key});

  final ValueNotifier<FormSchema?> _schema = ValueNotifier<FormSchema?>(null);
  final ValueNotifier<FillCommand?> _fillReq = ValueNotifier<FillCommand?>(null);
  final Map<String, dynamic> _values = {}; // stato form minimale

  @override
  ChatBotHostCallbacks get hostCallbacks => FormHostCallbacks(
        applySchema: (s) => _schema.value = s,
        fillFields: (cmd) => _fillReq.value = cmd,
      );

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'SetFormSchemaWidget': (data, onR, pCbs, hCbs) => SetFormSchemaWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as FormHostCallbacks,
            ),
        'FillFormFieldsWidget': (data, onR, pCbs, hCbs) => FillFormFieldsWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as FormHostCallbacks,
            ),
      };

  @override
  List<ToolSpec> get toolSpecs => const [kSetFormSchemaTool, kFillFormFieldsTool];

  @override
  State<FormBuilderPanel> createState() => _FormBuilderPanelState();
}

class _FormBuilderPanelState extends State<FormBuilderPanel>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _scrollCtrl = ScrollController();

  // Animazioni "staged build"
  List<AnimationController> _fieldCtrls = [];
  late AnimationController _buttonsCtrl;
  static const _staggerMs = 120; // distanza temporale tra un campo e il successivo

  // coda di compilazione per gestire richieste successive
  bool _isFilling = false;

  @override
  void initState() {
    super.initState();
    widget._schema.addListener(_onSchema);
    widget._fillReq.addListener(_onFillRequested);
    _buttonsCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  }

  @override
  void dispose() {
    widget._schema.removeListener(_onSchema);
    widget._fillReq.removeListener(_onFillRequested);
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _fieldCtrls) {
      c.dispose();
    }
    _buttonsCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSchema() {
    // Reset controllers dei campi
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    // Reset animazioni
    for (final c in _fieldCtrls) {
      c.dispose();
    }
    _fieldCtrls = [];
    _buttonsCtrl.reset();

    // Trigger rebuild
    setState(() {});

    // Avvia "costruzione" graduale dopo il frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = widget._schema.value;
      if (s == null) return;

      // Prepara un controller per ciascun campo
      _fieldCtrls = List.generate(
        s.fields.length,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ),
      );

      // Esegue le animazioni in sequenza
      for (int i = 0; i < _fieldCtrls.length; i++) {
        Future.delayed(Duration(milliseconds: i * _staggerMs), () async {
          if (!mounted) return;
          _fieldCtrls[i].forward();

          // auto-scroll verso il basso mentre si costruisce
          await Future.delayed(const Duration(milliseconds: 40));
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // Dopo che i campi hanno iniziato, mostra i pulsanti
      final totalDelay = (_fieldCtrls.length * _staggerMs) + 150;
      Future.delayed(Duration(milliseconds: totalDelay), () {
        if (!mounted) return;
        _buttonsCtrl.forward();
      });
    });
  }

  void _onFillRequested() {
    final cmd = widget._fillReq.value;
    if (cmd == null) return;
    // esegue in sequenza, evitando overlap
    _runFill(cmd).whenComplete(() {
      if (mounted) widget._fillReq.value = null;
    });
  }

  Future<void> _runFill(FillCommand cmd) async {
    if (_isFilling) {
      // semplice accodamento: attende un giro
      while (_isFilling) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    _isFilling = true;
    try {
      final schema = widget._schema.value;
      if (schema == null) return;

      // per scorrere nell'ordine dei campi nello schema:
      final fieldsByKey = {for (final f in schema.fields) f.key: f};
      for (final f in schema.fields) {
        if (!cmd.values.containsKey(f.key)) continue;
        final v = cmd.values[f.key];

        switch (f.type) {
          case FieldType.text:
          case FieldType.number:
          case FieldType.textarea:
            final t = _controllers[f.key] ??=
                TextEditingController(text: f.defaultValue?.toString());
            await _fillTextController(
              controller: t,
              target: v?.toString() ?? '',
              typewriter: cmd.animate,
              charDelayMs: cmd.charDelayMs,
            );
            widget._values[f.key] = t.text;
            break;

          case FieldType.dropdown:
            if (v == null) break;
            final str = v.toString();
            if (f.options?.contains(str) ?? false) {
              setState(() => widget._values[f.key] = str);
            } else {
              // prova match case-insensitive
              final match = (f.options ?? [])
                  .firstWhere((o) => o.toLowerCase() == str.toLowerCase(), orElse: () => '');
              if (match.isNotEmpty) {
                setState(() => widget._values[f.key] = match);
              }
            }
            break;

          case FieldType.date:
            final t = _controllers[f.key] ??= TextEditingController();
            final txt = v?.toString() ?? '';
            t.text = txt;
            widget._values[f.key] = txt;
            setState(() {}); // aggiorna icona/suffix ecc.
            break;

          case FieldType.checkbox:
          case FieldType.switcher:
            final boolVal = _toBool(v);
            setState(() => widget._values[f.key] = boolVal);
            break;
        }

        // breve pausa tra campi per effetto "umano"
        if (cmd.fieldDelayMs > 0) {
          await Future.delayed(Duration(milliseconds: cmd.fieldDelayMs));
        }

        // scrolla durante la compilazione
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      }
    } finally {
      _isFilling = false;
    }
  }

  Future<void> _fillTextController({
    required TextEditingController controller,
    required String target,
    required bool typewriter,
    required int charDelayMs,
  }) async {
    if (!typewriter) {
      controller.text = target;
      return;
    }
    controller.text = '';
    for (int i = 0; i < target.length; i++) {
      // se il widget è smontato, interrompi
      if (!mounted) return;
      controller.text += target[i];
      // posiziona il cursore alla fine per estetica
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
      await Future.delayed(Duration(milliseconds: charDelayMs));
    }
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes' || s == 'si' || s == 'sì';
  }

  // UI helpers
  InputDecoration _decoration(FieldSpec f, {Color? primary}) {
    final borderColor = f.color ?? primary ?? const Color(0xFF0A2B4E);
    return InputDecoration(
      labelText: f.label + (f.required ? ' *' : ''),
      hintText: f.placeholder,
      helperText: f.hint,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: f.icon != null ? Icon(f.icon, color: borderColor) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor.withOpacity(.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildField(FieldSpec f, Color? primary) {
    final widthFactor = f.width ?? 1.0;

    Widget child;
    switch (f.type) {
      case FieldType.text:
      case FieldType.number:
        final c = _controllers[f.key] ??=
            TextEditingController(text: f.defaultValue?.toString());
        child = TextFormField(
          controller: c,
          keyboardType: f.type == FieldType.number
              ? TextInputType.number
              : TextInputType.text,
          validator: (v) {
            if (f.required && (v == null || v.trim().isEmpty)) {
              return 'Campo obbligatorio';
            }
            return null;
          },
          onSaved: (v) => widget._values[f.key] = v,
          decoration: _decoration(f, primary: primary),
        );
        break;

      case FieldType.textarea:
        final c = _controllers[f.key] ??=
            TextEditingController(text: f.defaultValue?.toString());
        child = TextFormField(
          controller: c,
          maxLines: 5,
          minLines: 3,
          decoration: _decoration(f, primary: primary),
          validator: (v) {
            if (f.required && (v == null || v.trim().isEmpty)) {
              return 'Campo obbligatorio';
            }
            return null;
          },
          onSaved: (v) => widget._values[f.key] = v,
        );
        break;

      case FieldType.dropdown:
        final opts = f.options ?? const <String>[];
        // usa il valore presente nello stato, altrimenti fallback a default/first
        String? current = widget._values.containsKey(f.key)
            ? (widget._values[f.key] as String?)
            : ((f.defaultValue?.toString().isNotEmpty ?? false)
                ? f.defaultValue.toString()
                : (opts.isNotEmpty ? opts.first : null));
        widget._values[f.key] = current;
        child = DropdownButtonFormField<String>(
          value: current,
          items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => widget._values[f.key] = v),
          validator: (v) =>
              (f.required && (v == null || v.isEmpty)) ? 'Seleziona un valore' : null,
          decoration: _decoration(f, primary: primary)
              .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
        );
        break;

      case FieldType.date:
        final c = _controllers[f.key] ??=
            TextEditingController(text: f.defaultValue?.toString());
        child = GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime(now.year + 20),
              initialDate: now,
              helpText: f.label,
            );
            if (picked != null) {
              final txt =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              c.text = txt;
              widget._values[f.key] = txt;
              setState(() {});
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              controller: c,
              decoration: _decoration(f, primary: primary)
                  .copyWith(suffixIcon: const Icon(Icons.event_outlined)),
              validator: (v) =>
                  (f.required && (v == null || v.isEmpty)) ? 'Seleziona una data' : null,
              onSaved: (v) => widget._values[f.key] = v,
            ),
          ),
        );
        break;

      case FieldType.checkbox:
        bool current = widget._values.containsKey(f.key)
            ? (widget._values[f.key] as bool? ?? false)
            : (f.defaultValue is bool ? f.defaultValue as bool : false);
        widget._values[f.key] = current;
        child = CheckboxListTile(
          value: current,
          onChanged: (v) => setState(() {
            widget._values[f.key] = v ?? false;
          }),
          title: Text(f.label + (f.required ? ' *' : '')),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        );
        break;

      case FieldType.switcher:
        bool current = widget._values.containsKey(f.key)
            ? (widget._values[f.key] as bool? ?? false)
            : (f.defaultValue is bool ? f.defaultValue as bool : false);
        widget._values[f.key] = current;
        child = SwitchListTile(
          value: current,
          onChanged: (v) => setState(() {
            widget._values[f.key] = v;
          }),
          title: Text(f.label + (f.required ? ' *' : '')),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        );
        break;
    }

    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.2, 1.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget._schema.value;

    if (schema == null) {
      return Center(
        child: Card(
          elevation: 0,
          color: const Color(0xFFF5F7FB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Usa la chat a destra per inviare lo schema del form con lo strumento "SetFormSchemaWidget".',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final cs = ColorScheme.fromSeed(
      seedColor: schema.primaryColor ?? const Color(0xFF1E88E5),
      brightness: Theme.of(context).brightness,
    );

    // Tema + contenuto scrollabile (se molto alto)
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: cs,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side:
                BorderSide(color: (schema.primaryColor ?? cs.primary).withOpacity(.7)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              color: schema.surfaceColor ?? Colors.white,
              elevation: 2,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: schema.padding,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (schema.title != null) ...[
                        _StagedAppear(
                          // il titolo entra subito
                          controller: AnimationController(
                            vsync: this,
                            duration: const Duration(milliseconds: 300),
                          )..forward(),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              schema.title!,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Grid fluida (wrap) con comparsa graduale dei campi
                      LayoutBuilder(
                        builder: (ctx, c) {
                          return Wrap(
                            alignment: WrapAlignment.start,
                            runSpacing: 0,
                            children: [
                              for (int i = 0; i < schema.fields.length; i++)
                                _StagedAppear(
                                  controller: (i < _fieldCtrls.length)
                                      ? _fieldCtrls[i]
                                      : (AnimationController(
                                          vsync: this,
                                          duration:
                                              const Duration(milliseconds: 300),
                                        )..forward()),
                                  delayMs: 0, // già gestito in _onSchema
                                  child: _buildField(
                                      schema.fields[i], schema.primaryColor),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // Pulsanti con apparizione dopo i campi
                      _StagedAppear(
                        controller: _buttonsCtrl,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (int i = 0; i < schema.buttons.length; i++) ...[
                              _buildButton(schema.buttons[i], schema.primaryColor),
                              if (i < schema.buttons.length - 1)
                                const SizedBox(width: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(ButtonSpec b, Color? primary) {
    final bg = b.color ?? primary;
    final fg = b.textColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.white);
    final onPressed = () {
      if (b.action == 'submit') {
        if (_formKey.currentState?.validate() ?? false) {
          _formKey.currentState?.save();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form inviato (demo).')),
          );
        }
      } else if (b.action == 'reset') {
        _formKey.currentState?.reset();
        widget._values.clear();
        for (final c in _controllers.values) c.clear();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Azione: ${b.action}')),
        );
      }
    };

    switch (b.variant) {
      case 'outlined':
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor:
                b.textColor ?? bg ?? Theme.of(context).colorScheme.primary,
          ),
          child: Text(b.label),
        );
      case 'text':
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor:
                b.textColor ?? bg ?? Theme.of(context).colorScheme.primary,
          ),
          child: Text(b.label),
        );
      default: // filled
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? Theme.of(context).colorScheme.primary,
            foregroundColor: fg,
          ),
          child: Text(b.label),
        );
    }
  }
}

/// =======================================================
/// Widget helper: fade + slide-in per comparsa graduale
/// =======================================================
class _StagedAppear extends StatefulWidget {
  const _StagedAppear({
    super.key,
    required this.controller,
    required this.child,
    this.delayMs = 0,
    this.offsetBegin = const Offset(0, .06),
  });

  final AnimationController controller;
  final Widget child;
  final int delayMs;
  final Offset offsetBegin;

  @override
  State<_StagedAppear> createState() => _StagedAppearState();
}

class _StagedAppearState extends State<_StagedAppear> {
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final curved = CurvedAnimation(parent: widget.controller, curve: Curves.easeOut);
    _fade = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offsetBegin, end: Offset.zero).animate(curved);

    if (widget.delayMs > 0 && widget.controller.status == AnimationStatus.dismissed) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) widget.controller.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value.dy * 24), // piccolo slide morbido
          child: widget.child,
        ),
      ),
    );
  }
}
