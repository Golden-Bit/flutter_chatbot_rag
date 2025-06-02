import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/llm_ui_tools/utilities/auto_sequence_widget.dart';
import 'package:flutter_app/llm_ui_tools/utilities/js_runner_widget.dart';
import 'package:flutter_app/llm_ui_tools/utilities/toolEventWidget.dart';
import 'package:flutter_app/ui_components/chat/empty_chat_content.dart';
import 'package:flutter_app/ui_components/chat/utilities_functions/rename_chat_instructions.dart';
import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/ui_components/message/codeblock_md_builder.dart';
import 'package:flutter_app/llm_ui_tools/tools.dart';
import 'package:flutter_app/ui_components/buttons/blue_button.dart';
import 'package:flutter_app/ui_components/dialogs/search_dialog.dart';
import 'package:flutter_app/ui_components/dialogs/select_contexts_dialog.dart';
import 'package:flutter_app/ui_components/message/table_md_builder.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/components/settings_dialog.dart';
import 'package:flutter_app/user_manager/components/usage_analytics_dialog.dart';
import 'package:flutter_app/utilities/localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart'; // Aggiungi il pacchetto TTS
import 'package:flutter/services.dart'; // Per il pulsante di copia
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Per il color picker
import 'context_page.dart'; // Importa altri pacchetti necessari
import 'package:flutter/services.dart'
    show rootBundle; // Import necessario per caricare file JSON
import 'dart:convert'; // Per il parsing JSON
import 'context_api_sdk.dart'; // Importa lo script SDK
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'databases_manager/database_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Importa il pacchetto UUID (assicurati di averlo aggiunto a pubspec.yaml)
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart'; // Per gestire il tap sui link
import 'package:intl/intl.dart';
import 'dart:async'; // Assicurati di importare il package Timer
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';   // se non c’era già
// ↑ Nella sezione import esistente
import 'package:markdown/markdown.dart' as md;           // parse Element
import 'dart:html' as html;                              // download CSV
import 'package:collection/collection.dart';

/*void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatbot Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatBotPage(),
    );
  }
}*/
/// Risultato del parsing del testo chatbot:
/// text:   il testo "pulito" (senza la parte di <...>)
/// widgetData: se esiste un widget, i dati necessari (altrimenti null)


 class FileUploadInfo {
  String jobId;
  String ctxPath;     // path KB
  String fileName;
  TaskStage stage;    // pending | running | done | error

  FileUploadInfo({
    required this.jobId,
    required this.ctxPath,
    required this.fileName,
    this.stage = TaskStage.pending,
  });

  Map<String,dynamic> toJson() => {
    'jobId'   : jobId,
    'ctxPath' : ctxPath,
    'fileName': fileName,
    'stage'   : stage.name,
  };

  factory FileUploadInfo.fromJson(Map<String,dynamic> j) => FileUploadInfo(
    jobId   : j['jobId'],
    ctxPath : j['ctxPath'],
    fileName: j['fileName'],
    stage   : TaskStage.values.firstWhere(
                 (e) => e.name == (j['stage'] ?? 'pending')),
  );
}

/// Restituisce la coppia **icona + colore** in base all’estensione del file.
Map<String, dynamic> fileIconFor(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'pdf':
      return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
    case 'doc':
    case 'docx':
      return {'icon': Icons.description, 'color': Colors.blue};
    case 'xls':
    case 'xlsx':
      return {'icon': Icons.table_chart, 'color': Colors.green};
    case 'ppt':
    case 'pptx':
      return {'icon': Icons.slideshow, 'color': Colors.orange};
    case 'jpg':
    case 'jpeg':
    case 'png':
      return {'icon': Icons.image, 'color': Colors.purple};
    case 'zip':
    case 'rar':
      return {'icon': Icons.folder_zip, 'color': Colors.brown};
    default:
      return {'icon': Icons.insert_drive_file, 'color': Colors.grey};
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  MINI-CARD DI UPLOAD NELLA CHAT
///  • icona coerente con il tipo di file (in alto-sinistra)
///  • badge di stato (pending/running/done/error) sovrapposto
///  • pulsanti:   [👁 vedi docs]   [⬇ scarica]
/// ─────────────────────────────────────────────────────────────────────────
class FileUploadWidget extends StatelessWidget {
  final FileUploadInfo info;
  final VoidCallback? onDownload;
  final VoidCallback? onViewDocs;

  const FileUploadWidget({
    super.key,
    required this.info,
    this.onDownload,
    this.onViewDocs,
  });

  @override
  Widget build(BuildContext context) {
    // ── 1. icona principale in base al tipo di file
    final ic = fileIconFor(info.fileName);

    // ── 2. badge di stato
    late final IconData statusIcon;
    late final Color    statusColor;
    late final Widget   trailingSpinner;   // usato per PENDING/RUNNING

    switch (info.stage) {
      case TaskStage.pending:
        statusIcon     = Icons.schedule;
        statusColor    = Colors.orange;
        trailingSpinner = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case TaskStage.running:
        statusIcon     = Icons.sync;
        statusColor    = Colors.blue;
        trailingSpinner = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case TaskStage.done:
        statusIcon  = Icons.check;
        statusColor = Colors.green;
        trailingSpinner = const SizedBox.shrink();
        break;
      case TaskStage.error:
        statusIcon  = Icons.error;
        statusColor = Colors.red;
        trailingSpinner = const SizedBox.shrink();
        break;
    }

    // ── 3. azioni a destra
    final List<Widget> actions = [];
    if (onViewDocs != null) {
      actions.add(
        IconButton(
          tooltip: 'Mostra documenti indicizzati',
          icon: const Icon(Icons.visibility),
          onPressed: onViewDocs,
        ),
      );
    }
    if (info.stage == TaskStage.done && onDownload != null) {
      actions.add(
        IconButton(
          tooltip: 'Scarica file originale',
          icon: const Icon(Icons.download),
          onPressed: onDownload,
        ),
      );
    }
    if (actions.isEmpty &&                                           // per pending/running
        (info.stage == TaskStage.pending || info.stage == TaskStage.running)) {
      actions.add(trailingSpinner);
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.topRight,
          children: [
            Icon(ic['icon'] as IconData, size: 36, color: ic['color'] as Color),
            // badge circolare
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, size: 14, color: statusColor),
            ),
          ],
        ),
        title: Text(
          info.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Knowledge-Box: ${info.ctxPath}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }
}



class ParsedWidgetResult {
  final String text;
  final List<Map<String, dynamic>> widgetList;

  ParsedWidgetResult(this.text, this.widgetList);
}

/// Classe di appoggio per segmenti di testo o placeholder
class _Segment {
  final String? text;
  final String? placeholder;
  _Segment({this.text, this.placeholder});
}

class ChatBotPage extends StatefulWidget {
  final User user;
  final Token token;

  ChatBotPage({required this.user, required this.token});

  @override
  ChatBotPageState createState() => ChatBotPageState();
}

