import 'dart:convert';
import 'dart:math' as math;
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';

/// ============================
/// Host callbacks
/// ============================
class MyHostCallbacks extends ChatBotHostCallbacks {
  const MyHostCallbacks({required this.applyStyle});
  final void Function(ButtonStyleState) applyStyle;
}

/// ============================
/// Modello dello stile del bottone (colore o gradiente)
/// ============================
enum ButtonFillType { solid, linear, radial, sweep }

class ButtonStyleState {
  final ButtonFillType type;
  final List<Color> colors;         // 1..4
  final List<double>? stops;        // opzionale, 0..1, stessa len di colors
  // linear
  final double? angleDeg;           // 0=left→right, 90=top→bottom
  final TileMode tileMode;
  // radial/sweep
  final Offset? center01;           // 0..1
  final double? radius;             // 0..1 (radial)
  // sweep
  final double? startAngleDeg;      // sweep
  final double? endAngleDeg;        // sweep

  const ButtonStyleState({
    required this.type,
    required this.colors,
    this.stops,
    this.angleDeg,
    this.center01,
    this.radius,
    this.startAngleDeg,
    this.endAngleDeg,
    this.tileMode = TileMode.clamp,
  });

  factory ButtonStyleState.solid(Color c) =>
      ButtonStyleState(type: ButtonFillType.solid, colors: [c]);

  ButtonStyleState copyWith({
    ButtonFillType? type,
    List<Color>? colors,
    List<double>? stops,
    double? angleDeg,
    Offset? center01,
    double? radius,
    double? startAngleDeg,
    double? endAngleDeg,
    TileMode? tileMode,
  }) {
    return ButtonStyleState(
      type: type ?? this.type,
      colors: colors ?? this.colors,
      stops: stops ?? this.stops,
      angleDeg: angleDeg ?? this.angleDeg,
      center01: center01 ?? this.center01,
      radius: radius ?? this.radius,
      startAngleDeg: startAngleDeg ?? this.startAngleDeg,
      endAngleDeg: endAngleDeg ?? this.endAngleDeg,
      tileMode: tileMode ?? this.tileMode,
    );
  }
}

/// ============================
/// Widget tool richiamato dal ChatBot
/// Accetta:
///  - colore singolo (argb/hex/nome)
///  - gradient JSON fino a 4 colori:
///    {
///      "style": "linear|radial|sweep",
///      "colors": ["#FF1E88E5","FF00FF00",...],
///      "stops": [0,0.5,1],
///      "angle": 45,                 // linear
///      "tile_mode": "clamp|mirror|repeated",
///      "center": {"x":0.5,"y":0.5}, // radial/sweep
///      "radius": 0.6,               // radial
///      "start_angle": 0,            // sweep (deg)
///      "end_angle": 360             // sweep (deg)
///    }
/// ============================
class SetButtonStyleWidget extends StatefulWidget {
  const SetButtonStyleWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final MyHostCallbacks hostCbs;

  @override
  State<SetButtonStyleWidget> createState() => _SetButtonStyleWidgetState();
}

class _SetButtonStyleWidgetState extends State<SetButtonStyleWidget> {
  ButtonStyleState? _style;
  String? _error;

  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final (st, err) = _extractStyle(widget.jsonData);
    _style = st;
    _error = err;

