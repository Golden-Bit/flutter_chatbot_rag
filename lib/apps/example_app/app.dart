import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_app/chatbot.dart'; // <-- ChatBotPage
import 'package:flutter_app/context_api_sdk.dart';
import 'package:flutter_app/mini_chat.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

/// ───────────────────────────────────────────────────────────────────────────
///  CALLBACKS che l'host espone a ChatBotPage
/// ───────────────────────────────────────────────────────────────────────────
class MyHostCallbacks extends ChatBotHostCallbacks {
  const MyHostCallbacks({required this.setButtonColor});
  final void Function(Color) setButtonColor;
}

/// ───────────────────────────────────────────────────────────────────────────
///  WIDGET che l'LLM userà per cambiare il colore del pulsante
/// ───────────────────────────────────────────────────────────────────────────
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
  State<ChangeButtonColorWidget> createState() =>
      _ChangeButtonColorWidgetState();
}

class _ChangeButtonColorWidgetState extends State<ChangeButtonColorWidget> {

  @override
  void initState() {
    super.initState();

    // Estraggo il colore richiesto e verifico se è la prima esecuzione
    final raw = (widget.jsonData['color'] ?? '').toString().toLowerCase();
    final bool firstTime = widget.jsonData['is_first_time'] as bool? ?? true;

    if (firstTime) {
      Color? c;
      switch (raw) {
        case 'red':
          c = Colors.red;
          break;
        case 'green':
          c = Colors.green;
          break;
        case 'blue':
          c = Colors.blue;
          break;
      }
      if (c != null) {
        widget.hostCbs.setButtonColor(c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = (widget.jsonData['color'] ?? '').toString().toLowerCase();
    Color? c;
    switch (raw) {
      case 'red':
        c = Colors.red;
        break;
      case 'green':
        c = Colors.green;
        break;
      case 'blue':
        c = Colors.blue;
        break;
    }

    return Card(
      color: c?.withOpacity(.15) ?? Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          c == null
              ? 'Colore “$raw” non valido'
              : 'Colore del pulsante impostato a $raw',
        ),
      ),
    );
  }
}
/// ───────────────────────────────────────────────────────────────────────────
///  PAGINA HOST con divisore draggable “hit-area” 18 px (visibile 6 px)
/// ───────────────────────────────────────────────────────────────────────────
class DualPaneChatPage extends StatefulWidget {
  const DualPaneChatPage(
      {super.key,
      required this.user,
      required this.token,
      this.initialChatId,
      this.defaultChainId,
      this.defaultChainConfigId,
      this.defaultChainConfig});

  final User user;
  final Token token;
  final String? initialChatId;
  final String? defaultChainId;
  final String? defaultChainConfigId;
  final Map<String, dynamic>? defaultChainConfig;

  @override
  State<DualPaneChatPage> createState() => _DualPaneChatPageState();
}

class _DualPaneChatPageState extends State<DualPaneChatPage> {
final TextEditingController _chainIdCtrl     = TextEditingController();
final TextEditingController _configIdCtrl    = TextEditingController();
final TextEditingController _chainOutCtrl    = TextEditingController();
final TextEditingController _chainInCtrl     = TextEditingController();
  final TextEditingController _chatIdCtrl    = TextEditingController();
final TextEditingController _chatListCtrl  = TextEditingController();
final TextEditingController _currentIdCtrl = TextEditingController();
final TextEditingController _singleChatCtrl= TextEditingController();

final TextEditingController _dlNameCtrl = TextEditingController();

  // sotto le altre TextEditingController…
final TextEditingController _filesJsonCtrl = TextEditingController();

  /*──────── upload form ───────*/
  Uint8List? _pickedBytes;
  String?    _pickedFileName;
  final TextEditingController _loaderCtrl = TextEditingController();

  /*──────── message options ───*/
  String _visKind = kVisNormal;        // default
  final TextEditingController _phCtrl = TextEditingController();

