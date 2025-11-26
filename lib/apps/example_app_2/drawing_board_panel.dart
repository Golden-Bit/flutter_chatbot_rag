import 'dart:convert';
import 'dart:math' as math;
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';

/// =======================================================
/// HOST CALLBACKS per la tavola grafica
/// =======================================================
class DrawingBoardHostCallbacks extends ChatBotHostCallbacks {
  const DrawingBoardHostCallbacks({
    required this.applyOps,
    required this.clearBoard,
    required this.undo,
  });

  /// Applica una lista di operazioni (disegno)
  final void Function(List<DrawOp>) applyOps;

  /// Svuota la tavola
  final VoidCallback clearBoard;

  /// Undo ultimo step
  final VoidCallback undo;
}

/// =======================================================
/// MODEL: lista di operazioni con notify per repaint immediato
/// =======================================================
class DrawingBoardModel extends ChangeNotifier {
  final List<DrawOp> _ops = [];

  List<DrawOp> get ops => List.unmodifiable(_ops);

  void addAll(Iterable<DrawOp> items) {
    _ops.addAll(items);
    notifyListeners(); // repaint immediato
  }

  void add(DrawOp op) {
    _ops.add(op);
    notifyListeners();
  }

  void undo() {
    if (_ops.isNotEmpty) {
      _ops.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    if (_ops.isNotEmpty) {
      _ops.clear();
      notifyListeners();
    }
  }
}

/// =======================================================
/// SPECIFICA OPERAZIONE DISEGNO
/// =======================================================
enum DrawKind {
  line,
  polyline,
  freehand,
  rect,
  roundRect,
  circle,
  ellipse,  // ⬅️ importante
  curve,    // quadratic(3 pt) o cubic(4 pt)
  path,     // comandi: M/L/Q/C/Z
  clear,    // utility
  undo,     // utility
}

class DrawStyle {
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
  final List<double>? dash; // [on, off, on, off...]
  final double? miterLimit;

  const DrawStyle({
    this.fill,
    this.stroke,
    this.strokeWidth = 1.0,
    this.cap = StrokeCap.round,
    this.join = StrokeJoin.round,
    this.dash,
    this.miterLimit,
  });

  factory DrawStyle.fromJson(Map<String, dynamic> json) {
    final c = _ColorParser();
    StrokeCap _cap(String? s) => switch ((s ?? '').toLowerCase()) {
          'butt' => StrokeCap.butt,
          'square' => StrokeCap.square,
          _ => StrokeCap.round,
        };
    StrokeJoin _join(String? s) => switch ((s ?? '').toLowerCase()) {
          'miter' => StrokeJoin.miter,
          'bevel' => StrokeJoin.bevel,
          _ => StrokeJoin.round,
        };

    List<double>? _dash(dynamic v) {
      if (v is List) {
        final out = <double>[];
        for (final e in v) {
          final n = (e is num) ? e.toDouble() : double.tryParse(e.toString());
          if (n != null && n > 0) out.add(n);
        }
        return out.isEmpty ? null : out;
      }
      return null;
    }

    return DrawStyle(
      fill: c.parse(json['fill']),
      stroke: c.parse(json['stroke']),
      strokeWidth: (json['strokeWidth'] is num)
          ? (json['strokeWidth'] as num).toDouble().clamp(0.1, 100.0)
          : 1.0,
      cap: _cap(json['lineCap']),
      join: _join(json['lineJoin']),
      dash: _dash(json['strokeDash']),
      miterLimit: (json['miterLimit'] is num)
          ? (json['miterLimit'] as num).toDouble()
          : null,
    );
  }
}

class DrawOp {
  final DrawKind type;
  final List<Offset> points;
  final DrawStyle style;
  final double? radius;      // circle
  final double? rx, ry;      // ellipse explicit radii (opzionali)
  final List<PathCmd>? path; // path commands (se type == path)

