import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';          // ← Clipboard
import 'package:flutter_app/chatbot.dart';       // contiene ChatBotPageState


/// Restituisce sempre la stessa tonalità per la stessa **chiave**.
/// Hue deterministico (0-359), saturazione e lightness fisse per avere
/// colori “soft” ma riconoscibili.
Color colorForChatKey(String key) {
  final int h = key.codeUnits.fold(0, (sum, c) => (sum * 31 + c)) % 360;
  return HSLColor.fromAHSL(1, h.toDouble(), .55, .60).toColor();
}

/// Variante “scurita” (-35 % di lightness) — utile per il testo header.
Color darker(Color c) =>
    HSLColor.fromColor(c).withLightness((HSLColor.fromColor(c).lightness - .35).clamp(0.0, 1.0)).toColor();


class ChatVarsWidgetTool extends StatefulWidget {
  const ChatVarsWidgetTool({
    super.key,
    required this.jsonData,
    required this.applyPatch,
  });

  final Map<String, dynamic> jsonData;
  final void Function(Map<String, dynamic>) applyPatch;

  @override
  State<ChatVarsWidgetTool> createState() => _ChatVarsWidgetToolState();
}

class _ChatVarsWidgetToolState extends State<ChatVarsWidgetTool> {
  late final Map<String, dynamic> _patch;

  @override
  void initState() {
    super.initState();
    _patch = Map<String, dynamic>.from(widget.jsonData['updates'] ?? {});
    widget.applyPatch(_patch);                         // applica patch subito
  }

  /*────────── colori coerenti ──────────*/
  Color _colorFromValue(dynamic v) {
    final h = v.hashCode & 0x7FFFFFFF;                 // positivo
    return HSLColor.fromAHSL(1, (h % 360).toDouble(), .55, .55).toColor();
  }

  Color _darker(Color c) =>
      HSLColor.fromColor(c).withLightness(.25).toColor();   // lightness fisso

  /*────────── riquadro variabile ──────────*/
  Widget _buildVarCard(String key, dynamic value) {
  final Color border = colorForChatKey(key);   // colore deterministico
  final Color text   = darker(border);         // versione scurita

    final String pretty = (value is Map || value is List)
        ? const JsonEncoder.withIndent('  ').convert(value)
        : value.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* header */
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: border.withOpacity(.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(key,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: text)),
                ),
                IconButton(
                  tooltip: 'Copia',
                  icon: const Icon(Icons.copy, size: 16),
                  splashRadius: 18,
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: pretty)),
                ),
              ],
            ),
          ),
          /* divisore */
          Container(height: 2, color: border),
          /* valore */
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SelectableText(
              pretty,
              style:
                  const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /*────────── build ──────────*/
  @override
  Widget build(BuildContext context) {
    if (_patch.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // banner di conferma
        Card(
          color: Colors.lightGreen.shade50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('chatVars aggiornate'),
            subtitle: Text('${_patch.length} campo/i modificato/i'),
          ),
        ),
        // variabili
        ..._patch.entries.map((e) => _buildVarCard(e.key, e.value)),
      ],
    );
  }
}
