// lib/ui_components/ai_generate_panel.dart
//
// Pannello espandibile "Genera con AI" – DEBUG EDITION
// rev 2025‑07‑29‑F
//
// ▸ Traccia:
//   • Selezione e upload dei file
//   • Polling → getChatFiles() **+** stato streaming
//   • Stop / restart automatico del polling
//   • Spinner accanto al titolo e sul pulsante “Genera” mentre
//     ChatBotPageState.isAssistantStreaming == true
//   • Pulsante “Carica file” SOPRA “Genera”, entrambi full‑width,
//     angoli 4 px
//   • Tooltip con nome completo sul pass‑mouse delle card file
//   • Qualunque testo che in precedenza risultava rosso ora è nero bold
//
// BREAKING CHANGE: identità = fileName (non più jobId)
// ────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';          // debugPrint
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/llm_ui_tools/tools.dart';

/// ─────────────────────────────────────────────────────────────────
/// Loader di default – Unstructured
/// ─────────────────────────────────────────────────────────────────
const _kDefaultLoaders = {
  'loaders': {'default': 'UnstructuredLoader'},
  'loader_kwargs': {
    'default': {
      'mode': 'elements',
      'chunking_strategy': 'basic',
      'strategy': 'hi_res',
      'max_characters': 3000,
      'new_after_n_chars': 2500,
      'overlap': 0,
      'overlap_all': false,
      'include_page_breaks': false,
      'partition_via_api': false,
    },
  },
};


class AiGeneratePanel extends StatefulWidget {
  const AiGeneratePanel({super.key, required this.chatKey, this.defaultPrompt,});
  final GlobalKey<ChatBotPageState> chatKey;
   final String? defaultPrompt;   // ← NEW

  @override
  State<AiGeneratePanel> createState() => _AiGeneratePanelState();
}

// 1️⃣  – colore “istituzionale” usato anche dalla Top‑bar
const _kPrimaryBlue = Color(0xFF005E95); //Color(0xFF66A3FF);

class _AiGeneratePanelState extends State<AiGeneratePanel> {

  
/*──────────────────────── STATE ────────────────────────*/
  bool _expanded = false;
  final TextEditingController _txtCtrl = TextEditingController();

  final List<_LocalFile> _local = [];                 // file in attesa di upload
  /// Map <fileName , FileUploadInfo>
  final Map<String, FileUploadInfo> _remote = {};     // file presenti in chat
  Timer? _poller;

  ChatBotPageState? get _chat => widget.chatKey.currentState;

  // flag aggiornato dal poller
  bool _assistantStreaming = false;

/*──────────────────────── LIFECYCLE ───────────────────*/
  @override
  void initState() {
    super.initState();
    _txtCtrl.addListener(() => setState(() {}));   // ← NEW
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chat != null) _startPolling();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _txtCtrl.dispose();
    super.dispose();
  }

Future<void> _sendPrompt() async {
  if (_chat == null) return;

  String txt = _txtCtrl.text.trim();
  bool usedFallback = false;                 // ← NEW

  if (txt.isEmpty) {                         // nessun input utente
    final fallback = widget.defaultPrompt?.trim();
    if (fallback == null || fallback.isEmpty) return; // niente da inviare
    txt = fallback;
    usedFallback = true;                     // ← segnala che è default
  }

  debugPrint('[AIGEN‑DBG] ➡️  send prompt="$txt"');

  // ✦ visibile ↔ invisibile
  if (usedFallback) {
    await _chat!.sendHostMessage(txt, visibility: kVisInvisible);
  } else {
    await _chat!.sendHostMessage(txt);       // visibilità normale
  }

  _txtCtrl.clear();
  if (_poller == null) _startPolling();
}


