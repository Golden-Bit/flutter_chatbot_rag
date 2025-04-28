import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/chatbot.dart'; // dove risiede ChatBotPageState

/// Widget che invia automaticamente una sequenza di messaggi all’assistente
/// (una volta sola) e permette all’utente di espandere/collassare la card per
/// vedere l’elenco completo degli step.
///
/// Requisiti implementati:
/// * la sequenza parte **dopo** che l’assistente ha chiuso il turno in cui il
///   widget è comparso **e** la conversazione è già stata salvata;
/// * avvio garantito una sola volta grazie ai flag `_creationTurn` e
///   `_hasStarted`;
/// * `is_first_time` viene forzato subito a `false` in `jsonData` così non
///   verrà rieseguito in un restore futuro;
/// * listener su `assistantTurnCompleted` rimosso appena la sequenza termina
///   (oltre che in `dispose()`);
/// * card espandibile / collassabile con click sull’intestazione; a larghezza
///   massima disponibile (usa `width: double.infinity`);
/// * eliminato il concetto di delay tra step (campo ignorato se presente);
/// * quando la card è espansa viene visualizzato l’elenco numerato degli step.
class AutoSequenceWidgetTool extends StatefulWidget {
  const AutoSequenceWidgetTool({super.key, required this.jsonData, required this.onReply});

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;

  @override
  State<AutoSequenceWidgetTool> createState() => _AutoSequenceWidgetToolState();
}

class _AutoSequenceWidgetToolState extends State<AutoSequenceWidgetTool> {
  /*─────────────────── config ──────────────────*/
  late final List<dynamic> _steps;              // lista degli step
  late final bool _isFirstTime;                 // flag dal JSON

  /*─────────────────── stato logico ────────────*/
  bool _expanded   = false;                     // card aperta/chiusa
  bool _completed  = false;                     // sequenza terminata
  bool _hasStarted = false;                     // per evitare re‑entry

  int _creationTurn         = 0;               // valore del notifier al mount
  Completer<void>? _waitForAssistant;          // si completa quando l’assistente chiude un turno

  @override
  void initState() {
    super.initState();

    _steps       = widget.jsonData['sequence'] ?? [];
    _isFirstTime = widget.jsonData['is_first_time'] ?? true;

    // forza is_first_time=false per futuri restore
    widget.jsonData['is_first_time'] = false;

    // valore del notifier al momento della creazione del widget
    _creationTurn = ChatBotPageState.assistantTurnCompleted.value;

    // ascolta i turni dell’assistente
    ChatBotPageState.assistantTurnCompleted.addListener(_onAssistantTurnEnded);
  }

  @override
  void dispose() {
    ChatBotPageState.assistantTurnCompleted.removeListener(_onAssistantTurnEnded);
    super.dispose();
  }

  /*─────────────────── listener ────────────────*/
  void _onAssistantTurnEnded() {
    // se stiamo aspettando la chiusura dell’assistente per uno step, completa il completer
    if (_waitForAssistant != null && !_waitForAssistant!.isCompleted) {
      _waitForAssistant!.complete();
    }

    // avvia sequenza la prima volta che l’assistente termina **dopo** il turno di creazione
    if (_isFirstTime && !_hasStarted &&
        ChatBotPageState.assistantTurnCompleted.value > _creationTurn) {
      _hasStarted = true;
      _runSequence();
    }
  }

  /*─────────────────── sequenza ────────────────*/
  Future<void> _runSequence() async {
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final String msg = (step['message'] ?? '').toString();
      if (msg.trim().isEmpty) continue;

      widget.onReply(msg);                       // 1. invia messaggio

      // 2. aspetta che l’assistente risponda
      _waitForAssistant = Completer<void>();
      await _waitForAssistant!.future;
    }

    setState(() => _completed = true);
    // listener non più necessario
    ChatBotPageState.assistantTurnCompleted.removeListener(_onAssistantTurnEnded);
  }

  /*─────────────────── UI ──────────────────────*/
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,                    // occupa tutta la larghezza disponibile
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // intestazione cliccabile
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                width: double.infinity,
                color: Colors.blueGrey.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _completed ? 'Sequenza completata ✅' : 'Sequenza automatica',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),

            // corpo espandibile
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text('${i + 1}. ${_steps[i]['message'] ?? ''}'),
                      ),
                    if (!_completed)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Esecuzione sequenza… ⏳', style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