  DrawOp({
    required this.type,
    required this.points,
    required this.style,
    this.radius,
    this.rx,
    this.ry,
    this.path,
  });

  factory DrawOp.fromJson(Map<String, dynamic> json) {
    DrawKind _kind(String s) {
      switch (s.toLowerCase()) {
        case 'line':
          return DrawKind.line;
        case 'polyline':
          return DrawKind.polyline;
        case 'freehand':
          return DrawKind.freehand;
        case 'rect':
          return DrawKind.rect;
        case 'roundrect':
        case 'round_rect':
        case 'rrect':
          return DrawKind.roundRect;
        case 'circle':
          return DrawKind.circle;
        case 'ellipse':
          return DrawKind.ellipse;
        case 'curve':
          return DrawKind.curve;
        case 'path':
          return DrawKind.path;
        case 'clear':
          return DrawKind.clear;
        case 'undo':
          return DrawKind.undo;
        default:
          return DrawKind.polyline;
      }
    }

    List<Offset> _pts(dynamic v) {
      final out = <Offset>[];
      if (v is List) {
        for (final e in v) {
          if (e is List && e.length >= 2) {
            final dx = (e[0] is num) ? e[0].toDouble() : double.tryParse(e[0].toString());
            final dy = (e[1] is num) ? e[1].toDouble() : double.tryParse(e[1].toString());
            if (dx != null && dy != null) {
              out.add(Offset(dx, dy));
            }
          }
        }
      }
      return out;
    }

    List<PathCmd>? _parsePath(dynamic v) {
      if (v is List) {
        try {
          return v.map((e) => PathCmd.fromJson(Map<String, dynamic>.from(e))).toList();
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final kind = _kind((json['type'] ?? '').toString());
    final style = DrawStyle.fromJson(Map<String, dynamic>.from(json['style'] ?? {}));
    final pts = _pts(json['points']);

    final rad = (json['radius'] is num) ? (json['radius'] as num).toDouble() : null;
    final rx = (json['rx'] is num) ? (json['rx'] as num).toDouble() : null;
    final ry = (json['ry'] is num) ? (json['ry'] as num).toDouble() : null;

    final commands = _parsePath(json['commands']);

    return DrawOp(
      type: kind,
      points: pts,
      style: style,
      radius: rad,
      rx: rx,
      ry: ry,
      path: commands,
    );
  }
}

/// =======================================================
/// Comandi per Path (M,L,Q,C,Z)
/// =======================================================
abstract class PathCmd {
  const PathCmd();

  factory PathCmd.fromJson(Map<String, dynamic> json) {
    final t = (json['cmd'] ?? '').toString().toUpperCase();
    switch (t) {
      case 'M':
        return CmdM(_off(json['to']));
      case 'L':
        return CmdL(_off(json['to']));
      case 'Q':
        return CmdQ(_off(json['cp']), _off(json['to']));
      case 'C':
        return CmdC(_off(json['cp1']), _off(json['cp2']), _off(json['to']));
      case 'Z':
        return const CmdZ();
      default:
        return const CmdZ();
    }
  }

  static Offset _off(dynamic v) {
    if (v is List && v.length >= 2) {
      final dx = (v[0] is num) ? v[0].toDouble() : double.tryParse(v[0].toString());
      final dy = (v[1] is num) ? v[1].toDouble() : double.tryParse(v[1].toString());
      if (dx != null && dy != null) return Offset(dx, dy);
    }
    return Offset.zero;
  }

  void apply(Path p);
}

class CmdM extends PathCmd {
  final Offset to;
  const CmdM(this.to);
  @override
  void apply(Path p) => p.moveTo(to.dx, to.dy);
}

class CmdL extends PathCmd {
  final Offset to;
  const CmdL(this.to);
  @override
  void apply(Path p) => p.lineTo(to.dx, to.dy);
}

class CmdQ extends PathCmd {
  final Offset cp, to;
  const CmdQ(this.cp, this.to);
  @override
  void apply(Path p) => p.quadraticBezierTo(cp.dx, cp.dy, to.dx, to.dy);
}

class CmdC extends PathCmd {
  final Offset cp1, cp2, to;
  const CmdC(this.cp1, this.cp2, this.to);
  @override
  void apply(Path p) => p.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
}

class CmdZ extends PathCmd {
  const CmdZ();
  @override
  void apply(Path p) => p.close();
}

/// =======================================================
/// PARSER COLORE flessibile (HEX/ARGB/rgb()/rgba()/argb()/csv)
/// =======================================================
class _ColorParser {
  Color? parse(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'none') return null;

    final argb = RegExp(r'^argb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$', caseSensitive: false);
    final mArgb = argb.firstMatch(s);
    if (mArgb != null) {
      final a = int.parse(mArgb.group(1)!);
      final r = int.parse(mArgb.group(2)!);
      final g = int.parse(mArgb.group(3)!);
      final b = int.parse(mArgb.group(4)!);
      if (_inB(a) && _inB(r) && _inB(g) && _inB(b)) {
        return Color(((a & 0xFF) << 24) | (r << 16) | (g << 8) | b);
      }
      return null;
    }

    final rgba = RegExp(r'^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*([0-9]*\.?[0-9]+)\s*\)$', caseSensitive: false);
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
        return Color(((a & 0xFF) << 24) | (r << 16) | (g << 8) | b);
      }
      return null;
    }

    final rgb = RegExp(r'^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$', caseSensitive: false);
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

    final csv = RegExp(r'^\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*$');
    final mCsv = csv.firstMatch(s);
    if (mCsv != null) {
      final a = int.parse(mCsv.group(1)!);
      final r = int.parse(mCsv.group(2)!);
      final g = int.parse(mCsv.group(3)!);
      final b = int.parse(mCsv.group(4)!);
      if (_inB(a) && _inB(r) && _inB(g) && _inB(b)) {
        return Color(((a & 0xFF) << 24) | (r << 16) | (g << 8) | b);
      }
      return null;
    }

    final hex8 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{8})$');
    final m8 = hex8.firstMatch(s);
    if (m8 != null) return Color(int.parse(m8.group(1)!, radix: 16));

