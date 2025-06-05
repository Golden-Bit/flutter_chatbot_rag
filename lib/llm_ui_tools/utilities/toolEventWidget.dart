// © 2025 – updated ToolEventCard
import 'dart:convert';
import 'package:flutter/material.dart';

/// Card che mostra lo stato di esecuzione di un tool (start/end) e i
/// relativi payload di input/output.
///
/// • Lo spinner (o la spunta verde) è visualizzato **a sinistra** del nome.
/// • All'estrema destra un'icona freccia consente di espandere/collassare
///   i dettagli.  Di default la card è "chiusa".
/// • Sono stati aumentati i padding per rendere la scheda più ariosa.
class ToolEventCard extends StatefulWidget {
  const ToolEventCard({super.key, required this.data});

  /// `data` deve contenere almeno:
  ///  - name       : String – nome del tool
  ///  - input      : dynamic –  parametri d'ingresso (qualsiasi JSON‑like)
  ///  - output     : dynamic –  risultato (opzionale, null se non ancora concluso)
  ///  - isRunning  : bool    – true → spinner, false → completato
  final Map<String, dynamic> data;

  @override
  State<ToolEventCard> createState() => _ToolEventCardState();
}

class _ToolEventCardState extends State<ToolEventCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false; // ⬅︎  parte collassato

  String _prettyJson(Object obj) =>
      const JsonEncoder.withIndent('  ').convert(obj);

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] as String? ?? 'unknown_tool';
    final bool running = widget.data['isRunning'] == true;
    final input = widget.data['input'] ?? {};
    final output = widget.data['output'];

    // Padding lato scheda: più spazio verticale e leggero bordo
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────────────────────────  HEADER  ────────────────────────────
              Row(
                children: [
                  // Icona stato a SINISTRA
                  running
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  // Nome tool
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  // Freccia espandi/collassa a DESTRA
                  IconButton(
                    icon: Icon(_expanded
                        ? Icons.expand_less
                        : Icons.expand_more),
                    tooltip: _expanded ? 'Mostra meno' : 'Mostra di più',
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
              // Contenuto dettagliato (visibile solo quando _expanded == true)
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Text('Input',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(_prettyJson(input),
                    style:
                        const TextStyle(fontFamily: 'Courier', fontSize: 12)),
                if (output != null) ...[
                  const SizedBox(height: 16),
                  const Text('Output',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(_prettyJson(output),
                      style: const TextStyle(
                          fontFamily: 'Courier', fontSize: 12)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