/*──────────────────────── POLLING ─────────────────────*/
  void _startPolling() {
    if (_poller != null) return;
    debugPrint('[AIGEN‑DBG] ▶️  startPolling()');
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
    debugPrint('[AIGEN‑DBG] ⏹ stopPolling() – nessun file attivo & no streaming');
  }

  /// Ritorna *true* se esiste almeno un file pending/running **o** streaming.
  bool _tick() {
    if (!mounted || _chat == null) return false;

    /*── 0. streaming ─────────────────────────────────────────────*/
    final bool isStr = _chat!.isAssistantStreaming;
    if (isStr != _assistantStreaming) {
      debugPrint('[AIGEN‑DBG] streaming → $isStr');
      _assistantStreaming = isStr;
    }

    /*── 1. files in chat ─────────────────────────────────────────*/
    final chatFiles = _chat!.getChatFiles();
    debugPrint('[AIGEN‑DBG] getChatFiles() → '
        '${chatFiles.map((e) => "${e.fileName}:${e.stage.name}").join(", ")}');

    final fresh = {for (final f in chatFiles) f.fileName: f};
    _remote
      ..clear()
      ..addAll(fresh);

    _local.removeWhere((lf) => fresh.containsKey(lf.name));

    /*── 2. decide se tenere vivo il timer ───────────────────────*/
    final hasActiveUploads = _local.isNotEmpty ||
        _remote.values.any((e) =>
            e.stage == TaskStage.pending || e.stage == TaskStage.running);

    final keepAlive = hasActiveUploads || _assistantStreaming;
    if (!keepAlive) _stopPolling();

    if (mounted) setState(() {});
    return keepAlive;
  }

/*──────────────────────── PICK / UPLOAD ───────────────*/
  Future<void> _pickFiles() async {
    if (_chat == null) {
      debugPrint('[AIGEN‑DBG] ⚠️  chat == null (impossibile caricare)');
      return;
    }

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return;

    if (_poller == null) _startPolling(); // sicuro che il timer giri

    for (final f in res.files) {
      if (f.bytes == null) continue;

      debugPrint('[AIGEN‑DBG] 📥 selected "${f.name}"  bytes=${f.bytes!.length}');
      setState(() => _local.add(_LocalFile(name: f.name, bytes: f.bytes!)));

      try {
        await _chat!.uploadFileFromHost(
          f.bytes!,
          f.name,
          loaders: _kDefaultLoaders['loaders']!.cast<String, String>(),
          loaderKwargs: _kDefaultLoaders['loader_kwargs']!
              .cast<String, Map<String, dynamic>>(),
        );
        debugPrint('[AIGEN‑DBG] ✅ upload accepted "${f.name}"');
      } catch (e, st) {
        debugPrint('[AIGEN‑DBG] ❌ upload FAILED "${f.name}"  err=$e\n$st');
      }
    }
  }

bool _canSend() =>
    !_assistantStreaming &&
    (_txtCtrl.text.trim().isNotEmpty ||
     (widget.defaultPrompt?.trim().isNotEmpty ?? false));
     
/*──────────────────────── BUILD ───────────────────────*/
  @override
  Widget build(BuildContext context) {
    // safety‑net
    if (_chat != null &&
        _poller == null &&
        (_assistantStreaming ||
            _local.isNotEmpty ||
            _remote.values.any((e) =>
                e.stage == TaskStage.pending || e.stage == TaskStage.running))) {
      _startPolling();
    }

    return Material(
       color: Colors.white,          // ← bianco “vero”
       child: ColoredBox(
         color: Colors.white, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
      if (_expanded)
        Padding(                 // ← nuovo padding 8 px su tutti i lati
          padding: const EdgeInsets.all(8),
          child: _buildExpandedBody(),
        ),
      ],
    )));
  }

/// Contenuto espanso (tutto ciò che stava prima fra `if (_expanded) ...`)
Widget _buildExpandedBody() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildPromptField(),
        const SizedBox(height: 12),
        _buildFilesGrid(),
        if (_remote.isNotEmpty || _local.isNotEmpty)
          const SizedBox(height: 12),
        _buildButtonsColumn(),
      ],
    );