    final hex6 = RegExp(r'^(?:#|0x)?([A-Fa-f0-9]{6})$');
    final m6 = hex6.firstMatch(s);
    if (m6 != null) return Color(0xFF000000 | int.parse(m6.group(1)!, radix: 16));

    return null;
  }

  bool _inB(int v) => v >= 0 && v <= 255;
}

/// =======================================================
/// P A I N T E R
/// =======================================================
class _DrawingPainter extends CustomPainter {
  final DrawingBoardModel model;

  _DrawingPainter(this.model) : super(repaint: model); // ⬅️ repaint su ChangeNotifier

  @override
  void paint(Canvas canvas, Size size) {
    for (final op in model.ops) {
      _paintOp(canvas, size, op);
    }
  }

  void _paintOp(Canvas canvas, Size size, DrawOp op) {
    final s = op.style;

    // Fill paint
    Paint? fill;
    if (s.fill != null) {
      fill = Paint()
        ..color = s.fill!
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
    }

    // Stroke paint
    Paint? stroke;
    if (s.stroke != null && s.strokeWidth > 0) {
      stroke = Paint()
        ..color = s.stroke!
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.strokeWidth
        ..strokeCap = s.cap
        ..strokeJoin = s.join
        ..strokeMiterLimit = s.miterLimit ?? 4
        ..isAntiAlias = true;
    }

    switch (op.type) {
      case DrawKind.clear:
        // gestito a livello model (qui noop)
        break;

      case DrawKind.undo:
        // idem
        break;

      case DrawKind.line:
        if (op.points.length >= 2 && stroke != null) {
          final p0 = op.points.first;
          final p1 = op.points[1];
          if (s.dash?.isNotEmpty == true) {
            final path = Path()..moveTo(p0.dx, p0.dy)..lineTo(p1.dx, p1.dy);
            _drawDashedPath(canvas, path, stroke, s.dash!);
          } else {
            canvas.drawLine(p0, p1, stroke);
          }
        }
        break;

      case DrawKind.polyline:
      case DrawKind.freehand:
        if (op.points.length >= 2) {
          final path = Path()..moveTo(op.points.first.dx, op.points.first.dy);
          for (int i = 1; i < op.points.length; i++) {
            path.lineTo(op.points[i].dx, op.points[i].dy);
          }
          if (fill != null) canvas.drawPath(path, fill);
          if (stroke != null) {
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawPath(path, stroke);
            }
          }
        }
        break;

      case DrawKind.rect:
        if (op.points.length >= 2) {
          final r = Rect.fromPoints(op.points.first, op.points[1]);
          if (fill != null) canvas.drawRect(r, fill);
          if (stroke != null) {
            if (s.dash?.isNotEmpty == true) {
              final path = Path()..addRect(r);
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawRect(r, stroke);
            }
          }
        }
        break;

      case DrawKind.roundRect:
        if (op.points.length >= 2) {
          final r = Rect.fromPoints(op.points.first, op.points[1]);
          final rr = RRect.fromRectXY(r, 12, 12);
          if (fill != null) canvas.drawRRect(rr, fill);
          if (stroke != null) {
            final path = Path()..addRRect(rr);
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawRRect(rr, stroke);
            }
          }
        }
        break;

