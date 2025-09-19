import 'dart:async';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart'; // dove risiede ChatBotPageState

/// Widget che invia automaticamente una sequenza di messaggi all’assistente
/// (una volta sola) e permette all’utente di espandere/collassare la card per
/// vedere l’elenco completo degli step.
///
/// Novità rispetto alla versione iniziale
/// --------------------------------------
/// • Il pulsante STOP del ChatBot ora interrompe **anche** le sequenze
///   automatiche in esecuzione grazie al notifier globale
///   `ChatBotPageState.cancelSequences`.
/// • La sequenza termina immediatamente se riceve il segnale di annullo oppure
///   se l’utente ha già completato tutti gli step.
/// • Listener perfettamente puliti in `dispose()`.
class AutoSequenceWidgetTool extends StatefulWidget {
  const AutoSequenceWidgetTool({super.key, required this.jsonData, required this.onReply});

  final Map<String, dynamic> jsonData;
  final void Function(String) onReply;

  @override
  State<AutoSequenceWidgetTool> createState() => _AutoSequenceWidgetToolState();
}

class _AutoSequenceWidgetToolState extends State<AutoSequenceWidgetTool> {
  /*─────────────────── config ──────────────────*/
  late final List<dynamic> _steps;      // lista degli step
  late final bool _isFirstTime;         // flag dal JSON (prima visualizzazione)

  /*─────────────────── stato logico ────────────*/
  bool _expanded   = false;             // card aperta/chiusa
  bool _completed  = false;             // sequenza terminata o interrotta
  bool _hasStarted = false;             // evita ri‑entry

  int _creationTurn         = 0;        // valore notifier al mount
  Completer<void>? _waitForAssistant;   // completo quando l’assistente finisce

  late final VoidCallback _assistantListener;
  late final VoidCallback _cancelListener;

  @override
  void initState() {
    super.initState();

    _steps       = widget.jsonData['sequence'] ?? [];
    _isFirstTime = widget.jsonData['is_first_time'] ?? true;

    // forza is_first_time = false per i futuri restore da history
    widget.jsonData['is_first_time'] = false;

    // memorizza il valore attuale del contatore dei turni completati
    _creationTurn = ChatBotPageState.assistantTurnCompleted.value;

    /*──────── listener sui turni dell'assistente ────────*/
    _assistantListener = _onAssistantTurnEnded;
    ChatBotPageState.assistantTurnCompleted.addListener(_assistantListener);

    /*──────── listener sul segnale globale di annullo ───*/
    _cancelListener = () {
      if (ChatBotPageState.cancelSequences.value && !_completed) {
        _abortSequence();
      }
    };
    ChatBotPageState.cancelSequences.addListener(_cancelListener);

    
   //───────────────────────────────────────────────────────────────
   // Fallback: se l’agente ha già completato il turno PRIMA che il
   // widget sia montato, facciamo partire la sequenza al frame
   // successivo.
   //───────────────────────────────────────────────────────────────
   /* avvio unico, post-frame: */
   if (_isFirstTime) {
     WidgetsBinding.instance.addPostFrameCallback((_) async {
       if (!mounted || _completed) return;
       // aspetta che l’assistente abbia chiuso il suo messaggio
       while (mounted &&
              ChatBotPageState.assistantTurnCompleted.value <= _creationTurn) {
         await Future.delayed(const Duration(milliseconds: 50));
       }
       if (!mounted || _completed) return;
       _hasStarted = true;             // ⇠ flag una sola volta
       await _runSequence();           // avvia la sequenza
     });
   }
  }

  @override
  void dispose() {
    ChatBotPageState.assistantTurnCompleted.removeListener(_assistantListener);
    ChatBotPageState.cancelSequences.removeListener(_cancelListener);
    super.dispose();
  }

  /*─────────────────── listener ────────────────*/
  void _onAssistantTurnEnded() {
    // se stiamo aspettando la fine del turno dell’assistente per proseguire
    if (_waitForAssistant != null && !_waitForAssistant!.isCompleted) {
      _waitForAssistant!.complete();
    }

    // avvia la sequenza appena l’assistente chiude **dopo** la creazione
    /*if (_isFirstTime && !_hasStarted &&
        ChatBotPageState.assistantTurnCompleted.value > _creationTurn) {
      _hasStarted = true;
      _runSequence();
    }*/
  }

  /*─────────────────── sequenza ────────────────*/
  Future<void> _runSequence() async {
    for (int i = 0; i < _steps.length; i++) {
      // se è stato premuto STOP → interrompi loop
      if (_completed) break;

      final step = _steps[i];
      final String msg = (step['message'] ?? '').toString();
      if (msg.trim().isEmpty) continue;

      widget.onReply(msg);               // 1. invia messaggio

      // 2. aspetta che l’assistente risponda
      _waitForAssistant = Completer<void>();
      await _waitForAssistant!.future;
    }

    if (!_completed) {
      setState(() => _completed = true);
    }

    // non serve più ricevere notifiche
    ChatBotPageState.assistantTurnCompleted.removeListener(_assistantListener);
  }

  /// Interrompe immediatamente la sequenza e aggiorna la UI.
  void _abortSequence() {
    _completed = true;
    _waitForAssistant?.complete();
    setState(() {});
  }

  /*─────────────────── UI ──────────────────────*/
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,            // occupa tutta la larghezza disponibile
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        color: Colors.white,
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