  final GlobalKey<ChatBotPageState> _chatKey = GlobalKey<ChatBotPageState>();
final TextEditingController _msgCtrl = TextEditingController();
  final changeButtonColorTool = const ToolSpec(
    toolName: 'ChangeButtonColorWidget', // deve combaciare con WIDGET_ID
    description: 'Cambia il colore del pulsante rosso/verde/blu',
    params: [
      ToolParamSpec(
        name: 'color',
        paramType: ParamType.string,
        description: 'Nome del colore (red | green | blue)',
        allowedValues: ['red', 'green', 'blue'],
        example: 'green',
      ),
    ],
  );

  Color _buttonColor = Colors.red;
  double _split = .35; // 35 % larghezza colonna sinistra

  // limiti per non far scomparire le colonne
  static const double _kMinFrac = .15;
  static const double _kMaxFrac = .85;

  void _setButtonColor(Color c) => setState(() => _buttonColor = c);

  // builder extra -> ChangeButtonColorWidget
  late final Map<String, ChatWidgetBuilder> _extraBuilders = {
    'ChangeButtonColorWidget': (data, onR, pCbs, hCbs) =>
        ChangeButtonColorWidget(
          jsonData: data,
          onReply: onR,
          pageCbs: pCbs,
          hostCbs: hCbs as MyHostCallbacks,
        ),
  };

  @override
  void dispose() {
    // ② smaltisci il controller
    _msgCtrl.dispose();
     _loaderCtrl.dispose();
    _phCtrl.dispose();
    _filesJsonCtrl.dispose();
    _dlNameCtrl.dispose();
    _dlNameCtrl.dispose();
  _chatIdCtrl.dispose();
_chatListCtrl.dispose();
_currentIdCtrl.dispose();
_singleChatCtrl.dispose();
_chainIdCtrl.dispose();
_configIdCtrl.dispose();
_chainOutCtrl.dispose();
_chainInCtrl.dispose();

    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final hostCbs = MyHostCallbacks(setButtonColor: _setButtonColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final leftW = totalW * _split;
        final rightW = totalW - leftW - _dragHitWidth; // riserviamo 18 px

        return Row(
          children: [
            // ─── colonna sinistra ─────────────────────────────────────────
            SizedBox(
              width: leftW,
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*──────────────────────── pulsante demo ───────*/
        const SizedBox(height: 32),
AiGeneratePanel(chatKey: _chatKey),
const Divider(height: 48),
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonColor,
              fixedSize: const Size(140, 140),
              shape: const CircleBorder(),
            ),
            onPressed: () {},
            child: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 32),

        /*──────────────────────── UPLOAD FORM ─────────*/
        Text('Upload file', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(_pickedFileName ?? 'Scegli file'),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                    allowMultiple: false,
                    withData: true,
                  );
                  if (res != null && res.files.first.bytes != null) {
                    setState(() {
                      _pickedBytes    = res.files.first.bytes;
                      _pickedFileName = res.files.first.name;
                    });
                  }
                },
              ),
            ),
            if (_pickedBytes != null)
              IconButton(
                tooltip: 'Annulla',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() { _pickedBytes = null; _pickedFileName = null; }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _loaderCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Loader‑config JSON (facoltativo)',
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (_pickedBytes == null)
              ? null
              : () async {
                  Map<String, String>? loaders;
                  Map<String, Map<String, dynamic>>? kwargs;

                  if (_loaderCtrl.text.trim().isNotEmpty) {
                    try {
                      final Map<String, dynamic> j = jsonDecode(_loaderCtrl.text);
                      loaders = (j['loaders'] as Map?)?.cast<String, String>();
                      kwargs  = (j['loader_kwargs'] as Map?)?.cast<String, Map<String, dynamic>>();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('JSON non valido')),
                      );
                      return;
                    }
                  }

                  await _chatKey.currentState?.uploadFileFromHost(
                    _pickedBytes!, _pickedFileName!,
                    loaders: loaders,
                    loaderKwargs: kwargs,
                  );

                  setState(() {
                    _pickedBytes    = null;
                    _pickedFileName = null;
                    _loaderCtrl.clear();
                  });
                },
          child: const Text('Processa'),
        ),

const SizedBox(height: 24),