class ChatBotPageState extends State<ChatBotPage> {
  final ContextApiSdk _apiSdk = ContextApiSdk();
  // DOPO
final Map<String /*jobId*/, PendingUploadJob> _pendingJobs = {};
String? _chatKbPath;                                  // NEW – path KB legata alla chat
final Set<String> _syncedMsgIds = {};                 // NEW – id dei msg già caricati
// idem per le notifiche
final Map<String /*jobId*/, TaskNotification> _taskNotifications = {};
  final CognitoApiClient _apiClient = CognitoApiClient();
  final _inputScroll = ScrollController();
// Controller già esistente usato dallo ScrollView dei messaggi:
  final ScrollController _messagesScrollController = ScrollController();
  double _lastScrollPosition = 0;
// Nuova flag per mostrare/nascondere il FloatingActionButton
  bool _showScrollToBottomButton = false;
bool isLoggingOut = false;
/// ---------------------------------------------------------------------------
///  Restituisce la stessa struttura che metti nei messaggi “normali”
///  (aggiungi qui dentro ogni metadato aggiuntivo che ti serve)             ↓↓
Map<String, dynamic> _buildCurrentAgentConfig() {
  return {
    'model'     : _selectedModel,
    'contexts'  : _formattedContextsForAgent(),
    'chain_id'  : _latestChainId,
    'config_id' : _latestConfigId,
  };
}
  bool _appReady = false;
// Restituisce una stringa CSV escapando le virgolette
String _toCsv(List<List<String>> rows) {
  return rows.map((r) =>
      r.map((c) => '"${c.replaceAll('"', '""')}"').join(',')
    ).join('\r\n');
}

void _downloadCsv(List<List<String>> rows) {
  final buffer = StringBuffer();
  for (final r in rows) {
    buffer.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
  }
  final csvStr = buffer.toString();

  final blob = html.Blob([csvStr], 'text/csv');
  final url  = html.Url.createObjectUrlFromBlob(blob);
  final a    = html.AnchorElement(href: url)..download = 'table.csv';
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}

final FocusNode _inputFocus = FocusNode();
// ──────────────────────────────────────────────────────────────────
// crea una KB per la chat (se non esiste) e ne restituisce il path
Future<String> _ensureChatKb(String chatId, String chatName) async {
  if (_chatKbPath != null) return _chatKbPath!;                // già fatta

  final uuid = const Uuid().v4().substring(0, 9);               // path breve
  final displayName = 'Chat-$chatName';
  await _contextApiSdk.createContext(
    uuid,
    'Archivio messaggi chat $chatName',
    displayName,
    widget.user.username,
    widget.token.accessToken,
    extraMetadata: { 'chat_id': chatId },                       // ★ associazione
  );
  _chatKbPath = uuid;
  return uuid;
}


/// Se la chat ha documenti indicizzati ma l’ultima chain non include la sua KB,
/// riconfigura la chain includendo (solo) quella KB.
Future<void> _ensureChainIncludesChatKb(String chatId) async {
  // ── recupera la chat
  final chat = _chatHistory.firstWhere(
    (c) => c['id'] == chatId,
    orElse: () => null,
  );
  if (chat == null) return;

  // ── path KB associata
  final String? kbPath = chat['kb_path'] as String?;
  if (kbPath == null || kbPath.isEmpty) return;

  // ── verifica che esista ≥1 upload completato
  final bool hasIndexedDocs = (chat['messages'] as List).any((m) {
    final fu = m['fileUpload'] as Map<String, dynamic>?;
    return fu != null &&
        fu['ctxPath'] == kbPath &&
        fu['stage'] == TaskStage.done.name;
  });
  if (!hasIndexedDocs) return;                     // nessun doc indicizzato

  // ── estrai model + contesti dell’ultima agent-config
  String   model     = _defaultModel;
  List<String> ctx   = [];
  if ((chat['messages'] as List).isNotEmpty) {
    final cfg = (chat['messages'].last['agentConfig'] ??
            const {}) as Map<String, dynamic>;
    model = (cfg['model'] ?? _defaultModel) as String;
    ctx   = List<String>.from(cfg['contexts'] ?? const []);
  }

  // ── i contesti salvati sono con prefisso "<user>-…" ⇒ toglilo
  final List<String> rawCtx =
      ctx.map((c) => _stripUserPrefix(c)).toList();

  // ── se la KB è già presente non serve fare nulla
  if (rawCtx.contains(kbPath)) return;

  // ── prepara la nuova lista contesti
  final List<String> newCtx = [...rawCtx, kbPath];

  // ── chiama il backend
  final resp = await _contextApiSdk.configureAndLoadChain(
    widget.user.username,
    widget.token.accessToken,
    newCtx,
    model,
  );

  final String? newChainId  = resp['load_result']?['chain_id'];
  final String? newConfigId = resp['config_result']?['config_id'];

  // ── salva nella chat (così resta persistente)
  chat['latestChainId']  = newChainId;
  chat['latestConfigId'] = newConfigId;

  // aggiorna anche l’ultima agentConfig presente
  if ((chat['messages'] as List).isNotEmpty) {
    final cfg =
        (chat['messages'].last['agentConfig'] ?? <String, dynamic>{})
            as Map<String, dynamic>;
    cfg['chain_id']  = newChainId;
    cfg['config_id'] = newConfigId;
    cfg['contexts']  =
        newCtx.map((c) => "${widget.user.username}-$c").toList();
    chat['messages'].last['agentConfig'] = cfg;
  }

  // ── se è la chat visibile, aggiorna lo stato globale
  if (_activeChatIndex != null &&
      _chatHistory[_activeChatIndex!]['id'] == chatId) {
    setState(() {
      _latestChainId  = newChainId;
      _latestConfigId = newConfigId;
    });
  }

  // ── persistenza localStorage (il blocco DB verrà gestito dal tuo save/auto-save)
  html.window.localStorage['chatHistory'] =
      jsonEncode({'chatHistory': _chatHistory});
}

// ────────────────────────────────────────────────────────────────
//  CONFIG DI DEFAULT (usata quando apri una chat “vergine”)
// ────────────────────────────────────────────────────────────────
static const String _defaultModel = 'gpt-4o';   // cambia se ti serve

/// Rimuove il prefisso "<username>-" dai context formattati
String _stripUserPrefix(String ctx) {
  final prefix = "${widget.user.username}-";
  return ctx.startsWith(prefix) ? ctx.substring(prefix.length) : ctx;
}

/// Ritorna true se `ctxPath` esiste tra le KB note all’app
bool _contextIsKnown(String ctxPath) =>
    _availableContexts.any((c) => c.path == ctxPath);
    
static const _prefsKeyPending = 'kb_pending_jobs';
// ──────────────────────────────────────────────────────────────────
//  Prepara (se serve) la chain per la chat *corrente*
//
//  • se esiste già una chain-id valida ⇒ non fa nulla
//  • altrimenti:
//      1. assicura la KB della chat               (_chatKbPath)
//      2. crea una chain nuova con SOLO quella KB
// ──────────────────────────────────────────────────────────────────
Future<void> _prepareChainForCurrentChat() async {
  if (_latestChainId != null && _latestChainId!.isNotEmpty) return;

  // 1‧ assicura KB
  final chatId   = _getCurrentChatId().isEmpty ? uuid.v4() : _getCurrentChatId();
  final chatName = (_activeChatIndex != null)
      ? _chatHistory[_activeChatIndex!]['name']
      : 'New Chat';

  if (_chatKbPath == null) {
    _chatKbPath = await _ensureChatKb(chatId, chatName);
  }

  // 2‧ chain con SOLO la KB-chat
  await set_context(_rawContextsForChain(), _selectedModel);
}

Future<void> _savePendingJobs(Map<String, PendingUploadJob> jobs) async {
  // ① costruisci un vero Map<String,dynamic>
  final Map<String, dynamic> activeJobs = {
    for (final e in jobs.entries)
      if (e.value.tasksPerCtx.values.any((t) =>
          t.loaderTaskId != null || t.vectorTaskId != null))
        e.key: e.value.toJson(),
  };

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKeyPending, jsonEncode(activeJobs));
}



TaskStage _mapStatus(String? s) {
  switch (s?.toUpperCase()) {
    case 'FAILED':
    case 'ERROR':
    case 'CANCELLED':
      return TaskStage.error;

    case 'DONE':
    case 'SUCCESS':
    case 'COMPLETED':
    case 'SUCCEEDED':
      return TaskStage.done;

    case 'RUNNING':
    case 'STARTED':
    case 'PROCESSING':
    case 'INDEXING':
      return TaskStage.running;

    case 'PENDING':
    case 'QUEUED':
    case 'CREATED':
    case 'SCHEDULED':
    default:                      // fallback *non è* più errore
      return TaskStage.pending;
  }
}

// all’interno di ChatBotPageState
bool _isChainLoading = false;           // ← spinner / disabilita invio

/// Attende finché la chain non è pronta.
/// Se mancano gli ID li richiede e li salva in stato.
Future<void> _ensureChainReady() async {
  // già configurata?
  final bool ready = (_latestChainId?.isNotEmpty ?? false) &&
                     (_latestConfigId?.isNotEmpty ?? false);
  if (ready) return;

  // evita doppie inizializzazioni concorrenti
  if (_isChainLoading) {
    while (_isChainLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return;
  }

  setState(() => _isChainLoading = true);
  try {
    // 1. KB della chat e chain “vuota”
    await _prepareChainForCurrentChat();

    // 2. configura davvero la chain con i contesti correnti
    await set_context(_rawContextsForChain(), _selectedModel);
  } finally {
    setState(() => _isChainLoading = false);
  }
}


// ⇠ dentro ChatBotPage (stesso livello di _uploadFileForContextAsync nel Dashboard)
Future<void> _uploadFileForChatAsync({required bool isMedia}) async {
  // 1. scelta file -----------------------------------------------------------
  final result = await FilePicker.platform.pickFiles(
    type: isMedia ? FileType.media : FileType.any,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.first.bytes == null) return;

  final Uint8List bytes   = result.files.first.bytes!;
  final String    fName   = result.files.first.name;

  // 2. assicura che la KB della chat esista -------------------------------
  final String chatId   = _getCurrentChatId().isEmpty ? uuid.v4() : _getCurrentChatId();
  final String chatName = (_activeChatIndex != null)
        ? _chatHistory[_activeChatIndex!]['name']
        : 'New Chat';

  if (_chatKbPath == null) {
    _chatKbPath = await _ensureChatKb(chatId, chatName);
  }

  // 3. chiamata POST /upload_async ----------------------------------------
  final resp = await _contextApiSdk.uploadFileToContextsAsync(
    bytes,
    [_chatKbPath!],                       // una sola KB: quella della chat
    widget.user.username,
    widget.token.accessToken,
    fileName: fName,
  );

  final Map<String, TaskIdsPerContext> tasksPerCtx = resp.tasks;  

  // 4. registra job + notifica overlay ------------------------------------
  final String jobId = const Uuid().v4();
  _onNewPendingJob(jobId, chatId, _chatKbPath!, fName, tasksPerCtx);

  _pendingJobs[jobId] = PendingUploadJob(
    jobId:       jobId,
    chatId: chatId,
    contextPath: _chatKbPath!,
    fileName:    fName,
    tasksPerCtx: tasksPerCtx,
  );
  await _savePendingJobs(_pendingJobs);   // persistenza

  setState(() {
  messages.add({
    'id'        : uuid.v4(),
    'role'      : 'user',
    'content'   : 'File "$fName" caricato',   // testo visibile
    'createdAt' : DateTime.now().toIso8601String(),
    'fileUpload': FileUploadInfo(
                    jobId   : jobId,
                    ctxPath : _chatKbPath!,
                    fileName: fName,
                    stage   : TaskStage.pending,
                  ).toJson(),
    'agentConfig': _buildCurrentAgentConfig(),        //  <— aggiungi questo
  });

  _saveConversation(messages);
});

}

// ──────────────────────────────────────────────────────────────────
// carica nella KB tutti i messaggi non ancora presenti (uno .txt per msg)
Future<void> _syncMessagesToKb(String kbPath) async {
  // lista dei file già presenti nella KB
  final existing = await _contextApiSdk.listFiles(
    widget.user.username,
    widget.token.accessToken,
    contexts: [kbPath],
  );
  final already = existing.map((f) => f['custom_metadata']?['msg_id'] as String?)
                          .whereType<String>()
                          .toSet();

  for (final m in messages) {
    final id = m['id'] as String;
    if (already.contains(id) || _syncedMsgIds.contains(id)) continue;

    // JSON "pulito" del singolo messaggio
    final msgJson = jsonEncode({
      'id'      : m['id'],
      'role'    : m['role'],
      'content' : m['content'],
      'createdAt': m['createdAt'],
    });
    final bytes = utf8.encode(msgJson);

    await _contextApiSdk.uploadFileToContexts(
      Uint8List.fromList(bytes),
      [kbPath],
      widget.user.username,
      widget.token.accessToken,
      description : 'msg ${m['id']}',
      fileName    : '${m['id']}.txt',
      extraMetadata: {                                     // <-- traccia l’ID msg
        'msg_id': id,
      },
    );
    _syncedMsgIds.add(id);                                // evita doppioni futuri
  }
}

/// Ritorna `true` se esiste almeno un messaggio “fileUpload”
/// la cui `stage` è **DONE** (quindi il documento è stato indicizzato
/// e il vector-store esiste).  
bool _chatKbHasIndexedDocs() {
  if (_chatKbPath == null || _chatKbPath!.isEmpty) return false;

  return messages.any((m) {
    final fu = m['fileUpload'] as Map<String, dynamic>?;
    return fu != null &&
           fu['ctxPath'] == _chatKbPath! &&
           fu['stage']  == TaskStage.done.name;
  });
}


// ─────────────────────────────────────────────────────────────────────────
//  Raccoglie i CONTEXT PATH “grezzi” da passare al backend
//  • contesti scelti manualmente dall’utente
//  • KB associata alla chat **solo se** ha almeno un doc indicizzato
// ─────────────────────────────────────────────────────────────────────────
List<String> _rawContextsForChain() {
  final set = <String>{..._selectedContexts};

  // include la KB-chat SOLO se ha documenti indicizzati
  if (_chatKbHasIndexedDocs()) {
    set.add(_chatKbPath!);
  }
  return set.toList();
}


// Versione “formattata” (username-prefix) usata nei metadati visibili
List<String> _formattedContextsForAgent() =>
    _rawContextsForChain().map((c) => "${widget.user.username}-$c").toList();


void _onNewPendingJob(
  String jobId,
  String chatId,                               // NEW
  String ctxPath,
  String fileName,
  Map<String, TaskIdsPerContext> tasksPerCtx,
) {
  // display-name visibile nella card
  final displayName = _availableContexts
          .firstWhere(
              (c) => c.path == ctxPath,
              orElse: () =>
                  ContextMetadata(path: ctxPath, customMetadata: {}))
          .customMetadata?['display_name'] as String? ??
      ctxPath;

  // ① notifica visuale
  _taskNotifications[jobId] = TaskNotification(
    jobId       : jobId,
    contextPath : ctxPath,
    contextName : displayName,
    fileName    : fileName,
    stage       : TaskStage.pending,
  );

  // ② dati per il polling
  _pendingJobs[jobId] = PendingUploadJob(
    jobId       : jobId,
    chatId      : chatId,                      // NEW
    contextPath : ctxPath,
    fileName    : fileName,
    tasksPerCtx : tasksPerCtx,
  );

  if (_notifOverlay == null) _startNotifOverlay();
  _refreshNotifOverlay();
}
/// Se la KB-chat ora contiene almeno un documento, aggiorna subito la chain.
/// L’aggiornamento viene fatto SOLO se la chat è quella attualmente aperta,
/// altrimenti la chat verrà riallineata in automatico quando l’utente la riapre.
Future<void> _reconfigureChainIfNeeded(String chatId) async {
  // La chat aperta è diversa?  allora esci subito
  if (_activeChatIndex == null ||
      _chatHistory[_activeChatIndex!]['id'] != chatId) return;

  // Se la KB-chat ora ha documenti indicizzati rifai la set_context
  if (_chatKbHasIndexedDocs()) {
    await set_context(_rawContextsForChain(), _selectedModel);
  }
}

  /// ++ ogni volta che l’assistente **ha finito** di rispondere
  static final ValueNotifier<int> assistantTurnCompleted =
      ValueNotifier<int>(0);
  static const String kArchiveCollection = 'archived_chats';
  String spinnerPlaceholder = "[WIDGET_IN_CARICAMENTO]";
  int _widgetCounter = 0; // Contatore globale nella classe per i placeholder
void _refreshNotifOverlay() {
  // ① se non c’è alcuna card visibile esci subito
  final hasVisible = _taskNotifications.values.any(
  (n) => n.isVisible && _contextIsKnown(n.contextPath),
);
  if (!hasVisible) {
    // …ma tieniti pronto ad inserirlo alla prossima card “visibile”
    if (_notifOverlay != null) {
      _notifOverlay!.remove();   // chiude solo il widget overlay
      _notifOverlay = null;
    }
    return;
  }

  // ② se l’overlay non c’è più, ricrealo (non tocca il poller)
  if (_notifOverlay == null) {
    _startNotifOverlay();        // inserisce overlay ma **non** un nuovo timer
  } else {
    _notifOverlay!.markNeedsBuild();
  }
}

  String _finalizeWidgetBlock(String widgetBlock) {
    // 1) Trovi la parte JSON (tra le due barre verticali)
    final firstBar = widgetBlock.indexOf("|");
    final secondBar = widgetBlock.indexOf("|", firstBar + 1);
    if (firstBar == -1 || secondBar == -1) {
      // Errore di formattazione => Ritorna un placeholder fisso o stringa vuota
      return "[WIDGET_PLACEHOLDER_ERROR]";
    }

    final jsonString = widgetBlock.substring(firstBar + 1, secondBar).trim();
    // 2) Trova WIDGET_ID='...'
    final widgetIdSearch = "WIDGET_ID='";
    final widgetIdStart = widgetBlock.indexOf(widgetIdSearch);
    if (widgetIdStart == -1) {
      return "[WIDGET_PLACEHOLDER_ERROR]";
    }
    final widgetIdStartAdjusted = widgetIdStart + widgetIdSearch.length;
    final widgetIdEnd = widgetBlock.indexOf("'", widgetIdStartAdjusted);
    if (widgetIdEnd == -1) {
      return "[WIDGET_PLACEHOLDER_ERROR]";
    }
    final widgetId = widgetBlock.substring(widgetIdStartAdjusted, widgetIdEnd);

    // 3) Decodifica JSON
    Map<String, dynamic>? widgetJson;
    try {
      widgetJson = jsonDecode(jsonString);
    } catch (e) {
      return "[WIDGET_PLACEHOLDER_ERROR]";
    }
    if (widgetJson == null) {
      return "[WIDGET_PLACEHOLDER_ERROR]";
    }

    // 4) Eventuale gestione is_first_time
    if (!widgetJson.containsKey('is_first_time')) {
      widgetJson['is_first_time'] = true;
    } else {
      // se esiste ed è true, metti false, ecc.
    }

    // 5) Genera un ID univoco
    final widgetUniqueId = uuid.v4();

    // 6) Costruisce un segnaposto
    final placeholder = "[WIDGET_PLACEHOLDER_$_widgetCounter]";
    _widgetCounter++;

    // 7) Aggiungiamo questo widget alla widgetDataList dell'ULTIMO messaggio
    final lastMsg = messages[messages.length - 1];
    List<dynamic> wList = lastMsg['widgetDataList'] ?? [];
    wList.add({
      "_id": widgetUniqueId,
      "widgetId": widgetId,
      "jsonData": widgetJson,
      "placeholder": placeholder,
    });
    lastMsg['widgetDataList'] = wList;

    // 8) Ritorniamo il placeholder
    return placeholder;
  }

  Future<void> _renameChat(String chatId, String newName) async {
    // Trova l'indice della chat in base all'ID
    int index = _chatHistory.indexWhere((chat) => chat['id'] == chatId);
    if (index != -1) {
      // Richiama la funzione già esistente per aggiornare il nome della chat
      await _editChatName(index, newName);
      // Facoltativo: mostra un messaggio di conferma
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat renamed to "$newName"')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat with ID "$chatId" not found.')),
      );
    }
  }

  List<Map<String, dynamic>> messages = [];

  final Map<String, Widget> _widgetCache = {}; // Cache dei widget
  final Uuid uuid = Uuid(); // Istanza di UUID (può essere globale nel file)

  final TextEditingController _controller = TextEditingController();
  String fullResponse = "";
  bool showKnowledgeBase = false;

  //String _selectedContext = "default";  // Variabile per il contesto selezionato
  List<String> _selectedContexts =
      []; // Variabile per memorizzare i contesti selezionati
  final ContextApiSdk _contextApiSdk =
      ContextApiSdk(); // Istanza dell'SDK per le API dei contesti
  List<ContextMetadata> _availableContexts =
      []; // Lista dei contesti caricati dal backend

  // Variabili per gestire la colonna espandibile e ridimensionabile
  bool isExpanded = false;
  double sidebarWidth = 0.0; // Impostata a 0 di default (collassata)
  bool showSettings = false; // Per mostrare la sezione delle impostazioni

  // Variabili per il riconoscimento vocale
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Inizializza il TTS
  late FlutterTts _flutterTts;
  bool _isPlaying = false; // Stato per controllare se TTS è in esecuzione

  // Variabili di personalizzazione TTS
  String _selectedLanguage = "en-US";
  double _speechRate = 0.5; // Velocità di lettura
  double _pitch = 1.0; // Pitch (intonazione)
  double _volume = 0.5; // Volume
  double _pauseBetweenSentences = 0.5; // Pausa tra le frasi

  // Variabili di customizzazione grafica
  Color _userMessageColor = Colors.blue[100]!;
  double _userMessageOpacity = 1.0;

  Color _assistantMessageColor = Colors.grey[200]!;
  double _assistantMessageOpacity = 1.0;

  Color _chatBackgroundColor = Colors.white;
  double _chatBackgroundOpacity = 1.0;

  Color _avatarBackgroundColor = Colors.grey[600]!;
  double _avatarBackgroundOpacity = 1.0;

  Color _avatarIconColor = Colors.white;
  double _avatarIconOpacity = 1.0;

  String _selectedModel =
      "gpt-4o"; // Variabile per il modello selezionato, di default GPT-4O
  int? _buttonHoveredIndex; // Variabile per i pulsanti principali
  int? hoveredIndex; // Variabile per le chat salvate

  int? _activeChatIndex; // Chat attiva (null se si sta creando una nuova chat)
  final DatabaseService _databaseService = DatabaseService();
// Aggiungi questa variabile per contenere la chat history simulata
  List<dynamic> _chatHistory = [];
  String? _nlpApiUrl;
  int? _activeButtonIndex;

  String? _latestChainId;
  String? _latestConfigId;
final Map<String, Map<String, dynamic>> _toolEvents = {}; 


  /// Risultato del parsing del testo chatbot:
  /// text: testo "pulito" dopo la rimozione dei blocchi widget,
  ///       in cui ogni widget è sostituito da un segnaposto [WIDGET_PLACEHOLDER_X]
  /// widgetList: lista di dati dei widget estratti
// ————————————————————————————————————————————————————————————————
// ARCHIVIA TUTTE LE CHAT NON ARCHIVIATE
  Future<void> _archiveAllChats() async {
    final loc = LocalizationProvider.of(context);
    final dbName = "${widget.user.username}-database";
    final token = widget.token.accessToken;

    try {
      // assicura che la collezione di archivio esista
      await _databaseService
          .createCollection(dbName, kArchiveCollection, token)
          .catchError((_) {});

      // prendi tutte le chat correnti
      final chats = await _databaseService.fetchCollectionData(
        dbName,
        'chats',
        token,
      );

      // sposta ogni chat
      for (final chat in chats) {
        await _databaseService.addDataToCollection(
            dbName, kArchiveCollection, chat, token);

        if (chat.containsKey('_id')) {
          await _databaseService.deleteCollectionData(
              dbName, 'chats', chat['_id'], token);
        }
      }

      // stato locale & localStorage
      setState(() => _chatHistory.clear());
      html.window.localStorage.remove('chatHistory');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chat_archived)), // <Chat archiviate>
      );
    } catch (e) {
      print("Archive‑all error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.genericError)),
      );
    }
  }

// ————————————————————————————————————————————————————————————————
// ELIMINA TUTTE LE CHAT NON ARCHIVIATE
  Future<void> _deleteAllChats() async {
    final loc = LocalizationProvider.of(context);
    final dbName = "${widget.user.username}-database";
    final token = widget.token.accessToken;

    try {
      // Cancella l’intera collezione…
      await _databaseService
          .deleteCollection(dbName, 'chats', token)
          .catchError((_) {}); // se non esiste, ignora
      // …e la ricrea vuota così l’app non va in errore più tardi
      await _databaseService.createCollection(dbName, 'chats', token);

      // pulizia stato locale
      setState(() => _chatHistory.clear());
      html.window.localStorage.remove('chatHistory');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.all_chats_deleted)), // <Chat eliminate>
      );
    } catch (e) {
      print("Delete‑all error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.genericError)),
      );
    }
  }

  ParsedWidgetResult _parsePotentialWidgets(String fullText) {
    String updatedText = fullText;
    final List<Map<String, dynamic>> widgetList = [];
    int widgetCounter = 0;

    while (true) {
      // 1) Trova l'indice di inizio del pattern "< TYPE='WIDGET'"
      final startIndex = updatedText.indexOf("< TYPE='WIDGET'");
      if (startIndex == -1) break;

      // 2) Trova il marker di chiusura "| TYPE='WIDGET'" **dopo** startIndex
      const String endMarker = "| TYPE='WIDGET'";
      final markerIndex = updatedText.indexOf(endMarker, startIndex);
      if (markerIndex == -1) break;

      // 3) Trova il carattere '>' **dopo** il marker
      final endIndex = updatedText.indexOf(">", markerIndex + endMarker.length);
      if (endIndex == -1) break;

      // 4) Estrarre il sottoblocco completo
      final widgetBlock = updatedText.substring(startIndex, endIndex + 1);

      // 5) Cerchiamo la prima e la seconda barra verticale "|"
      final firstBar = widgetBlock.indexOf("|");
      final secondBar = widgetBlock.indexOf("|", firstBar + 1);
      if (firstBar == -1 || secondBar == -1) {
        // Pattern non valido, rimuoviamo e proseguiamo
        updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
        continue;
      }

      // 6) Estrarre la parte JSON
      final jsonString = widgetBlock.substring(firstBar + 1, secondBar).trim();

      // 7) Estrarre widgetId (dopo WIDGET_ID=' ... ')
      const String widgetIdSearch = "WIDGET_ID='";
      final widgetIdStart = widgetBlock.indexOf(widgetIdSearch);
      if (widgetIdStart == -1) {
        updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
        continue;
      }
      final widgetIdStartAdjusted = widgetIdStart + widgetIdSearch.length;
      final widgetIdEnd = widgetBlock.indexOf("'", widgetIdStartAdjusted);
      if (widgetIdEnd == -1 || widgetIdEnd <= widgetIdStartAdjusted) {
        updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
        continue;
      }
      final widgetId =
          widgetBlock.substring(widgetIdStartAdjusted, widgetIdEnd);

      // 8) Decodifica del JSON
      Map<String, dynamic>? widgetJson;
      try {
        widgetJson = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        print("Errore parse JSON widget: $e");
        widgetJson = null;
      }
      if (widgetJson == null) {
        updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
        continue;
      }

      // 9) Integrazione logica is_first_time
      if (!widgetJson.containsKey('is_first_time')) {
        widgetJson['is_first_time'] = true;
      } else if (widgetJson['is_first_time'] == true) {
        widgetJson['is_first_time'] = false;
      }

      // 10) Genera un _id univoco e placeholder
      final widgetUniqueId = uuid.v4();
      final placeholder = "[WIDGET_PLACEHOLDER_$widgetCounter]";

      // 11) Aggiunge alla lista
      widgetList.add({
        "_id": widgetUniqueId,
        "widgetId": widgetId,
        "jsonData": widgetJson,
        "placeholder": placeholder,
      });

      // 12) Sostituisce il blocco nel testo
      updatedText = updatedText.replaceRange(
        startIndex,
        endIndex + 1,
        placeholder,
      );

      widgetCounter++;
    }

    return ParsedWidgetResult(updatedText, widgetList);
  }

