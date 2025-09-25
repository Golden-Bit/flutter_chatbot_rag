// lib/shared/dual_pane_wrapper.dart
//
// Dual‑pane layout con ChatBot a destra e, **sovrapposto** al contenuto
// di sinistra, il pannello “Genera con AI” (AiGeneratePanel).
//
// • Il pannello AI è ancorato in alto‑centro della colonna sinistra
//   con un leggero sollevamento (elevation).
// • La chiave (GlobalKey<ChatBotPageState>) del ChatBot è generata
//   internamente e condivisa sia con ChatBotPage sia con AiGeneratePanel.
//
// In questa versione il wrapper rileva dinamicamente – se presenti –
// le estensioni dichiarate dalla pagina di sinistra tramite il mixin
// `ChatBotExtensions` e le inoltra a ChatBotPage, rendendo
// l’integrazione completamente plug‑and‑play.
//

//─────────────────────────────────────────────────────────────────────────────
// IMPORT
//─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/mini_chat.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

// (facoltativo) se la pagina vuole ricevere la chat‑key
mixin ChatBotKeyConsumer on Widget {
  Widget withChatKey(GlobalKey<ChatBotPageState> k);
}

/// Ogni pagina che vuole “estendersi” verso il ChatBot
/// implementa semplicemente questa interfaccia.
/// Tutti i getter hanno già un default → la pagina può
/// sovrascrivere **solo** ciò che le serve.
mixin ChatBotExtensions {
  /// Nuovi widget renderizzabili nei messaggi
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => const {};

  /// Nuove ToolSpec da inserire nell’header “tools”
  List<ToolSpec> get toolSpecs => const [];

  /// Callback verso l’host (es. cambia‑colore, naviga, ecc.)
  ChatBotHostCallbacks get hostCallbacks => const ChatBotHostCallbacks();
}


//─────────────────────────────────────────────────────────────────────────────
// REGISTRY ­— gestione apertura/chiusura globale di tutti i wrapper
//─────────────────────────────────────────────────────────────────────────────
class DualPaneRegistry {
  DualPaneRegistry._();

  static final _controllers = <DualPaneController>{};
  static bool _isOpen = false;

  static void register(DualPaneController c)   => _controllers.add(c);
  static void unregister(DualPaneController c) => _controllers.remove(c);

  static void openAll()  {
    _isOpen = true;
    for (final c in _controllers) c.openChat();
  }

  static void closeAll() {
    _isOpen = false;
    for (final c in _controllers) c.closeChat();
  }

  static bool toggleAll() {
    _isOpen ? closeAll() : openAll();
    return _isOpen;
  }

  static bool get areOpen => _isOpen;
}

//─────────────────────────────────────────────────────────────────────────────
// CONTROLLER
//─────────────────────────────────────────────────────────────────────────────
class DualPaneController {
  _DualPaneWrapperState? _state;

  void openChat()  => _state?._setChatVisible(true);
  void closeChat() => _state?._setChatVisible(false);

  /* internal */
  void _attach(_DualPaneWrapperState s) => _state = s;
  void _detach()                        => _state = null;
}

//─────────────────────────────────────────────────────────────────────────────
// COSTANTI LAYOUT
//─────────────────────────────────────────────────────────────────────────────
const double _kMinFrac            = .15; // larghezza minima colonna sinistra
const double _kMaxFrac            = .85; // larghezza massima colonna sinistra
const double _dividerVisibleWidth = 4;   // spessore barra visibile
const double _dragHitWidth        = 4;   // area di drag

//─────────────────────────────────────────────────────────────────────────────
// WIDGET WRAPPER
//─────────────────────────────────────────────────────────────────────────────
class DualPaneWrapper extends StatefulWidget {
  const DualPaneWrapper({
    super.key,
    required this.controller,
    required this.leftChild,          // può (o meno) implementare ChatBotExtensions
    required this.user,
    required this.token,
  });

  final DualPaneController controller;
  final Widget leftChild;
  final User   user;
  final Token  token;

  @override
  State<DualPaneWrapper> createState() => _DualPaneWrapperState();
}

class _DualPaneWrapperState extends State<DualPaneWrapper> {
  // Key creata internamente e condivisa fra ChatBotPage e AiGeneratePanel
  final GlobalKey<ChatBotPageState> _chatbotKey = GlobalKey<ChatBotPageState>();