      case DrawKind.circle:
        if (op.points.isNotEmpty) {
          final c = op.points.first;
   final radius = op.radius ??
       (op.points.length >= 2
           ? (op.points[1] - c).distance
           : 20.0);
          if (fill != null) canvas.drawCircle(c, radius, fill);
          if (stroke != null) {
            final path = Path()..addOval(Rect.fromCircle(center: c, radius: radius));
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawCircle(c, radius, stroke);
            }
          }
        }
        break;

      case DrawKind.ellipse:
        // ⬇️ CORRETTA IMPLEMENTAZIONE OVAL/ELLISSE
        if (op.points.length >= 2) {
          Rect oval;
          if (op.rx != null && op.ry != null) {
            // center + rx,ry (se points[0] è centro)
            final center = op.points.first;
            oval = Rect.fromCenter(center: center, width: (op.rx! * 2), height: (op.ry! * 2));
          } else {
            // bounding box dai due punti
            oval = Rect.fromPoints(op.points.first, op.points[1]);
          }
          if (fill != null) canvas.drawOval(oval, fill);
          if (stroke != null) {
            final path = Path()..addOval(oval);
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawOval(oval, stroke);
            }
          }
        }
        break;

      case DrawKind.curve:
        // 3 pt => quadratic (p0, cp, p1)
        // 4 pt => cubic (p0, cp1, cp2, p1)
        if (op.points.length >= 3) {
          final pts = op.points;
          final path = Path()..moveTo(pts.first.dx, pts.first.dy);
          if (pts.length == 3) {
            path.quadraticBezierTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy);
          } else {
            final cp1 = pts[1], cp2 = pts[2], p1 = pts[3];
            path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
          }
          if (fill != null) canvas.drawPath(path, fill);
          if (stroke != null) {
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawPath(path, stroke);
            }
          }
        }
        break;

      case DrawKind.path:
        // comandi M/L/Q/C/Z
        final cmds = op.path;
        if (cmds != null && cmds.isNotEmpty) {
          final path = Path();
          for (final c in cmds) {
            c.apply(path);
          }
          if (fill != null) canvas.drawPath(path, fill);
          if (stroke != null) {
            if (s.dash?.isNotEmpty == true) {
              _drawDashedPath(canvas, path, stroke, s.dash!);
            } else {
              canvas.drawPath(path, stroke);
            }
          }
        }
        break;
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, List<double> dashArray) {
    // Semplice dash path
    final pm = path.computeMetrics();
    for (final metric in pm) {
      double distance = 0.0;
      int i = 0;
      while (distance < metric.length) {
        final len = dashArray[i % dashArray.length];
        final next = distance + len;
        final extract = metric.extractPath(distance, next.clamp(0.0, metric.length));
        canvas.drawPath(extract, paint);
        distance = next + (dashArray[(i + 1) % dashArray.length]);
        i += 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => oldDelegate.model != model;
}

/// =======================================================
/// WIDGET TOOL per l’agente: applica operazioni di disegno
/// Parametro: "ops" JSON (lista o oggetto { ops:[...] })
/// Supporta anche { "type":"clear" } e { "type":"undo" }.
/// =======================================================
class ApplyDrawingOpsWidget extends StatefulWidget {
  const ApplyDrawingOpsWidget({
    super.key,
    required this.jsonData,
    required this.onReply,
    required this.pageCbs,
    required this.hostCbs,
  });

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;
  final ChatBotPageCallbacks pageCbs;
  final DrawingBoardHostCallbacks hostCbs;

  @override
  State<ApplyDrawingOpsWidget> createState() => _ApplyDrawingOpsWidgetState();
}

class _ApplyDrawingOpsWidgetState extends State<ApplyDrawingOpsWidget> {
  String? _err;
  int _applied = 0;

  @override
  void initState() {
    super.initState();
    final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
    final (ops, err, special) = _extractOps(widget.jsonData);
    _err = err;

    if (firstTime && err == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // azioni speciali
        if (special == 'clear') {
          widget.hostCbs.clearBoard();
        } else if (special == 'undo') {
          widget.hostCbs.undo();
        } else if (ops != null && ops.isNotEmpty) {
          widget.hostCbs.applyOps(ops);
        }
      });
      _applied = ops?.length ?? 0;
    }
  }

  /// Ritorna: (ops, error, special)
  /// special: 'clear' | 'undo' | null
  (List<DrawOp>?, String?, String?) _extractOps(Map<String, dynamic> data) {
    // azioni speciali dirette
    final t = (data['type'] ?? '').toString().toLowerCase();
    if (t == 'clear') return (null, null, 'clear');
    if (t == 'undo') return (null, null, 'undo');

    dynamic raw = data['ops'];
    if (raw == null && data.isNotEmpty) {
      // consenti passaggio diretto come oggetto {ops:[...]} in stringa
      final s = data['payload']?.toString();
      if (s != null && s.trim().isNotEmpty) {
        try {
          final m = jsonDecode(s);
          raw = (m is Map) ? m['ops'] : m;
        } catch (_) {}
      }
    }

    List opsJson;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['ops'] is List) {
          opsJson = decoded['ops'] as List;
        } else if (decoded is List) {
          opsJson = decoded;
        } else {
          return (null, 'Formato "ops" non valido.', null);
        }
      } catch (e) {
        return (null, 'JSON non valido: $e', null);
      }
    } else if (raw is Map && raw['ops'] is List) {
      opsJson = raw['ops'] as List;
    } else if (raw is List) {
      opsJson = raw;
    } else {
      return (null, 'Parametro "ops" mancante o malformato.', null);
    }

    try {
      final ops = opsJson
          .map((e) => DrawOp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (ops, null, null);
    } catch (e) {
      return (null, 'Errore parsing ops: $e', null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _err == null;
    return Card(
      color: ok ? Colors.green.withOpacity(.10) : Colors.red.withOpacity(.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ok
            ? Text('Operazioni applicate: $_applied',
                style: const TextStyle(fontWeight: FontWeight.w600))
            : Text(_err!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// =======================================================
/// ToolSpec per l’LLM (agente)
/// - ApplyDrawingOpsWidget: applica operazioni
///   Esempio payload:
///   {"ops":[{"type":"ellipse","points":[[100,100],[200,200]],"style":{"stroke":"#1E90FF","strokeWidth":5,"fill":"#ADD8E6"}}]}
///   Speciali: {"type":"clear"} | {"type":"undo"}
/// =======================================================
const ToolSpec kApplyDrawingOpsTool = ToolSpec(
  toolName: 'ApplyDrawingOpsWidget',
  description:
      'Applica operazioni di disegno alla tavola (line, polyline, freehand, rect, roundRect, circle, ellipse, curve, path). '
      'Supporta fill/stroke/strokeWidth/dash/join/cap e azioni speciali clear/undo.',
  params: [
    ToolParamSpec(
      name: 'ops',
      paramType: ParamType.string,
      description:
          'JSON con lista di operazioni o oggetto con chiave "ops". Ogni op ha: type, points, style. Esempio: '
          '{"ops":[{"type":"ellipse","points":[[100,100],[200,200]],"style":{"stroke":"#1E90FF","strokeWidth":5,"fill":"#ADD8E6"}}]}',
      example:
          '{"ops":[{"type":"line","points":[[20,20],[200,60]],"style":{"stroke":"#FF5722","strokeWidth":6}}]}',
    ),
  ],
);

/// =======================================================
/// PANNELLO SINISTRO: tavola grafica + input locale freehand
/// Implementa ChatBotExtensions per registrare il tool.
/// =======================================================
class DrawingBoardPanel extends StatefulWidget with ChatBotExtensions {
  DrawingBoardPanel({super.key});

  final DrawingBoardModel _model = DrawingBoardModel();

  // Host callbacks per l’agente
  @override
  ChatBotHostCallbacks get hostCallbacks => DrawingBoardHostCallbacks(
        applyOps: (ops) => _model.addAll(ops),
        clearBoard: () => _model.clear(),
        undo: () => _model.undo(),
      );

  // Tool widget dell’agente
  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'ApplyDrawingOpsWidget': (data, onR, pCbs, hCbs) => ApplyDrawingOpsWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as DrawingBoardHostCallbacks,
            ),
      };

  @override
  List<ToolSpec> get toolSpecs => const [kApplyDrawingOpsTool];

  @override
  State<DrawingBoardPanel> createState() => _DrawingBoardPanelState();
}

class _DrawingBoardPanelState extends State<DrawingBoardPanel> {
  bool _freehand = false;
  List<Offset> _currentStroke = [];

  void _toggleFreehand() => setState(() => _freehand = !_freehand);

  void _onPanStart(DragStartDetails d) {
    if (!_freehand) return;
    _currentStroke = [d.localPosition];
    // aggiungiamo subito il primo punto per vedere il tratto
    widget._model.add(DrawOp(
      type: DrawKind.freehand,
      points: List.of(_currentStroke),
      style: const DrawStyle(
        stroke: Color(0xFF111111),
        strokeWidth: 3,
        cap: StrokeCap.round,
        join: StrokeJoin.round,
      ),
    ));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_freehand) return;
    _currentStroke.add(d.localPosition);
    // aggiorna l'ultima op freehand in tempo reale
    final ops = widget._model.ops;
    if (ops.isNotEmpty && ops.last.type == DrawKind.freehand) {
      final last = ops.last;
      ops.removeLast();
      widget._model.add(DrawOp(
        type: DrawKind.freehand,
        points: List.of(_currentStroke),
        style: last.style,
      ));
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _currentStroke = [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra strumenti minimale
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _toggleFreehand,
                icon: Icon(_freehand ? Icons.draw : Icons.draw_outlined),
                label: Text(_freehand ? '✍️ Freehand ON' : '✍️ Freehand'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget._model.undo,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: widget._model.clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
              const Spacer(),
              const Text('Agent-ready • Live repaint'),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: const Color(0xFFF7F9FC),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DrawingPainter(widget._model),
                  // IMPORTANTISSIMO: anche se l’utente non tocca,
                  // il painter si aggiorna grazie a repaint:model (notifyListeners)
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