// 🔹 Helper: configura una chain di default se ne manca una
  Future<void> _ensureDefaultChainConfigured() async {
    // se c’è già una chain attiva usciamo subito
    print('$_latestChainId - $_latestChainId');
    if (_latestChainId != null && _latestChainId!.isNotEmpty) return;

    // modello di default
    const String _defaultModel = 'gpt-4o';

    try {
      // nessun contesto = []   →   chiama già la tua API
      set_context([], _defaultModel);

      // Aggiorna lo stato locale per coerenza UI
      setState(() {
        _selectedContexts = [];
        _selectedModel = _defaultModel;
      });

      debugPrint('[init] Default chain creata con modello $_defaultModel');
    } catch (e) {
      debugPrint('[init] Errore creazione default-chain: $e');
    }
  }

  String _getCurrentChatId() {
    if (_activeChatIndex != null && _chatHistory.isNotEmpty) {
      return _chatHistory[_activeChatIndex!]['id'] as String;
    }
    return "";
  }

// Mappa di funzioni: un widget ID -> funzione che crea il Widget corrispondente
  Map<
          String,
          Widget Function(
              Map<String, dynamic> data, void Function(String) onReply)>
      get widgetMap {
    return {
      "FileUploadWidget": (data, onReply) =>
    FileUploadWidget(
      info: FileUploadInfo.fromJson(data),
      onDownload: () {
        final fPath =
          "${data['ctxPath']}/${data['fileName']}";
        _apiSdk.downloadFile(fPath, token: widget.token.accessToken);
      },
    ),
      "ToolEventWidget": (data, onReply) =>
    ToolEventCard(data: data),      // non serve onReply qui
      "JSRunnerWidget": (data, onReply) => JSRunnerWidgetTool(jsonData: data),
      "AutoSequenceWidget": (data, onReply) =>
          AutoSequenceWidgetTool(jsonData: data, onReply: onReply),
      "NButtonWidget": (data, onReply) =>
          NButtonWidget(data: data, onReply: onReply),
      "RadarChart": (data, onReply) =>
          RadarChartWidgetTool(jsonData: data, onReply: onReply),
      "TradingViewAdvancedChart": (data, onReply) =>
          TradingViewAdvancedChartWidget(jsonData: data, onReply: onReply),
      "TradingViewMarketOverview": (data, onReply) =>
          TradingViewMarketOverviewWidget(jsonData: data, onReply: onReply),
      "CustomChartWidget": (data, onReply) =>
          CustomChartWidgetTool(jsonData: data, onReply: onReply),
      "ChangeChatNameWidget": (data, onReply) => ChangeChatNameWidgetTool(
            jsonData: data,
            // Modifica qui il callback onRenameChat per usare _getCurrentChatId se chatId risulta vuoto
            onRenameChat: (chatId, newName) async {
              // Se il chatId passato è vuoto, usiamo il metodo _getCurrentChatId
              final effectiveChatId =
                  chatId.isEmpty ? await _getCurrentChatId() : chatId;

              if (effectiveChatId.isNotEmpty) {
                await _renameChat(effectiveChatId, newName);
                // Puoi eventualmente chiamare onReply per dare feedback all'utente
                print('Chat renamed to "$newName"');
              } else {
                // Gestione dell'errore: nessuna chat selezionata
                print('Errore: nessuna chat selezionata');
              }
            },
            getCurrentChatId: () async => _getCurrentChatId(),
          ),
      "SpinnerPlaceholder": (data, onReply) => const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Caricamento in corso..."),
                SizedBox(width: 8),
                CircularProgressIndicator(),
              ],
            ),
          ),
    };
  }

    Future<void> _downloadDocumentsJson(
      String collection, String baseFileName) async {
    // 1) scarica i documenti
    final docs = await _apiSdk.listDocuments(collection, token: widget.token.accessToken);

    // 2) serializza con indentazione
    final jsonStr = const JsonEncoder.withIndent('  ').convert(
      docs
          .map((d) => {
                'page_content': d.pageContent,
                'metadata': d.metadata,
                'type': d.type,
              })
          .toList(),
    );

    // 3) disponibile solo per Web
    if (!kIsWeb) {
      throw UnsupportedError('Download JSON supportato solo su Web');
    }

    final blob = html.Blob([jsonStr], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${baseFileName}_docs.json');
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
  }
  
    String _collectionNameFrom(Map<String, dynamic> file) {
    final raw = file['name'] ?? '';
    // es.: "ctx/filename.pdf"  →  "ctxfilename.pdf_collection"
    return raw.replaceAll('/', '') + '_collection';
  }

  void _showFilePreviewDialog(Map<String, dynamic> file, String fileName) {
    final collection = _collectionNameFrom(file);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

          // ──────────────────────────────────────────────────────
          // ⬆️  TITOLO + PULSANTE DOWNLOAD JSON A DESTRA
          // ──────────────────────────────────────────────────────
          title: Row(
            children: [
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Scarica JSON documenti',
                icon: const Icon(Icons.download),
                onPressed: () => _downloadDocumentsJson(collection, fileName),
              ),
            ],
          ),

          // ──────────────────────────────────────────────────────
          //  Contenuto: lista documenti (scrollabile)
          // ──────────────────────────────────────────────────────
          content: FutureBuilder<List<DocumentModel>>(
            future: _apiSdk.listDocuments(collection, token: widget.token.accessToken),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 300,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('Errore caricamento documenti: ${snap.error}');
              }

              final jsonStr = const JsonEncoder.withIndent('  ').convert(
                snap.data!
                    .map((d) => {
                          'page_content': d.pageContent,
                          'metadata': d.metadata,
                          'type': d.type,
                        })
                    .toList(),
              );

              return Container(
                width: 400,
                height: 400,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Chiudi'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
  Widget _buildMixedContent(Map<String, dynamic> message) {
    // Se il messaggio non contiene nessuna lista di widget, rendiamo il testo direttamente

    // messaggio "speciale" di upload file
if (message.containsKey('fileUpload')) {
  final info = FileUploadInfo.fromJson(
      (message['fileUpload'] as Map).cast<String,dynamic>());
  return FileUploadWidget(
    info: info,
    onDownload: () {
      final fPath =
        "${widget.user.username}-${info.ctxPath}/${info.fileName}";
      _apiSdk.downloadFile(fPath,
                           token: widget.token.accessToken);
    },
      onViewDocs: () {
    // ri-usa lo stesso dialog che hai nella ContextPage
    _showFilePreviewDialog(
      {
        'name' : "${widget.user.username}-${info.ctxPath}/${info.fileName}",
        'path' : "${widget.user.username}-${info.ctxPath}/${info.fileName}",
        'custom_metadata': {'file_uuid': info.jobId}
      },
      info.fileName,
    );
  },
  );
}

    final widgetDataList = message['widgetDataList'] as List<dynamic>?;
    if (widgetDataList == null || widgetDataList.isEmpty) {
      final isUser = (message['role'] == 'user');
      return _buildMessageContent(
        context,
        message['content'] ?? '',
        isUser,
        userMessageColor: Colors.white,
        assistantMessageColor: Colors.white,
      );
    }

    // Costante per lo spinner
    const spinnerPlaceholder = "[WIDGET_SPINNER]";

    // Otteniamo il testo completo “pulito” (con i placeholder) dal messaggio
    final textContent = message['content'] ?? '';

    // Ordiniamo i widgetData in base al nome/numero del placeholder
    widgetDataList.sort((a, b) {
      final pa = a['placeholder'] as String;
      final pb = b['placeholder'] as String;
      return pa.compareTo(pb);
    });

    // Costruiamo un array di segmenti di testo o "placeholder"
    final segments = <_Segment>[];
    String temp = textContent;

    while (true) {
      // Troviamo il placeholder che compare prima nel testo
      int foundPos = temp.length;
      String foundPh = "";
      for (final w in widgetDataList) {
        final ph = w['placeholder'] as String;
        final idx = temp.indexOf(ph);
        if (idx != -1 && idx < foundPos) {
          foundPos = idx;
          foundPh = ph;
        }
      }

      if (foundPos == temp.length) {
        // Nessun placeholder trovato
        if (temp.isNotEmpty) {
          segments.add(_Segment(text: temp));
        }
        break;
      }

      // Aggiungiamo l’eventuale testo prima del placeholder
      if (foundPos > 0) {
        final beforeText = temp.substring(0, foundPos);
        segments.add(_Segment(text: beforeText));
      }

      // Aggiungiamo il placeholder come segment
      segments.add(_Segment(placeholder: foundPh));

      // Rimuoviamo la parte elaborata
      temp = temp.substring(foundPos + foundPh.length);
    }

    // Ora costruiamo i widget finali
    final contentWidgets = <Widget>[];

    for (final seg in segments) {
      // Se non è un placeholder (testo normale)
      if (seg.placeholder == null) {
        final isUser = (message['role'] == 'user');
        if (seg.text != null && seg.text!.isNotEmpty) {
          contentWidgets.add(
            _buildMessageContent(
              context,
              seg.text!,
              isUser,
              userMessageColor: Colors.white,
              assistantMessageColor: Colors.white,
            ),
          );
        }
      }
      // Altrimenti, è un placeholder
      else {
        final ph = seg.placeholder!;

        // (1) Se è lo spinner "[WIDGET_SPINNER]", mostriamo la rotella di caricamento
        if (ph == spinnerPlaceholder) {
          contentWidgets.add(
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Caricamento in corso..."),
                  const SizedBox(width: 8),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // (2) Altrimenti, potrebbe essere un segnaposto di un widget reale
        else {
          // Cerchiamo i dati del widget corrispondente
          final wdata =
              widgetDataList.firstWhere((x) => x['placeholder'] == ph);
          final widgetUniqueId = wdata['_id'] as String;
          final widgetId = wdata['widgetId'] as String;
          final jsonData = wdata['jsonData'] as Map<String, dynamic>? ?? {};

          // Verifichiamo se abbiamo già un widget in cache
          Widget? embeddedWidget = _widgetCache[widgetUniqueId];
          if (embeddedWidget == null) {
            // Creiamo il widget adesso
            final widgetBuilder = widgetMap[widgetId];
            if (widgetBuilder != null) {
              embeddedWidget =
                  widgetBuilder(jsonData, (reply) => _handleUserInput(reply));
            } else {
              embeddedWidget = Text("Widget sconosciuto: $widgetId");
            }
            _widgetCache[widgetUniqueId] = embeddedWidget;
          }

          // Inseriamo il widget, centrato orizzontalmente
          contentWidgets.add(
            Container(
              width: double.infinity,
              child: Align(
                alignment: Alignment.center,
                child: embeddedWidget,
              ),
            ),
          );
        }
      }
    }

    // Restituiamo i widget sotto forma di colonna
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  Future<void> _loadConfig() async {
    try {
      //final String response = await rootBundle.loadString('assets/config.json');
      //final data = jsonDecode(response);
      final data = {
        "backend_api": "https://teatek-llm.theia-innovation.com/user-backend",
        "nlp_api": "https://teatek-llm.theia-innovation.com/llm-core",
        //"nlp_api": "http://35.195.200.211:8100",
        "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
        //"chatbot_nlp_api": "http://127.0.0.1:8000"
      };
      _nlpApiUrl = data['chatbot_nlp_api'];
    } catch (e) {
      print("Errore nel caricamento del file di configurazione: $e");
    }
  }

  Future<void> _animateChatNameChange(int index, String finalName) async {
    String currentName = "";
    int charIndex = 0;
    const duration = Duration(milliseconds: 100);
    final completer = Completer<void>();

    Timer.periodic(duration, (timer) {
      if (charIndex < finalName.length) {
        currentName += finalName[charIndex];
        setState(() {
          _chatHistory[index]['name'] = currentName;
        });
        charIndex++;
      } else {
        timer.cancel();
        completer.complete();
      }
    });

    return completer.future;
  }

// Funzione di logout
  // Funzione di logout aggiornata
  
  Future<void> _logout(BuildContext context) async {
    setState(() {
      isLoggingOut = true;
    });

    // 1) Leggi il tipo di login da localStorage
    final authMethod = html.window.localStorage['auth_method'];

    // 2) Se era "azure", fai prima il logout federato
    if (authMethod == 'azure') {
      try {
        await _apiClient.performAzureLogout();
        // Se il redirect riesce, il browser verrà spostato su AzureAD → Cognito → SPA.
        // Non verrà eseguito il codice seguente, perché la pagina cambierà.
        return;
      } catch (e) {
        // Se qualcosa va storto, rimuovi comunque i dati locali e rimaniamo nella UI
        html.window.localStorage.remove('token');
        html.window.localStorage.remove('user');
        html.window.localStorage.remove('auth_method');
        setState(() {
          isLoggingOut = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il logout federato: $e')),
        );
        return;
      }
    }

    // 3) Altrimenti (login "standard"), rimuovi semplicemente i token e naviga su /login
    html.window.localStorage.remove('token');
    html.window.localStorage.remove('refreshToken');
    html.window.localStorage.remove('user');
    html.window.localStorage.remove('auth_method');

    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadChatHistory() async {
    try {
      // Definisci il nome del database e della collection
      final dbName = "${widget.user.username}-database";
      final collectionName = 'chats';

      print('chats:');

      // Carica le chat dalla collection 'chats' nel database
      final chats = await _databaseService.fetchCollectionData(
        dbName,
        collectionName,
        widget.token.accessToken,
      );

      print('$chats');

      if (chats.isNotEmpty) {
        // Ordina le chat in base al campo 'updatedAt' (dalla più recente alla meno recente)
        chats.sort((a, b) {
          final updatedAtA = DateTime.parse(a['updatedAt'] as String);
          final updatedAtB = DateTime.parse(b['updatedAt'] as String);
          return updatedAtB.compareTo(updatedAtA); // Ordinamento discendente
        });

        // Aggiorna lo stato locale con la lista ordinata di chat
        setState(() {
          _chatHistory = chats;
        });

        print('Chat history loaded and sorted from database: $_chatHistory');
      } else {
        print('No chat history found in the database.');
      }
    } catch (e) {
      // Gestisci gli errori di accesso al database, inclusi errori 403 (collection non trovata)
      if (e.toString().contains('403')) {
        print("Collection 'chats' does not exist. Creating the collection...");

        // Crea la collection 'chats' se non esiste
        await _databaseService.createCollection(
            "${widget.user.username}-database",
            'chats',
            widget.token.accessToken);

        // Imposta lo stato locale per indicare che non ci sono chat
        setState(() {
          _chatHistory = [];
        });

        print(
            "Collection 'chats' created successfully. No previous chat history found.");
      } else {
        // Log degli altri errori
        print("Error loading chat history from database: $e");
      }
    }
  }

  late Future<void> _chatHistoryFuture;
@override
void initState() {
  super.initState();
  _initStateAsync();                 // parte subito ma resta fuori dal build
}

// helper “completo” (può usare await senza problemi)
Future<void> _initStateAsync() async {
  // ────────────────────────────────────────────────────────────────────
  // ① bootstrap: config + contesti
  // ────────────────────────────────────────────────────────────────────
  await _bootstrap();

  // ────────────────────────────────────────────────────────────────────
  // ② prepara una chain “vuota” legata alla chat corrente
  // ────────────────────────────────────────────────────────────────────
  await _prepareChainForCurrentChat();

  // ────────────────────────────────────────────────────────────────────
  // ③ notifiche & inizializzazioni varie
  // ────────────────────────────────────────────────────────────────────
  _initTaskNotifications();
  _speech     = stt.SpeechToText();
  _flutterTts = FlutterTts();

  // ────────────────────────────────────────────────────────────────────
  // ④ carica *e aspetta* la chat-history
  // ────────────────────────────────────────────────────────────────────
  _chatHistoryFuture = _loadChatHistory();
  await _chatHistoryFuture;              // ← attesa effettiva

  // ────────────────────────────────────────────────────────────────────
  // ⑤ listener & scroll
  // ────────────────────────────────────────────────────────────────────
  _controller.addListener(() => setState(() {}));

  _messagesScrollController.addListener(() {
    final maxScroll     = _messagesScrollController.position.maxScrollExtent;
    final currentScroll = _messagesScrollController.position.pixels;
    final shouldShow    = currentScroll < maxScroll - 20;
    final scrolledDown  = currentScroll > _lastScrollPosition + 50;
    _lastScrollPosition = currentScroll;
    final newValue      = shouldShow && !scrolledDown;
    if (newValue != _showScrollToBottomButton) {
      setState(() => _showScrollToBottomButton = newValue);
    }
  });

  // ────────────────────────────────────────────────────────────────────
  // ⑥ crea (o verifica) il DB – **attendi** prima di sbloccare la UI
  // ────────────────────────────────────────────────────────────────────
  await _databaseService.createDatabase('database', widget.token.accessToken);

  // ────────────────────────────────────────────────────────────────────
  // ⑦ ripristina eventuali ID di chain salvati in precedenza
  // ────────────────────────────────────────────────────────────────────
  _latestChainId  = html.window.localStorage['latestChainId'];
  _latestConfigId = html.window.localStorage['latestConfigId'];

  // ────────────────────────────────────────────────────────────────────
  // ⑧ tutto pronto → alza il flag (solo se il widget è ancora montato)
  // ────────────────────────────────────────────────────────────────────
  if (mounted) setState(() => _appReady = true);
}

// ─────────────────────────────────────────────────────────────────────────────
// 2.  _bootstrap  ➜  solo pre-caricamenti “leggeri”
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _bootstrap() async {
  await _loadConfig();
  await _loadAvailableContexts();
}


  /*@override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();  // Inizializza FlutterTTS
    _loadAvailableContexts();  // Carica i contesti esistenti al caricamento della pagina
      _loadChatHistory();  // Carica la chat history simulata
  }*/

// ──────────────────────────────────────────────────────────────────
// Carica (o ricarica) tutti i contesti disponibili dal backend.
// Manteniamo la *stessa* istanza di `_availableContexts` in modo che
// i widget già montati (es. il dialog di selezione) vedano subito
// l’aggiornamento senza dover essere ri-creati.
// ──────────────────────────────────────────────────────────────────
bool _isCtxLoading = false;            // evita fetch concorrenti

Future<void> _loadAvailableContexts() async {
  if (_isCtxLoading) return;           // già in corso
  _isCtxLoading = true;

  try {
    final ctx = await _contextApiSdk.listContexts(
      widget.user.username,
      widget.token.accessToken,
    );

    // aggiorniamo dentro `setState`, MA senza sostituire la lista
    setState(() {
      _availableContexts          // stessa List, nuovi elementi
        ..clear()
        ..addAll(ctx);
    });
  } catch (e, st) {
    debugPrint('[contexts] errore: $e\n$st');
  } finally {
    _isCtxLoading = false;
  }
}


  // Funzione per aprire il dialog con il ColorPicker
  void _showColorPickerDialog(
      Color currentColor, Function(Color) onColorChanged) {
    final localizations = LocalizationProvider.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona il colore'),
          backgroundColor: Colors.white, // Sfondo del popup
          elevation: 6, // Intensità dell'ombra
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8), // Arrotondamento degli angoli
            //side: BorderSide(
            //  color: Colors.blue, // Colore del bordo
            //  width: 2, // Spessore del bordo
            //),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                setState(() {
                  onColorChanged(color);
                });
              },
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text(localizations.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

// Funzione che restituisce il widget per il messaggio Markdown, con formattazione avanzata
  Widget _buildMessageContent(
    BuildContext context,
    String content,
    bool isUser, {
    Color? userMessageColor,
    double? userMessageOpacity,
    Color? assistantMessageColor,
    double? assistantMessageOpacity,
  }) {
    // Definisce il colore di sfondo in base al ruolo del mittente
    final bgColor = isUser
        ? (userMessageColor ?? Colors.blue[100])!
            .withOpacity(userMessageOpacity ?? 1.0)
        : (assistantMessageColor ?? Colors.grey[200])!
            .withOpacity(assistantMessageOpacity ?? 1.0);

    //final bgColor = Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: MarkdownBody(
        extensionSet: md.ExtensionSet.gitHubWeb,
        selectable: true,
        data: content,
        // Inserisci il builder personalizzato per i blocchi di codice
        builders: {
          'code': CodeBlockBuilder(context),
          'table':ScrollableTableBuilder(onDownload: _downloadCsv),
 
        },
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16.0, color: Colors.black87),
          h1: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
          h3: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
          // Lo stile 'code' qui è usato per il rendering base (verrà sovrascritto dal nostro builder)
          code: TextStyle(
            fontFamily: 'Courier',
            backgroundColor: Colors.grey[300],
            fontSize: 14.0,
          ),
          blockquote: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.blueGrey,
            fontSize: 14.0,
          ),
        ),
        // Gestione opzionale del tap sui link
        onTapLink: (text, href, title) async {
          if (href != null && await canLaunch(href)) {
            await launch(href);
          }
        },
      ),
    );
  }

  void _showMessageInfoDialog(Map<String, dynamic> message) {
    final localizations = LocalizationProvider.of(context);
    final String role = message['role'] ?? 'unknown'; // Ruolo del messaggio
    final String createdAt = message['createdAt'] ?? 'N/A'; // Data di creazione
    final int contentLength =
        (message['content'] ?? '').length; // Lunghezza contenuto

    // Estrai la configurazione dell'agente dal messaggio, se presente
    final Map<String, dynamic>? agentConfig = message['agentConfig'];

    // Informazioni di configurazione dell'agente
    final String? model = agentConfig?['model']; // Modello selezionato
    final List<String>? contexts =
        List<String>.from(agentConfig?['contexts'] ?? []);
    final String? chainId = agentConfig?['chain_id'];

    // Altri dettagli (aggiustabili secondo il caso)
    final int tokensReceived =
        role == 'assistant' ? 0 : 0; // Modifica se disponi di dati token reali
    final int tokensGenerated =
        role == 'assistant' ? 0 : 0; // Modifica se disponi di dati token reali
    final double responseCost =
        role == 'assistant' ? 0.0 : 0.0; // Modifica se disponi di dati reali

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.message_details),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dettagli di base del messaggio
                Text(
                  "${localizations.roleLabel} ${role == 'user' ? localizations.userRole : localizations.assistantRole}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("${localizations.dateLabel} $createdAt"),
                Text("${localizations.charLength} $contentLength"),
                Text(
                    "${localizations.tokenLength} 0"), // Sostituisci se disponi di dati token

                // Divider per separare i dettagli base dai dettagli di configurazione
                if (role == 'assistant' || agentConfig != null) ...[
                  const Divider(),
                  Text(localizations.agentConfigDetails,
                      style: TextStyle(fontWeight: FontWeight.bold)),

                  // Mostra il modello selezionato
                  if (model != null) Text("${localizations.modelLabel} $model"),
                  const SizedBox(height: 8),

                  // Mostra i contesti utilizzati
                  if (contexts != null && contexts.isNotEmpty) ...[
                    Text(localizations.selectedContextsLabel,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...contexts.map((context) => Text("- $context")).toList(),
                  ],

                  const SizedBox(height: 8),

                  // Mostra l'ID della chain
                  if (chainId != null)
                    Text("${localizations.chainIdLabel} $chainId"),

                  // Divider aggiuntivo per eventuali altri dettagli
                  const Divider(),
                  Text(localizations.additionalMetrics,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${localizations.tokensGenerated} $tokensReceived"),
                  Text("${localizations.tokensReceived} $tokensGenerated"),
                  Text(
                      "${localizations.responseCost} \$${responseCost.toStringAsFixed(4)}"),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Chiudi il dialog
                },
                child: Text(localizations.close)),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _getDateSeparator(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));
    if (_isSameDay(date, today)) {
      return "Today";
    } else if (_isSameDay(date, yesterday)) {
      return "Yesterday";
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  List<Widget> _buildMessagesList(double containerWidth) {
    final localizations = LocalizationProvider.of(context);
    List<Widget> widgets = [];
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final bool isUser = (message['role'] == 'user');
      final DateTime parsedTime =
          DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
      final String formattedTime = DateFormat('h:mm a').format(parsedTime);

      // Se è il primo messaggio o se la data del messaggio corrente è diversa da quella del precedente,
      // aggiungi un separatore.
      if (i == 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                _getDateSeparator(parsedTime),
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      } else {
        final DateTime previousTime =
            DateTime.tryParse(messages[i - 1]['createdAt'] ?? '') ?? parsedTime;
        if (!_isSameDay(parsedTime, previousTime)) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  _getDateSeparator(parsedTime),
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }
      }

      // Aggiungi il widget del messaggio (codice originale invariato)
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: containerWidth,
                  minWidth: 200,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4.0,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RIGA 1: Avatar, nome e orario
                      Row(
                        children: [
                          if (!isUser)
                            CircleAvatar(
                              backgroundColor: Colors.transparent,
                              child: assistantAvatar,
                            )
                          else
                            CircleAvatar(
                              backgroundColor: _avatarBackgroundColor
                                  .withOpacity(_avatarBackgroundOpacity),
                              child: Icon(
                                Icons.person,
                                color: _avatarIconColor
                                    .withOpacity(_avatarIconOpacity),
                              ),
                            ),
                          const SizedBox(width: 8.0),
                          Text(
                            isUser ? widget.user.username : assistantName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const VerticalDivider(
                            thickness: 1,
                            color: Colors.black,
                            width: 4,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedTime,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      // RIGA 2: Contenuto del messaggio (Markdown)
                      _buildMixedContent(message),
                      const SizedBox(height: 8.0),
                      // RIGA 3: Icone (copia, feedback, TTS, info)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            tooltip: localizations.copy,
                            onPressed: () {
                              _copyToClipboard(message['content'] ?? '');
                            },
                          ),
                          if (!isUser) ...[
                            IconButton(
                              icon: const Icon(Icons.thumb_up, size: 14),
                              tooltip: localizations.positive_feedback,
                              onPressed: () {
                                print(
                                    "Feedback positivo per il messaggio: ${message['content']}");
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_down, size: 14),
                              tooltip: localizations.negative_feedback,
                              onPressed: () {
                                print(
                                    "Feedback negativo per il messaggio: ${message['content']}");
                              },
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 14),
                            tooltip: localizations.volume,
                            onPressed: () {
                              _speak(message['content'] ?? '');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 14),
                            tooltip: localizations.messageInfoTitle,
                            onPressed: () {
                              _showMessageInfoDialog(message);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _archiveChat(int index) async {
    final localizations = LocalizationProvider.of(context);
    final chatToArchive = _chatHistory[index];
    final dbName = "${widget.user.username}-database";
    final token = widget.token.accessToken;

    try {
      // 1.‑ assicura che la collezione di archivio esista (se c’è già l’eccezione viene ignorata)
      await _databaseService
          .createCollection(dbName, kArchiveCollection, token)
          .catchError((_) {});

      // 2.‑ inserisci la chat in 'archived_chats'
      await _databaseService.addDataToCollection(
        dbName,
        kArchiveCollection,
        chatToArchive,
        token,
      );

      // 3.‑ rimuovi la chat da 'chats'
      if (chatToArchive.containsKey('_id')) {
        await _databaseService.deleteCollectionData(
          dbName,
          'chats',
          chatToArchive['_id'],
          token,
        );
      }

      // 4.‑ aggiorna stato locale + localStorage
      setState(() => _chatHistory.removeAt(index));
      html.window.localStorage['chatHistory'] =
          jsonEncode({'chatHistory': _chatHistory});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.chat_archived)),
      );
    } catch (e) {
      print("Errore archiviazione chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.genericError)),
      );
    }
  }





// ——————————————————————————————————————————
//  NOTIFICHE TASK
// ——————————————————————————————————————————
OverlayEntry? _notifOverlay;
Timer? _notifPoller;

Future<void> _initTaskNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  final raw   = prefs.getString('kb_pending_jobs');
  if (raw == null) return;

  final Map<String, dynamic> stored = jsonDecode(raw);

  stored.forEach((String jobId, dynamic j) {
    final ctx      = j['contextPath'] ?? 'unknown_ctx';
    final fileName = j['fileName']    ?? 'file';

    // — migration: se chatId non esiste, lo ricaviamo dal chatHistory
    final String chatId = j['chatId'] ?? _findChatIdForJob(jobId);

    // display-name (se _availableContexts è già popolato)
    final displayName = _availableContexts
        .firstWhere(
          (c) => c.path == ctx,
          orElse: () => ContextMetadata(path: ctx, customMetadata: const {}),
        )
        .customMetadata?['display_name'] as String? ??
        ctx;

    // notifica overlay
    _taskNotifications[jobId] = TaskNotification(
      jobId      : jobId,
      contextPath: ctx,
      contextName: displayName,
      fileName   : fileName,
      stage      : TaskStage.pending,
    );

    // pending-job per il poller
    if (j['tasksPerCtx'] != null) {
      _pendingJobs[jobId] = PendingUploadJob(
        jobId      : jobId,
        chatId     : chatId,
        contextPath: ctx,
        fileName   : fileName,
        tasksPerCtx: (j['tasksPerCtx'] as Map).map(
          (k, v) => MapEntry(k, TaskIdsPerContext.fromJson(v)),
        ),
      );
    }
  });

  await _savePendingJobs(_pendingJobs);
  
}

/// Se non troviamo la chat, restituiamo stringa vuota
String _findChatIdForJob(String jobId) {
  for (final chat in _chatHistory) {
    for (final m in (chat['messages'] as List)) {
      final fu = m['fileUpload'] as Map<String, dynamic>?;
      if (fu != null && fu['jobId'] == jobId) return chat['id'];
    }
  }
  return '';
}

// ────────────────────────────────────────────────────────────────────────────
//  OVERLAY + POLLER (ogni 3 s)
// ────────────────────────────────────────────────────────────────────────────
void _startNotifOverlay() {
  _notifOverlay ??= _buildOverlay();
  Overlay.of(context, rootOverlay: true)!.insert(_notifOverlay!);

  _notifPoller = Timer.periodic(const Duration(seconds: 3), (_) async {

    if (_taskNotifications.isEmpty) return;

          if (_pendingJobs.isEmpty) {
    _notifPoller?.cancel();
    _notifPoller = null;
    return;                       // niente GET se non c’è nulla da controllare
  }
  

    /* 1 ── chiedi lo stato di tutti i task ancora attivi */
    final allTaskIds =
        _pendingJobs.values.expand((j) => j.tasksPerCtx.values);
    final statusResp = await _apiSdk.getTasksStatus(allTaskIds);

  // <<< QUI: log di tutti i task-id con lo stato grezzo e la mappatura >>>
  statusResp.statuses.forEach((tid, st) {
    debugPrint('$tid  -> ${st.status}  => ${_mapStatus(st.status)}');
  });
  
    /* 2 ── chat da salvare perché almeno un msg ha cambiato stato */
    final Set<String> finishedChatIds = {};

    /* 3 ── loop su ogni task-id restituito */
    statusResp.statuses.forEach((tid, st) {
// ✅ nuovo
final jobEntry = _pendingJobs.entries.firstWhereOrNull(
  (e) => e.value.tasksPerCtx.values.any(
        (t) => t.loaderTaskId == tid || t.vectorTaskId == tid),
);

if (jobEntry == null) return;   // nessun job corrispondente ⇒ ignora
      final String jobId  = jobEntry.key;
      final job           = jobEntry.value;
      final String chatId = job.chatId;                 // può essere vuoto
      final bool   hasChat = chatId.isNotEmpty;         // <── NOVITÀ

      final newStage = _mapStatus(st.status);

// ▼▼▼ BLOCCO A ▼▼▼  (pulisce job/task risolti)
if (newStage == TaskStage.done || newStage == TaskStage.error) {
  // 1. togli questo taskId dal job
  job.tasksPerCtx.removeWhere((ctx, t) =>
      t.loaderTaskId == tid || t.vectorTaskId == tid);

  // 2. se non resta alcun task attivo → rimuovi l’intero job
  final allResolved = job.tasksPerCtx.values.every((t) =>
      t.loaderTaskId == null && t.vectorTaskId == null);

  if (allResolved) {
    _pendingJobs.remove(jobId);
    // facoltativo: chiudi anche la card
    //_dismissNotification(jobId);
  }
}

      // 3-a  ► card overlay (sempre presente)
      final notif = _taskNotifications[jobId];
      if (notif != null) {
        notif.stage = newStage;
        if (!notif.isVisible &&
            (newStage == TaskStage.done || newStage == TaskStage.error)) {
          notif.isVisible = true;
        }
      }

      // 3-b  ► chat correntemente aperta (solo se esiste)
      if (hasChat &&
          _activeChatIndex != null &&
          _chatHistory[_activeChatIndex!]['id'] == chatId) {
        for (final m in messages) {
          final fu = m['fileUpload'] as Map<String, dynamic>?;
          if (fu != null &&
              fu['jobId'] == jobId &&
              fu['stage'] != newStage.name) {
            fu['stage'] = newStage.name;
          }
        }
      }

      // 3-c  ► chat proprietaria dentro _chatHistory (solo se esiste)
      if (hasChat) {
        final chat = _chatHistory.firstWhere(
          (c) => c['id'] == chatId,
          orElse: () => null,
        );
        if (chat != null) {
          bool changed = false;
          for (final m in (chat['messages'] as List)) {
            final fu = m['fileUpload'] as Map<String, dynamic>?;
            if (fu != null &&
                fu['jobId'] == jobId &&
                fu['stage'] != newStage.name) {
              fu['stage'] = newStage.name;
              changed = true;
            }
          }
          if (changed &&
              (newStage == TaskStage.done || newStage == TaskStage.error)) {
            chat['updatedAt'] = DateTime.now().toIso8601String();
            finishedChatIds.add(chatId);
          }
          if (changed && newStage == TaskStage.done) {
  // la loader-task è conclusa con successo →
  _reconfigureChainIfNeeded(chatId);       // <── nuovo helper
}
        }
      }
    });

    /* 4 ── refresh UI */
    setState(() {});
    _refreshNotifOverlay();

    /* 5 ── persistenza SOLO delle chat realmente toccate */
    if (finishedChatIds.isNotEmpty) {
      // localStorage
      html.window.localStorage['chatHistory'] =
          jsonEncode({'chatHistory': _chatHistory});

      // database
      for (final chat in _chatHistory) {
        if (finishedChatIds.contains(chat['id']) && chat.containsKey('_id')) {
          await _databaseService.updateCollectionData(
            "${widget.user.username}-database",
            'chats',
            chat['_id'],
            {
              'updatedAt': chat['updatedAt'],
              'messages' : chat['messages'],
            },
            widget.token.accessToken,
          ).catchError((_) {}); // race-condition: ignora
        }
      }
    }

    /* 6 ── salva lo stato dei job ancora pendenti */
    _savePendingJobs(_pendingJobs);

    /* 7 ── auto-dismiss card concluse */
    _taskNotifications.values
        .where((n) =>
            n.isVisible &&
            (n.stage == TaskStage.done || n.stage == TaskStage.error))
        .forEach((n) {
      Future.delayed(
        const Duration(seconds: 10),
        () => _dismissNotification(n.jobId),
      );
    });
  });
}




/// Chiude (o rimuove) la card di notifica.
///
/// • Se lo stato è **DONE/ERROR** la elimina per sempre.
/// • Se è ancora PENDING/RUNNING la nasconde soltanto: potrà ri-apparire
///   alla transizione di stato (vedi punto 2).
void _dismissNotification(String jobId) {
  final notif = _taskNotifications[jobId];
  if (notif == null) return;

  // ── A.  DONE / ERROR  →  rimozione permanente ──────────────────────────
  final permanentlyRemove =
      notif.stage == TaskStage.done || notif.stage == TaskStage.error;
  if (permanentlyRemove) {
    _taskNotifications.remove(jobId);
  } else {
    notif.isVisible = false;   // solo nascosta (potrà ri-apparire)
  }

  setState(() {});             // refresh locale
  _refreshNotifOverlay();      // refresh (o chiusura) overlay

  // ── B.  decidiamo se interrompere il poller ────────────────────────────
  // se restano job PENDING/RUNNING (anche se invisibili) il poller deve
  // restare vivo.
  final stillActive = _taskNotifications.values.any((n) =>
      n.stage == TaskStage.pending || n.stage == TaskStage.running);

  if (!stillActive) {
    // tutti i job ormai sono DONE/ERROR e le card sono state nascoste o rimosse
    _notifPoller?.cancel();
    _notifPoller = null;
  }
}


bool _noCardIsVisible() =>
    _taskNotifications.values.every((n) => !n.isVisible);


void _removeOverlay() {
  _notifOverlay?.remove();
  _notifOverlay = null;
  // (il poller viene eventualmente fermato da _dismissNotification)
}

@override
void dispose() {
  _notifPoller?.cancel();
  _removeOverlay();
  super.dispose();
}


/// ---------------------------------------------------------------------------
/// OVERLAY con le card di notifica
/// ---------------------------------------------------------------------------
OverlayEntry _buildOverlay() {
  return OverlayEntry(
    builder: (_) => Positioned(
      // subito sotto la Top-Bar (56 px) + eventuale status-bar
      top: MediaQuery.of(context).padding.top + 56 + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(                  // clic “pass-through” tranne la X
        ignoring: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
children: _taskNotifications.values
    .where((n) => n.isVisible && _contextIsKnown(n.contextPath))
    .map(_buildNotifCard)
    .toList(),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildNotifCard(TaskNotification n) {
  // ─────────────────────────────  icona / colore / etichetta per stage
  late final IconData icon;
  late final Color    color;
  late final String   statusLabel;

  switch (n.stage) {
    case TaskStage.pending:
      icon        = Icons.schedule;
      color       = Colors.orange;
      statusLabel = 'In coda…';
      break;
    case TaskStage.running:
      icon        = Icons.sync;
      color       = Colors.blue;
      statusLabel = 'In corso…';
      break;
    case TaskStage.done:
      icon        = Icons.check_circle;
      color       = Colors.green;
      statusLabel = 'Completato!';
      break;
    case TaskStage.error:
      icon        = Icons.error;
      color       = Colors.red;
      statusLabel = 'Errore ❗';
      break;
  }

  // ─────────────────────────────  card vera e propria
  return Dismissible(
    key: ValueKey(n.jobId),                         // ► chiave = jobId
    direction: DismissDirection.endToStart,
    onDismissed: (_) => _dismissNotification(n.jobId),
    child: Card(
      color: Colors.white,
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          n.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KB: ${n.contextName}'),
            Text(statusLabel),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _dismissNotification(n.jobId),
        ),
      ),
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Barra laterale con possibilità di ridimensionamento
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (isExpanded) {
                setState(() {
                  sidebarWidth +=
                      details.delta.dx; // Ridimensiona la barra laterale
                  if (sidebarWidth < 200)
                    sidebarWidth = 200; // Larghezza minima
                  if (sidebarWidth > 900)
                    sidebarWidth = 900; // Larghezza massima
                });
              }
            },
            child: AnimatedContainer(
              margin: EdgeInsets.fromLTRB(isExpanded ? 16.0 : 0.0, 0, 0, 0),
              duration: Duration(
                  milliseconds:
                      300), // Animazione per l'espansione e il collasso
              width:
                  sidebarWidth, // Usa la larghezza calcolata (può essere 0 se collassato)
              decoration: BoxDecoration(
                color:
                    Colors.white, // Colonna laterale con colore personalizzato
                /*boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
        blurRadius: 8.0, // Sfocatura dell'ombra
        offset: Offset(2, 0), // Posizione dell'ombra (x, y)
      ),
    ],*/
              ),
              child: MediaQuery.of(context).size.width < 600 || sidebarWidth > 0
                  ? Column(
                      children: [
                        // Linea di separazione bianca tra AppBar e sidebar
                        Container(
                          width: double.infinity,
                          height: 2.0, // Altezza della linea
                          color: Colors.white, // Colore bianco per la linea
                        ),
                        // Padding verticale tra l'AppBar e le voci del menu
                        SizedBox(
                            height:
                                8.0), // Spazio verticale tra la linea e le voci del menu

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          color: Colors
                              .white, // oppure usa lo stesso colore del menu laterale
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Titolo a sinistra
                              fullLogo,
                              // Icona di espansione/contrazione a destra
                              IconButton(
                                icon: _appReady ? SvgPicture.network(
                                    'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
                                    width: 24,
                                    height: 24,
                                    color: Colors.grey) : const SizedBox(
          width:24, height:24,
          child:CircularProgressIndicator(strokeWidth:2)),
                                onPressed: _appReady ? () {
                                  setState(() {
                                    isExpanded = !isExpanded;
                                    if (isExpanded) {
                                      sidebarWidth = MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600
                                          ? MediaQuery.of(context).size.width
                                          : 300.0;
                                    } else {
                                      sidebarWidth = 0.0;
                                    }
                                  });
                                }: () {},
                              ),
                            ],
                          ),
                        ),

// Sezione fissa con le voci principali

// Pulsante "Cerca"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  99; // un indice qualsiasi per l'hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex = null;
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              // Quando clicco, apro il dialog di ricerca
                              showSearchDialog(
                                context: context,
                                chatHistory: _chatHistory,
                                onNavigateToMessage:
                                    (String chatId, String messageId) {
                                  // Carica la chat corrispondente
                                  _loadMessagesForChat(chatId);
                                  // Se vuoi scrollare al messaggio specifico, puoi salvare
                                  // un "targetMessageId" e poi gestire lo scroll/spostamento
                                  // dopo che i messaggi sono stati caricati.
                                },
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4.0),
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 99
                                    ? const Color.fromARGB(255, 224, 224, 224)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.search,
                                      size: 24.0, color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    localizations.searchButton,
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

// Pulsante "Conversazione"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  0; // Identifica "Conversazione" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeButtonIndex =
                                    0; // Imposta "Conversazione" come attivo
                                showKnowledgeBase =
                                    false; // Deseleziona "Basi di conoscenza"
                                showSettings =
                                    false; // Deseleziona "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              _loadChatHistory(); // Carica la cronologia delle chat
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 0 ||
                                        _activeButtonIndex == 0
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  //Icon(Icons.chat_bubble_outline_outlined,
                                  //    color: Colors.black),
                                  SvgPicture.network(
                                      'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element.svg',
                                      width: 24,
                                      height: 24,
                                      color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    localizations.conversation,
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

// Pulsante "Basi di conoscenza"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  1; // Identifica "Basi di conoscenza" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeButtonIndex =
                                    1; // Imposta "Basi di conoscenza" come attivo
                                showKnowledgeBase =
                                    true; // Mostra "Basi di conoscenza"
                                showSettings =
                                    false; // Deseleziona "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 1 ||
                                        _activeButtonIndex == 1
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  SvgPicture.network(
                                      'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element2.svg',
                                      width: 24,
                                      height: 24,
                                      color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    localizations.knowledgeBoxes,
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

// Lista delle chat salvate
                        Expanded(
                          child: FutureBuilder(
                            future:
                                _chatHistoryFuture, // Assicurati che le chat siano caricate
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }

                              // Raggruppa le chat in base alla data di aggiornamento
                              final groupedChats =
                                  _groupChatsByDate(_chatHistory);

                              // Filtra le sezioni per rimuovere quelle vuote
                              final nonEmptySections = groupedChats.entries
                                  .where((entry) => entry.value.isNotEmpty)
                                  .toList();

                              if (nonEmptySections.isEmpty) {
                                return Center(
                                  child: Text(
                                    localizations.noChatAvailable,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                );
                              }

                              return ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent, // Mantiene opaco
                                        Colors.transparent, // Ancora opaco
                                        Colors
                                            .white, // A partire da qui diventa trasparente
                                      ],
                                      stops: [0.0, 0.75, 1.0],
                                    ).createShader(bounds);
                                  },
                                  // Con dstOut, le parti del gradiente che sono bianche (o trasparenti) "tagliano" via il contenuto
                                  blendMode: BlendMode.dstOut,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                        bottom: 32.0), // Spazio extra in fondo
                                    itemCount: nonEmptySections
                                        .length, // Numero delle sezioni non vuote
                                    itemBuilder: (context, sectionIndex) {
                                      final section =
                                          nonEmptySections[sectionIndex];
                                      final sectionTitle = section
                                          .key; // Ottieni il titolo della sezione
                                      final chatsInSection = section
                                          .value; // Ottieni le chat di quella sezione

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Intestazione della sezione
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0, vertical: 4.0),
                                            child: Text(
                                              sectionTitle, // Titolo della sezione
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          // Lista delle chat di questa sezione
                                          ...chatsInSection.map((chat) {
                                            final chatName = chat['name'] ??
                                                'Chat senza nome'; // Nome della chat
                                            final chatId =
                                                chat['id']; // ID della chat
                                            final isActive = _activeChatIndex ==
                                                _chatHistory.indexOf(
                                                    chat); // Chat attiva
                                            final isHovered = hoveredIndex ==
                                                _chatHistory.indexOf(
                                                    chat); // Chat in hover

                                            return MouseRegion(
                                              onEnter: (_) {
                                                setState(() {
                                                  hoveredIndex =
                                                      _chatHistory.indexOf(
                                                          chat); // Aggiorna hover
                                                });
                                              },
                                              onExit: (_) {
                                                setState(() {
                                                  hoveredIndex =
                                                      null; // Rimuovi hover
                                                });
                                              },
                                              child: GestureDetector(
                                                onTap: () {
                                                  _loadMessagesForChat(
                                                      chatId); // Carica messaggi della chat
                                                  setState(() {
                                                    _activeChatIndex =
                                                        _chatHistory.indexOf(
                                                            chat); // Imposta la chat attiva
                                                    _activeButtonIndex =
                                                        null; // Deseleziona i pulsanti principali
                                                    showKnowledgeBase =
                                                        false; // Deseleziona "Basi di conoscenza"
                                                    showSettings =
                                                        false; // Deseleziona "Impostazioni"
                                                  });
                                                  if (MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      600) {
                                                    sidebarWidth =
                                                        0.0; // Collassa barra laterale
                                                  }
                                                },
                                                child: Container(
                                                  height: 40,
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical:
                                                          2), // Margini laterali
                                                  decoration: BoxDecoration(
                                                    color: isHovered || isActive
                                                        ? const Color.fromARGB(
                                                            255,
                                                            224,
                                                            224,
                                                            224) // Colore scuro per hover o selezione
                                                        : Colors
                                                            .transparent, // Sfondo trasparente quando non attivo
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4.0), // Arrotonda gli angoli
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 4.0,
                                                      horizontal: 16.0),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        
  child: Text(
    chatName,
    maxLines: 1,                      // 👉 mai andare a capo
    overflow: TextOverflow.ellipsis,  // 👉 “…”
    softWrap: false,                  // 👉 disabilita il wrap
    style: TextStyle(
      color: Colors.black,
      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
    ),
  ),

                                                      ),
                                                      Theme(
                                                          data:
                                                              Theme.of(context)
                                                                  .copyWith(
                                                            popupMenuTheme:
                                                                PopupMenuThemeData(
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            16),
                                                              ),
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                          child:
                                                              PopupMenuButton<
                                                                  String>(
                                                            offset:
                                                                const Offset(
                                                                    0, 32),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16), // Imposta un raggio di 8
                                                            color: Colors.white,
                                                            icon: Icon(
                                                              Icons.more_horiz,
                                                              color: (isHovered ||
                                                                      isActive)
                                                                  ? Colors
                                                                      .black // Colore bianco per l'icona in hover o selezione
                                                                  : Colors
                                                                      .transparent, // Nascondi icona se non attivo o in hover
                                                            ),
                                                            padding:
                                                                EdgeInsets.only(
                                                                    right:
                                                                        4.0), // Riduci margine destro
                                                            onSelected:
                                                                (String value) {
                                                              if (value ==
                                                                  'delete') {
                                                                _deleteChat(
                                                                    _chatHistory
                                                                        .indexOf(
                                                                            chat)); // Elimina la chat
                                                              } else if (value ==
                                                                  'edit') {
                                                                _showEditChatDialog(
                                                                    _chatHistory
                                                                        .indexOf(
                                                                            chat)); // Modifica la chat
                                                              } else if (value ==
                                                                  'archive') {
                                                                _archiveChat(
                                                                    _chatHistory
                                                                        .indexOf(
                                                                            chat));
                                                              }
                                                            },
                                                            itemBuilder:
                                                                (BuildContext
                                                                    context) {
                                                              return [
                                                                PopupMenuItem(
                                                                  value: 'edit',
                                                                  child: Text(
                                                                      localizations
                                                                          .edit),
                                                                ),
                                                                PopupMenuItem(
                                                                    value:
                                                                        'archive',
                                                                    child: Text(
                                                                        localizations
                                                                            .archive)),
                                                                PopupMenuItem(
                                                                  value:
                                                                      'delete',
                                                                  child: Text(
                                                                      localizations
                                                                          .delete),
                                                                ),
                                                              ];
                                                            },
                                                          )),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          const SizedBox(
                                              height:
                                                  24), // Spaziatura tra le sezioni
                                        ],
                                      );
                                    },
                                  ));
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
// Pulsante "Nuova Chat"
                        HoverableNewChatButton(
                            label: localizations.newChat,
                            onPressed: () {
                              _startNewChat();
                              setState(() {
                                _activeButtonIndex = 3;
                                showKnowledgeBase = false;
                                showSettings = false;
                                _activeChatIndex = null;

                                
                              });
                            }),
                        const SizedBox(height: 56),
                      ],
                    )
                  : SizedBox.shrink(),
            ),
          ),
          // Area principale

          Expanded(
            child: Container(
                clipBehavior: Clip.hardEdge,
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 1.0),
                  borderRadius: BorderRadius.circular(16.0),
                  gradient: const RadialGradient(
                    center: Alignment(0.5, 0.25),
                    radius:
                        1.2, // aumenta o diminuisci per rendere più o meno ampio il cerchio
                    colors: [
                      Color.fromARGB(
                          255, 199, 230, 255), // Azzurro pieno al centro
                      Colors.white, // Bianco verso i bordi
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: Column(children: [
                  // Nuova top bar per info e pulsante utente
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Lato sinistro: un Expanded per allineare a sinistra
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (sidebarWidth == 0.0) ...[
                                IconButton(
                                  icon: _appReady ? SvgPicture.network(
                                      'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
                                      width: 24,
                                      height: 24,
                                      color:
                                          Colors.grey) : const SizedBox(
          width:24, height:24,
          child:CircularProgressIndicator(strokeWidth:2)), //const Icon(Icons.menu,
                                  //color: Colors.black),
                                  onPressed: _appReady ? () {
                                    setState(() {
                                      isExpanded = true;
                                      sidebarWidth = MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600
                                          ? MediaQuery.of(context).size.width
                                          : 300.0;
                                    });
                                  } : () {},
                                ),
                                const SizedBox(width: 8),
                                fullLogo,
                              ],
                            ],
                          ),
                        ),
                        Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                color: Colors.white,
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              offset: const Offset(0, 50),
                              borderRadius: BorderRadius.circular(
                                  16), // Imposta un raggio di 8
                              color: Colors.white,
                              icon: Builder(
                                builder: (context) {
                                  // Recupera la larghezza disponibile usando MediaQuery
                                  final availableWidth =
                                      MediaQuery.of(context).size.width;
                                  return Row(
                                    mainAxisSize: MainAxisSize
                                        .min, // Occupa solo lo spazio necessario
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.black,
                                        child: Text(
                                          widget.user.email
                                              .substring(0, 2)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                      // Mostra nome ed email solo se la larghezza è almeno 450
                                      if (availableWidth >= 450)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.user.username,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                widget.user.email,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Aggiungi icona della lingua
                                      //const SizedBox(width: 8.0),
                                      //Icon(Icons.language, color: Colors.blue),
                                    ],
                                  );
                                },
                              ),
                              onSelected: (value) {
                                if (value == 'language') {
                                  // Mostra un dialogo per selezionare la lingua
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      final selectedLanguage =
                                          LocalizationProviderWrapper.of(
                                                  context)
                                              .currentLanguage;

                                      Widget languageOption({
                                        required String label,
                                        required Language language,
                                        required String
                                            countryCode, // es: "it", "us", "es"
                                      }) {
                                        final isSelected =
                                            selectedLanguage == language;
                                        return SimpleDialogOption(
                                          onPressed: () {
                                            LocalizationProviderWrapper.of(
                                                    context)
                                                .setLanguage(language);
                                            Navigator.pop(context);
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.grey.shade200
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Image.network(
                                                    'https://flagcdn.com/w40/$countryCode.png',
                                                    width: 24,
                                                    height: 18,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        const Icon(Icons.flag),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      return SimpleDialog(
                                        backgroundColor: Colors.white,
                                        title:
                                            Text(localizations.select_language),
                                        children: [
                                          languageOption(
                                            label: 'Italiano',
                                            language: Language.italian,
                                            countryCode: 'it',
                                          ),
                                          languageOption(
                                            label: 'English',
                                            language: Language.english,
                                            countryCode: 'us',
                                          ),
                                          languageOption(
                                            label: 'Español',
                                            language: Language.spanish,
                                            countryCode: 'es',
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  // Altri casi di selezione
                                  switch (value) {
                                    //case 'Profilo':
                                      //Navigator.push(
                                      //context,
                                      //MaterialPageRoute(
                                      //  builder: (context) => AccountSettingsPage(
                                      //    user: widget.user,
                                      //    token: widget.token,
                                      //  ),
                                      //),
                                      //);
                                      //break;
                                    case 'Utilizzo':
                                      showDialog(
                                        context: context,
                                        builder: (_) => UsageDialog(),
                                      );
                                      break;
                                    case 'Impostazioni':
                                      /*setState(() {
            showSettings = true;
            showKnowledgeBase = false;
          });*/
                                      showDialog(
                                        context: context,
                                        builder: (_) => SettingsDialog(
                                          accessToken: widget.token.accessToken,
                                          onArchiveAll: _archiveAllChats,
                                          onDeleteAll: _deleteAllChats,
                                        ),
                                      );
                                      break;
                                    case 'Logout':
                                      _logout(context);
                                      break;
                                  }
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  /*PopupMenuItem(
                                    value: 'Profilo',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, color: Colors.black),
                                        const SizedBox(width: 8.0),
                                        Text(localizations.profile),
                                      ],
                                    ),
                                  ),*/
                                  PopupMenuItem(
                                    value: 'Utilizzo',
                                    child: Row(
                                      children: [
                                        Icon(Icons.bar_chart,
                                            color: Colors.black),
                                        const SizedBox(width: 8.0),
                                        Text(localizations.usage),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'Impostazioni',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings,
                                            color: Colors.black),
                                        const SizedBox(width: 8.0),
                                        Text(localizations.settings),
                                      ],
                                    ),
                                  ),
                                  // Elemento per la selezione della lingua
                                  PopupMenuItem(
                                    value: 'language',
                                    child: Row(
                                      children: [
                                        Icon(Icons.language,
                                            color: Colors.black),
                                        const SizedBox(width: 8.0),
                                        Text(localizations.select_language),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'Logout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.logout, color: Colors.red),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          localizations.logout,
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ))
                      ],
                    ),
                  ),

                  const Divider(
                    color: Colors.grey,
                    height: 0,
                  ),

                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0.0, vertical: 0.0),
                      color: Colors.transparent,
                      child: showKnowledgeBase
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DashboardScreen(
  username: widget.user.username,
  token: widget.token.accessToken,

  // ▼▼▼  NUOVO PARAMETRO  ▼▼▼
  onNewPendingJob: _onNewPendingJob,
),
                                  ),
                                ],
                              ),
                            )
                          : showSettings
                              ? Container(
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  //child: AccountSettingsPage(
                                  //  user: widget.user,
                                  //  token: widget.token,
                                  //),
                                )
                              : Column(
                                  children: [
                                    // Sezione principale con i messaggi

                                    messages.isEmpty
                                        ? buildEmptyChatScreen(
                                            context, _handleUserInput)
                                        : Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                final double
                                                    rightContainerWidth =
                                                    constraints.maxWidth;
                                                final double containerWidth =
                                                    (rightContainerWidth > 800)
                                                        ? 800.0
                                                        : rightContainerWidth;

                                                return Stack(children: [
                                                  ShaderMask(
                                                      shaderCallback:
                                                          (Rect bounds) {
                                                        return const LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Colors.white,
                                                            Colors.transparent,
                                                            Colors.transparent,
                                                            Colors.white,
                                                          ],
                                                          stops: [
                                                            0.0,
                                                            0.03,
                                                            0.97,
                                                            1.0
                                                          ],
                                                        ).createShader(bounds);
                                                      },
                                                      blendMode:
                                                          BlendMode.dstOut,
                                                      child:
                                                          SingleChildScrollView(
                                                              controller:
                                                                  _messagesScrollController,
                                                              physics:
                                                                  const AlwaysScrollableScrollPhysics(),
                                                              child: Center(
                                                                  // (2) Centra la colonna
                                                                  child:
                                                                      ConstrainedBox(
                                                                // (3) Limita la larghezza della colonna a containerWidth
                                                                constraints:
                                                                    BoxConstraints(
                                                                  maxWidth:
                                                                      containerWidth,
                                                                ),
                                                                child: Column(
                                                                  children:
                                                                      _buildMessagesList(
                                                                          containerWidth),
                                                                ),
                                                              )))),
// 2️⃣ The FAB, positioned at bottom-center:
                                                  if (_showScrollToBottomButton)
                                                    Positioned(
                                                      bottom: 16,
                                                      left: 0,
                                                      right:
                                                          0, // ← fa sì che il Positioned sia largo quanto il parent
                                                      child: Align(
                                                        // ← allinea il figlio al centro orizzontalmente
                                                        alignment:
                                                            Alignment.center,
                                                        child:
                                                            FloatingActionButton(
                                                          mini: true,
                                                          backgroundColor: Colors
                                                              .white, // ← sfondo bianco
                                                          elevation: 4.0,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            // ← bordo arrotondato con raggio 30
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        30),
                                                          ), // ← ombra sottile
                                                          child: const Icon(
                                                            Icons
                                                                .arrow_downward,
                                                            color: Colors
                                                                .blue, // ← freccia blu
                                                          ),
                                                          onPressed: () {
                                                            _messagesScrollController
                                                                .animateTo(
                                                              _messagesScrollController
                                                                  .position
                                                                  .maxScrollExtent,
                                                              duration:
                                                                  const Duration(
                                                                      milliseconds:
                                                                          300),
                                                              curve: Curves
                                                                  .easeOut,
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                ]);
                                              },
                                            ),
                                          ),

                                    // Container di input unificato (testo + icone + mic/invia)
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          0, 16, 0, 0),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double availableWidth =
                                              constraints.maxWidth;
                                          final double containerWidth =
                                              (availableWidth > 800)
                                                  ? 800
                                                  : availableWidth;

                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: containerWidth,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4.0,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  // RIGA 1: Campo di input testuale
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        16.0, 8.0, 16.0, 8.0),
                                                    child: // ⬅︎ metti in cima al widget build o come campo di stato

                                                        ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                        // ⬅︎ limite d’altezza
                                                        maxHeight:
                                                            150, //   200 px
                                                      ),
                                                      child: Scrollbar(
                                                        // ⬅︎ mostra la barra se necessario
                                                        thumbVisibility: true,
                                                        controller:
                                                            _inputScroll,
                                                        child: TextField(
  controller: _controller,
  focusNode: _inputFocus,        // 👈 nuovo
  minLines: 1,
  maxLines: null,
  keyboardType: TextInputType.multiline,
  textInputAction: TextInputAction.send,   // 👈 mostra “Send” su mobile
  decoration: const InputDecoration(
    hintText: 'Scrivi qui…',
    border: InputBorder.none,
    isCollapsed: true,
  ),
  onSubmitted: (value) => _handleUserInput(value), // ⇢ Enter invia
  /*onEditingComplete: () {
    // impedisce l’andare‐a‐capo quando TextInputAction.send non è supportato
    _handleUserInput(_controller.text);
  },*/
),

                                                      ),
                                                    ),
                                                  ),

                                                  // Divider sottile per separare input text e icone
                                                  const Divider(
                                                    height: 1,
                                                    thickness: 1,
                                                    color: Color(0xFFE0E0E0),
                                                  ),

                                                  // RIGA 2: Icone in basso (contesti, doc, media) + mic/freccia
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 0.0),
                                                    child: Row(
                                                      children: [
                                                        // Icona contesti
                                                        IconButton(
                                                          icon: SvgPicture.network(
                                                              'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element2.svg',
                                                              width: 24,
                                                              height: 24,
                                                              color:
                                                                  Colors.grey),
                                                          tooltip: localizations
                                                              .knowledgeBoxes,
                                                          onPressed:
                                                              _showContextDialog,
                                                        ),
                                                        // Icona doc (inattiva)
                                                        IconButton(
                                                          icon: SvgPicture.network(
                                                              'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element7.svg',
                                                              width: 24,
                                                              height: 24,
                                                              color:
                                                                  Colors.grey),
                                                          tooltip: localizations
                                                              .upload_document,
                                                          
                                                            onPressed: () => _uploadFileForChatAsync(isMedia: false),
                                                          
                                                        ),
                                                        // Icona media (inattiva)
                                                        IconButton(
                                                          icon: SvgPicture.network(
                                                              'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element8.svg',
                                                              width: 24,
                                                              height: 24,
                                                              color:
                                                                  Colors.grey),
                                                          tooltip: localizations
                                                              .upload_media,
                                                          onPressed: () => _uploadFileForChatAsync(isMedia: true),
                                                        ),

                                                        const Spacer(),

                                                        (_controller
                                                                .text.isEmpty)
                                                            ? IconButton(
                                                                icon: Icon(
                                                                  _isListening
                                                                      ? Icons
                                                                          .mic_off
                                                                      : Icons
                                                                          .mic,
                                                                ),
                                                                tooltip:
                                                                    localizations
                                                                        .enable_mic,
                                                                onPressed:
                                                                    _listen,
                                                              )
                                                            : IconButton(
                                                                icon: const Icon(
                                                                    Icons.send),
                                                                tooltip:
                                                                    localizations
                                                                        .send_message,
                                                                onPressed: () =>
                                                                    _handleUserInput(
                                                                        _controller
                                                                            .text),
                                                              ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  )
                ])),
          )
        ],
      ),
    );
  }

  Future<void> _deleteChat(int index) async {
    try {
      final chatToDelete = _chatHistory[index];

      // Rimuovi dal database, se la chat ha un ID esistente
      if (chatToDelete.containsKey('_id')) {
        await _databaseService.deleteCollectionData(
          "${widget.user.username}-database",
          'chats',
          chatToDelete['_id'],
          widget.token.accessToken,
        );
      }

      // Rimuovi dalla lista locale e aggiorna il local storage
      setState(() {
        _chatHistory.removeAt(index);
      });
      final String jsonString = jsonEncode({'chatHistory': _chatHistory});
      html.window.localStorage['chatHistory'] = jsonString;

      print('Chat eliminata con successo.');
    } catch (e) {
      print('Errore durante l\'eliminazione della chat: $e');
    }
  }

  void _showEditChatDialog(int index) {
    final localizations = LocalizationProvider.of(context);
    final chat = _chatHistory[index];
    final TextEditingController _nameController =
        TextEditingController(text: chat['name']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.edit_chat_name),
          backgroundColor: Colors.white, // Sfondo del popup
          elevation: 6, // Intensità dell'ombra
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16), // Arrotondamento degli angoli
            //side: BorderSide(
            //  color: Colors.blue, // Colore del bordo
            //  width: 2, // Spessore del bordo
            //),
          ),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: localizations.chat_name),
          ),
          actions: [
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.save),
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  _editChatName(index, newName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editChatName(int index, String newName) async {
    try {
      // Avvia l'animazione per cambiare il nome
      await _animateChatNameChange(index, newName);

      // Dopo l'animazione, aggiorna il nome nel localStorage e nel database
      final chatToUpdate = _chatHistory[index];

      // Aggiorna il localStorage
      final String jsonString = jsonEncode({'chatHistory': _chatHistory});
      html.window.localStorage['chatHistory'] = jsonString;

      // Aggiorna il database, se disponibile
      if (chatToUpdate.containsKey('_id')) {
        await _databaseService.updateCollectionData(
          "${widget.user.username}-database",
          'chats',
          chatToUpdate['_id'],
          {'name': newName},
          widget.token.accessToken,
        );
        print('Nome chat aggiornato con successo nel database.');
      } else {
        // Se _id non è presente (caso di modifica tramite tool Chatbot)
        // Chiamiamo _saveConversation per forzare la creazione/aggiornamento del record nel DB.
        print(
            'Nessun _id presente, forzo il salvataggio tramite _saveConversation.');
        await _saveConversation(messages);
      }
    } catch (e) {
      print('Errore durante l\'aggiornamento del nome della chat: $e');
    }
  }

Future<void> _startNewChat() async {
  setState(() {
    _activeChatIndex   = null;
    messages.clear();
    _chatKbPath        = null;
    _latestChainId     = null;      // reset id chain / config
    _latestConfigId    = null;

    _selectedContexts  = [];        // ★★★  NUOVO  – niente K-Box ereditati
    _selectedModel     = _defaultModel;

    showKnowledgeBase  = false;
    showSettings       = false;
  });

  await _prepareChainForCurrentChat();   // creerà una chain VUOTA
}

  void _loadMessagesForChat(String chatId) {
    // Svuota la cache dei widget per forzare la ricostruzione con i nuovi dati
    _widgetCache.clear();
    try {
      final chat = _chatHistory.firstWhere(
        (chat) => chat['id'] == chatId,
        orElse: () => null, // se non trova nulla, restituisce null
      );

      if (chat == null) {
        // gestisci il caso in cui la chat NON esiste
      } else {
        // gestisci la chat trovata
      }

      if (chat == null) {
        print('Errore: Nessuna chat trovata con ID $chatId');
        return;
      }

_chatKbPath = chat['kb_path'] as String?;        // NEW
_syncedMsgIds.clear();                           // reset cache

      // Estrai e ordina i messaggi della chat
      List<dynamic> chatMessages = chat['messages'] ?? [];
      chatMessages.sort((a, b) {
        final aCreatedAt = DateTime.parse(a['createdAt']);
        final bCreatedAt = DateTime.parse(b['createdAt']);
        return aCreatedAt
            .compareTo(bCreatedAt); // Ordina dal più vecchio al più recente
      });

      // Aggiorna lo stato
      setState(() {
        _activeChatIndex = _chatHistory.indexWhere(
            (c) => c['id'] == chatId); // Imposta l'indice della chat attiva
        messages.clear();
        messages.addAll(chatMessages.map((message) {
          // Assicura che ogni messaggio sia un Map<String, dynamic>
          return Map<String, dynamic>.from(message);
        }).toList());

        // Forza il passaggio alla schermata delle conversazioni
        showKnowledgeBase = false; // Nascondi KnowledgeBase
        showSettings = false; // Nascondi Impostazioni
      });

      if (messages.isNotEmpty) {
        final lastConfig = messages.last['agentConfig'];
        if (lastConfig != null &&
            (lastConfig['chain_id'] as String?)?.isNotEmpty == true) {
          _latestChainId  = lastConfig['chain_id'];
          _latestConfigId = lastConfig['config_id'];
        } else {
          // chat senza chain precedente → reset
          _latestChainId  = null;
          _latestConfigId = null;
        }
      } else {
        // chat vuota → reset
        _latestChainId  = null;
        _latestConfigId = null;
      }

      _ensureChainIncludesChatKb(chatId);

      // Debug: Messaggi caricati
      print(
          'Messaggi caricati per chat ID $chatId (${chat['name']}): $chatMessages');
    } catch (e) {
      print(
          'Errore durante il caricamento dei messaggi per chat ID $chatId: $e');
    }
  }

  Future<void> _handleUserInput(String input) async {
    if (input.isEmpty) return;

    await _ensureChainReady();

    // Make absolutely sure we have a chain.
    //await _ensureDefaultChainConfigured();
    print("************************");
    print(_latestChainId);
    print(_latestConfigId);
    print("************************");
    // Determina il nome corrente della chat (se non esiste, il default è "New Chat")
    String currentChatName = "New Chat";
    if (_activeChatIndex != null && _chatHistory.isNotEmpty) {
      currentChatName = _chatHistory[_activeChatIndex!]['name'] as String;
    }

    // Qui decidiamo quanti messaggi sono già stati inviati
    // Puoi utilizzare messages.length oppure tenere un contatore separato
    final int currentMessageCount = messages.length;

    // Ottieni l'input modificato usando la funzione esterna
    final modifiedInput = appendChatInstruction(
      input,
      currentChatName: currentChatName,
      messageCount: currentMessageCount,
    );

    final currentTime = DateTime.now().toIso8601String(); // Ora corrente
    final userMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio utente
    final assistantMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio dell'assistente
    final formattedContexts =
        _selectedContexts.map((c) => "${widget.user.username}-$c").toList();

// Usa i contesti formattati se ti servono in debug, ma la vera chain la prendi dallo state:
    final agentConfiguration = {
      'model': _selectedModel, // Modello
      'contexts': formattedContexts, // Teniamo traccia dei contesti
      'chain_id': _latestChainId, // Usa la chain ID reale dal backend
      'config_id': _latestConfigId, // Salva anche il config ID
    };

    setState(() {
      // Aggiungi il messaggio dell'utente con le informazioni di configurazione
      messages.add({
        'id': userMessageId, // ID univoco del messaggio utente
        'role': 'user', // Ruolo dell'utente
        'content': input, // Contenuto del messaggio
        'createdAt': currentTime, // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
      });

      fullResponse = ""; // Reset della risposta completa

      // Aggiungi un placeholder per la risposta dell'assistente
      messages.add({
        'id': assistantMessageId, // ID univoco del messaggio dell'assistente
        'role': 'assistant', // Ruolo dell'assistente
        'content': '', // Placeholder per il contenuto
        'createdAt': DateTime.now().toIso8601String(), // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
      });
    });

    // Pulisce il campo di input
    _controller.clear();

    // Invia il messaggio all'API per ottenere la risposta
    await _sendMessageToAPI(modifiedInput);

    // Salva la conversazione con ID univoco per ogni messaggio
    _saveConversation(messages);
  }

  Map<String, List<Map<String, dynamic>>> _groupChatsByDate(
      List<dynamic> chats) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final sevenDaysAgo = today.subtract(Duration(days: 7));
    final thirtyDaysAgo = today.subtract(Duration(days: 30));

    Map<String, List<Map<String, dynamic>>> groupedChats = {
      'Oggi': [],
      'Ieri': [],
      'Ultimi 7 giorni': [],
      'Ultimi 30 giorni': [],
      'Chat passate': []
    };

    for (var chat in chats) {
      final chatDate = DateTime.parse(chat['updatedAt']);
      if (chatDate.isAfter(today)) {
        groupedChats['Oggi']?.add(chat);
      } else if (chatDate.isAfter(yesterday)) {
        groupedChats['Ieri']?.add(chat);
      } else if (chatDate.isAfter(sevenDaysAgo)) {
        groupedChats['Ultimi 7 giorni']?.add(chat);
      } else if (chatDate.isAfter(thirtyDaysAgo)) {
        groupedChats['Ultimi 30 giorni']?.add(chat);
      } else {
        groupedChats['Chat passate']?.add(chat);
      }
    }

    return groupedChats;
  }

  Future<void> _saveConversation(List<Map<String, dynamic>> messages) async {
    try {
      final currentTime =
          DateTime.now().toIso8601String(); // Ora corrente in formato ISO
      final chatId = _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['id'] // ID della chat esistente
          : uuid.v4(); // Genera un nuovo ID univoco per una nuova chat
      final chatName = _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['name'] // Nome della chat esistente
          : 'New Chat'; // Nome predefinito per le nuove chat

       // assicura che la KB esista anche per le chat appena create
       if (_chatKbPath == null) {
      _chatKbPath = await _ensureChatKb(chatId, chatName);
    }

    
     // ▸ 2. sincronizza tutti i messaggi non ancora presenti nella KB
     //     (la funzione usa la variabile globale `messages` e _syncedMsgIds)
     //await _syncMessagesToKb(_chatKbPath!);
    
      // Effettua una copia profonda di tutti i messaggi
      final List<Map<String, dynamic>> updatedMessages =
          messages.map((originalMessage) {
        // Cloniamo l'intero messaggio (struttura annidata) con jsonDecode(jsonEncode(...))
        final newMsg =
            jsonDecode(jsonEncode(originalMessage)) as Map<String, dynamic>;

        // Se il messaggio ha dei widget, forziamo is_first_time = false in ognuno
if (newMsg['widgetDataList'] != null) {
  final List widgetList = newMsg['widgetDataList'];

  for (int i = 0; i < widgetList.length; i++) {
    final element = widgetList[i];
    print('****$element');

    // ✔ 1. assicurati che SIA davvero una Map
    if (element is Map) {
      //    …e convertila in Map<String,dynamic>
      final Map<String, dynamic> widgetMap = Map<String, dynamic>.from(element);

      // ✔ 2. forza is_first_time = false
      final Map<String, dynamic> jsonData =
          (widgetMap['jsonData'] ?? {}) as Map<String, dynamic>;
      jsonData['is_first_time'] = false;
      widgetMap['jsonData'] = jsonData;

      // ✔ 3. riscrivi l’elemento normalizzato
      widgetList[i] = widgetMap;
    }
    //    se NON è una Map lo lasci com’è (o rimuovilo se non ti serve)
  }

  newMsg['widgetDataList'] = widgetList;
}


        // Aggiorniamo la agentConfig per riflettere contesti e modello
        final Map<String, dynamic> oldAgentConfig =
            (newMsg['agentConfig'] ?? {}) as Map<String, dynamic>;
        oldAgentConfig['model'] = _selectedModel;
        oldAgentConfig['contexts'] = _selectedContexts;
        newMsg['agentConfig'] = oldAgentConfig;

        return newMsg;
      }).toList();

      // Crea o aggiorna la chat corrente con ID, timestamp e messaggi
      final Map<String, dynamic> currentChat = {
        'id': chatId, // ID della chat
        'name': chatName, // Nome della chat
        'createdAt': _activeChatIndex != null
            ? _chatHistory[_activeChatIndex!]['createdAt']
            : currentTime, // Se esisteva già, mantengo la data di creazione, altrimenti quella attuale
        'updatedAt': currentTime, // Aggiorna il timestamp di ultima modifica
        'messages': updatedMessages, // Lista di messaggi clonati e modificati
        'kb_path'  : _chatKbPath,        // ← salva sempre il path
      };

      if (_activeChatIndex != null) {
        // Aggiorna la chat esistente nella lista locale
        _chatHistory[_activeChatIndex!] =
            jsonDecode(jsonEncode(currentChat)) as Map<String, dynamic>;
      } else {
        // Aggiungi una nuova chat alla lista locale
        _chatHistory.insert(
            0, jsonDecode(jsonEncode(currentChat)) as Map<String, dynamic>);
        _activeChatIndex = 0; // Imposta l'indice della nuova chat
      }

      // Salva la cronologia delle chat nel Local Storage
      final String jsonString = jsonEncode({'chatHistory': _chatHistory});
      html.window.localStorage['chatHistory'] = jsonString;
      print('Chat salvata correttamente nel Local Storage.');

      // Salva o aggiorna la chat nel database
      final dbName =
          "${widget.user.username}-database"; // Nome del DB basato sull'utente
      final collectionName = 'chats';

      try {
        // Carica le chat esistenti dal database
        final existingChats = await _databaseService.fetchCollectionData(
          dbName,
          collectionName,
          widget.token.accessToken,
        );

        // Trova la chat corrente nel database
        final existingChat = existingChats.firstWhere(
          (chat) => chat['id'] == chatId,
          orElse: () =>
              <String, dynamic>{}, // Ritorna una mappa vuota se non trovata
        );

        if (existingChat.isNotEmpty && existingChat.containsKey('_id')) {
          // Chat esistente: aggiorniamo i campi
          await _databaseService.updateCollectionData(
            dbName,
            collectionName,
            existingChat['_id'], // ID del documento esistente
            {
              'name': currentChat['name'], // Aggiorna il nome della chat
              'updatedAt': currentTime, // Aggiorna la data di ultima modifica
              'messages': updatedMessages, // Aggiorna i messaggi
            },
            widget.token.accessToken,
          );
          print('Chat aggiornata nel database.');
        } else {
          // Chat non esistente, aggiungiamone una nuova
          await _databaseService.addDataToCollection(
            dbName,
            collectionName,
            currentChat,
            widget.token.accessToken,
          );
          print('Nuova chat aggiunta al database.');
        }
      } catch (e) {
        if (e.toString().contains('Failed to load collection data')) {
          // Se la collection non esiste, la creiamo e aggiungiamo la chat
          print('Collection "chats" non esistente. Creazione in corso...');
          await _databaseService.createCollection(
              dbName, collectionName, widget.token.accessToken);

          // Aggiungi la nuova chat
          await _databaseService.addDataToCollection(
            dbName,
            collectionName,
            currentChat,
            widget.token.accessToken,
          );

          print('Collection "chats" creata e chat aggiunta al database.');
        } else {
          throw e; // Propaga eventuali altri errori
        }
      }
    } catch (e) {
      print('Errore durante il salvataggio della conversazione: $e');
    }
  }

  void _showContextDialog() {
    // Carichiamo i contesti (se serve farlo qui) ...
    _loadAvailableContexts();

    // Richiamiamo il dialog esterno
    showSelectContextDialog(
      chatHistory: _chatHistory,
      context: context,
      availableContexts: _availableContexts,
      initialSelectedContexts: _selectedContexts,
      initialModel: _selectedModel,
      onConfirm: (List<String> newContexts, String newModel) async {
        setState(() {
          _selectedContexts = newContexts;
          _selectedModel = newModel;
        });
        // E se vuoi, chiami la funzione set_context
        await set_context(_rawContextsForChain(), _selectedModel);
      },
    );
  }