/*──────────────────────── UI SUB‑WIDGETS ─────────────*/
  Widget _buildHeader() => InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kPrimaryBlue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Text(
  'Genera con AI',
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  ),
),
              const Spacer(),
              if (_assistantStreaming)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              if (_assistantStreaming) const SizedBox(width: 8),
              Icon(color: Colors.white,
               _expanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
            ],
          ),
        ),
      );

  Widget _buildPromptField() => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 160),
        child: Scrollbar(
          thumbVisibility: true,
          child: TextField(
            controller: _txtCtrl,
            minLines: 3,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Scrivi il prompt…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      );

  /// Pulsanti verticali full‑width
  Widget _buildButtonsColumn() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    /*───── CARICA FILE ─────*/
    ElevatedButton.icon(
      icon: const Icon(Icons.attach_file, color: Colors.white),
      label: const Text(
        'Carica file',
        style: TextStyle(
          color: Colors.white,          // testo nero
          fontWeight: FontWeight.bold,  // se vuoi bold
        ),
      ),
      onPressed: _assistantStreaming ? null : _pickFiles,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimaryBlue,        // sfondo grigio
        foregroundColor: _kPrimaryBlue,                // colore per splash/hover
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    const SizedBox(height: 8),

    /*───── GENERA ─────*/
    ElevatedButton(
      onPressed: _canSend() ? _sendPrompt : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimaryBlue,      // sfondo grigio
        foregroundColor: _kPrimaryBlue,                // colore splash/hover
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: _assistantStreaming
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,  // spinner nero su grigio
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'In corso…',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Genera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    ),
  ],
);


  Widget _buildFilesGrid() {
    final cards = <Widget>[
      for (final f in _local) _FileCard.local(fileName: f.name),
      for (final info in _remote.values)
        _FileCard.remote(key: ValueKey(info.fileName), info: info),
    ];

    return cards.isEmpty
        ? const SizedBox.shrink()
        : Wrap(spacing: 8, runSpacing: 8, children: cards);
  }
}

/*════════════════════════════════════════════════════*/
/*  Helper classes                                    */
/*════════════════════════════════════════════════════*/
class _LocalFile {
  _LocalFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class _FileCard extends StatelessWidget {
  const _FileCard.local({required this.fileName, Key? key})
      : info = null,
        _isLocal = true,
        super(key: key);

  _FileCard.remote({required this.info, Key? key})
      : fileName = info!.fileName,
        _isLocal = false,
        super(key: key);

  final String fileName;
  final FileUploadInfo? info;
  final bool _isLocal;

  @override
  Widget build(BuildContext context) {
    late final IconData leading;
    late final Color iconColor;
    late final Widget trailing;
    TextStyle          textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );

    if (_isLocal) {
      leading = Icons.schedule;
      iconColor = Colors.orange;
      trailing = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
        textStyle =  TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );
    } else {
      switch (info!.stage) {
  case TaskStage.pending:
    leading    = Icons.schedule;          // icona “in coda”
    iconColor  = Colors.orange;
    trailing   = const SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  textStyle =  TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );
    break;   
        case TaskStage.running:
          leading = Icons.sync;
          iconColor = Colors.blue;
          trailing = const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
  textStyle =  TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );
          break;
        case TaskStage.done:
          leading = Icons.check_circle;
          iconColor = Colors.green;
          trailing = const Icon(Icons.check, size: 16, color: Colors.green);
  textStyle =  TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );
          break;
        case TaskStage.error:
          leading = Icons.error;
          iconColor = Colors.red;
          trailing = const Icon(Icons.error, size: 16, color: Colors.red);
          textStyle =  TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.black,
    decoration: TextDecoration
        .none,           // ← nessuna sottolineatura (rimuove le linee)
    // rimuovi (o commenta) decorationColor / decorationThickness
  );
          break;
      }
    }

    return Tooltip(
      message: fileName, // nome completo
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(leading, color: iconColor, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
