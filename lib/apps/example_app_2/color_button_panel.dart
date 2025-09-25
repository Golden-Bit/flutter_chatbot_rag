import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';

// === Host callbacks (riuso lo stesso tipo che usi nell’esempio) ===
class MyHostCallbacks extends ChatBotHostCallbacks {
  const MyHostCallbacks({required this.setButtonColor});
  final void Function(Color) setButtonColor;
}

// === Il widget-tool che ChatBot renderizza e che chiama la callback host ===
class ChangeButtonColorWidget extends StatefulWidget {
  const ChangeButtonColorWidget({
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
  State<ChangeButtonColorWidget> createState() => _ChangeButtonColorWidgetState();
}

class _ChangeButtonColorWidgetState extends State<ChangeButtonColorWidget> {
  @override
// nel ChangeButtonColorWidgetState
@override
void initState() {
  super.initState();
  final raw = (widget.jsonData['color'] ?? '').toString().toLowerCase();
  final firstTime = widget.jsonData['is_first_time'] as bool? ?? true;
  if (!firstTime) return;

  Color? c;
  switch (raw) {
    case 'red':   c = Colors.red;   break;
    case 'green': c = Colors.green; break;
    case 'blue':  c = Colors.blue;  break;
  }
  if (c != null) {
    // 👇 decoupla l'update host dal build corrente del ChatPanel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.hostCbs.setButtonColor(c!);
    });
    // In alternativa (meno “frame-friendly”): scheduleMicrotask(...)
  }
}

  @override
  Widget build(BuildContext context) {
    final raw = (widget.jsonData['color'] ?? '').toString().toLowerCase();
    Color? c;
    switch (raw) {
      case 'red':   c = Colors.red;   break;
      case 'green': c = Colors.green; break;
      case 'blue':  c = Colors.blue;  break;
    }
    return Card(
      color: c?.withOpacity(.15) ?? Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(c == null ? 'Colore “$raw” non valido'
                              : 'Colore del bottone impostato a $raw'),
      ),
    );
  }
}

// === ToolSpec coerente col WIDGET_ID sopra ===
const ToolSpec kChangeButtonColorTool = ToolSpec(
  toolName: 'ChangeButtonColorWidget',
  description: 'Cambia il colore del pulsante (red | green | blue)',
  params: [
    ToolParamSpec(
      name: 'color',
      paramType: ParamType.string,
      description: 'Nome del colore',
      allowedValues: ['red', 'green', 'blue'],
      example: 'green',
    ),
  ],
);

// === Pagina sinistra: un solo bottone + implementazione ChatBotExtensions ===
class ColorButtonPanel extends StatefulWidget with ChatBotExtensions {
  ColorButtonPanel({super.key});

  // Piccolo bus: lo stato ascolta e rinfresca la UI
  final ValueNotifier<Color> _color = ValueNotifier<Color>(Colors.red);

  // → HostCallbacks che il ChatBotPage riceve dal wrapper
  @override
  ChatBotHostCallbacks get hostCallbacks =>
      MyHostCallbacks(setButtonColor: (c) => _color.value = c);

  // → Registrazione del builder del WIDGET_ID che l’LLM userà
  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'ChangeButtonColorWidget': (data, onR, pCbs, hCbs) =>
            ChangeButtonColorWidget(
              jsonData: data,
              onReply: onR,
              pageCbs: pCbs,
              hostCbs: hCbs as MyHostCallbacks,
            ),
      };

  // → Espongo il tool nello “schema” visibile all’LLM
  @override
  List<ToolSpec> get toolSpecs => const [kChangeButtonColorTool];

  @override
  State<ColorButtonPanel> createState() => _ColorButtonPanelState();
}

class _ColorButtonPanelState extends State<ColorButtonPanel> {
  @override
  void initState() {
    super.initState();
    widget._color.addListener(_onColor);
  }

  @override
  void dispose() {
    widget._color.removeListener(_onColor);
    super.dispose();
  }

  void _onColor() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final color = widget._color.value;
    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          fixedSize: const Size(160, 160),
          shape: const CircleBorder(),
        ),
        onPressed: () {},
        child: const SizedBox.shrink(),
      ),
    );
  }
}
