import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

// Pagine sinistra
import 'color_button_panel.dart';    // ⬅️ esistente
import 'form_builder_panel.dart';    // ⬅️ esistente
import 'drawing_board_panel.dart';   // ⬅️ nuova tavola grafica

enum _DemoPage { buttonColor, formBuilder, drawingBoard }

class ChatPanelDemoPage extends StatefulWidget {
  const ChatPanelDemoPage({super.key, required this.user, required this.token});
  final User user;
  final Token token;

  @override
  State<ChatPanelDemoPage> createState() => _ChatPanelDemoPageState();
}

class _ChatPanelDemoPageState extends State<ChatPanelDemoPage> {
  final DualPaneController _ctrl = DualPaneController();
  _DemoPage _current = _DemoPage.buttonColor;

  // Stato visibilità chat laterale (true = aperta)
  bool _chatOpen = true;

  @override
  void initState() {
    super.initState();
    // All'avvio rispetta lo stato desiderato (_chatOpen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatOpen) {
        _ctrl.openChat();
      } else {
        _ctrl.closeChat();
      }
    });
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
    });
    if (_chatOpen) {
      _ctrl.openChat();
    } else {
      _ctrl.closeChat();
    }
  }

  void _select(_DemoPage page) {
    Navigator.of(context).maybePop();
    if (_current != page) {
      setState(() => _current = page);
      // Mantieni lo stato della chat anche al cambio pagina
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatOpen) {
          _ctrl.openChat();
        } else {
          _ctrl.closeChat();
        }
      });
    }
  }

  String _titleOf(_DemoPage p) => switch (p) {
        _DemoPage.buttonColor  => 'Demo · Button Color',
        _DemoPage.formBuilder  => 'Demo · Form Builder',
        _DemoPage.drawingBoard => 'Demo · Drawing Board',
      };

  Widget _leftChildOf(_DemoPage p) => switch (p) {
        _DemoPage.buttonColor  => ColorButtonPanel(),
        _DemoPage.formBuilder  => FormBuilderPanel(),
        _DemoPage.drawingBoard => DrawingBoardPanel(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // sfondo pagina
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Text(
          _titleOf(_current),
          style: const TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: _chatOpen ? 'Chiudi chat' : 'Apri chat',
            onPressed: _toggleChat,
            icon: Icon(_chatOpen ? Icons.close : Icons.chat_bubble_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.white),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Demos',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.color_lens_outlined),
                title: const Text('Button Color'),
                selected: _current == _DemoPage.buttonColor,
                selectedTileColor: Color(0xFFE8F0FE),
                onTap: () => _select(_DemoPage.buttonColor),
              ),
              ListTile(
                leading: const Icon(Icons.dynamic_form_outlined),
                title: const Text('Form Builder'),
                selected: _current == _DemoPage.formBuilder,
                selectedTileColor: Color(0xFFE8F0FE),
                onTap: () => _select(_DemoPage.formBuilder),
              ),
              ListTile(
                leading: const Icon(Icons.gesture_outlined),
                title: const Text('Drawing Board'),
                selected: _current == _DemoPage.drawingBoard,
                selectedTileColor: Color(0xFFE8F0FE),
                onTap: () => _select(_DemoPage.drawingBoard),
              ),
            ],
          ),
        ),
      ),
      body: DualPaneWrapper(
        key: ValueKey(_current), // forza remount al cambio pagina
        controller: _ctrl,
        user: widget.user,
        token: widget.token,
        leftChild: _leftChildOf(_current),
      ),
    );
  }
}