    if (firstTime && st != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.hostCbs.applyStyle(st);
      });
    }
  }

  /// Estrae stile: prova prima GRADIENT, poi colore singolo (legacy).
  (ButtonStyleState?, String?) _extractStyle(Map<String, dynamic> data) {
    // 1) gradient come oggetto o stringa JSON
    dynamic gRaw = data['gradient'];
    Map<String, dynamic>? g;
    if (gRaw is String && gRaw.trim().isNotEmpty) {
      try { g = jsonDecode(gRaw) as Map<String, dynamic>; } catch (_) {}
    } else if (gRaw is Map) {
      g = Map<String, dynamic>.from(gRaw);
    }
    // oppure parametri gradient "sparsi" in root
    g ??= _looksLikeGradientRoot(data) ? Map<String, dynamic>.from(data) : null;

    if (g != null) {
      final styleStr = (g['style'] ?? '').toString().toLowerCase();
      final type = switch (styleStr) {
        'linear' => ButtonFillType.linear,
        'radial' => ButtonFillType.radial,
        'sweep'  => ButtonFillType.sweep,
        _        => ButtonFillType.linear,
      };

      final colors = _parseColorsList(g['colors']);
      if (colors == null || colors.isEmpty) {
        return (null, 'Gradient: lista colori mancante o non valida.');
      }
      if (colors.length > 4) colors.removeRange(4, colors.length);
      if (colors.length == 1) {
        // degrada a colore pieno
        return (ButtonStyleState.solid(colors.first), null);
      }

      final stops = _parseStopsList(g['stops'], colors.length);
      final tm = _parseTileMode(g['tile_mode']);

      if (type == ButtonFillType.linear) {
        final angle = _parseDouble(g['angle']) ?? 0.0;
        return (ButtonStyleState(
          type: ButtonFillType.linear,
          colors: colors,
          stops: stops,
          angleDeg: angle,
          tileMode: tm,
        ), null);
      }

      if (type == ButtonFillType.radial) {
        final cx = _parseDouble((g['center'] is Map) ? g['center']['x'] : g['center_x']) ?? 0.5;
        final cy = _parseDouble((g['center'] is Map) ? g['center']['y'] : g['center_y']) ?? 0.5;
        final radius = _parseDouble(g['radius']) ?? 0.5;
        return (ButtonStyleState(
          type: ButtonFillType.radial,
          colors: colors,
          stops: stops,
          center01: Offset(cx.clamp(0.0, 1.0), cy.clamp(0.0, 1.0)),
          radius: radius.clamp(0.0, 1.0),
          tileMode: tm,
        ), null);
      }

      // sweep
      final cx = _parseDouble((g['center'] is Map) ? g['center']['x'] : g['center_x']) ?? 0.5;
      final cy = _parseDouble((g['center'] is Map) ? g['center']['y'] : g['center_y']) ?? 0.5;
      final start = _parseDouble(g['start_angle']) ?? 0.0;
      final end   = _parseDouble(g['end_angle']) ?? 360.0;
      return (ButtonStyleState(
        type: ButtonFillType.sweep,
        colors: colors,
        stops: stops,
        center01: Offset(cx.clamp(0.0, 1.0), cy.clamp(0.0, 1.0)),
        startAngleDeg: start,
        endAngleDeg: end,
        tileMode: tm,
      ), null);
    }

    // 2) colore singolo (compat)
    final (col, err) = _extractSingleColor(data);
    if (col != null) return (ButtonStyleState.solid(col), null);
    return (null, err ?? 'Nessun colore o gradiente valido fornito.');
  }

  bool _looksLikeGradientRoot(Map<String, dynamic> d) {
    final s = (d['style'] ?? '').toString().toLowerCase();
    return d['colors'] != null && (s == 'linear' || s == 'radial' || s == 'sweep');
  }

  (Color?, String?) _extractSingleColor(Map<String, dynamic> data) {
    final candidates = <String>[
      (data['argb'] ?? '').toString(),
      (data['hex'] ?? '').toString(),
      (data['color'] ?? '').toString(),
    ].where((s) => s.trim().isNotEmpty).toList();

    if (candidates.isEmpty) {
      final a = data['a'], r = data['r'], g = data['g'], b = data['b'];
      if (a != null && r != null && g != null && b != null) {
        candidates.add('$a,$r,$g,$b');
      }
    }
    if (candidates.isEmpty) return (null, 'Nessun codice colore fornito.');

    for (final raw in candidates) {
      final c = _parseColorFlexible(raw);
      if (c != null) return (c, null);
    }

    final named = (data['color'] ?? '').toString().trim().toLowerCase();
    Color? c;
    switch (named) {
      case 'red':   c = Colors.red; break;
      case 'green': c = Colors.green; break;
      case 'blue':  c = Colors.blue; break;
    }
    if (c != null) return (c, null);
    return (null, 'Formato colore non riconosciuto.');
  }

  List<Color>? _parseColorsList(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final out = <Color>[];
      for (final it in raw) {
        final c = _parseColorFlexible(it.toString());
        if (c != null) out.add(c);
      }
      return out;
    }
    // anche stringa separata da virgole
    if (raw is String && raw.contains(',')) {
      final out = <Color>[];
      for (final part in raw.split(',')) {
        final c = _parseColorFlexible(part.trim());
        if (c != null) out.add(c);
      }
      return out;
    }
    final single = _parseColorFlexible(raw.toString());
    return single == null ? null : [single];
  }

  List<double>? _parseStopsList(dynamic raw, int nColors) {
    if (raw == null) return null;
    List<double>? list;
    if (raw is List) {
      list = raw.map((e) => _parseDouble(e) ?? double.nan).toList();
    } else if (raw is String) {
      list = raw.split(',').map((e) => _parseDouble(e.trim()) ?? double.nan).toList();
    }
    if (list == null) return null;
    // valida
    if (list.length != nColors) return null;
    final clamped = list.map((v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0)).toList();
    return clamped;
  }

  TileMode _parseTileMode(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    return switch (s) {
      'mirror'   => TileMode.mirror,
      'repeated' => TileMode.repeated,
      _          => TileMode.clamp,
    };
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ====== Color parsing (flessibile) ======
  Color? _parseColorFlexible(String rawInput) {
    final raw = rawInput.trim();

    // argb(a,r,g,b)
    final argb = RegExp(r'^argb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$', caseSensitive: false);
    final mArgb = argb.firstMatch(raw);
    if (mArgb != null) {
      final a = int.parse(mArgb.group(1)!);
      final r = int.parse(mArgb.group(2)!);
      final g = int.parse(mArgb.group(3)!);
      final b = int.parse(mArgb.group(4)!);
      if (_inByte(a) && _inByte(r) && _inByte(g) && _inByte(b)) {
        return Color(_argbToInt(a, r, g, b));
      }
      return null;
    }

    // rgba(r,g,b,a)
    final rgba = RegExp(r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*([0-9]*\.?[0-9]+)\s*\)$', caseSensitive: false);
    final mRgba = rgba.firstMatch(raw);
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
      if (_inByte(a) && _inByte(r) && _inByte(g) && _inByte(b)) {
        return Color(_argbToInt(a, r, g, b));
      }
      return null;
    }

    // rgb(r,g,b)
    final rgb = RegExp(r'^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$', caseSensitive: false);
    final mRgb = rgb.firstMatch(raw);
    if (mRgb != null) {
      final r = int.parse(mRgb.group(1)!);
      final g = int.parse(mRgb.group(2)!);
      final b = int.parse(mRgb.group(3)!);
      if (_inByte(r) && _inByte(g) && _inByte(b)) {
        return Color(_argbToInt(255, r, g, b));
      }
      return null;
    }

    // a,r,g,b
    final csv = RegExp(r'^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$');
    final mCsv = csv.firstMatch(raw);
    if (mCsv != null) {
      final a = int.parse(mCsv.group(1)!);
      final r = int.parse(mCsv.group(2)!);
      final g = int.parse(mCsv.group(3)!);
      final b = int.parse(mCsv.group(4)!);
      if (_inByte(a) && _inByte(r) && _inByte(g) && _inByte(b)) {
        return Color(_argbToInt(a, r, g, b));
      }
      return null;
    }

    // #AARRGGBB, 0xAARRGGBB, AARRGGBB
    final hex8 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{8})$');
    final m8 = hex8.firstMatch(raw);
    if (m8 != null) {
      final v = int.parse(m8.group(1)!, radix: 16);
      return Color(v);
    }

    // #RRGGBB, 0xRRGGBB, RRGGBB
    final hex6 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{6})$');
    final m6 = hex6.firstMatch(raw);
    if (m6 != null) {
      final v = int.parse(m6.group(1)!, radix: 16);
      return Color(0xFF000000 | v);
    }

    return null;
  }

  bool _inByte(int v) => v >= 0 && v <= 255;

  int _argbToInt(int a, int r, int g, int b) =>
      ((a & 0xFF) << 24) |
      ((r & 0xFF) << 16) |
      ((g & 0xFF) << 8)  |
      (b & 0xFF);

  String _hex(Color c) {
    String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${two(c.alpha)}${two(c.red)}${two(c.green)}${two(c.blue)}';
  }

  String _argb(Color c) => 'ARGB(${c.alpha}, ${c.red}, ${c.green}, ${c.blue})';

  @override
  Widget build(BuildContext context) {
    final ok = _style != null;
    return Card(
      color: ok ? Colors.green.withOpacity(.10) : Colors.red.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ok ? _buildOk() : _buildErr(),
      ),
    );
  }

  Widget _buildOk() {
    final s = _style!;
    final title = switch (s.type) {
      ButtonFillType.solid  => 'Colore impostato',
      ButtonFillType.linear => 'Gradiente LINEARE impostato',
      ButtonFillType.radial => 'Gradiente RADIALE impostato',
      ButtonFillType.sweep  => 'Gradiente SWEEP impostato',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (s.type == ButtonFillType.solid)
          Text('${_argb(s.colors.first)} — HEX ${_hex(s.colors.first)}')
        else ...[
          for (int i = 0; i < s.colors.length; i++)
            Text('C${i + 1}: ${_argb(s.colors[i])} — HEX ${_hex(s.colors[i])}'
                '${s.stops != null ? ' — stop ${s.stops![i].toStringAsFixed(3)}' : ''}'),
          const SizedBox(height: 6),
          if (s.type == ButtonFillType.linear)
            Text('Angolo: ${s.angleDeg?.toStringAsFixed(1) ?? '0'}°  ·  Tile: ${s.tileMode.name}'),
          if (s.type == ButtonFillType.radial)
            Text('Centro: (${s.center01?.dx.toStringAsFixed(2)}, ${s.center01?.dy.toStringAsFixed(2)})  ·  Raggio: ${s.radius?.toStringAsFixed(2)}  ·  Tile: ${s.tileMode.name}'),
          if (s.type == ButtonFillType.sweep)
            Text('Centro: (${s.center01?.dx.toStringAsFixed(2)}, ${s.center01?.dy.toStringAsFixed(2)})  ·  Start: ${s.startAngleDeg?.toStringAsFixed(1)}°  ·  End: ${s.endAngleDeg?.toStringAsFixed(1)}°  ·  Tile: ${s.tileMode.name}'),
        ],
        const SizedBox(height: 8),
        const Text('Il pulsante a sinistra è stato aggiornato.'),
      ],
    );
  }

  Widget _buildErr() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Impossibile applicare lo stile.', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_error ?? 'Parametro non valido.'),
        const SizedBox(height: 6),
        const Text(
          'Solid: param "argb" (es. "FF1E88E5", "#FF1E88E5", "argb(255,30,136,229)").\n'
          'Gradient (param "gradient" string JSON):\n'
          '{ "style":"linear|radial|sweep", "colors":["#FF1E88E5","FF00FF00"], "stops":[0,1], "angle":45, "tile_mode":"clamp", "center":{"x":0.5,"y":0.5}, "radius":0.6, "start_angle":0, "end_angle":360 }',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

/// ============================
/// ToolSpec esposto all’LLM
/// - "argb" per colore singolo
/// - "gradient" (JSON string) per gradiente fino a 4 colori
/// ============================
const ToolSpec kSetButtonStyleTool = ToolSpec(
  toolName: 'SetButtonStyleWidget',
  description: 'Imposta il bottone con colore pieno o gradiente (linear/radial/sweep).',
  params: [
    ToolParamSpec(
      name: 'argb',
      paramType: ParamType.string,
      description: 'Colore singolo (#AARRGGBB, 0xAARRGGBB, AARRGGBB, argb(a,r,g,b), rgba, rgb, "a,r,g,b").',
      example: 'FF1E88E5',
    ),
    ToolParamSpec(
      name: 'gradient',
      paramType: ParamType.string,
      description:
          'JSON con stile e parametri. Esempio: '
          '{"style":"linear","colors":["#FF1E88E5","#FF00BCD4"],"stops":[0,1],"angle":45,"tile_mode":"clamp"} '
          'oppure {"style":"radial","colors":["#FFFF8A65","#FFFFD180","#FF4DB6AC"],"center":{"x":0.5,"y":0.5},"radius":0.6} '
          'oppure {"style":"sweep","colors":["#FFFF8A65","#FF4DB6AC","#FFFFD180"],"center":{"x":0.5,"y":0.5},"start_angle":0,"end_angle":360}.',
      example: '{"style":"linear","colors":["#FF1E88E5","#FF00BCD4"],"stops":[0,1],"angle":45}',
    ),
  ],
);

/// ============================
/// Pannello sinistro:
///  - Pulsante circolare con colore/gradiente
///  - Sotto: elenco ARGB/HEX dei colori e parametri del gradiente
/// ============================
class ColorButtonPanel extends StatefulWidget with ChatBotExtensions {
  ColorButtonPanel({super.key});

  final ValueNotifier<ButtonStyleState> _style =
      ValueNotifier<ButtonStyleState>(ButtonStyleState.solid(Colors.red));

  @override
  ChatBotHostCallbacks get hostCallbacks =>
      MyHostCallbacks(applyStyle: (s) => _style.value = s);

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'SetButtonStyleWidget': (data, onR, pCbs, hCbs) => SetButtonStyleWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as MyHostCallbacks,
            ),
      };

  @override
  List<ToolSpec> get toolSpecs => const [kSetButtonStyleTool];

  @override
  State<ColorButtonPanel> createState() => _ColorButtonPanelState();
}