  double _split       = .5;   // frazione colonna sinistra (0‑1)
  bool   _chatVisible = false;

  //───────────────────────────────────────────────────────────────────────────
  // Helper: se leftChild implementa ChatBotExtensions la restituisce
  //───────────────────────────────────────────────────────────────────────────
  ChatBotExtensions? get _extProvider =>
      widget.leftChild is ChatBotExtensions
          ? widget.leftChild as ChatBotExtensions
          : null;

  //───────────────────────────────────────────────────────────────────────────
  // Helper: se leftChild vuole la chat‑key gliela iniettiamo
  //───────────────────────────────────────────────────────────────────────────
  Widget _injectChatKey(Widget w) =>
      (w is ChatBotKeyConsumer) ? (w as ChatBotKeyConsumer).withChatKey(_chatbotKey) : w;

  //───────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    DualPaneRegistry.register(widget.controller);
  }

  @override
  void dispose() {
    DualPaneRegistry.unregister(widget.controller);
    widget.controller._detach();
    super.dispose();
  }

  void _setChatVisible(bool v) => setState(() => _chatVisible = v);

  //───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final leftW  = _chatVisible ? totalW * _split : totalW;
        final rightW = _chatVisible ? totalW - leftW - _dragHitWidth : 0;

        return Row(
          children: [
            //──── colonna sinistra (contenuto + pannello AI sovrapposto) ──
            SizedBox(
              width: leftW,
              child: RepaintBoundary( // ✅ ISOLAMENTO DESTRA
                  child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // contenuto principale
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _chatVisible ? 16 : 0,
                      75,
                      _chatVisible ? 16 : 0,
                      _chatVisible ? 16 : 0,
                    ),
                    child: _injectChatKey(widget.leftChild),
                  ),

                  // pannello “Genera con AI” con elevazione
                  Positioned(
                    top: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: AiGeneratePanel(chatKey: _chatbotKey),
                      ),
                    ),
                  ),
                ],
              ),
            )),

            //──── drag‑handle (solo se chat visibile) ────────────────────
            if (_chatVisible)
              _DragHandle(
                onDragDx: (dx) {
                  setState(() {
                    _split =
                        (_split + dx / totalW).clamp(_kMinFrac, _kMaxFrac);
                  });
                },
              ),

            //──── colonna destra (ChatBot) — mantenuta con stato ─────────
            Visibility(
              visible: _chatVisible,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: SizedBox(
                width: rightW as double,
                child: RepaintBoundary( // ✅ ISOLAMENTO DESTRA
                  child: ChatBotPage(
                  key          : _chatbotKey,
                  user         : widget.user,
                  token        : widget.token,
                  // INIEZIONE DINAMICA DELLE ESTENSIONI (fallback ai default)
                  hostCallbacks         : _extProvider?.hostCallbacks         ?? const ChatBotHostCallbacks(),
                  externalWidgetBuilders: _extProvider?.extraWidgetBuilders  ?? const {},
                  toolSpecs             : _extProvider?.toolSpecs             ?? const [],
                  // — parametri UI invariati —
                  hasSidebar               : true,
                  showEmptyChatPlaceholder : false,
                  showTopBarLogo           : false,
                  showSidebarLogo          : false,
                  showUserMenu             : false,
                  showConversationButton   : false,
                  showKnowledgeBoxButton   : false,
                  borderStyle : const ChatBorderStyle(
                    visible: true,
                    margin : EdgeInsets.all(16),
                    radius : 4,
                  ),
                  separatorStyle : const TopBarSeparatorStyle(
                    visible   : false,
                    thickness : 1,
                    color     : Colors.grey,
                    topOffset : 0,
                  ),
                  topBarMinHeight : 50,
                  backgroundStyle : const ChatBackgroundStyle(
                    useGradient : false,
                    baseColor   : Colors.white,
                  ),
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// DRAG HANDLE
//─────────────────────────────────────────────────────────────────────────────
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.onDragDx});
  final void Function(double dx) onDragDx;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDragDx(d.delta.dx),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: SizedBox(
            width: _dragHitWidth,
            child: Center(
              child: Container(
                width: _dividerVisibleWidth,
                color: Colors.grey[200],
              ),
            ),
          ),
        ),
      );
}
