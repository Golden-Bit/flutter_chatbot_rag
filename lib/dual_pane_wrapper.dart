// lib/shared/dual_pane_wrapper.dart
//
// Dual-pane layout con ChatBot a destra e, sovrapposto al contenuto
// di sinistra, il pannello “Genera con AI” (AiGeneratePanel).
//
// - Mini panel SEMPRE visibile (anche con chat chiusa).
// - Nessun overlay grigio: pannello clippato (Material.clipBehavior + ClipRect).
// - ChatBotPage sempre montata (Offstage+IgnorePointer quando chiusa).
//

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/mini_chat.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

// (facoltativo) se la pagina vuole ricevere la chat-key
mixin ChatBotKeyConsumer on Widget {
  Widget withChatKey(GlobalKey<ChatBotPageState> k);
}

mixin ChatBotExtensions {
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => const {};
  List<ToolSpec> get toolSpecs => const [];
  ChatBotHostCallbacks get hostCallbacks => const ChatBotHostCallbacks();
}

/*───────────────────────────────────────────────────────────────────────────*/
/* REGISTRY                                                                  */
/*───────────────────────────────────────────────────────────────────────────*/
class DualPaneRegistry {
  DualPaneRegistry._();

  static final Set<DualPaneController> _controllers = <DualPaneController>{};
  static bool _areOpen = false;
  static bool _isBroadcasting = false;

  static void register(DualPaneController c) {
    _controllers.add(c);
    if (_areOpen) c.openChat();
  }

  static void unregister(DualPaneController c) => _controllers.remove(c);

  static void openAll()  => _broadcast(open: true);
  static void closeAll() => _broadcast(open: false);

  static bool toggleAll() {
    _broadcast(open: !_areOpen);
    return _areOpen;
  }

  static bool get areOpen => _areOpen;

  static void _broadcast({required bool open}) {
    if (_isBroadcasting) return;
    _isBroadcasting = true;
    try {
      _areOpen = open;
      final snapshot = List<DualPaneController>.from(_controllers);
      for (final c in snapshot) {
        try { open ? c.openChat() : c.closeChat(); } catch (_) {}
      }
    } finally {
      _isBroadcasting = false;
    }
  }
}

/*───────────────────────────────────────────────────────────────────────────*/
/* CONTROLLER                                                                */
/*───────────────────────────────────────────────────────────────────────────*/
class DualPaneController {
  _DualPaneWrapperState? _state;
  bool _visible = false;

  void openChat()  { _visible = true;  _state?._setChatVisibleSafe(true); }
  void closeChat() { _visible = false; _state?._setChatVisibleSafe(false); }

  void _attach(_DualPaneWrapperState s) {
    _state = s;
    if (_visible || DualPaneRegistry.areOpen) {
      _state?._setChatVisibleSafe(true);
    }
  }
  void _detach() => _state = null;
}

/*───────────────────────────────────────────────────────────────────────────*/
/* COSTANTI LAYOUT                                                           */
/*───────────────────────────────────────────────────────────────────────────*/
const double _kMinFrac            = .15;
const double _kMaxFrac            = .85;
const double _dividerVisibleWidth = 4;
const double _dragHitWidth        = 4;

/*───────────────────────────────────────────────────────────────────────────*/
/* WIDGET WRAPPER                                                            */
/*───────────────────────────────────────────────────────────────────────────*/
class DualPaneWrapper extends StatefulWidget {
  const DualPaneWrapper({
    super.key,
    required this.controller,
    required this.leftChild,
    required this.user,
    required this.token,
    this.autoStartMessage,
    this.autoStartInvisible = false,
    this.openChatOnMount = false,
  });

  final DualPaneController controller;
  final Widget leftChild;
  final User   user;
  final Token  token;

  final String? autoStartMessage;
  final bool    autoStartInvisible;
  final bool    openChatOnMount;

  @override
  State<DualPaneWrapper> createState() => _DualPaneWrapperState();
}

class _DualPaneWrapperState extends State<DualPaneWrapper> {
  final GlobalKey<ChatBotPageState> _chatbotKey = GlobalKey<ChatBotPageState>();