// ── pulsante Mostra file in chat ────────────────────────────
Center(
  child: ElevatedButton.icon(
    icon: const Icon(Icons.folder_open),
    label: const Text('Mostra file in chat'),
    onPressed: () {
      // Recupera la lista
      final infos = _chatKey.currentState?.getChatFiles() ?? [];
      // Serializza in JSON indentato
      final pretty = const JsonEncoder.withIndent('  ')
          .convert(infos.map((f) => {
                'jobId':   f.jobId,
                'fileName':f.fileName,
                'ctxPath': f.ctxPath,
                'stage':   f.stage.name,
              }).toList());
      // Visualizza nell'output
      _filesJsonCtrl.text = pretty;
    },
  ),
),

const Divider(height: 16),

// ── output JSON dei file ────────────────────────────────────
TextField(
  controller: _filesJsonCtrl,
  readOnly: true,
  maxLines: 8,                // regola a piacere
  decoration: const InputDecoration(
    labelText: 'File in chat (JSON)',
    border: OutlineInputBorder(),
  ),
),


const Divider(height: 24),

// ── download per nome ─────────────────────────────────────────
Text('Scarica file per nome',
    style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _dlNameCtrl,
        decoration: const InputDecoration(
          hintText: 'file.pdf',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    const SizedBox(width: 8),
    ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('Scarica'),
      onPressed: () async {
        final name = _dlNameCtrl.text.trim();
        if (name.isEmpty) return;

        try {
          await _chatKey.currentState?.downloadFileByName(name);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore download: $e')),
          );
        }
      },
    ),
  ],
),

        const Divider(height: 48),

// ──────────────────────────────  GESTIONE CHAT  ─────────────────────────────
const Divider(height: 48),
Text('Gestione chat', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),

// ➊  Mostra lista chat -------------------------------------------------------
ElevatedButton.icon(
  icon: const Icon(Icons.list),
  label: const Text('Mostra lista chat'),
  onPressed: () {
    final chats = _chatKey.currentState?.getChatList() ?? [];
    _chatListCtrl.text =
        const JsonEncoder.withIndent('  ').convert(chats);
  },
),
const SizedBox(height: 8),
TextField(
  controller: _chatListCtrl,
  readOnly: true,
  maxLines: 8,
  decoration: const InputDecoration(
    labelText: 'Chat disponibili (JSON senza messages)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 16),

// ➋  ID chat corrente --------------------------------------------------------
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _currentIdCtrl,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Chat corrente (ID)',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    const SizedBox(width: 8),
    ElevatedButton(
      child: const Text('Aggiorna'),
      onPressed: () {
        _currentIdCtrl.text =
            _chatKey.currentState?.getCurrentChatId() ?? '(nessuna)';
      },
    ),
  ],
),

const SizedBox(height: 16),

// ➌  Apri chat per ID --------------------------------------------------------
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _chatIdCtrl,
        decoration: const InputDecoration(
          hintText: 'chat‑id',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    const SizedBox(width: 8),
    ElevatedButton(
      child: const Text('Apri'),
      onPressed: () async {
        final id = _chatIdCtrl.text.trim();
        if (id.isEmpty) return;

        final ok = await _chatKey.currentState?.openChatById(id) ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Chat caricata' : 'Chat non trovata')),
        );
        /*if (ok && MediaQuery.of(context).size.width < 600) {
          setState(() => sidebarWidth = 0);
        }*/
        _currentIdCtrl.text =
            _chatKey.currentState?.getCurrentChatId() ?? '(nessuna)';
      },
    ),
  ],
),

const SizedBox(height: 16),

// ➍  Mostra chat (oggetto completo) -----------------------------------------
Row(
  children: [
    Expanded(
      child: TextField(
        controller: _singleChatCtrl,
        readOnly: true,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Dettaglio chat (JSON completo)',
          border: OutlineInputBorder(),
        ),
      ),
    ),
    const SizedBox(width: 8),
    ElevatedButton(
      child: const Text('Mostra'),
      onPressed: () {
        final id = _chatIdCtrl.text.trim();
        if (id.isEmpty) return;

        final chat = _chatKey.currentState?.getChatById(id);
        _singleChatCtrl.text = chat != null
            ? const JsonEncoder.withIndent('  ').convert(chat)
            : 'Chat non trovata';
      },
    ),
  ],
),

