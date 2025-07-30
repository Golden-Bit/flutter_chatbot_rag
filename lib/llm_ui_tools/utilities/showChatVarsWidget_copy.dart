
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/chatbot.dart';
import 'package:flutter_app/llm_ui_tools/utilities/ChatVarsContentRendered.dart';          // ← Clipboard

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


class ShowChatVarsWidgetTool extends StatelessWidget {
  const ShowChatVarsWidgetTool({
    super.key,
    required this.jsonData,
    required this.getVars,
  });

  final Map<String, dynamic> jsonData;
  final Map<String, dynamic> Function() getVars;

  // ---------- stub callbacks -------------------------------------------------
  static final _dummyPageCbs = ChatBotPageCallbacks(
    renameChat: (_, __) async {},
    sendReply : (_) {},
  );
  static const _dummyHostCbs = ChatBotHostCallbacks();
  static const Map<String, ChatWidgetBuilder> _emptyBuilders = {};

  // ---------------------------------------------------------------------------

  /*────────── colori deterministici ──────────*/
  Color _colorFromString(String s) {
    final h = s.codeUnits.fold(0, (a, b) => a + b) % 360;
    return HSLColor.fromAHSL(1, h.toDouble(), .55, .55).toColor();
  }

  Color _darker(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - .35).clamp(0.0, 1.0)).toColor();
  }

  /*────────── card singola ──────────*/
  Widget _buildVarCard(BuildContext context, String k, dynamic v) {
final Color borderColor = colorForChatKey(k);
final Color headerText  = darker(borderColor);

    final String pretty = (v is Map || v is List)
        ? const JsonEncoder.withIndent('  ').convert(v)
        : v.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* header */
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(.12),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(k,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: headerText)),
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
          /* separatore */
          Container(height: 2, color: borderColor),
          /* valore */
          /* valore renderizzato con Markdown + Tool-UI inline */
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: renderContent(
                context,
                parseContent(pretty),               // onReply: no-op
                _dummyPageCbs,          // stub callbacks interni
                _dummyHostCbs, 
                const {},               // passa la mappa VERA         // stub callbacks host
                (_) {},          // nessun widget extra
              ),
            ),
          ),
        ],
      ),
    );
  }

  /*────────── build ──────────*/
  @override
  Widget build(BuildContext context) {
    final vars   = getVars();
final List<String> wanted = (jsonData['keys'] == null || (jsonData['keys'] as List).isEmpty)
    ? vars.keys.toList()  // tutte le variabili
    : List<String>.from(jsonData['keys']);
    final cards = <Widget>[
      for (final k in wanted)
        if (vars.containsKey(k)) _buildVarCard(context, k, vars[k]),
    ];

    if (cards.isEmpty) {
      cards.add(const Text(
        '⚠️ Nessuna variabile corrispondente',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cards,
    );
  }
}