  double _split       = .5;
  bool   _chatVisible = false;
  bool   _autoSent    = false;

  ChatBotExtensions? get _extProvider =>
      widget.leftChild is ChatBotExtensions ? widget.leftChild as ChatBotExtensions : null;

  Widget _injectChatKey(Widget w) =>
      (w is ChatBotKeyConsumer) ? (w as ChatBotKeyConsumer).withChatKey(_chatbotKey) : w;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    DualPaneRegistry.register(widget.controller);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.openChatOnMount) _setChatVisibleSafe(true);
      await _tryAutoSend();
    });
  }

  @override
  void dispose() {
    DualPaneRegistry.unregister(widget.controller);
    widget.controller._detach();
    super.dispose();
  }

  void _setChatVisibleSafe(bool v) {
    if (!mounted || _chatVisible == v) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final inFrame = phase == SchedulerPhase.persistentCallbacks ||
                    phase == SchedulerPhase.transientCallbacks   ||
                    phase == SchedulerPhase.postFrameCallbacks;

    if (inFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _chatVisible = v);
      });
    } else {
      setState(() => _chatVisible = v);
    }
  }

  Future<void> _tryAutoSend() async {
    if (_autoSent) return;
    final msg = widget.autoStartMessage?.trim();
    if (msg == null || msg.isEmpty) return;

    final chat = _chatbotKey.currentState;
    if (chat == null) return;
    try {
      await chat.sendHostMessage(
        msg,
        visibility: widget.autoStartInvisible ? kVisInvisible : kVisNormal,
      );
      _autoSent = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalW = constraints.maxWidth;
      final leftW  = _chatVisible ? totalW * _split : totalW;
      final double rightW = _chatVisible ? (totalW - leftW - _dragHitWidth) : 0.0;

      return Row(
        children: [
          // ── colonna sinistra ──
          SizedBox(
            width: leftW,
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none, // ombre ok; il pannello è clippato internamente
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

                  // ── Mini panel SEMPRE visibile ──
                  Positioned(
                    top: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias, // limita la pittura del contenuto
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ClipRect( // blocca eventuali scrim/backdrop fuori dai bounds
                          child: AiGeneratePanel(chatKey: _chatbotKey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // drag-handle
          if (_chatVisible)
            _DragHandle(
              onDragDx: (dx) {
                setState(() {
                  _split = (_split + dx / totalW).clamp(_kMinFrac, _kMaxFrac);
                });
              },
            ),

          // ── colonna destra (ChatBot) — SEMPRE montata ──
          SizedBox(
            width: rightW,
            child: Offstage(
              offstage: !_chatVisible,       // non occupa layout quando chiusa
              child: IgnorePointer(
                ignoring: !_chatVisible,     // non riceve input quando chiusa
                child: RepaintBoundary(
                  child: ChatBotPage(
                    key: _chatbotKey,
                    user: widget.user,
                    token: widget.token,

                    // estensioni dinamiche
                    hostCallbacks: _extProvider?.hostCallbacks ?? const ChatBotHostCallbacks(),
                    externalWidgetBuilders: _extProvider?.extraWidgetBuilders ?? const {},
                    toolSpecs: _extProvider?.toolSpecs ?? const [],

                    // UI
                    hasSidebar: true,
                    showEmptyChatPlaceholder: false,
                    showTopBarLogo: false,
                    showSidebarLogo: false,
                    showUserMenu: false,
                    showConversationButton: false,
                    showKnowledgeBoxButton: false,
                    borderStyle: const ChatBorderStyle(
                      visible: true,
                      margin: EdgeInsets.all(16),
                      radius: 4,
                    ),
                    separatorStyle: const TopBarSeparatorStyle(
                      visible: false,
                      thickness: 1,
                      color: Colors.grey,
                      topOffset: 0,
                    ),
                    topBarMinHeight: 50,
                    backgroundStyle: const ChatBackgroundStyle(
                      useGradient: false,
                      baseColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/*───────────────────────────────────────────────────────────────────────────*/
/* DRAG HANDLE                                                               */
/*───────────────────────────────────────────────────────────────────────────*/
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