class _ColorButtonPanelState extends State<ColorButtonPanel> {
  @override
  void initState() {
    super.initState();
    widget._style.addListener(_onStyle);
  }

  @override
  void dispose() {
    widget._style.removeListener(_onStyle);
    super.dispose();
  }

  void _onStyle() => setState(() {});

  // Helpers di presentazione
  String _hex(Color c) {
    String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${two(c.alpha)}${two(c.red)}${two(c.green)}${two(c.blue)}';
  }
  String _argb(Color c) => 'ARGB(${c.alpha}, ${c.red}, ${c.green}, ${c.blue})';

  // Converte angolo (deg) in begin/end Alignment per LinearGradient
  (Alignment, Alignment) _angleToAlign(double angleDeg) {
    final rad = angleDeg * math.pi / 180.0;
    final x = math.cos(rad);
    final y = math.sin(rad);
    // begin: opposto
    return (Alignment(-x, -y), Alignment(x, y));
  }

  Gradient? _asGradient(ButtonStyleState s) {
    if (s.type == ButtonFillType.solid) return null;
    if (s.colors.length == 1) return null;

    switch (s.type) {
      case ButtonFillType.linear:
        final angle = s.angleDeg ?? 0.0;
        final (begin, end) = _angleToAlign(angle);
        return LinearGradient(
          colors: s.colors,
          stops: s.stops,
          begin: begin,
          end: end,
          tileMode: s.tileMode,
        );

      case ButtonFillType.radial:
        final c = s.center01 ?? const Offset(.5, .5);
        return RadialGradient(
          colors: s.colors,
          stops: s.stops,
          center: Alignment(c.dx * 2 - 1, c.dy * 2 - 1),
          radius: (s.radius ?? .5).clamp(0.0, 1.0),
          tileMode: s.tileMode,
        );

      case ButtonFillType.sweep:
        final c = s.center01 ?? const Offset(.5, .5);
        final start = (s.startAngleDeg ?? 0.0) * math.pi / 180.0;
        final end   = (s.endAngleDeg   ?? 360.0) * math.pi / 180.0;
        return SweepGradient(
          colors: s.colors,
          stops: s.stops,
          center: Alignment(c.dx * 2 - 1, c.dy * 2 - 1),
          startAngle: start,
          endAngle: end,
          tileMode: s.tileMode,
        );

      case ButtonFillType.solid:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget._style.value;
    final grad = _asGradient(s);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsante circolare con gradiente/colore
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: grad == null ? s.colors.first : null,
                gradient: grad,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Didascalie: ARGB/HEX e parametri gradient
          if (s.type == ButtonFillType.solid) ...[
            Text(
              _argb(s.colors.first),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('HEX ${_hex(s.colors.first)}',
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ] else ...[
            // elenco colori
            for (int i = 0; i < s.colors.length; i++) ...[
              Text(
                'C${i + 1}: ${_argb(s.colors[i])} — HEX ${_hex(s.colors[i])}'
                '${s.stops != null ? ' — stop ${s.stops![i].toStringAsFixed(3)}' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: i == 0 ? Colors.black87 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (i < s.colors.length - 1) const SizedBox(height: 2),
            ],
            const SizedBox(height: 6),
            if (s.type == ButtonFillType.linear)
              Text('Linear  ·  angle ${s.angleDeg?.toStringAsFixed(1) ?? '0'}°  ·  tile ${s.tileMode.name}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (s.type == ButtonFillType.radial)
              Text('Radial  ·  center (${(s.center01?.dx ?? .5).toStringAsFixed(2)}, ${(s.center01?.dy ?? .5).toStringAsFixed(2)})'
                   '  ·  radius ${(s.radius ?? .5).toStringAsFixed(2)}  ·  tile ${s.tileMode.name}',
                   style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (s.type == ButtonFillType.sweep)
              Text('Sweep  ·  center (${(s.center01?.dx ?? .5).toStringAsFixed(2)}, ${(s.center01?.dy ?? .5).toStringAsFixed(2)})'
                   '  ·  start ${s.startAngleDeg?.toStringAsFixed(1) ?? '0'}°  ·  end ${s.endAngleDeg?.toStringAsFixed(1) ?? '360'}°'
                   '  ·  tile ${s.tileMode.name}',
                   style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ],
      ),
    );
  }
}