// ─────────────────────────────────────────────────────────────────────────────
//  Configura (o riconfigura) la chain LLM
//  • `userSelected`  = contesti scelti manualmente nel dialog
//  • `model`         = modello LLM da usare
//
//  La funzione aggiunge AUTOMATICAMENTE – se esiste – la KB collegata
//  alla chat corrente (_chatKbPath) in modo che il backend la indicizzi
//  insieme agli altri contesti.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> set_context(List<String> userSelected, String model) async {
  try {
    // 1.  salva subito le scelte manuali dell’utente
    _selectedContexts = userSelected;
    _selectedModel    = model;

    // 2.  lista “effettiva” da passare al backend
    //     (= contesti scelti  +  KB-chat  senza doppi)
    final List<String> effectiveRaw = _rawContextsForChain();

    // 3.  chiama l’SDK
    final response = await _contextApiSdk.configureAndLoadChain(
      widget.user.username,
      widget.token.accessToken,
      effectiveRaw,
      model,
    );
    debugPrint('Chain configurata su: $effectiveRaw');

    // 4.  estrae gli ID restituiti
    final String? chainIdFromResponse  =
        response['load_result']?['chain_id']   as String?;
    final String? configIdFromResponse =
        response['config_result']?['config_id'] as String?;

    // 5.  aggiorna stato + localStorage
    setState(() {
      _latestChainId  = chainIdFromResponse;
      _latestConfigId = configIdFromResponse;
    });

    html.window.localStorage['latestChainId']  = _latestChainId  ?? '';
    html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';
  } catch (e, st) {
    debugPrint('❌  set_context error: $e\n$st');
  }
}


  // Sezione impostazioni TTS e customizzazione grafica nella barra laterale
  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double
            .infinity, // Imposta la larghezza per occupare tutto lo spazio disponibile
        decoration: BoxDecoration(
          color: Colors.white, // Colore di sfondo bianco
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Impostazioni Text-to-Speech",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.0),
            // Dropdown per la lingua
            Text("Seleziona lingua"),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: [
                DropdownMenuItem(
                  value: "en-US",
                  child: Text("English (US)"),
                ),
                DropdownMenuItem(
                  value: "it-IT",
                  child: Text("Italian"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Slider per la velocità di lettura
            Text("Velocità lettura: ${_speechRate.toStringAsFixed(2)}"),
            Slider(
              value: _speechRate,
              min: 0.1,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _speechRate = value;
                });
              },
            ),
            // Slider per il pitch
            Text("Intonazione (Pitch): ${_pitch.toStringAsFixed(1)}"),
            Slider(
              value: _pitch,
              min: 0.5,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _pitch = value;
                });
              },
            ),
            // Slider per il volume
            Text("Volume: ${_volume.toStringAsFixed(2)}"),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
              },
            ),
            // Slider per la pausa tra le frasi
            Text(
                "Pausa tra frasi: ${_pauseBetweenSentences.toStringAsFixed(1)} sec"),
            Slider(
              value: _pauseBetweenSentences,
              min: 0.0,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _pauseBetweenSentences = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            Text("Personalizzazione grafica",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            // Colore del messaggio dell'utente
            Text("Colore messaggio utente"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _userMessageColor),
                onPressed: () {
                  _showColorPickerDialog(_userMessageColor, (color) {
                    _userMessageColor = color;
                  });
                },
              ),
            ),
            // Opacità messaggio utente
            Slider(
              value: _userMessageOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _userMessageOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore del messaggio dell'assistente
            Text("Colore messaggio assistente"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _assistantMessageColor),
                onPressed: () {
                  _showColorPickerDialog(_assistantMessageColor, (color) {
                    _assistantMessageColor = color;
                  });
                },
              ),
            ),
            // Opacità messaggio assistente
            Slider(
              value: _assistantMessageOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _assistantMessageOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore dello sfondo della chat
            Text("Colore sfondo chat"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _chatBackgroundColor),
                onPressed: () {
                  _showColorPickerDialog(_chatBackgroundColor, (color) {
                    _chatBackgroundColor = color;
                  });
                },
              ),
            ),
            // Opacità sfondo chat
            Slider(
              value: _chatBackgroundOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _chatBackgroundOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore avatar
            Text("Colore avatar"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _avatarBackgroundColor),
                onPressed: () {
                  _showColorPickerDialog(_avatarBackgroundColor, (color) {
                    _avatarBackgroundColor = color;
                  });
                },
              ),
            ),
            // Opacità avatar
            Slider(
              value: _avatarBackgroundOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _avatarBackgroundOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore icona avatar
            Text("Colore icona avatar"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _avatarIconColor),
                onPressed: () {
                  _showColorPickerDialog(_avatarIconColor, (color) {
                    _avatarIconColor = color;
                  });
                },
              ),
            ),
            // Opacità icona avatar
            Slider(
              value: _avatarIconOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _avatarIconOpacity = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Funzione per iniziare o fermare l'ascolto
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _controller.text = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // Funzione per il Text-to-Speech
  Future<void> _speak(String message) async {
    if (message.isNotEmpty) {
      await _flutterTts.setLanguage(_selectedLanguage); // Lingua personalizzata
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate); // Velocità personalizzata
      await _flutterTts.setVolume(_volume); // Volume personalizzato
      await _flutterTts.speak(message);
      setState(() {
        _isPlaying = true;
      });
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isPlaying = false;
        });
      });
    }
  }

  // Funzione per fermare il Text-to-Speech
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // Funzione per copiare il messaggio negli appunti
  void _copyToClipboard(String message) {
    final localizations = LocalizationProvider.of(context);
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.copyMessage)),
    );
  }

  Future<void> _sendMessageToAPI(String input) async {
    if (_nlpApiUrl == null) {
      await _loadConfig(); // Assicurati che l'URL sia caricato
    }

    // URL della chain API
    final url = "$_nlpApiUrl/stream_events_chain";

    final chainIdToUse = _latestChainId?.isNotEmpty == true
        ? _latestChainId!
        : 'default_agent_with_tools';

    // Configurazione dell'agente
    final agentConfiguration = {
      'model': _selectedModel, // Modello selezionato
      'contexts': _formattedContextsForAgent(), // Contesti selezionati
      'chain_id': chainIdToUse, // Usa la chain ID dal backend (oppure fallback)
      'config_id': _latestConfigId, // Memorizza anche la config ID
    };

// Trasforma la chat history sostituendo i placeholder dei widget con i JSON reali
    final transformedChatHistory = messages.map((message) {
      String content = message['content'] as String;
      if (message.containsKey('widgetDataList')) {
        final List widgetList = message['widgetDataList'];
        for (final widgetEntry in widgetList) {
          final String placeholder = widgetEntry['placeholder'] as String;

          // 1) Copia profonda dei dati del widget
          final Map<String, dynamic> jsonData =
              Map<String, dynamic>.from(widgetEntry['jsonData'] as Map);

          // 2) Rimuovi il campo is_first_time se esiste
          jsonData.remove('is_first_time');

          // 3) Serializza il JSON “pulito”
          final String widgetJsonStr = jsonEncode(jsonData);

          // 4) Ricostruisci la stringa del widget
          final String widgetFormattedStr =
              "< TYPE='WIDGET' WIDGET_ID='${widgetEntry['widgetId']}'"
              " | $widgetJsonStr"
              " | TYPE='WIDGET' WIDGET_ID='${widgetEntry['widgetId']}' >";

          // 5) Sostituisci il placeholder
          content = content.replaceAll(placeholder, widgetFormattedStr);
        }
      }
      return {
        "id": message['id'],
        "role": message['role'],
        "content": content,
        "createdAt": message['createdAt'],
        "agentConfig": message['agentConfig'],
      };
    }).toList();

    // Prepara il payload per l'API
    final payload = jsonEncode({
      "chain_id": chainIdToUse,
      "query": {"input": input, "chat_history": transformedChatHistory},
      "inference_kwargs": {}
    });

    try {
      // Esegui la fetch
      final response = await js_util.promiseToFuture(js_util.callMethod(
        html.window,
        'fetch',
        [
          url,
          js_util.jsify({
            'method': 'POST',
            'headers': {'Content-Type': 'application/json'},
            'body': payload,
          }),
        ],
      ));

      // Verifica lo stato della risposta
      final ok = js_util.getProperty(response, 'ok') as bool;
      if (!ok) {
        throw Exception('Network response was not ok');
      }

      // Recupera il body dello stream
      final body = js_util.getProperty(response, 'body');
      if (body == null) {
        throw Exception('Response body is null');
      }

      // Ottieni un reader per leggere lo stream chunk-by-chunk
      final reader = js_util.callMethod(body, 'getReader', []);

      // Qui memorizziamo l'intero testo completo (con i widget originali)
      final StringBuffer fullOutput = StringBuffer();

      // Qui memorizziamo solo ciò che mostriamo in tempo reale
      final StringBuffer displayOutput = StringBuffer();

      // Variabili per la logica di scanning
      //bool insideWidgetBlock = false;      // Siamo dentro<TYPE='WIDGET' ... > ?
      final StringBuffer widgetBuffer =
          StringBuffer(); // Accumula i caratteri mentre siamo dentro il blocco widget

      final String startPattern = "< TYPE='WIDGET'";
      final int patternLength = startPattern.length;

      // Un piccolo buffer circolare per rilevare retroattivamente la comparsa di startPattern
      final List<int> ringBuffer = [];
// ────────── PARSER STATO TOOL-EVENTS ──────────
final StringBuffer _toolBuf = StringBuffer();
int  _toolDepth      = 0;    // { … }
bool _inQuotes       = false;
bool _escapeNextChar = false;

      // Funzione locale che processa un chunk di testo
// -----------------------------------------------------------------------------
// ✔ Revised version of `processChunk()`
//   ‑ fixes the bug with stray `>` inside the JSON by keeping a second sliding
//     window that waits for the terminator string "| TYPE='WIDGET'" *before*
//     accepting the closing `>`.
//   ‑ drop‑in replacement: no other part of the widget‑streaming pipeline
//     needs to change.
// -----------------------------------------------------------------------------

// ⬇︎ add these globals near the other stream‑parser state variables -------------

      bool insideWidgetBlock = false; // ▶ already present in old code
      bool seenEndMarker = false; // ▶ NEW
// ringBuffer (startPattern) already exists; this one is for the END marker
      final List<int> _ringEnd = <int>[]; // ▶ NEW, per‑message state
/// Consuma il chunk e intercetta TUTTI gli eventi tool.{start|end}.
/// Ritorna `true` se *almeno un carattere* apparteneva ad un JSON-evento
/// (così il chiamante non lo passerà a `processChunk`).
bool _maybeHandleToolEvent(String chunk) {
  bool somethingHandled = false;

  void _feed(int codeUnit) {
    final String c = String.fromCharCode(codeUnit);

    _toolBuf.write(c);

    // ── gestione escape & stringhe JSON
    if (_escapeNextChar) {
      _escapeNextChar = false;
      return;
    }
    if (c == r'\') {
      _escapeNextChar = true;
      return;
    }
    if (c == '"') {
      _inQuotes = !_inQuotes;
    }
    if (_inQuotes) return;

    // ── bilanciamento parentesi graffe
    if (c == '{') _toolDepth++;
    if (c == '}') _toolDepth--;

    // JSON completo quando la depth torna a 0
    if (_toolDepth == 0) {
      final String rawJson = _toolBuf.toString().trim();
      _toolBuf.clear();           // reset buffer per il prossimo evento

      if (rawJson.isEmpty) return;

      // prova di parse
      Map<String, dynamic>? evt;
      try {
        evt = jsonDecode(rawJson) as Map<String, dynamic>;
      } catch (_) {
        return;                   // non era un JSON valido
      }

      if (evt == null || !evt.containsKey('event')) return;

      somethingHandled = true;    // 👈 almeno un carattere gestito

      final String runId = evt['run_id'] as String;
      final String name  = evt['name']  as String;

      switch (evt['event']) {

        case 'on_tool_start':
          final placeholder = "[TOOL_PLACEHOLDER_$runId]";
          _toolEvents[runId] = {
            'name'      : name,
            'input'     : evt['data']['input'],
            'isRunning' : true,
            'placeholder': placeholder,
          };

          // inserisci placeholder nel testo visibile
          displayOutput.write(placeholder);

          // e relativa card
          (messages.last['widgetDataList'] ??= <dynamic>[]).add({
            "_id"       : runId,
            "widgetId"  : "ToolEventWidget",
            "jsonData"  : _toolEvents[runId],
            "placeholder": placeholder,
          });

          setState(() =>
              messages.last['content'] = displayOutput.toString());
          break;

        case 'on_tool_end':
          final existing = _toolEvents[runId];
          if (existing == null) break;

          existing['output']    = evt['data']['output'];
          existing['isRunning'] = false;

          // forza rebuild della card
          _widgetCache.remove(runId);
          setState(() {});
          break;
      }
    }
  }

  // ── feed carattere per carattere
  for (final cu in chunk.codeUnits) {
    _feed(cu);
  }

  return somethingHandled;
}

// -----------------------------------------------------------------------------
      void processChunk(String chunk) {
        const String spinnerPlaceholder = "[WIDGET_SPINNER]";

        // pattern di chiusura senza il '>' finale
        const String endMarker = "| TYPE='WIDGET'";
        const int endLen = endMarker.length;

        for (int i = 0; i < chunk.length; i++) {
          final String c = chunk[i];

          // 0) Accumula SEMPRE nel testo completo (serve per parse finale)
          fullOutput.write(c);

          // -----------------------------------------------------------------
          // 1) ‑‑ siamo FUORI da un blocco widget
          // -----------------------------------------------------------------
          if (!insideWidgetBlock) {
            // (a) sliding‑window di startPattern (già lungo startPattern.length)
            ringBuffer.add(c.codeUnitAt(0));
            if (ringBuffer.length > startPattern.length) ringBuffer.removeAt(0);

            // (b) esponi all'utente
            displayOutput.write(c);

            // (c) check se gli ultimi char == startPattern → entra in blocco
            if (ringBuffer.length == startPattern.length) {
              final recent = String.fromCharCodes(ringBuffer);
              if (recent == startPattern) {
                // ‑ rimuovi il pattern scritto visivamente
                final int newLen = displayOutput.length - startPattern.length;
                if (newLen >= 0) {
                  final String soFar = displayOutput.toString();
                  displayOutput
                    ..clear()
                    ..write(soFar.substring(0, newLen));
                }

                // ‑ inizializza stato interno
                insideWidgetBlock = true;
                seenEndMarker = false;
                widgetBuffer
                  ..clear()
                  ..write(startPattern);
                _ringEnd.clear();

                // ‑ mostra spinner + fake widget per placeholder
                displayOutput.write(spinnerPlaceholder);
                final lastMsg = messages.last;
                (lastMsg['widgetDataList'] ??= <dynamic>[])
                  ..add({
                    "_id":
                        "SpinnerFake_${DateTime.now().millisecondsSinceEpoch}",
                    "widgetId": "SpinnerPlaceholder",
                    "jsonData": <String, dynamic>{},
                    "placeholder": spinnerPlaceholder,
                  });
                setState(() =>
                    messages.last['content'] = displayOutput.toString() + "▌");
              }
            }
            continue; // fine ramo "fuori" – passa al prossimo carattere
          }

          // -----------------------------------------------------------------
          // 2) ‑‑ siamo DENTRO a « TYPE='WIDGET' … »
          // -----------------------------------------------------------------
          widgetBuffer.write(c);

          // (a) aggiorna ringEnd per individuare endMarker
          _ringEnd.add(c.codeUnitAt(0));
          if (_ringEnd.length > endLen) _ringEnd.removeAt(0);
          if (!seenEndMarker && _ringEnd.length == endLen) {
            if (String.fromCharCodes(_ringEnd) == endMarker) {
              seenEndMarker = true; // abbiamo visto "| TYPE='WIDGET'"
            }
          }

          // (b) chiusura: SOLO se endMarker visto *e* char corrente == '>'
          if (c == '>' && seenEndMarker) {
            // 1‑ togli lo spinner
            final String currentText =
                displayOutput.toString().replaceFirst(spinnerPlaceholder, "");
            displayOutput
              ..clear()
              ..write(currentText);

            // 2‑ finalize
            final String placeholder =
                _finalizeWidgetBlock(widgetBuffer.toString());
            displayOutput.write(placeholder);

            // 3‑ reset stato interno
            insideWidgetBlock = false;
            seenEndMarker = false;
            _ringEnd.clear();
          }
        }

        // ---------------------------------------------------------------------------
        // 3) Aggiorna la UI dopo aver consumato l'intero chunk
        // ---------------------------------------------------------------------------
        setState(() {
          messages.last['content'] = displayOutput.toString();
        });
      }

      // Legge ricorsivamente i chunk
      void readChunk() {
        js_util
            .promiseToFuture(js_util.callMethod(reader, 'read', []))
            .then((result) {
          final done = js_util.getProperty(result, 'done') as bool;
          if (!done) {
            final value = js_util.getProperty(result, 'value');
            // Converte in stringa
            final bytes = _convertJSArrayBufferToDartUint8List(value);
            final chunkString = utf8.decode(bytes);

            // Processa il chunk (token per token)
            final handled = _maybeHandleToolEvent(chunkString);

            if (!handled) {
              processChunk(chunkString);
            }

            // Continua a leggere
            readChunk();
          } else {
                       // ──────────────────────────────────────────────────────────────
            //  FINE STREAMING  – patch di fusione widget
            // ──────────────────────────────────────────────────────────────
            setState(() {
              final msg = messages.last;           // l’ultimo (assistant)

              // 1) TESTO: tieni quello già visto in tempo reale
              const String spinnerPh = "[WIDGET_SPINNER]";
              final String visibleText =
                  displayOutput.toString().replaceFirst(spinnerPh, "");
              msg['content'] = visibleText;

              // 2) PARSE dei blocchi < TYPE='WIDGET' … >
              final parsed = _parsePotentialWidgets(fullOutput.toString());

              // 3) MERGE  (vecchi widget + nuovi “classici”)
              final List<dynamic> existing =
                  (msg['widgetDataList'] ?? <dynamic>[]) as List<dynamic>;
              msg['widgetDataList'] = [...existing, ...parsed.widgetList];
              // 4) (opz.) rimuovi lo spinner provvisorio
              msg['widgetDataList']
                  .removeWhere((w) => w['widgetId'] == 'SpinnerPlaceholder');

              // 5) aggiungi la agentConfig se serve
              msg['agentConfig'] = agentConfiguration;
            });

            assistantTurnCompleted.value++;

            print('$assistantTurnCompleted');

            // Salviamo la conversazione (DB/localStorage)
            _saveConversation(messages);
          }
        }).catchError((error) {
          // Errore durante la lettura del chunk
          print('Errore durante la lettura del chunk: $error');
          setState(() {
            messages[messages.length - 1]['content'] = 'Errore: $error';
          });
        });
      }

      // Avvia la lettura dei chunk
      readChunk();
    } catch (e) {
      // Gestione errori fetch
      print('Errore durante il fetch dei dati: $e');
      setState(() {
        messages[messages.length - 1]['content'] = 'Errore: $e';
      });
    }

    
  }

  Uint8List _convertJSArrayBufferToDartUint8List(dynamic jsArrayBuffer) {
    final buffer = js_util.getProperty(jsArrayBuffer, 'buffer') as ByteBuffer;
    final byteOffset = js_util.getProperty(jsArrayBuffer, 'byteOffset') as int;
    final byteLength = js_util.getProperty(jsArrayBuffer, 'byteLength') as int;
    return Uint8List.view(buffer, byteOffset, byteLength);
  }
}

class NButtonWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String) onReply;

  const NButtonWidget({Key? key, required this.data, required this.onReply})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttons = data["buttons"] as List<dynamic>? ?? [];
    return Wrap(
      alignment: WrapAlignment.center, // Centra i pulsanti orizzontalmente
      spacing: 8.0, // Spazio orizzontale tra i pulsanti
      runSpacing: 8.0, // Spazio verticale tra le righe
      children: buttons.map((btn) {
        return ElevatedButton(
          onPressed: () {
            final replyText = btn["reply"] ?? "Nessuna reply definita";
            onReply(replyText);
          },
          style: ButtonStyle(
            // Sfondo di default blu, hover bianco
            backgroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return Colors.white;
                return Colors.blue;
              },
            ),
            // Testo di default bianco, hover blu
            foregroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return Colors.blue;
                return Colors.white;
              },
            ),
            // Bordo visibile solo in hover (blu) altrimenti nessun bordo
            side: MaterialStateProperty.resolveWith<BorderSide>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered))
                  return const BorderSide(color: Colors.blue);
                return BorderSide.none;
              },
            ),
            // Angoli arrotondati a 8
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: Text(btn["label"] ?? "Senza etichetta"),
        );
      }).toList(),
    );
  }
}