const SizedBox(height: 16),

// ➎  Nuova chat --------------------------------------------------------------
ElevatedButton.icon(
  icon: const Icon(Icons.add),
  label: const Text('Nuova chat'),
  onPressed: () async {
    await _chatKey.currentState?.newChat();

    // refresh UI
    _chatIdCtrl.clear();
    _currentIdCtrl.text =
        _chatKey.currentState?.getCurrentChatId() ?? '(nessuna)';
    final chats = _chatKey.currentState?.getChatList() ?? [];
    _chatListCtrl.text =
        const JsonEncoder.withIndent('  ').convert(chats);
  },
),

// ──────────────────────────────  GESTIONE CHAIN  ─────────────────────────────
const Divider(height: 48),
Text('Gestione chain', style: Theme.of(context).textTheme.titleMedium),
const SizedBox(height: 8),

// ➊  Campi ID ----------------------------------------------------------------
TextField(
  controller: _chainIdCtrl,
  decoration: const InputDecoration(
    labelText: 'chain_id (opz.)',
    border: OutlineInputBorder(),
  ),
),
const SizedBox(height: 8),
TextField(
  controller: _configIdCtrl,
  decoration: const InputDecoration(
    labelText: 'config_id (opz.)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 8),
// ➋  Scarica la configurazione -----------------------------------------------
ElevatedButton.icon(
  icon: const Icon(Icons.download),
  label: const Text('Scarica config'),
  onPressed: () async {
    final cfg = await _chatKey.currentState?.fetchChainConfig(
      chainId : _chainIdCtrl.text.trim().isEmpty ? null : _chainIdCtrl.text.trim(),
      configId: _configIdCtrl.text.trim().isEmpty ? null : _configIdCtrl.text.trim(),
    );
    _chainOutCtrl.text = (cfg == null)
        ? '— Nessuna configurazione trovata —'
        : const JsonEncoder.withIndent('  ').convert(cfg);
  },
),
const SizedBox(height: 8),
TextField(
  controller: _chainOutCtrl,
  readOnly: true,
  maxLines: 10,
  decoration: const InputDecoration(
    labelText: 'Configurazione scaricata (JSON)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 16),
// ➌  Imposta default via ID ---------------------------------------------------
ElevatedButton.icon(
  icon: const Icon(Icons.push_pin),
  label: const Text('Imposta default da ID'),
  onPressed: () {
    _chatKey.currentState?.setDefaultChain(
      chainId : _chainIdCtrl.text.trim().isEmpty ? null : _chainIdCtrl.text.trim(),
      configId: _configIdCtrl.text.trim().isEmpty ? null : _configIdCtrl.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chain di default impostata')),
    );
  },
),

const SizedBox(height: 16),
// ➍  JSON libero per override completo ----------------------------------------
TextField(
  controller: _chainInCtrl,
  maxLines: 10,
  decoration: const InputDecoration(
    labelText: 'JSON chain‑config da applicare',
    border: OutlineInputBorder(),
  ),
),
const SizedBox(height: 8),
ElevatedButton.icon(
  icon: const Icon(Icons.upload),
  label: const Text('Imposta default da JSON'),
  onPressed: () {
    try {
      final Map<String, dynamic> cfg =
          jsonDecode(_chainInCtrl.text.trim()) as Map<String, dynamic>;
      _chatKey.currentState?.setDefaultChain(config: cfg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config di default impostata')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON non valido: $e')),
      );
    }
  },
),

        /*──────────────────────── INVIO MEX ───────────*/
        Text('Invia messaggio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
// ── Modalità di invio del messaggio ────────────────────────────
Expanded(
  child: SizedBox(
    width: double.infinity,
    child: DropdownButton<String>(
      // forza l’overlay a ridimensionarsi al genitore
      isExpanded: true,
      value: _visKind,
      onChanged: (v) {
        try {
          setState(() => _visKind = v!);
        } catch (e, st) {
          debugPrint('Errore dropdown: $e\n$st');
        }
      },
      items: const [
        DropdownMenuItem(value: kVisNormal,      child: Text('normal')),
        DropdownMenuItem(value: kVisInvisible,   child: Text('invisible')),
        DropdownMenuItem(value: kVisPlaceholder, child: Text('placeholder')),
      ],
    ),
  ),
),

            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _phCtrl,
                enabled: _visKind == kVisPlaceholder,
                decoration: const InputDecoration(
                  hintText: 'Placeholder visibile',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: const InputDecoration(
                  hintText: 'Scrivi…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                final txt = _msgCtrl.text.trim();
                if (txt.isEmpty) return;

                await _chatKey.currentState?.sendHostMessage(
                  txt,
                  visibility: _visKind,
                  displayText: _visKind == kVisPlaceholder
                      ? (_phCtrl.text.trim().isEmpty
                          ? '(messaggio nascosto)'
                          : _phCtrl.text.trim())
                      : null,
                );
                _msgCtrl.clear();
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
        Center(
          child: IconButton(
            icon: Icon(
              _chatKey.currentState?.isUiVisible ?? true
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            tooltip: 'Mostra/nascondi ChatBot',
            onPressed: () => _chatKey.currentState?.toggleUiVisibility(),
          ),
        ),
      ],
    ),
  ),
),

      

            // ─── divisore: hit-area 18 px, barra visibile 6 px ────────────
            _DragHandle(
              hitWidth: _dragHitWidth,
              barWidth: _dividerVisibleWidth,
              onDragDx: (dx) {
                setState(() {
                  _split = (_split + dx / totalW).clamp(_kMinFrac, _kMaxFrac);
                });
              },
            ),

            // ─── colonna destra (ChatBotPage) ─────────────────────────────
            SizedBox(
              width: rightW,
              child: ChatBotPage(
                key: _chatKey,
                user: widget.user,
                token: widget.token,
                initialChatId: widget.initialChatId,
                defaultChainId: widget.defaultChainId,
                defaultChainConfigId: widget.defaultChainConfigId,
                defaultChainConfig: widget.defaultChainConfig,
                hostCallbacks: hostCbs,
                externalWidgetBuilders: _extraBuilders,
                toolSpecs: [changeButtonColorTool],
                hasSidebar: true,
                showTopBarLogo: false,
                showSidebarLogo: false,
                showUserMenu: false,
                showConversationButton: false,
                showKnowledgeBoxButton: false,
                borderStyle: const ChatBorderStyle(
                  visible: false, // niente bordo
                  margin: EdgeInsets.all(16), // nessuno spazio extra
                  radius: 24,
                  // thickness / color / radius sono ignorati perché visible=false
                ),
                /*backgroundStyle: const ChatBackgroundStyle(
    useGradient: false,
    baseColor  : Colors.white,   // o qualunque tu voglia
  ),*/
                /*backgroundStyle: const ChatBackgroundStyle(
    useGradient    : true,
    baseColor      : Colors.white,        // fallback, bordo, ecc.
    gradientCenter : Alignment(0.0, -0.2),// centro un po’ più in alto
    gradientRadius : 1.4,
    gradientInner  : Color(0xFFFFF5E5),   // arancio chiaro
    gradientOuter  : Color(0xFFFFFFFF),
  ),*/
                separatorStyle: const TopBarSeparatorStyle(
                  visible: false,
                  thickness: 1.0,
                  color: Colors.grey,
                  topOffset: 0.0, // distanza fissa dal bordo superiore
                ),
                topBarMinHeight: 50,
              ),
            ),
          ],
        );
      },
    );
  }
}

/*═════════════════════════════════════════════════════════════════════════════
                                DRAG HANDLE
═════════════════════════════════════════════════════════════════════════════*/

const double _dividerVisibleWidth = 4; // barra nera visibile
const double _dragHitWidth = 4; // area di drag effettiva

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.hitWidth,
    required this.barWidth,
    required this.onDragDx,
  });

  final double hitWidth; // 18 px
  final double barWidth; // 6 px
  final void Function(double dx) onDragDx;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => onDragDx(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: hitWidth, // area sensibile al drag
          child: Center(
            child: Container(
              width: barWidth, // barra visibile
              color: Colors.grey[200],
            ),
          ),
        ),
      ),
    );
  }
}
