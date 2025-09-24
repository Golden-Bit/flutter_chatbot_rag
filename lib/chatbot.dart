import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/llm_ui_tools/utilities/auto_sequence_widget.dart';
import 'package:boxed_ai/llm_ui_tools/utilities/chatVarsWidget.dart';
import 'package:boxed_ai/llm_ui_tools/utilities/js_runner_widget.dart';
import 'package:boxed_ai/llm_ui_tools/utilities/showChatVarsWidget.dart';
import 'package:boxed_ai/llm_ui_tools/utilities/toolEventWidget.dart';
import 'package:boxed_ai/ui_components/chat/chat_input_widget.dart';
import 'package:boxed_ai/ui_components/chat/chat_media_widgets.dart';
import 'package:boxed_ai/ui_components/chat/empty_chat_content.dart';
import 'package:boxed_ai/ui_components/chat/utilities_functions/kb_utilities.dart';
import 'package:boxed_ai/ui_components/chat/utilities_functions/rename_chat_instructions.dart';
import 'package:boxed_ai/ui_components/custom_components/general_components_v1.dart';
import 'package:boxed_ai/ui_components/dialogs/loader_config_dialog.dart';
import 'package:boxed_ai/ui_components/message/codeblock_md_builder.dart';
import 'package:boxed_ai/llm_ui_tools/tools.dart';
import 'package:boxed_ai/ui_components/buttons/blue_button.dart';
import 'package:boxed_ai/ui_components/dialogs/search_dialog.dart';
import 'package:boxed_ai/ui_components/dialogs/select_contexts_dialog.dart';
import 'package:boxed_ai/ui_components/message/table_md_builder.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/components/settings_dialog.dart';
import 'package:boxed_ai/user_manager/components/usage_analytics_dialog.dart';
import 'package:boxed_ai/user_manager/pages/billing_page.dart';
import 'package:boxed_ai/utilities/localization.dart';
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
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
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
import 'package:shared_preferences/shared_preferences.dart'; // se non c’era già
// ↑ Nella sezione import esistente
import 'package:markdown/markdown.dart' as md; // parse Element
import 'dart:html' as html; // download CSV
import 'package:collection/collection.dart';
import 'dart:async';
import 'package:boxed_ai/user_manager/state/billing_globals.dart';

/// ➊  Chiave che descrive come il messaggio deve apparire nella UI
///     'normal'      → si vede subito (default)
///     'invisible'   → non si vede mai in chat
///     'placeholder' → l’utente vede solo displayContent
const String kMsgVisibility   = 'visibility';
const String kVisNormal       = 'normal';
const String kVisInvisible    = 'invisible';
const String kVisPlaceholder  = 'placeholder';

/// ➋  Se visibility == 'placeholder' questo è il testo che
///     l’utente visualizza al posto di `content`.
const String kMsgDisplayText  = 'displayContent';

/// Proprietà del separatore subito sotto la Top-Bar.
class TopBarSeparatorStyle {
  const TopBarSeparatorStyle({
    this.visible = true,
    this.thickness = 1.0,
    this.color = Colors.grey,
    this.topOffset = 0.0, // distanza dal bordo superiore
  });

  /// Se `false` il separatore non viene renderizzato.
  final bool visible;

  /// Altezza (px) del separatore.
  final double thickness;

  /// Colore del separatore.
  final Color color;

  /// Spazio verticale *sopra* il separatore.
  /// Imposta 50.0 per avere sempre 50 px dal bordo superiore anche con Top-Bar vuota.
  final double topOffset;

  /// Stile di default identico al comportamento attuale.
  static const def = TopBarSeparatorStyle();
}

/// Impostazioni dello sfondo (colore piatto oppure gradiente radiale).
class ChatBackgroundStyle {
  const ChatBackgroundStyle({
    this.useGradient = true,
    this.baseColor = const Color(0xFFFFFFFF),
    this.gradientCenter = const Alignment(0.5, 0.25),
    this.gradientRadius = 1.2,
    this.gradientInner = const Color(0xFFC7E6FF), // azzurro “soft”
    this.gradientOuter = const Color(0xFFFFFFFF),
  });

  /// `false` = colore piatto `baseColor`
  final bool useGradient;

  /// Colore usato **sempre** come fallback e come outer-color se
  /// `useGradient == false`.
  final Color baseColor;

  /// Parametri solo se `useGradient == true`
  final Alignment gradientCenter;
  final double gradientRadius;
  final Color gradientInner;
  final Color gradientOuter;
}

class ChatBorderStyle {
  final bool visible;
  final double thickness;
  final Color color;
  final double radius;
  final EdgeInsets margin;

  const ChatBorderStyle({
    this.visible = true,
    this.thickness = 1.0,
    this.color = Colors.grey,
    this.radius = 16.0,
    this.margin = const EdgeInsets.all(16), // 〈── default ex-container
  });

  /// Stile “nessun bordo”
  static const none = ChatBorderStyle(visible: false);

  /// Stile di default usato da ChatBotPage se l’host non specifica nulla
  static const def = ChatBorderStyle(); // visibile + parametri sopra
}

// ─── callbacks.dart (o in cima a ChatBotPage.dart) ───────────────
class ChatBotHostCallbacks {
  const ChatBotHostCallbacks({
    this.renameChat,
    this.showSnackBar,
    this.navigate,
  });

  /// Funzioni che il *genitore* (host) vuole esporre.
  final Future<void> Function(String chatId, String newName)? renameChat;
  final void Function(String message)? showSnackBar;
  final void Function(String routeName)? navigate;
}

class ChatBotPageCallbacks {
  const ChatBotPageCallbacks({
    required this.renameChat,
    required this.sendReply,
  });

  final Future<void> Function(String chatId, String newName) renameChat;

  // 🔸 AGGIUNGI il named-parameter facoltativo
  final void Function(
    String reply, {
    String? sequenceId, // <── NEW
  }) sendReply;
}

typedef ChatWidgetBuilder = Widget Function(
  Map<String, dynamic> data,
  void Function(String reply, {Map<String, dynamic>? meta}) onReply, // <── NEW
  ChatBotPageCallbacks pageCbs,
  ChatBotHostCallbacks hostCbs,
);

class FileUploadInfo {
  String jobId;
  String ctxPath; // path KB
  String fileName;
  TaskStage stage; // pending | running | done | error

  FileUploadInfo({
    required this.jobId,
    required this.ctxPath,
    required this.fileName,
    this.stage = TaskStage.pending,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'ctxPath': ctxPath,
        'fileName': fileName,
        'stage': stage.name,
      };

  factory FileUploadInfo.fromJson(Map<String, dynamic> j) => FileUploadInfo(
        jobId: j['jobId'],
        ctxPath: j['ctxPath'],
        fileName: j['fileName'],
        stage: TaskStage.values
            .firstWhere((e) => e.name == (j['stage'] ?? 'pending')),
      );
      
}

/*─────────────────────────────────────────────────────────────*/
/* EXTENSION: FileUploadInfo ← PendingUploadJob                */
/*─────────────────────────────────────────────────────────────*/
extension FileUploadInfoX on FileUploadInfo {
  /// Costruisce un [FileUploadInfo] a partire da un [PendingUploadJob]
  static FileUploadInfo fromPending(PendingUploadJob job) {
    // lo stato lo deduciamo dal primo task ancora “vivo”, se esiste
    final TaskStage stage = job.tasksPerCtx.values.any(
            (t) => t.loaderTaskId != null || t.vectorTaskId != null)
        ? TaskStage.running
        : TaskStage.pending;

    return FileUploadInfo(
      jobId: job.jobId,
      ctxPath: job.contextPath,
      fileName: job.fileName,
      stage: stage,
    );
  }
}


class _PaginatedDocViewer extends StatefulWidget {
  final ContextApiSdk apiSdk;
  final String        token;

  /// ► Modalità A (legacy): passo direttamente la collection
  final String?       collection;

  /// ► Modalità B (nuova): passo sorgente per calcolare la collection lato server
  final String?       ctx;
  final String?       filename;

  final int           pageSize;

  _PaginatedDocViewer({
    Key? key,
    required this.apiSdk,
    required this.token,
    this.collection,           // ← opzionale
    this.ctx,                  // ← opzionale
    this.filename,             // ← opzionale
    this.pageSize = 1,
  }) : assert(
         // almeno una delle due modalità deve essere valorizzata:
         (collection != null && collection!.isNotEmpty) ||
         ((ctx != null && ctx!.isNotEmpty) && (filename != null && filename!.isNotEmpty)),
         "Devi fornire 'collection' oppure la coppia 'ctx' + 'filename'.",
       ),
       super(key: key);

  @override
  State<_PaginatedDocViewer> createState() => _PaginatedDocViewerState();
}

class _PaginatedDocViewerState extends State<_PaginatedDocViewer> {
  late Future<List<DocumentModel>> _future;
  int  _page  = 0;        // 0-based
  int? _total;

  @override
  void initState() {
    super.initState();
    _future = _fetch();           // ► prima pagina
  }

  /*──────── helper API (skip / limit fissi) ────────*/
  Future<List<DocumentModel>> _fetch() async {
    final skip  = _page * widget.pageSize;
    final limit = widget.pageSize;

    // ► Se ho ctx+filename → nuova API che risolve lato server (hash 15 + "_collection")
    if ((widget.ctx != null && widget.ctx!.isNotEmpty) &&
        (widget.filename != null && widget.filename!.isNotEmpty)) {
      return widget.apiSdk.listDocumentsResolved(
        ctx   : widget.ctx,
        filename: widget.filename,
        token : widget.token,
        skip  : skip,
        limit : limit,
        onTotal: (t) => _total = t,
      );
    }

    // ► Altrimenti fallback legacy su collection (compatibilità)
    return widget.apiSdk.listDocuments(
      widget.collection!,
      token : widget.token,
      skip  : skip,
      limit : limit,              // sempre = pageSize
      onTotal: (t) => _total = t,
    );
  }

  /*──────── cambio pagina (con guard-rail) ────────*/
  void _go(int delta) {
    final next = _page + delta;
    if (next < 0) return;                                   // < 0
    if (_total != null && next * widget.pageSize >= _total!) return; // oltre fine

    setState(() {
      _page   = next;
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width : 400,
      height: 400,
      child : FutureBuilder<List<DocumentModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Text('Errore caricamento documenti: ${snap.error}');
          }

          final docs    = snap.data ?? const <DocumentModel>[];
          final isEmpty = docs.isEmpty;

          final jsonStr = isEmpty
              ? ''
              : const JsonEncoder.withIndent('  ').convert(
                  docs.map((d) => {
                    'page_content': d.pageContent,
                    'metadata'    : d.metadata,
                    'type'        : d.type,
                  }).toList(),
                );

          /*───────── UI completa ─────────*/
          return Column(
            children: [
              /*───── frecce + contatore ─────*/
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip : 'Pagina precedente',
                    icon    : const Icon(Icons.arrow_back_ios_new, size: 16),
                    onPressed: _page == 0 ? null : () => _go(-1),
                  ),
                  Text(
                    _total == null
                      ? 'Pagina ${_page + 1}'
                      : 'Pagina ${_page + 1} / ${(_total! / widget.pageSize).ceil()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  IconButton(
                    tooltip : 'Pagina successiva',
                    icon    : const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: (isEmpty || (_total != null && (_page + 1) * widget.pageSize >= _total!))
                      ? null
                      : () => _go(1),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              /*───── riquadro scroll / placeholder ─────*/
              Expanded(
                child: Container(
                  width : double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isEmpty
                      ? const Center(
                          child: Text(
                            '— Nessun documento disponibile —',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              jsonStr,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize : 12,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
    late final Color statusColor;
    late final Widget trailingSpinner; // usato per PENDING/RUNNING

    switch (info.stage) {
      case TaskStage.pending:
        statusIcon = Icons.schedule;
        statusColor = Colors.orange;
        trailingSpinner = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case TaskStage.running:
        statusIcon = Icons.sync;
        statusColor = Colors.blue;
        trailingSpinner = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case TaskStage.done:
        statusIcon = Icons.check;
        statusColor = Colors.green;
        trailingSpinner = const SizedBox.shrink();
        break;
      case TaskStage.error:
        statusIcon = Icons.error;
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
    if (actions.isEmpty && // per pending/running
        (info.stage == TaskStage.pending || info.stage == TaskStage.running)) {
      actions.add(trailingSpinner);
    }

    final bool showProgress =
        info.stage == TaskStage.pending || info.stage == TaskStage.running;

    return Card(
        elevation: 4,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          ListTile(
            leading: Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(ic['icon'] as IconData,
                    size: 36, color: ic['color'] as Color),
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
          if (showProgress)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(
                minHeight: 3, // sottile e discreta
              ),
            ),
        ]));
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
  final bool startVisible;
  final String? initialChatId; // ✅ NEW: chat da aprire subito (opzionale)
  final String? defaultChainId; // es: "abc123"
  final String? defaultChainConfigId; // es: "abc123_config"
  final Map<String, dynamic>?
      defaultChainConfig; // es. {'model': 'gpt‑4o', 'contexts': ['sales_db']}
  final bool hasSidebar; // true = sidebar presente
  final double sidebarStartMinWidth; // larghezza iniziale se presente
  final double sidebarStartMaxWidth; // larghezza iniziale se presente
  final bool showEmptyChatPlaceholder;
  final bool showUserMenu; // mostra avatar + menu in top-bar
  final bool showTopBarLogo; // logo nella top-bar
  final bool showSidebarLogo; // logo nella sidebar (se esiste)
  final bool showSearchButton;
  final bool showConversationButton;
  final bool showKnowledgeBoxButton;
  final bool showNewChatButton;
  final bool showChatList;
  final ChatBorderStyle borderStyle;
  final ChatBackgroundStyle backgroundStyle;
  final TopBarSeparatorStyle separatorStyle;
  final double topBarMinHeight;
  final Map<String, ChatWidgetBuilder> externalWidgetBuilders;
  final ChatBotHostCallbacks hostCallbacks;

  /// (opzionale) elenco dei tool che il backend deve conoscere
  final List<ToolSpec> toolSpecs;

  ChatBotPage({
    Key? key,
    required this.user,
    required this.token,
    this.startVisible = true,
    this.initialChatId, // = '0e332ebb-2e24-4722-baab-b024342b1f9c',
    this.defaultChainId, // = '28d28fdff',
    this.defaultChainConfigId, // = '28d28fdff_config',
    this.defaultChainConfig,
    this.hasSidebar = true, // ⇦ DEFAULT
    this.sidebarStartMinWidth = 300.0, // ⇦ DEFAULT
    this.sidebarStartMaxWidth = 300.0, // ⇦ DEFAULT
    this.showEmptyChatPlaceholder = true,
    this.showUserMenu = true, // ⇦ DEFAULT
    this.showTopBarLogo = true, // ⇦ DEFAULT
    this.showSidebarLogo = true, // ⇦ DEFAULT
    this.showSearchButton = true,
    this.showConversationButton = true,
    this.showKnowledgeBoxButton = true,
    this.showNewChatButton = true,
    this.showChatList = true,
    this.borderStyle = ChatBorderStyle.def,
    this.backgroundStyle = const ChatBackgroundStyle(),
    this.separatorStyle = TopBarSeparatorStyle.def,
    this.topBarMinHeight = 75.0,
    this.externalWidgetBuilders = const {},
    this.hostCallbacks = const ChatBotHostCallbacks(),
    this.toolSpecs = const [],
  }) : super(key: key);

  @override
  ChatBotPageState createState() => ChatBotPageState();
}

class ChatBotPageState extends State<ChatBotPage> {
  Map<String, dynamic>? _defaultChainConfig;
// ────────────────────────────────────────────────────────────────
// NEW ▸ stato billing (copia locale + guard)
// ────────────────────────────────────────────────────────────────
CurrentPlanResponse? _currentPlan;
UserCreditsResponse? _currentCredits;
bool _paymentsFetchInFlight = false;

CurrentPlanResponse? get currentPlan => _currentPlan;
UserCreditsResponse? get currentCredits => _currentCredits;

  // ───────────────────────────────────────────────────────────
//  NEW STATE – lista di immagini da allegare prima dell'invio
// ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _pendingInputImages = [];

  void _addInputImage(Map<String, dynamic> img) {
    setState(() => _pendingInputImages.add(img));
  }

  void _removeInputImageAt(int idx) {
    setState(() => _pendingInputImages.removeAt(idx));
  }

bool _didRefreshCreditsOnFirstToken = false;
  bool _isSending = false; // spinner sull’icona SEND
  static const int _maxSendRetries = 5;
  late final List<ToolSpec> _toolSpecs;
  late final ChatBotPageCallbacks _pageCbs;
  String? _forcedDefaultChainId;
  String? _forcedDefaultChainConfigId;
  bool _forceInitialChatLoading = false;
  bool _openedWithInitialChat = false; //
  late final bool _mustForceInitialChat = // deciso subito
      (widget.initialChatId?.isNotEmpty ?? false);
  final ContextApiSdk _apiSdk = ContextApiSdk();
  // DOPO
  final Map<String /*jobId*/, PendingUploadJob> _pendingJobs = {};
  String? _chatKbPath; // NEW – path KB legata alla chat
  final Set<String> _syncedMsgIds = {}; // NEW – id dei msg già caricati
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
// ──────────────────────────────────────────────
//  Retry sulla risposta dell’agente
// ──────────────────────────────────────────────
  static const int _maxRetries = 5; // tentativi massimi
  final Map<String, int> _retryCounts = {}; // msgId → tentativi fatti
  /// ---------------------------------------------------------------------------
  ///  Restituisce la stessa struttura che metti nei messaggi “normali”
  ///  (aggiungi qui dentro ogni metadato aggiuntivo che ti serve)             ↓↓
  Map<String, dynamic> _buildCurrentAgentConfig() {
    return {
      'model': _selectedModel,
      'contexts': buildFormattedContextsForAgent(
        widget.user.username,
        _selectedContexts,
        chatKbPath: _chatKbPath,
        chatKbHasDocs: chatKbHasIndexedDocs(
          chatKbPath: _chatKbPath,
          messages: messages,
        ),
      ),
      'chain_id': _latestChainId,
      'config_id': _latestConfigId,
    };
  }

  bool _appReady = false;

/*─────────────────────────────────────────────────────────────────────
  Helper generico: esegue fn() al massimo [retries] volte con back-off
─────────────────────────────────────────────────────────────────────*/
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int retries = 5,
    Duration baseDelay = const Duration(milliseconds: 400),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn(); // 🟢 OK
      } catch (e) {
        attempt += 1;
        if (attempt >= retries) rethrow; // 🔴 esauriti i tentativi
        // solo se è effettivamente un 5xx
        if (e.toString().contains('500')) {
          await Future.delayed(baseDelay * attempt); // back-off lineare
          continue;
        }
        rethrow; // altri errori: propagali
      }
    }
  }

  void _downloadCsv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final r in rows) {
      buffer.writeln(r.map((c) => '"${c.replaceAll('"', '""')}"').join(','));
    }
    final csvStr = buffer.toString();

    final blob = html.Blob([csvStr], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)..download = 'table.csv';
    html.document.body!.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  void _safeSetActiveIdx(int idx) {
    if (idx == 99 && !widget.showSearchButton) return;
    if (idx == 0 && !widget.showConversationButton) return;
    if (idx == 1 && !widget.showKnowledgeBoxButton) return;
    _activeButtonIndex = idx;
  }

  void sendSequenceMessage(String text, String sequenceId) {
    _handleUserInput(text, sequenceId: sequenceId);
  }

/// PUBLIC – chiamabile dallo State‐ful host:
///
/// • `visibility`    = kVisNormal | kVisInvisible | kVisPlaceholder
/// • `displayText`   = facoltativo, usato solo se visibility == 'placeholder'
Future<void> sendHostMessage(String text,
    { String visibility = kVisNormal, String? displayText }) async {

  await _handleUserInput(
    text,
    visibility: visibility,
    displayText: displayText,
  );
}

/*─────────────────────────────────────────────────────────────*/
/* PUBLIC API  ➜  elenco file presenti nella chat corrente    */
/*─────────────────────────────────────────────────────────────*/
List<FileUploadInfo> getChatFiles({
  bool includePending = true,
  bool includeRunning = true,
  bool includeDone    = true,
  bool includeError   = true,
}) {
  final List<FileUploadInfo> out = [];

  // ❶  file “materializzati” dentro i messaggi
  for (final m in messages) {
    final dyn = m['fileUpload'];
    if (dyn is Map) {
      final info = FileUploadInfo.fromJson(Map<String, dynamic>.from(dyn));

      switch (info.stage) {
        case TaskStage.pending:
          if (includePending) out.add(info);
          break;
        case TaskStage.running:
          if (includeRunning) out.add(info);
          break;
        case TaskStage.done:
          if (includeDone) out.add(info);
          break;
        case TaskStage.error:
          if (includeError) out.add(info);
          break;
      }
    }
  }

  // ❷  job ancora in polling ma che non hanno (ancora) prodotto il messaggio
  for (final job in _pendingJobs.values) {
    if (out.any((e) => e.jobId == job.jobId)) continue; // già presente
    final info = FileUploadInfoX.fromPending(job);

    switch (info.stage) {
      case TaskStage.pending:
        if (includePending) out.add(info);
        break;
      case TaskStage.running:
        if (includeRunning) out.add(info);
        break;
      default:
        break; // DONE / ERROR saranno sincronizzati dal poller
    }
  }

  return out;
}

final TextEditingController _dlNameCtrl = TextEditingController();


/// PUBLIC – caricamento file dall’host.
/// • `bytes` / `fileName` = file effettivo
/// • `loaderConfig`      = mappa "loaders"/"loader_kwargs"
///   – se null mostri il dialogo di scelta
Future<void> uploadFileFromHost(
  Uint8List bytes,
  String fileName, {
  Map<String, String>?   loaders,
  Map<String, Map<String, dynamic>>? loaderKwargs,
}) async {

  final Map<String, dynamic>? cfg =
      (loaders != null && loaderKwargs != null)
          ? {'loaders': loaders, 'loader_kwargs': loaderKwargs}
          : null;                                   // forza dialogo

  await _uploadFileForChatAsync(                  // funzione già esistente
      isMedia: false,
      externalBytes: bytes,
      externalFileName: fileName,
      externalLoaderConfig: cfg,
  );
}

/// Scarica un file presente nella chat *corrente* partendo dal suo nome.
/// Ritorna i bytes (Uint8List) se il file esiste, altrimenti `null`.
Future<Uint8List?> downloadFileBytesByName(String fileName) async {
  // ❶ cerchiamo il FileUploadInfo corrispondente
  final info = getChatFiles().firstWhereOrNull(
      (f) => f.fileName.toLowerCase() == fileName.toLowerCase());

  if (info == null) return null; // nessun file con quel nome

  // ❷ costruiamo il file_id nello stesso formato usato da downloadFile()
  final String fileId =
      "${widget.user.username}-${info.ctxPath}/${info.fileName}";

  // ❸ scarichiamo i bytes dalla SDK
  return await _apiSdk.fetchFileBytes(
    fileId,
    token: widget.token.accessToken,
  );
}

/// Variante “convenience” che apre direttamente la finestra di download
Future<void> downloadFileByName(String fileName) async {
  final bytes = await downloadFileBytesByName(fileName);
  if (bytes == null) return; // file non trovato

  // Solo Web: creiamo il blob e lanciamo il download
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}


// Streaming in corso?
  bool _isStreaming = false;

  // ──────────────────────────────────────────────────────────────
//  PUBLIC API – stato dello stream
//  Accessible via  chatKey.currentState?.isAssistantStreaming
// ──────────────────────────────────────────────────────────────
bool get isAssistantStreaming => _isStreaming;
// ─────────────────────────────────────────────────────────────
//  cost‑estimate  (widget ChatBotPageState)
// ─────────────────────────────────────────────────────────────
  InteractionCost? _baseCost; // baseline ufficiale (arriva UNA volta)
  double _liveCost = 0;
  bool _isCostLoading = false;

// ─────────────────────────────────────────────────────────────
//  util: stima rapida token → #char / 4
// ─────────────────────────────────────────────────────────────
  int _estimateTokens(String txt) => (txt.length / 4).ceil();
// ─────────────────────────────────────────────────────────────
//  helper: converte messages ➔ chat_history per il backend
// ─────────────────────────────────────────────────────────────
  List<List<String>> _transformChatHistory(List<Map<String, dynamic>> msgs) {
    // tieni solo user / assistant, in ordine cronologico
    return msgs
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .map((m) {
      final role = m['role'] as String? ?? 'assistant';
      var txt = m['content'] as String? ?? '';

      // rimuovi eventuali spinner / placeholder di caret
      txt = txt.replaceAll("[WIDGET_SPINNER]", "").replaceAll("▌", "");

      return [role, txt];
    }).toList();
  }

  /// ❶  backend – una sola volta per configurazione
  Future<void> _fetchInitialCost() async {
    if (_latestChainId?.isEmpty ?? true) return;

    setState(() => _isCostLoading = true);
    try {
      _baseCost = await _apiSdk.estimateChainInteractionCost(
        chainId: _latestChainId!,
        message: "",
        chatHistory: _transformChatHistory(messages),
      );
      _liveCost = _baseCost!.costTotalUsd;
    } catch (e) {
      debugPrint('[cost] errore: $e');
    } finally {
      if (mounted)
        setState(() {
          _isCostLoading = false;
        }); // F‑6
    }
  }

  /// ❷  live‑preview mentre l’utente digita
  void _updateLiveCost(String draft) {
    if (_baseCost == null) return;

    final newTokensUser = _estimateTokens(draft);

    final est = _apiSdk.recomputeInteractionCost(
      _baseCost!,
      configOverride: {
        'tokens_user': newTokensUser,
        'tokens_history': _baseCost!.params['tokens_history'], // int safe
      },
    );

    setState(() => _liveCost = est.costTotalUsd);
  }

  /// ❸  roll‑forward: nuova baseline in locale
  ///
  ///  sentTxt  → contenuto appena inviato dall’utente
  ///  outTok   → token di output dell’assistente (reali o stimati)
  void _advanceBaseline(String sentTxt, int outTok) {
    if (_baseCost == null) return;

    final sentTok = _estimateTokens(sentTxt);
    final oldHist = (_baseCost!.params['tokens_history'] as int?) ?? 0; // F‑3

    _baseCost = _apiSdk.recomputeInteractionCost(
      _baseCost!,
      configOverride: {
        'tokens_history': oldHist + sentTok + outTok,
        'tokens_user': 0, // reset per il turno dopo
      },
    );

    _liveCost = _baseCost!.costTotalUsd;
    setState(() {}); // refresh UI
  }

// Riferimenti per cancellare lo stream
  dynamic _streamReader; // il reader JS
  dynamic _abortController; // AbortController
  final FocusNode _inputFocus = FocusNode();
// ──────────────────────────────────────────────────────────────────

  static final ValueNotifier<bool> cancelSequences =
      ValueNotifier(false); // NEW

// ────────────────────────────────────────────────────────────────
//  CONFIG DI DEFAULT (usata quando apri una chat “vergine”)
// ────────────────────────────────────────────────────────────────
  static const String _defaultModel = 'gpt-4o'; // cambia se ti serve

  static const _prefsKeyPending = 'kb_pending_jobs';
// ──────────────────────────────────────────────────────────────────
//  Prepara (se serve) la chain per la chat *corrente*
//
//  • se esiste già una chain-id valida ⇒ non fa nulla
//  • altrimenti:
//      1. assicura la KB della chat               (_chatKbPath)
//      2. crea una chain nuova con SOLO quella KB
// ──────────────────────────────────────────────────────────────────
  Future<void> _prepareChainForCurrentChat({bool allowCreateKb = true}) async {
    if (_latestChainId != null && _latestChainId!.isNotEmpty) return;

    await _applyForcedDefaultChainIfNeeded();
    if (_latestChainId != null && _latestChainId!.isNotEmpty) return;

    // 1‧ assicura KB
    final chatId =
        _getCurrentChatId().isEmpty ? uuid.v4() : _getCurrentChatId();
    final chatName = (_activeChatIndex != null)
        ? _chatHistory[_activeChatIndex!]['name']
        : 'New Chat';

    // <-- BLOCCO CAMBIATO
    final needKb = _chatKbPath == null &&
        allowCreateKb &&
        messages.isNotEmpty; // crea solo se c'è almeno 1 msg

    if (needKb) {
      _chatKbPath = await ensureChatKb(
        api: _contextApiSdk,
        userName: widget.user.username,
        accessToken: widget.token.accessToken,
        chatId: chatId,
        chatName: chatName,
        currentKbPath: _chatKbPath, // passa quello attuale (può essere null)
      );
    }

    // 2‧ chain con SOLO la KB-chat
    await set_context(
        buildRawContexts(
          _selectedContexts,
          chatKbPath: _chatKbPath,
          chatKbHasDocs: chatKbHasIndexedDocs(
            chatKbPath: _chatKbPath,
            messages: messages,
          ),
        ),
        _selectedModel);
    await _fetchInitialCost(); // unica call al backend
  }

  Future<void> _savePendingJobs(Map<String, PendingUploadJob> jobs) async {
    // ① costruisci un vero Map<String,dynamic>
    final Map<String, dynamic> activeJobs = {
      for (final e in jobs.entries)
        if (e.value.tasksPerCtx.values
            .any((t) => t.loaderTaskId != null || t.vectorTaskId != null))
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
      default: // fallback *non è* più errore
        return TaskStage.pending;
    }
  }

// all’interno di ChatBotPageState
  bool _isChainLoading = false; // ← spinner / disabilita invio

  /// All’interno di ChatBotPageState:
  Future<void> _uploadFileForChatAsync({
    required bool isMedia,
   Uint8List? externalBytes,
   String?    externalFileName,
   Map<String,dynamic>? externalLoaderConfig,
}) async {
    if (_chatKbPath == null) {
      await _prepareChainForCurrentChat(allowCreateKb: true);
    }

    // 1. scelta file -----------------------------------------------------------
  final Uint8List bytes;
  final String    fName;

  if (externalBytes != null && externalFileName != null) {
    // ► upload invocato dall’host
    bytes = externalBytes;
    fName = externalFileName;
  } else {
    // ► upload avviato dall’utente → apri file‑picker
    final result = await FilePicker.platform.pickFiles(
     type: isMedia ? FileType.media : FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;
    bytes = result.files.first.bytes!;
    fName = result.files.first.name;
  }

    // 2. assicura che la KB della chat esista -------------------------------
    final String chatId =
        _getCurrentChatId().isEmpty ? uuid.v4() : _getCurrentChatId();
    final String chatName = (_activeChatIndex != null)
        ? _chatHistory[_activeChatIndex!]['name']
        : 'New Chat';

    if (_chatKbPath == null) {
      _chatKbPath = await ensureChatKb(
        api: _contextApiSdk,
        userName: widget.user.username,
        accessToken: widget.token.accessToken,
        chatId: chatId,
        chatName: chatName,
        currentKbPath: _chatKbPath, // passa quello attuale (può essere null)
      );
    }

final curPlan = BillingGlobals.snap.plan;
final subId   = _readSubscriptionId(curPlan);

    // ─────────────────────────────────────────────────────────────────────────
    // 3. apri dialog per configurare il loader + stima costo live ------------
    // Se l’utente annulla, esci senza fare nulla
    final loaderConfig = externalLoaderConfig ??
     await showLoaderConfigDialog(context, fName, bytes);
  if (loaderConfig == null) return;              // utente ha annullato

    // 4. chiamata POST /upload_async con i parametri scelti nell’UI ---------
    final resp = await _contextApiSdk.uploadFileToContextsAsync(
      bytes,
      [_chatKbPath!], // contesti (solo la KB chat)
      widget.user.username,
      widget.token.accessToken,
      subscriptionId: subId,
      fileName: fName,
      loaders: loaderConfig['loaders'] as Map<String, String>,
      loaderKwargs:
          loaderConfig['loader_kwargs'] as Map<String, Map<String, dynamic>>,
    );

    // ⬇⬇⬇  NEW: refresh crediti non-bloccante (subito dopo l’upload)
_scheduleCreditsRefresh();

    final Map<String, TaskIdsPerContext> tasksPerCtx = resp.tasks;

    // 5. registra job + notifica overlay ------------------------------------
    final String jobId = const Uuid().v4();
    _onNewPendingJob(jobId, chatId, _chatKbPath!, fName, tasksPerCtx);

    _pendingJobs[jobId] = PendingUploadJob(
      jobId: jobId,
      chatId: chatId,
      contextPath: _chatKbPath!,
      fileName: fName,
      tasksPerCtx: tasksPerCtx,
    );
    await _savePendingJobs(_pendingJobs); // persistenza

    // 6. aggiungi il messaggio in chat con badge di upload ------------------
    setState(() {
      messages.add({
        'id': uuid.v4(),
        'role': 'user',
        'content': 'File "$fName" caricato',
        'createdAt': DateTime.now().toIso8601String(),
        'fileUpload': FileUploadInfo(
          jobId: jobId,
          ctxPath: _chatKbPath!,
          fileName: fName,
          stage: TaskStage.pending,
        ).toJson(),
        'agentConfig': _buildCurrentAgentConfig(),
      });

      _saveConversation(messages);
    });
  }

  void _onNewPendingJob(
    String jobId,
    String chatId, // NEW
    String ctxPath,
    String fileName,
    Map<String, TaskIdsPerContext> tasksPerCtx,
  ) {
    // display-name visibile nella card
    final displayName = _availableContexts
            .firstWhere((c) => c.path == ctxPath,
                orElse: () =>
                    ContextMetadata(path: ctxPath, customMetadata: {}))
            .customMetadata?['display_name'] as String? ??
        ctxPath;

    // ① notifica visuale
    _taskNotifications[jobId] = TaskNotification(
      jobId: jobId,
      contextPath: ctxPath,
      contextName: displayName,
      fileName: fileName,
      stage: TaskStage.pending,
    );

    // ② dati per il polling
    _pendingJobs[jobId] = PendingUploadJob(
      jobId: jobId,
      chatId: chatId, // NEW
      contextPath: ctxPath,
      fileName: fileName,
      tasksPerCtx: tasksPerCtx,
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
    if (chatKbHasIndexedDocs(
      chatKbPath: _chatKbPath,
      messages: messages,
    )) {
      await set_context(
          buildRawContexts(
            _selectedContexts,
            chatKbPath: _chatKbPath,
            chatKbHasDocs: chatKbHasIndexedDocs(
              chatKbPath: _chatKbPath,
              messages: messages,
            ),
          ),
          _selectedModel);
      await _fetchInitialCost(); // unica call al backend
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
      (n) => n.isVisible && contextIsKnown(n.contextPath, _availableContexts),
    );
    if (!hasVisible) {
      // …ma tieniti pronto ad inserirlo alla prossima card “visibile”
      if (_notifOverlay != null) {
        _notifOverlay!.remove(); // chiude solo il widget overlay
        _notifOverlay = null;
      }
      return;
    }

    // ② se l’overlay non c’è più, ricrealo (non tocca il poller)
    if (_notifOverlay == null) {
      _startNotifOverlay(); // inserisce overlay ma **non** un nuovo timer
    } else {
      _notifOverlay!.markNeedsBuild();
    }
  }

  /// Ferma lo stream attivo **e** persiste lo stato corrente della chat.
  /// Chiama questa funzione PRIMA di cambiare chat / sezione /
  /// modello di UI, così da non portarsi dietro lo stream.
  void _cancelActiveStreamAndPersist() {
    if (!_isStreaming) return; // niente da fare

    // 1‧ interrompe fetch / reader
    _stopStreaming(); // già presente nel codice

    // 2‧ ripulisce l’ultimo messaggio assistant da spinner/caret
    if (messages.isNotEmpty && messages.last['role'] == 'assistant') {
      final m = messages.last;
      m['content'] = (m['content'] as String)
          .replaceAll("[WIDGET_SPINNER]", "")
          .replaceAll("▌", "");
    }

    // 3‧ salva la conversazione nella **chat corrente**
    _saveConversation(messages);
  }

// ─────────────────────────────────────────────
//  METODI PUBBLICI INVOCABILI DALL'HOST
// ─────────────────────────────────────────────

/// ID della chat attualmente aperta.
/// Ritorna `null` se l’utente non ha ancora selezionato/creato alcuna chat.
String? getCurrentChatId() =>
    (_activeChatIndex != null && _chatHistory.isNotEmpty)
        ? _chatHistory[_activeChatIndex!]['id'] as String
        : null;

/// Ritorna la **lista delle chat** SENZA il campo `messages`,
/// così il payload rimane leggero.
/// Ritorna la lista delle chat con *solo* i campi essenziali
/// (id, name, createdAt, updatedAt, kb_path).
List<Map<String, dynamic>> getChatList() {
  const allowed = <String>{
    'id',
    'name',
    'createdAt',
    'updatedAt',
    'kb_path',
  };

  return _chatHistory.map<Map<String, dynamic>>((orig) {
    final filtered = <String, dynamic>{};
    for (final k in allowed) {
      if (orig.containsKey(k)) filtered[k] = orig[k];
    }
    return filtered;
  }).toList();
}


/// Ritorna la *copia profonda* della chat corrispondente all’ID dato,
/// `null` se non esiste.  Include **tutti** i campi, quindi anche `messages`.
Map<String, dynamic>? getChatById(String chatId) {
  final chat = _chatHistory.firstWhereOrNull((c) => c['id'] == chatId);
  return chat != null
      ? jsonDecode(jsonEncode(chat)) as Map<String, dynamic>
      : null;
}

/// Carica la chat con l’ID indicato.  
/// Ritorna `true` se la chat esiste e viene aperta, `false` altrimenti.
Future<bool> openChatById(String chatId) async {
  final exists = _chatHistory.any((c) => c['id'] == chatId);
  if (!exists) return false;
  await _loadMessagesForChat(chatId);
  return true;
}

/// Crea e seleziona immediatamente una nuova chat.
Future<void> newChat() async => _startNewChat();

// ─────────────────────────────────────────────
//  CONFIGURAZIONI DELLE CHAIN
// ─────────────────────────────────────────────

/// Scarica dal backend la configurazione completa (JSON) di una chain.
/// Puoi indicare `chainId`, `configId` o entrambi.
/// Ritorna `null` se la configurazione non esiste o in caso di errore.
Future<Map<String, dynamic>?> fetchChainConfig({
  String? chainId,
  String? configId,
}) async {
  if ((chainId == null || chainId.isEmpty) &&
      (configId == null || configId.isEmpty)) return null;

  try {
    final cfg = await _contextApiSdk.getChainConfiguration(
      chainId: chainId,
      chainConfigId: configId,
      token: widget.token.accessToken,
    );

    // Cast “sicuro” a Map<String,dynamic>
    return cfg.extraMetadata;//Map<String, dynamic>.from(jsonDecode(jsonEncode(cfg)));
  } catch (e) {
    debugPrint('[fetchChainConfig] errore: $e');
    return null;
  }
}

/// Imposta la *chain di default* che ChatBotPage tenterà di usare
/// all’avvio o quando crea una nuova chat.
/// – se passi `config` (mappa JSON) questa ha la precedenza assoluta  
/// – altrimenti usa `chainId` e/o `configId` (come prima)  
void setDefaultChain({
  String? chainId,
  String? configId,
  Map<String, dynamic>? config,
}) {
  if (config != null) {
    // forziamo un override completo con il JSON fornito
    _defaultChainConfig = Map<String, dynamic>.from(config);
    _forcedDefaultChainId = null;
    _forcedDefaultChainConfigId = null;
  } else {
    // override tramite identificativi
    _forcedDefaultChainId = chainId;
    _forcedDefaultChainConfigId = configId;
    _defaultChainConfig = null;
  }
}


  Future<void> _restoreChainForCurrentChat(
      {bool skipInheritance = false}) async {
    String? chainIdCandidate = _latestChainId;

    // 1) prova dall'ultimo messaggio (solo se NON vuoi saltare l’eredità)
    if (!skipInheritance && messages.isNotEmpty) {
      final cfg = messages.last['agentConfig'] as Map<String, dynamic>?;
      final cand = cfg?['chain_id'] as String?;
      if (cand != null && cand.isNotEmpty) chainIdCandidate = cand;
    }

    // 2) fallback localStorage (solo se NON vuoi saltare l’eredità)
    if (!skipInheritance &&
        (chainIdCandidate == null || chainIdCandidate.isEmpty)) {
      final ls = html.window.localStorage['latestChainId'];
      if (ls != null && ls.isNotEmpty) chainIdCandidate = ls;
    }

    // 3) chat nuova / nessun chainId -> usa prima la forced default
    if (chainIdCandidate == null || chainIdCandidate.isEmpty) {

            final List<String> ctxs =
          List<String>.from(_defaultChainConfig!['contexts'] ?? const []);
      final String mdl = _defaultChainConfig?['model_name'] ?? _defaultModel;
      final String sysMsg = _defaultChainConfig?["system_message"];
      final List<Map<String, dynamic>> srvrTls =
          _defaultChainConfig?["custom_server_tools"];

      // tenta la chain forzata
      await _applyForcedDefaultChainIfNeeded();
      if (_latestChainId?.isNotEmpty == true) {
        await _fetchInitialCost();
        return;
      }

      // fallback vecchio comportamento (crea KB ecc.)
      await _prepareChainForCurrentChat();
      /*_selectedModel =
          _selectedModel.isNotEmpty ? _selectedModel : _defaultModel;*/

      /*final effectiveRaw = _stripUserPrefixList(
        buildRawContexts(
          _selectedContexts,
          chatKbPath: _chatKbPath,
          chatKbHasDocs: chatKbHasIndexedDocs(
            chatKbPath: _chatKbPath,
            messages: messages,
          ),
        ),
      );*/


      final resp = await _contextApiSdk.configureAndLoadChain(
        widget.user.username,
        widget.token.accessToken,
        ctxs,
        mdl,
        systemMessageContent: sysMsg,
        customServerTools: srvrTls,
        toolSpecs: _toolSpecs,
      );

      _latestChainId = resp['load_result']?['chain_id'] as String?;
      _latestConfigId = resp['config_result']?['config_id'] as String?;

      html.window.localStorage['latestChainId'] = _latestChainId ?? '';
      html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';

      await _fetchInitialCost();
      return;
    }

    // 4) recupera config dal backend e riconfigura
    try {
      final cfg = await _contextApiSdk.getChainConfiguration(
        chainId: chainIdCandidate,
        token: widget.token.accessToken,
      );
      await _reconfigureFromChainConfig(cfg);
    } catch (e) {
      debugPrint('getChainConfiguration fallita: $e');
      // fallback: prova forced default, poi default locale
      await _applyForcedDefaultChainIfNeeded();
      if (_latestChainId?.isNotEmpty != true) {
        await _prepareChainForCurrentChat();
      }
      await _fetchInitialCost();
    }
  }

  List<String> _extractContextsFromConfig(ChainConfiguration cfg) {
    final extra = cfg.extraMetadata ?? const <String, dynamic>{};
    final ctx = extra['contexts'];
    if (ctx is List) {
      return ctx.cast<String>();
    }
    return const <String>[];
  }

  String _extractModelFromConfig(ChainConfiguration cfg) {
    final extra = cfg.extraMetadata ?? const <String, dynamic>{};
    final model = extra['model_name'];

    return model;
  }

  List<Map<String, dynamic>> _extractCusotmServerToolsFromConfig(
      ChainConfiguration cfg) {
    final extra = cfg.extraMetadata ?? const <String, dynamic>{};
    final model = extra['custom_server_tools'];

    return model;
  }

  String _extractSystemMessageContentFromConfig(ChainConfiguration cfg) {
    final extra = cfg.extraMetadata ?? const <String, dynamic>{};
    final model = extra['system_message_content'];

    return model;
  }

  Future<void> _reconfigureFromChainConfig(ChainConfiguration cfg) async {
    // contexts dal backend (ripulisci doppione KB-chat)
    final extracted = _extractContextsFromConfig(cfg);
    _selectedContexts = extracted
        .where((c) => c != _chatKbPath) // evita duplicare la KB della chat
        .toList();

    // modello
    _selectedModel = _extractModelFromConfig(cfg);

    // contesti effettivi = scelti + KB-chat (se ha docs)
    final effectiveRaw = _stripUserPrefixList(
      buildRawContexts(
        _selectedContexts,
        chatKbPath: _chatKbPath,
        chatKbHasDocs: chatKbHasIndexedDocs(
          chatKbPath: _chatKbPath,
          messages: messages,
        ),
      ),
    );

    final resp = await _contextApiSdk.configureAndLoadChain(
      widget.user.username,
      widget.token.accessToken,
      effectiveRaw,
      _selectedModel,
      systemMessageContent: _extractSystemMessageContentFromConfig(cfg),
      customServerTools: _extractCusotmServerToolsFromConfig(cfg),
      toolSpecs: _toolSpecs,
    );

    setState(() {
      _latestChainId = resp['load_result']?['chain_id'] as String?;
      _latestConfigId = resp['config_result']?['config_id'] as String?;
    });

    html.window.localStorage['latestChainId'] = _latestChainId ?? '';
    html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';

    //_syncLastMessageAgentConfig();
    await _fetchInitialCost();
  }

  /// Rimuove il prefisso "<username>-" se presente.
  String _stripUserPrefix(String ctx) {
    final prefix = "${widget.user.username}-";
    return ctx.startsWith(prefix) ? ctx.substring(prefix.length) : ctx;
  }

  /// Applica lo strip a tutta la lista e de-duplica.
  List<String> _stripUserPrefixList(Iterable<String> ctxs) {
    final prefix = "${widget.user.username}-";
    final set = <String>{};
    for (final c in ctxs) {
      set.add(c.startsWith(prefix) ? c.substring(prefix.length) : c);
    }
    return set.toList();
  }

  /// Restituisce una lista dove coppie USER/AI con stesso sequenceId
  /// Fusiona in un unico “super-messaggio” tutte le coppie user+assistant
  /// che condividono lo stesso sequenceId.
  ///
  /// Il risultato è una lista di Map pronta per _buildMessagesList:
  /// - messaggi “normali” rimangono invariati
  /// - per ogni gruppo di coppie (user, assistant) emesso un singolo:
  ///   {
  ///     'role'      : 'sequence',
  ///     'sequenceId': <sid>,
  ///     'createdAt' : <timestamp più vecchio del gruppo>,
  ///     'steps'     : [
  ///       { 'instruction': <Map user>, 'response': <Map assistant> },
  ///       …
  ///     ],
  ///   }
  /// Scansione lineare di `src`: mantiene l’ordine e
  /// inserisce la super-sequenza esattamente dove è nata.
  /// 
  // Dentro ChatBotPageState
String _userInputPrefix = '';

/// Imposta/aggiorna il prefisso da pre‑appendere a TUTTI i prossimi input utente
void setUserInputPrefix(String prefix) {
  _userInputPrefix = prefix.trim();
}

/// Cancella il prefisso
void clearUserInputPrefix() => _userInputPrefix = '';

  List<Map<String, dynamic>> _mergeSequences(List<Map<String, dynamic>> src) {
    final out = <Map<String, dynamic>>[]; // output finale
    final seen = <String>{}; // sequenceId già emessi

    int i = 0;
    while (i < src.length) {
      final msg = src[i];
      final sid = msg['sequenceId'] as String?;

      // 1) messaggio “normale”
      if (sid == null) {
        out.add(msg);
        i += 1;
        continue;
      }

      // 2) se questo sequenceId è già stato raggruppato, salto
      if (seen.contains(sid)) {
        out.add(msg); // o puoi anche saltare del tutto, a seconda del fallback
        i += 1;
        continue;
      }

      // 3) nuovo blocco di sequenza → raccolgo tutte le coppie user+assistant
      final steps = <Map<String, Map<String, dynamic>>>[];
      DateTime? earliest;

      while (i + 1 < src.length &&
          src[i]['sequenceId'] == sid &&
          src[i]['role'] == 'user' &&
          src[i + 1]['role'] == 'assistant' &&
          src[i + 1]['sequenceId'] == sid) {
        final instr = Map<String, dynamic>.from(src[i]);
        final resp = Map<String, dynamic>.from(src[i + 1]);

        steps.add({
          'instruction': instr,
          'response': resp,
        });

        final t = DateTime.tryParse(instr['createdAt'] ?? '') ?? DateTime.now();
        earliest = earliest == null || t.isBefore(earliest) ? t : earliest;

        i += 2; // salto la coppia
      }

      // 4) emetto la “super-sequenza” subito qui
      if (steps.isNotEmpty) {
        out.add({
          'role': 'sequence',
          'sequenceId': sid,
          'createdAt': (earliest ?? DateTime.now()).toIso8601String(),
          'steps': steps,
        });
        seen.add(sid);
      } else {
        // fallback: nessuna coppia valida → ricaduta sul singolo
        out.add(msg);
        i += 1;
      }
    }

    return out;
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
      /*ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat renamed to "$newName"')),
      );*/
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

  String _getCurrentChatId() {
    if (_activeChatIndex != null && _chatHistory.isNotEmpty) {
      return _chatHistory[_activeChatIndex!]['id'] as String;
    }
    return "";
  }

// adatta builder con 2 argomenti  →  ChatWidgetBuilder
// adattatore per i widget legacy che vogliono 2 parametri
  ChatWidgetBuilder _wrap2(
    Widget Function(
      Map<String, dynamic>,
      void Function(String reply, {Map<String, dynamic>? meta}),
    ) builder, // <─ firma aggiornata
  ) {
    return (data, onReply, pageCbs, hostCbs) => builder(
          data,
          // inoltra anche il named-parameter `meta`
          (txt, {meta}) => onReply(txt, meta: meta),
        );
  }

// Mappa di funzioni: un widget ID -> funzione che crea il Widget corrispondente
  Map<String, ChatWidgetBuilder> get _internalWidgetMap => {
        "ShowChatVarsWidget": _wrap2((data, onReply) => ShowChatVarsWidgetTool(
              jsonData: data,
              getVars: () =>
                  _chatVars, // ← mappa che contiene tutte le chatVars
            )),
        "ChatVarsWidget": _wrap2((data, onReply) => ChatVarsWidgetTool(
              jsonData: data,
              applyPatch: _applyChatVars, // callback definita al § 1.4
            )),
        "FileUploadWidget": _wrap2((data, onReply) => FileUploadWidget(
              info: FileUploadInfo.fromJson(data),
              onDownload: () {
                final fPath = "${data['ctxPath']}/${data['fileName']}";
                _apiSdk.downloadFile(fPath, token: widget.token.accessToken);
              },
            )),
        "ToolEventWidget": _wrap2((data, onReply) =>
            ToolEventCard(data: data)), // non serve onReply qui
        "JSRunnerWidget":
            _wrap2((data, onReply) => JSRunnerWidgetTool(jsonData: data)),
        "AutoSequenceWidget": (data, onReply, pageCbs, hostCbs) =>
            AutoSequenceWidgetTool(
              jsonData: data,
              onReply: (txt, {meta}) {
                // firma estesa
                final seq = meta?['sequenceId'] as String?;
                if (seq != null) {
                  pageCbs.sendReply(txt,
                      sequenceId: seq); // passa l’id a ChatBot
                } else {
                  pageCbs.sendReply(txt); // messaggio normale
                }
              },
            ),
        "NButtonWidget": _wrap2(
            (data, onReply) => NButtonWidget(data: data, onReply: onReply)),
        "RadarChart": _wrap2((data, onReply) =>
            RadarChartWidgetTool(jsonData: data, onReply: onReply)),
        "TradingViewAdvancedChart": _wrap2((data, onReply) =>
            TradingViewAdvancedChartWidget(jsonData: data, onReply: onReply)),
        "TradingViewMarketOverview": _wrap2((data, onReply) =>
            TradingViewMarketOverviewWidget(jsonData: data, onReply: onReply)),
        "CustomChartWidget": _wrap2((data, onReply) =>
            CustomChartWidgetTool(jsonData: data, onReply: onReply)),
        "ChangeChatNameWidget":
            _wrap2((data, onReply) => ChangeChatNameWidgetTool(
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
                )),
        "SpinnerPlaceholder": _wrap2((data, onReply) => const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("Caricamento in corso..."),
                  SizedBox(width: 8),
                  CircularProgressIndicator(),
                ],
              ),
            )),
      };

  Map<String, ChatWidgetBuilder> get widgetMap =>
      {..._internalWidgetMap, ...widget.externalWidgetBuilders};

// ─── stato “variabili di chat” ──────────────────────────────────────────
  Map<String, dynamic> _chatVars = {}; // <── NEW


Future<void> _downloadDocumentsJsonByName(String ctx, String fname, String baseFileName) async {
  final docs = await _apiSdk.listDocumentsResolved(
    ctx: ctx, filename: fname, token: widget.token.accessToken,
  );

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
String _extractCtx(String rawPath) {
  final i = rawPath.indexOf('/');
  return i < 0 ? rawPath : rawPath.substring(0, i);
}

String _extractFilename(String rawPath, String fallbackUiName) {
  // rawPath tipicamente "ctx/filename.ext"; se manca "/", ripiega su titolo UI
  final i = rawPath.indexOf('/');
  return i < 0 ? fallbackUiName : rawPath.substring(i + 1);
}

void _showFilePreviewDialog(Map<String, dynamic> file, String fileName) {
  final raw = (file['name'] as String?) ?? '';
  final ctx = _extractCtx(raw);
  final fname = _extractFilename(raw, fileName);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding   : const EdgeInsets.fromLTRB(16,16,16,0),
      contentPadding : const EdgeInsets.fromLTRB(16,8,16,16),

      /*──────────────────────── titolo + pulsante download ─────────────────────*/
      title: Row(
        children: [
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Scarica JSON documenti',
            icon   : const Icon(Icons.download),
            onPressed: () => _downloadDocumentsJsonByName(ctx, fname, fileName),
          ),
        ],
      ),

      /*──────────────────────── corpo paginato (Stateful) ──────────────────────*/
 content: _PaginatedDocViewer(
   apiSdk   : _apiSdk,
   token    : widget.token.accessToken,
   ctx      : ctx,          // ← NEW
   filename : fname,        // ← NEW
   pageSize : 1,
 ),

      actions: [
        TextButton(
          child: const Text('Chiudi'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

  Widget _buildMixedContent(Map<String, dynamic> message) {
    // Se il messaggio non contiene nessuna lista di widget, rendiamo il testo direttamente

    // messaggio "speciale" di upload file
    if (message.containsKey('fileUpload')) {
      final info = FileUploadInfo.fromJson(
          (message['fileUpload'] as Map).cast<String, dynamic>());
      return FileUploadWidget(
        info: info,
        onDownload: () {
          final fPath =
              "${widget.user.username}-${info.ctxPath}/${info.fileName}";
          _apiSdk.downloadFile(fPath, token: widget.token.accessToken);
        },
        onViewDocs: () {
          // ri-usa lo stesso dialog che hai nella ContextPage
          _showFilePreviewDialog(
            {
              'name':
                  "${widget.user.username}-${info.ctxPath}/${info.fileName}",
              'path':
                  "${widget.user.username}-${info.ctxPath}/${info.fileName}",
              'custom_metadata': {'file_uuid': info.jobId}
            },
            info.fileName,
          );
        },
      );
    }

    // ─────────────────────────────────────────────────────────────
    // 1) NEW: prendi le immagini allegate al messaggio
    // ─────────────────────────────────────────────────────────────
    final List<Map<String, dynamic>> attachedImages = (message['input_images']
                as List?) // <<< cambia qui se il tuo campo ha un altro nome
            ?.cast<Map<String, dynamic>>() ??
        const [];

    final widgetDataList = message['widgetDataList'] as List<dynamic>?;
    if (widgetDataList == null || widgetDataList.isEmpty) {
      final isUser = (message['role'] == 'user');
      final widgets = <Widget>[];

 // ▼▼ nuovo: applica correttamente la visibilità
  final String textContent =
      message[kMsgVisibility] == kVisPlaceholder
          ? (message[kMsgDisplayText] ?? '')
          : (message['content'] ?? '');

      // NEW: galleria in alto se ci sono immagini
      if (attachedImages.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ImagesGallery(
              images: attachedImages,
              apiSdk: _apiSdk, // NEW
              onTapImage: (index) {
                openFullScreenGallery(
                    context, attachedImages, index, _apiSdk); // NEW
              },
            ),
          ),
        );
      }
      // Testo
      if (textContent.isNotEmpty)  
      widgets.add(
        _buildMessageContent(
        context,
        textContent,                  //  ← usa la logica sopra
          isUser,
          userMessageColor: Colors.white,
          assistantMessageColor: Colors.white,
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    // Costante per lo spinner
    const spinnerPlaceholder = "[WIDGET_SPINNER]";

    // Otteniamo il testo completo “pulito” (con i placeholder) dal messaggio
    final textContent =
      message[kMsgVisibility] == kVisPlaceholder
          ? (message[kMsgDisplayText] ?? '')
          : (message['content'] ?? '');

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
    // NEW: galleria in alto
    if (attachedImages.isNotEmpty) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ImagesGallery(
            images: attachedImages,
            apiSdk: _apiSdk, // NEW
            onTapImage: (index) {
              openFullScreenGallery(
                  context, attachedImages, index, _apiSdk); // NEW
            },
          ),
        ),
      );
    }
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
            final ChatWidgetBuilder? builder = widgetMap[widgetId];
            if (builder != null) {
              embeddedWidget = builder(
                jsonData,

                /*  LAMBDA CORRETTA  */
                (reply, {meta}) {
                  final seq = meta?['sequenceId'] as String?;
                  _handleUserInput(reply,
                      sequenceId: seq); // seq può essere null
                },
                _pageCbs,
                widget.hostCallbacks,
              );
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
        //"nlp_api": "http://127.0.0.1:8777",
        "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
        //"chatbot_nlp_api": "http://127.0.0.1:8888"
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

  Future<void> _applyForcedDefaultChainIfNeeded() async {
    // 0) se l’host ha passato un dict di configurazione usalo subito
    if (_defaultChainConfig != null &&
        (_latestChainId == null || _latestChainId!.isEmpty)) {
      final List<String> ctxs =
          List<String>.from(_defaultChainConfig!['contexts'] ?? const []);
      final String mdl = _defaultChainConfig?['model_name'] ?? _defaultModel;
      final String sysMsg = _defaultChainConfig?["system_message"];
      final List<Map<String, dynamic>> srvrTls =
          _defaultChainConfig?["custom_server_tools"];

      final resp = await _contextApiSdk.configureAndLoadChain(
        widget.user.username,
        widget.token.accessToken,
        _stripUserPrefixList(ctxs), // rimuove eventuale "<user>-"
        mdl,
        systemMessageContent: sysMsg,
        customServerTools: srvrTls,
        toolSpecs: _toolSpecs,
      );

      _latestChainId = resp['load_result']?['chain_id'] as String?;
      _latestConfigId = resp['config_result']?['config_id'] as String?;

      // (in alternativa – se volete evitare duplicazione di logica):
      final cfg = await _contextApiSdk.getChainConfiguration(
         chainId: _latestChainId, token: widget.token.accessToken);
       await _reconfigureFromChainConfig(cfg);

      html.window.localStorage['latestChainId'] = _latestChainId ?? '';
      html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';
      await _fetchInitialCost(); // baseline costi

      return; // termina qui: forced‑chain non serve
    }

    // se NON ho forced o ho già una chain -> niente
    if ((_forcedDefaultChainId == null || _forcedDefaultChainId!.isEmpty) &&
        (_forcedDefaultChainConfigId == null ||
            _forcedDefaultChainConfigId!.isEmpty)) {
      return;
    }
    if (_latestChainId != null && _latestChainId!.isNotEmpty) return;

    try {
      // 1) prendo la config (serve per conoscere model/contexts)
      final cfg = await _contextApiSdk.getChainConfiguration(
        chainId: _forcedDefaultChainId,
        chainConfigId: _forcedDefaultChainConfigId,
        token: widget.token.accessToken,
      );

      // 2) re-installa la chain localmente (come fai già in _reconfigureFromChainConfig)
      await _reconfigureFromChainConfig(cfg);

      // 3) salviamo subito in localStorage
      html.window.localStorage['latestChainId'] = _latestChainId ?? '';
      html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';

      // 4) baseline costi
      await _fetchInitialCost();
    } catch (e, st) {
      debugPrint('[forcedChain] errore: $e\n$st');
      // fallback: crea come prima
      await _prepareChainForCurrentChat(allowCreateKb: false);
      await _fetchInitialCost();
    }
  }

  late Future<void> _chatHistoryFuture;

  late bool _uiVisible;

  /// Rende la UI visibile / invisibile. Può essere invocato dall’host.
  void setUiVisibility(bool visible) {
    if (visible == _uiVisible) return;
    setState(() => _uiVisible = visible);
  }

  /// Shortcut comodo per il caller.
  void toggleUiVisibility() => setUiVisibility(!_uiVisible);

  /// Per sapere dallo host lo stato corrente.
  bool get isUiVisible => _uiVisible;


// ChatBotPageState

bool _creditsRefreshInFlight = false;

/// Refresh "leggero" dei crediti: non blocca la UI.
/// - se conosciamo già il piano (_currentPlan), evitiamo round-trip extra
/// - altrimenti usiamo getCurrentPlanOrNull
Future<void> _refreshCreditsFast() async {
  if (_creditsRefreshInFlight) return;
  _creditsRefreshInFlight = true;
  try {
    final tok = widget.token.accessToken;

    // 1) Piano (preferisci cache locale se presente)
    CurrentPlanResponse? plan = _currentPlan;
    plan ??= await _apiSdk.getCurrentPlanOrNull(tok);

    if (plan == null) {
      // nessuna subscription attiva
      _currentPlan = null;
      _currentCredits = null;
      BillingGlobals.setNoPlan();
      if (mounted) setState(() {}); // ridisegna pill
      return;
    }

    // 2) Crediti con subscription_id (più veloce/selettivo lato backend)
    final credits = await _apiSdk.getUserCredits(tok, subscriptionId: plan.subscriptionId);

    // 3) aggiorna stato + notifier globale (Top-Bar si aggiorna da sola)
    _currentPlan = plan;
    _currentCredits = credits;
    BillingGlobals.setData(plan: plan, credits: credits);
    if (mounted) setState(() {}); // opzionale
  } catch (e) {
    // non bloccare: esponi errore “soft” e prosegui
    BillingGlobals.setError(e);
  } finally {
    _creditsRefreshInFlight = false;
  }
}

/// Schedula senza await (non blocca)
void _scheduleCreditsRefresh() {
  unawaited(_refreshCreditsFast());
}


Future<void> _fetchPaymentsInfo() async {
  try {
    final tok = widget.token.accessToken;


// 1) Piano corrente (404 => nessuna subscription attiva)
// ✅ DOPO (ritorna null se 404, niente eccezioni)
final plan = await _apiSdk.getCurrentPlanOrNull(tok);
_currentPlan = plan;

final bool noPlan = (plan == null);

    // 2) Crediti
    dynamic credits;
    if (!noPlan && plan != null) {
      try {
        credits =
            await _apiSdk.getUserCredits(tok, subscriptionId: plan.subscriptionId);
      } catch (_) {
        // fallback senza subscriptionId
        credits = await _apiSdk.getUserCredits(tok);
      }
      _currentCredits = credits;
    } else {
      // Richiesta: “crediti nulli” se l’utente non ha piani
      credits = null;
      _currentCredits = null;
    }

    // 3) Aggiorna lo stato GLOBALE reattivo (usato dalla UI)
    if (noPlan) {
      BillingGlobals.setNoPlan();
    } else {
      BillingGlobals.setData(plan: plan, credits: credits);
    }

    // (facoltativo) mantieni anche queste vecchie assegnazioni se le usi altrove
    // BillingGlobals.currentPlan / userCredits sono già disponibili via getter
    // BillingGlobals.lastUpdated è nel notifier (snapshot)

    // Notifica UI immediata locale se serve
    if (mounted) setState(() {});
  } catch (e) {
    debugPrint('[payments] fetch error: $e');
    BillingGlobals.setError(e); // sblocca lo spinner anche in errore
  } finally {
    _paymentsFetchInFlight = false;
  }
}

void _kickoffPaymentsFetch() {
  if (_paymentsFetchInFlight) return;
  _paymentsFetchInFlight = true;

  // Stato globale: sta caricando
  BillingGlobals.setLoading();

  // Avvia senza bloccare l’init (unawaited)
  unawaited(_fetchPaymentsInfo());
}

  @override
  void initState() {
    super.initState();

    _defaultChainConfig = widget.defaultChainConfig;
    _forceInitialChatLoading = _mustForceInitialChat; // 🔹 evita il flash

    _forcedDefaultChainId = widget.defaultChainId;
    _forcedDefaultChainConfigId = widget.defaultChainConfigId;

    _pageCbs = ChatBotPageCallbacks(
      renameChat: _renameChat,
      sendReply: (txt, {sequenceId}) =>
          _handleUserInput(txt, sequenceId: sequenceId),
    );

    _toolSpecs = widget.toolSpecs;

    _initStateAsync(); // parte subito ma resta fuori dal build

    _uiVisible = widget.startVisible; // ⬅ inizializza
    
    _initStateAsync(); // parte subito ma resta fuori dal build

      // ─────────────────────────────────────────────────────────────
  // NEW ▸ fai partire il recupero piano/crediti in background
  //      (non blocca il resto dell'init e dell'UI)
  // ─────────────────────────────────────────────────────────────
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _kickoffPaymentsFetch(); // NON await
  });
  
  }

  /// helper “completo” (può usare await senza problemi)
  Future<void> _initStateAsync() async {
    // ────────────────────────────────────────────────────────────────
    // ① bootstrap: config + contesti
    // ────────────────────────────────────────────────────────────────
    await _bootstrap();

    // ────────────────────────────────────────────────────────────────
    // ② carica *e aspetta* la chat-history (così sappiamo se esistono chat/messaggi)
    // ────────────────────────────────────────────────────────────────
    _chatHistoryFuture = _loadChatHistory();
    await _chatHistoryFuture; // ← attesa effettiva

    // ────────────────────────────────────────────────────────────────
    // ③ se ci è stato passato un chatId, prova ad aprirlo SUBITO
    // ────────────────────────────────────────────────────────────────
    if (_mustForceInitialChat) {
      // lo spinner è già true da initState
      final exists = _chatHistory.any((c) => c['id'] == widget.initialChatId);
      if (exists) {
        await _loadMessagesForChat(widget.initialChatId!);
        _openedWithInitialChat = true;
      }
      _forceInitialChatLoading = false; // chiudi spinner
      if (mounted) setState(() {}); // refresh finale
    }

    // ────────────────────────────────────────────────────────────────
    // ④ prepara la chain SOLO se non abbiamo già aperto una chat iniziale
    //     (niente KB se chat vuota)
    // ────────────────────────────────────────────────────────────────
    if (!_openedWithInitialChat) {
      // prima prova a usare la chain forzata
      await _applyForcedDefaultChainIfNeeded();

      // se ancora non ho una chain, fai come prima
      if (_latestChainId == null || _latestChainId!.isEmpty) {
        await _prepareChainForCurrentChat(allowCreateKb: false);
      }
    }
    // ────────────────────────────────────────────────────────────────
    // ④ notifiche & inizializzazioni varie
    // ────────────────────────────────────────────────────────────────
    _initTaskNotifications();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    // ────────────────────────────────────────────────────────────────
    // ⑤ listener & scroll
    // ────────────────────────────────────────────────────────────────
    _controller.addListener(() => setState(() {}));

    _messagesScrollController.addListener(() {
      final maxScroll = _messagesScrollController.position.maxScrollExtent;
      final currentScroll = _messagesScrollController.position.pixels;
      final shouldShow = currentScroll < maxScroll - 20;
      final scrolledDown = currentScroll > _lastScrollPosition + 50;
      _lastScrollPosition = currentScroll;
      final newValue = shouldShow && !scrolledDown;
      if (newValue != _showScrollToBottomButton) {
        setState(() => _showScrollToBottomButton = newValue);
      }
    });

    // ────────────────────────────────────────────────────────────────
    // ⑥ crea (o verifica) il DB – **attendi** prima di sbloccare la UI
    // ────────────────────────────────────────────────────────────────
    await _databaseService.createDatabase('database', widget.token.accessToken);

    // ────────────────────────────────────────────────────────────────
    // ⑦ ripristina eventuali ID di chain salvati in precedenza
    // ────────────────────────────────────────────────────────────────
    _latestChainId = html.window.localStorage['latestChainId'];
    _latestConfigId = html.window.localStorage['latestConfigId'];

    // ────────────────────────────────────────────────────────────────
    // ⑧ se abbiamo già una chat attiva o messaggi caricati,
    //    ripristina la chain (senza forzare la creazione della KB)
    // ────────────────────────────────────────────────────────────────
    if (_activeChatIndex != null || messages.isNotEmpty) {
      await _restoreChainForCurrentChat(); // assicurati che dentro non crei KB
    }

    // ────────────────────────────────────────────────────────────────
    // ⑨ tutto pronto → alza il flag (solo se il widget è ancora montato)
    // ────────────────────────────────────────────────────────────────
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
  bool _isCtxLoading = false; // evita fetch concorrenti

  Future<void> _loadAvailableContexts() async {
    if (_isCtxLoading) return; // già in fetch
    setState(() => _isCtxLoading = true); // spinner on

    try {
      final ctx = await fetchAvailableContexts(
        _contextApiSdk,
        username: widget.user.username,
        accessToken: widget.token.accessToken,
      );

      // ri-utilizziamo la *stessa* lista per non perdere i riferimenti
      setState(() {
        _availableContexts
          ..clear()
          ..addAll(ctx);
      });
    } finally {
      setState(() => _isCtxLoading = false); // spinner off
    }
  }

// Inserisci in ChatBotPageState
  void _applyChatVars(Map<String, dynamic> patch) {
    _chatVars.addAll(patch);
    _saveConversation(messages); // persiste subito
    setState(() {}); // force-refresh eventuali widget
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
          'table': ScrollableTableBuilder(onDownload: _downloadCsv),
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

// ────────────────────────────────────────────────────────────────────
// 3. FUNZIONE RISCRITTA: usa il merge ↑ e gestisce il nuovo tipo
// ────────────────────────────────────────────────────────────────────
  List<Widget> _buildMessagesList(double containerWidth) {
    final loc = LocalizationProvider.of(context);


  final displayMsgs = _mergeSequences(
  messages.where((m) => m[kMsgVisibility] != kVisInvisible).toList());


    final widgets = <Widget>[];

    for (int i = 0; i < displayMsgs.length; i++) {
      final message = displayMsgs[i];
      final role = message['role'] as String? ?? 'assistant';

      // ───── date-separator identico a prima ───────────────
      final DateTime parsedTime =
          DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
      if (i == 0 ||
          !_isSameDay(
            parsedTime,
            DateTime.tryParse(displayMsgs[i - 1]['createdAt'] ?? '') ??
                parsedTime,
          )) {
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

      // ───── CASE 1: messaggio “sequence” raggruppato ───────
      if (role == 'sequence') {
        widgets.add(
          _SequenceCard(
            key: ValueKey('${_getCurrentChatId()}_${message['sequenceId']}'),
            seqMsg: message,
            containerWidth: containerWidth,
            buildMixedContent: (msg) => _buildMixedContent(msg),
          ),
        );
        continue;
      }

      // ───── CASE 2: messaggi normali (stesso layout di prima) ─────
      final bool isUser = (role == 'user');
      final String formattedTime = DateFormat('h:mm a').format(parsedTime);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: containerWidth, minWidth: 200),
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
                      // RIGA 2: Contenuto del messaggio (Markdown + widget)
                      _buildMixedContent(message),
                      const SizedBox(height: 8.0),
                      // RIGA 3: Icone azione
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            tooltip: loc.copy,
                            onPressed: () =>
                                _copyToClipboard(message['content'] ?? ''),
                          ),
                          if (!isUser) ...[
                            IconButton(
                              icon: const Icon(Icons.thumb_up, size: 14),
                              tooltip: loc.positive_feedback,
                              onPressed: () => print(
                                  "Feedback positivo: ${message['content']}"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.thumb_down, size: 14),
                              tooltip: loc.negative_feedback,
                              onPressed: () => print(
                                  "Feedback negativo: ${message['content']}"),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 14),
                            tooltip: loc.volume,
                            onPressed: () => _speak(message['content'] ?? ''),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 14),
                            tooltip: loc.messageInfoTitle,
                            onPressed: () => _showMessageInfoDialog(message),
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
    final raw = prefs.getString('kb_pending_jobs');
    if (raw == null) return;

    final Map<String, dynamic> stored = jsonDecode(raw);

    stored.forEach((String jobId, dynamic j) {
      final ctx = j['contextPath'] ?? 'unknown_ctx';
      final fileName = j['fileName'] ?? 'file';

      // — migration: se chatId non esiste, lo ricaviamo dal chatHistory
      final String chatId = j['chatId'] ?? _findChatIdForJob(jobId);

      // display-name (se _availableContexts è già popolato)
      final displayName = _availableContexts
              .firstWhere(
                (c) => c.path == ctx,
                orElse: () =>
                    ContextMetadata(path: ctx, customMetadata: const {}),
              )
              .customMetadata?['display_name'] as String? ??
          ctx;

      // notifica overlay
      _taskNotifications[jobId] = TaskNotification(
        jobId: jobId,
        contextPath: ctx,
        contextName: displayName,
        fileName: fileName,
        stage: TaskStage.pending,
      );

      // pending-job per il poller
      if (j['tasksPerCtx'] != null) {
        _pendingJobs[jobId] = PendingUploadJob(
          jobId: jobId,
          chatId: chatId,
          contextPath: ctx,
          fileName: fileName,
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
        return; // niente GET se non c’è nulla da controllare
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
          (e) => e.value.tasksPerCtx.values
              .any((t) => t.loaderTaskId == tid || t.vectorTaskId == tid),
        );

        if (jobEntry == null) return; // nessun job corrispondente ⇒ ignora
        final String jobId = jobEntry.key;
        final job = jobEntry.value;
        final String chatId = job.chatId; // può essere vuoto
        final bool hasChat = chatId.isNotEmpty; // <── NOVITÀ

        final newStage = _mapStatus(st.status);

// ▼▼▼ BLOCCO A ▼▼▼  (pulisce job/task risolti)
        if (newStage == TaskStage.done || newStage == TaskStage.error) {
          // 1. togli questo taskId dal job
          job.tasksPerCtx.removeWhere(
              (ctx, t) => t.loaderTaskId == tid || t.vectorTaskId == tid);

          // 2. se non resta alcun task attivo → rimuovi l’intero job
          final allResolved = job.tasksPerCtx.values
              .every((t) => t.loaderTaskId == null && t.vectorTaskId == null);

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
              _reconfigureChainIfNeeded(chatId); // <── nuovo helper
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
            await _databaseService
                .updateCollectionData(
                  "${widget.user.username}-database",
                  'chats',
                  chat['_id'],
                  {
                    'updatedAt': chat['updatedAt'],
                    'messages': chat['messages'],
                  },
                  widget.token.accessToken,
                )
                .catchError((_) {}); // race-condition: ignora
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
      notif.isVisible = false; // solo nascosta (potrà ri-apparire)
    }

    setState(() {}); // refresh locale
    _refreshNotifOverlay(); // refresh (o chiusura) overlay

    // ── B.  decidiamo se interrompere il poller ────────────────────────────
    // se restano job PENDING/RUNNING (anche se invisibili) il poller deve
    // restare vivo.
    final stillActive = _taskNotifications.values.any(
        (n) => n.stage == TaskStage.pending || n.stage == TaskStage.running);

    if (!stillActive) {
      // tutti i job ormai sono DONE/ERROR e le card sono state nascoste o rimosse
      _notifPoller?.cancel();
      _notifPoller = null;
    }
  }

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
        child: IgnorePointer(
          // clic “pass-through” tranne la X
          ignoring: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _taskNotifications.values
                    .where((n) =>
                        n.isVisible &&
                        contextIsKnown(n.contextPath, _availableContexts))
                    .map(_buildNotifCard)
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _stopStreaming() {
    // 1) blocca il reader se è vivo
    if (_streamReader != null) {
      js_util.callMethod(_streamReader, 'cancel', []);
    }

    // 2) o, se hai usato AbortController, abortisci la fetch
    if (_abortController != null) {
      js_util.callMethod(_abortController, 'abort', []);
    }

    // 3) reset stato UI
    setState(() => _isStreaming = false);

    // 3️⃣ avvisa tutte le Auto-Sequence di interrompersi
    cancelSequences.value = true; // emette il segnale
    // subito dopo lo rimettiamo a false, così un secondo STOP
    // invierà un nuovo fronte di discesa
    Future.microtask(() => cancelSequences.value = false);
  }

  Widget _buildNotifCard(TaskNotification n) {
    // ─────────────────────────────  icona / colore / etichetta per stage
    late final IconData icon;
    late final Color color;
    late final String statusLabel;

    switch (n.stage) {
      case TaskStage.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        statusLabel = 'In coda…';
        break;
      case TaskStage.running:
        icon = Icons.sync;
        color = Colors.blue;
        statusLabel = 'In corso…';
        break;
      case TaskStage.done:
        icon = Icons.check_circle;
        color = Colors.green;
        statusLabel = 'Completato!';
        break;
      case TaskStage.error:
        icon = Icons.error;
        color = Colors.red;
        statusLabel = 'Errore ❗';
        break;
    }

    // ─────────────────────────────  card vera e propria
    return Dismissible(
      key: ValueKey(n.jobId), // ► chiave = jobId
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



// ─────────────────────────────────────────────────────────────
// Letture sicure (riuso con i modelli del tuo SDK o Map)
// ─────────────────────────────────────────────────────────────
num? _readNum(dynamic obj, String camel, String snake) {
  try { final v = obj?.toJson()?[camel]; if (v is num) return v; } catch (_) {}
  try { final v = obj?[camel]; if (v is num) return v; } catch (_) {}
  try { if (obj is Map && obj[camel] is num) return obj[camel] as num; } catch (_) {}
  try { if (obj is Map && obj[snake] is num) return obj[snake] as num; } catch (_) {}
  return null;
}

Widget _spinnerPill({
  required EdgeInsetsGeometry padding,
  required double borderRadius,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black12),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Caricamento…', style: TextStyle(fontSize: 13, color: Colors.black87)),
      ],
    ),
  );
}

Widget _errorPill({
  required String message,
  required EdgeInsetsGeometry padding,
  required double borderRadius,
  double fontSize = 13,
  double iconSize = 16,
}) {
  return Tooltip(
    message: message,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: iconSize, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Text('Crediti: —', style: TextStyle(fontSize: fontSize, color: Colors.red.shade700)),
        ],
      ),
    ),
  );
}

// ⬇⬇⬇ Sostituisci la vecchia versione con questa ⬇⬇⬇
Widget _buildTopbarCreditsPillWithText({
  double fontSize = 14,
  double iconSize = 18,
  EdgeInsetsGeometry padding =
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  double borderRadius = 28,
}) {
  final snap = BillingGlobals.notifier.value;

  // Evita overflow su schermi molto stretti: in questo caso mostriamo comunque,
  // ma potresti decidere di ridurre font/padding se vuoi.
  // final w = MediaQuery.of(context).size.width;

  // 1) FETCH IN CORSO → rotella
  if (!snap.hasFetched || snap.isLoading) {
    return _spinnerPill(padding: padding, borderRadius: borderRadius);
  }

  // 2) ERRORE NON-404 → pill rossa con tooltip (credits null per errore)
  if (snap.error != null) {
    return _errorPill(
      message: snap.error!,
      padding: padding,
      borderRadius: borderRadius,
      fontSize: fontSize,
      iconSize: iconSize,
    );
  }

  // 3) NESSUN PIANO ATTIVO → mostra 0 (credits null per "no plan")
  if (!snap.hasActiveSubscription) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Icon(Icons.attach_money_outlined, size: iconSize, color: Colors.black87),
          //const SizedBox(width: 8),
          Text('Crediti: 0', style: TextStyle(fontSize: fontSize, color: Colors.black87)),
        ],
      ),
    );
  }

  // 4) PIANO ATTIVO → prova a leggere i numeri; se mancanti, mostra "—"
  final credits   = snap.credits;
  num? remaining  = _readNum(credits, 'remainingTotal', 'remaining_total');
  num? used       = _readNum(credits, 'usedTotal', 'used_total');
  num? provided   = _readNum(credits, 'providedTotal', 'provided_total');

  final text    = (remaining != null) ? '$remaining' : 'Crediti: —';
  final tooltip = 'Restanti: ${remaining ?? '—'} • Usati: ${used ?? '—'} • Totali: ${provided ?? '—'}';

  return Tooltip(
    message: tooltip,
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //Icon(Icons.attach_money_outlined, size: iconSize, color: Colors.black87),
          //const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: fontSize, color: Colors.black87)),
        ],
      ),
    ),
  );
}

Future<void> _openBillingPageFromTopbar() async {
  // usa un SDK già esistente se lo hai (_apiSdk); altrimenti creane uno al volo
  final ContextApiSdk sdk = (_apiSdk ?? ContextApiSdk());
  if (_apiSdk == null) {
    try { await sdk.loadConfig(); } catch (_) {}
  }

  if (!mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BillingPage(
        onClose: () => Navigator.of(context).pop(),
        sdk: sdk,
        token: widget.token.accessToken, // già usato altrove
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    final bs = widget.borderStyle;
    final bg = widget.backgroundStyle;
    return Offstage(
        offstage: !_uiVisible, // true ⇒ invisibile
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Row(
            children: [
              // Barra laterale con possibilità di ridimensionamento
              if (widget.hasSidebar)
                GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (isExpanded) {
                      setState(() {
                        sidebarWidth +=
                            details.delta.dx; // Ridimensiona la barra laterale
                        if (sidebarWidth < widget.sidebarStartMinWidth)
                          sidebarWidth =
                              widget.sidebarStartMinWidth; // Larghezza minima
                        if (sidebarWidth > widget.sidebarStartMaxWidth)
                          sidebarWidth =
                              widget.sidebarStartMaxWidth; // Larghezza massima
                      });
                    }
                  },
                  child: AnimatedContainer(
                    // ➊ Padding condizionale: 16 px solo se la sidebar è aperta
                    padding: EdgeInsets.only(left: isExpanded ? 16.0 : 0.0),
                    // lo spostamento orizzontale viene ora gestito dal padding
                    margin: EdgeInsets.zero,
                    duration: Duration(
                        milliseconds:
                            300), // Animazione per l'espansione e il collasso
                    width:
                        sidebarWidth, // Usa la larghezza calcolata (può essere 0 se collassato)
                    decoration: BoxDecoration(
                      color: Colors
                          .white, // Colonna laterale con colore personalizzato
                      /*boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
        blurRadius: 8.0, // Sfocatura dell'ombra
        offset: Offset(2, 0), // Posizione dell'ombra (x, y)
      ),
    ],*/
                    ),
                    child:
                        MediaQuery.of(context).size.width < 600 ||
                                sidebarWidth > 0
                            ? Column(
                                children: [
                                  // Linea di separazione bianca tra AppBar e sidebar
                                  Container(
                                    width: double.infinity,
                                    height: 2.0, // Altezza della linea
                                    color: Colors
                                        .white, // Colore bianco per la linea
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Titolo a sinistra
                                        if (widget.showSidebarLogo)
                                          fullLogo
                                        else
                                          const SizedBox(
                                              width:
                                                  1), // occupa appena 1 px e non si vede

                                        // ❷ spinge SEMPRE l’icona del menu all’estrema destra
                                        const Spacer(),
                                        // Icona di espansione/contrazione a destra
                                        IconButton(
                                          icon: _appReady
                                              ? SvgPicture.network(
                                                  'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
                                                  width: 24,
                                                  height: 24,
                                                  color: Colors.grey)
                                              : const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)),
                                          onPressed: _appReady
                                              ? () {
                                                  setState(() {
                                                    isExpanded = !isExpanded;
                                                    if (isExpanded) {
                                                      sidebarWidth =
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  600
                                                              ? MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width
                                                              : 300.0;
                                                    } else {
                                                      sidebarWidth = 0.0;
                                                    }
                                                  });
                                                }
                                              : () {},
                                        ),
                                      ],
                                    ),
                                  ),

// Sezione fissa con le voci principali

// Pulsante "Cerca"
                                  if (widget.showSearchButton)
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
                                            onNavigateToMessage: (String chatId,
                                                String messageId) {
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
                                                ? const Color.fromARGB(
                                                    255, 224, 224, 224)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12.0, horizontal: 16.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.search,
                                                  size: 24.0,
                                                  color: Colors.black),
                                              const SizedBox(width: 8.0),
                                              Text(
                                                localizations.searchButton,
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

// Pulsante "Conversazione"
                                  if (widget.showConversationButton)
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
                                          _cancelActiveStreamAndPersist(); // 🔹 NEW
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
                                          if (MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600) {
                                            setState(() {
                                              sidebarWidth =
                                                  0.0; // Collassa la barra laterale
                                            });
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(
                                              4.0), // Margini laterali
                                          decoration: BoxDecoration(
                                            color: _buttonHoveredIndex == 0 ||
                                                    _activeButtonIndex == 0
                                                ? const Color.fromARGB(
                                                    255,
                                                    224,
                                                    224,
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
                                  if (widget.showKnowledgeBoxButton)
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
                                          _cancelActiveStreamAndPersist(); // 🔹 NEW
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
                                          if (MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600) {
                                            setState(() {
                                              sidebarWidth =
                                                  0.0; // Collassa la barra laterale
                                            });
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(
                                              4.0), // Margini laterali
                                          decoration: BoxDecoration(
                                            color: _buttonHoveredIndex == 1 ||
                                                    _activeButtonIndex == 1
                                                ? const Color.fromARGB(
                                                    255,
                                                    224,
                                                    224,
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
                                  if (widget.showChatList)
                                    Expanded(
                                      child: FutureBuilder(
                                        future:
                                            _chatHistoryFuture, // Assicurati che le chat siano caricate
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }

                                          // Raggruppa le chat in base alla data di aggiornamento
                                          final groupedChats =
                                              _groupChatsByDate(_chatHistory);

                                          // Filtra le sezioni per rimuovere quelle vuote
                                          final nonEmptySections = groupedChats
                                              .entries
                                              .where((entry) =>
                                                  entry.value.isNotEmpty)
                                              .toList();

                                          if (nonEmptySections.isEmpty) {
                                            return Center(
                                              child: Text(
                                                localizations.noChatAvailable,
                                                style: TextStyle(
                                                    color: Colors.white70),
                                              ),
                                            );
                                          }

                                          return ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors
                                                        .transparent, // Mantiene opaco
                                                    Colors
                                                        .transparent, // Ancora opaco
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
                                                    bottom:
                                                        32.0), // Spazio extra in fondo
                                                itemCount: nonEmptySections
                                                    .length, // Numero delle sezioni non vuote
                                                itemBuilder:
                                                    (context, sectionIndex) {
                                                  final section =
                                                      nonEmptySections[
                                                          sectionIndex];
                                                  final sectionTitle = section
                                                      .key; // Ottieni il titolo della sezione
                                                  final chatsInSection = section
                                                      .value; // Ottieni le chat di quella sezione

                                                  return Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Intestazione della sezione
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8.0,
                                                                vertical: 4.0),
                                                        child: Text(
                                                          sectionTitle, // Titolo della sezione
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ),
                                                      // Lista delle chat di questa sezione
                                                      ...chatsInSection
                                                          .map((chat) {
                                                        final chatName = chat[
                                                                'name'] ??
                                                            'Chat senza nome'; // Nome della chat
                                                        final chatId = chat[
                                                            'id']; // ID della chat
                                                        final isActive =
                                                            _activeChatIndex ==
                                                                _chatHistory
                                                                    .indexOf(
                                                                        chat); // Chat attiva
                                                        final isHovered =
                                                            hoveredIndex ==
                                                                _chatHistory
                                                                    .indexOf(
                                                                        chat); // Chat in hover

                                                        return MouseRegion(
                                                          onEnter: (_) {
                                                            setState(() {
                                                              hoveredIndex =
                                                                  _chatHistory
                                                                      .indexOf(
                                                                          chat); // Aggiorna hover
                                                            });
                                                          },
                                                          onExit: (_) {
                                                            setState(() {
                                                              hoveredIndex =
                                                                  null; // Rimuovi hover
                                                            });
                                                          },
                                                          child:
                                                              GestureDetector(
                                                            onTap: () {
                                                              _loadMessagesForChat(
                                                                  chatId); // Carica messaggi della chat
                                                              setState(() {
                                                                _activeChatIndex =
                                                                    _chatHistory
                                                                        .indexOf(
                                                                            chat); // Imposta la chat attiva
                                                                _activeButtonIndex =
                                                                    null; // Deseleziona i pulsanti principali
                                                                showKnowledgeBase =
                                                                    false; // Deseleziona "Basi di conoscenza"
                                                                showSettings =
                                                                    false; // Deseleziona "Impostazioni"
                                                              });
                                                              if (MediaQuery.of(
                                                                          context)
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
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isHovered ||
                                                                        isActive
                                                                    ? const Color
                                                                        .fromARGB(
                                                                        255,
                                                                        224,
                                                                        224,
                                                                        224) // Colore scuro per hover o selezione
                                                                    : Colors
                                                                        .transparent, // Sfondo trasparente quando non attivo
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4.0), // Arrotonda gli angoli
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          4.0,
                                                                      horizontal:
                                                                          16.0),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      chatName,
                                                                      maxLines:
                                                                          1, // 👉 mai andare a capo
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis, // 👉 “…”
                                                                      softWrap:
                                                                          false, // 👉 disabilita il wrap
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight: isActive
                                                                            ? FontWeight.bold
                                                                            : FontWeight.normal,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Theme(
                                                                      data: Theme.of(
                                                                              context)
                                                                          .copyWith(
                                                                        popupMenuTheme:
                                                                            PopupMenuThemeData(
                                                                          shape:
                                                                              RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(16),
                                                                          ),
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                      child: PopupMenuButton<
                                                                          String>(
                                                                        offset: const Offset(
                                                                            0,
                                                                            32),
                                                                        borderRadius:
                                                                            BorderRadius.circular(16), // Imposta un raggio di 8
                                                                        color: Colors
                                                                            .white,
                                                                        icon:
                                                                            Icon(
                                                                          Icons
                                                                              .more_horiz,
                                                                          color: (isHovered || isActive)
                                                                              ? Colors.black // Colore bianco per l'icona in hover o selezione
                                                                              : Colors.transparent, // Nascondi icona se non attivo o in hover
                                                                        ),
                                                                        padding:
                                                                            EdgeInsets.only(right: 4.0), // Riduci margine destro
                                                                        onSelected:
                                                                            (String
                                                                                value) {
                                                                          if (value ==
                                                                              'delete') {
                                                                            _deleteChat(_chatHistory.indexOf(chat)); // Elimina la chat
                                                                          } else if (value ==
                                                                              'edit') {
                                                                            _showEditChatDialog(_chatHistory.indexOf(chat)); // Modifica la chat
                                                                          } else if (value ==
                                                                              'archive') {
                                                                            _archiveChat(_chatHistory.indexOf(chat));
                                                                          }
                                                                        },
                                                                        itemBuilder:
                                                                            (BuildContext
                                                                                context) {
                                                                          return [
                                                                            PopupMenuItem(
                                                                              value: 'edit',
                                                                              child: Text(localizations.edit),
                                                                            ),
                                                                            PopupMenuItem(
                                                                                value: 'archive',
                                                                                child: Text(localizations.archive)),
                                                                            PopupMenuItem(
                                                                              value: 'delete',
                                                                              child: Text(localizations.delete),
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
                                  if (widget.showNewChatButton)
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
                    margin: bs.margin, // margine esterno
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      // ─── SFONDO ────────────────────────────────────────────────
                      color: bg.baseColor, // altrimenti usa il colore scelto
                      gradient: bg.useGradient
                          ? RadialGradient(
                              center:
                                  bg.gradientCenter, // es. Alignment(0.5, 0.25)
                              radius: bg.gradientRadius, // es. 1.2
                              colors: [bg.gradientInner, bg.gradientOuter],
                              stops: const [
                                0.0,
                                1.0
                              ], // es. [Color(0xFFC7E6FF), Colors.white]
                            )
                          : null,

                      // ─── BORDO ────────────────────────────────────────────────
                      borderRadius: BorderRadius.circular(bs.radius),
                      border: bs.visible
                          ? Border.all(
                              color: bs.color,
                              width: bs.thickness,
                            )
                          : null, // nessun bordo se visibile = false
                    ),
                    child: Column(children: [
                      // Nuova top bar per info e pulsante utente
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        // ❶ garantisce SEMPRE l’altezza minima voluta
                        constraints:
                            BoxConstraints(minHeight: widget.topBarMinHeight),

                        // ❷ background rimane trasparente come prima
                        decoration:
                            const BoxDecoration(color: Colors.transparent),

                        // ❸ la Row originale resta identica:
                        child: Row(
                          children: [
                            SizedBox(height: widget.topBarMinHeight, width: 0),
                            // Lato sinistro: un Expanded per allineare a sinistra
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (sidebarWidth == 0.0) ...[
                                    if (widget.hasSidebar)
                                      IconButton(
                                        icon: _appReady
                                            ? SvgPicture.network(
                                                'https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
                                                width: 24,
                                                height: 24,
                                                color: Colors.grey)
                                            : const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                    strokeWidth:
                                                        2)), //const Icon(Icons.menu,
                                        //color: Colors.black),
                                        onPressed: _appReady
                                            ? () {
                                                setState(() {
                                                  isExpanded = true;
                                                  sidebarWidth = MediaQuery.of(
                                                                  context)
                                                              .size
                                                              .width <
                                                          600
                                                      ? MediaQuery.of(context)
                                                          .size
                                                          .width
                                                      : 300.0;
                                                });
                                              }
                                            : () {},
                                      ),
                                    const SizedBox(width: 8),
                                    if (widget.showTopBarLogo) fullLogo,
                                  ],
                                ],
                              ),
                            ),




ValueListenableBuilder<BillingSnapshot>(
  valueListenable: BillingGlobals.notifier,
  builder: (context, snap, _) {
    // Se la tua _buildTopbarCreditsPillWithText legge BillingGlobals.snap
    // internamente, non devi passare nulla: la sola ricostruzione basta.
    // (In caso contrario, puoi estenderla per accettare credits/isLoading/error.)
    final pill = _buildTopbarCreditsPillWithText(
      fontSize: 14,
      iconSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 28,

      // ───────────────────────────────────────────────────────────────
      // Se la funzione supporta parametri dinamici, puoi sbloccarli qui:
      // credits   : snap.credits?.remainingTotal,
      // isLoading : snap.isLoading,
      // hasPlan   : snap.hasActiveSubscription,
      // errorText : snap.error,
      // ───────────────────────────────────────────────────────────────
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _openBillingPageFromTopbar, // apre BillingPage
            child: pill,
          ),
        ),
      ),
    );
  },
)
,
                            if (widget.showUserMenu)
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
                                                padding: const EdgeInsets.only(
                                                    left: 8.0),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      widget.user.username,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                  LocalizationProviderWrapper
                                                          .of(context)
                                                      .setLanguage(language);
                                                  Navigator.pop(context);
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.grey.shade200
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
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
                                                              : FontWeight
                                                                  .normal,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        child: Image.network(
                                                          'https://flagcdn.com/w40/$countryCode.png',
                                                          width: 24,
                                                          height: 18,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              const Icon(
                                                                  Icons.flag),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }

                                            return SimpleDialog(
                                              backgroundColor: Colors.white,
                                              title: Text(localizations
                                                  .select_language),
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
  builder: (_) => SettingsDialog(                 // ⬅️ PASSA L’SDK
    accessToken: widget.token.accessToken,   // ⬅️ PASSA IL TOKEN
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
                                              Text(localizations
                                                  .select_language),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'Logout',
                                          child: Row(
                                            children: [
                                              Icon(Icons.logout,
                                                  color: Colors.red),
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
                            else
                              const SizedBox.shrink()
                          ],
                        ),
                      ),

                      if (widget.separatorStyle.visible)
                        Container(
                          margin: EdgeInsets.only(
                              top: widget.separatorStyle.topOffset),
                          height: widget.separatorStyle.thickness,
                          color: widget.separatorStyle.color,
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
                                  constraints:
                                      const BoxConstraints(maxWidth: 800),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        borderRadius:
                                            BorderRadius.circular(2.0),
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
                                        _forceInitialChatLoading
                                            ? const Expanded(
                                                child: Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                              )
: messages.isEmpty
    ? (
        widget.showEmptyChatPlaceholder
            // placeholder classico
            ? buildEmptyChatScreen(context, _handleUserInput)
            // chat vuota “silenziosa” ma che riempie lo spazio
            : Expanded(
                child: Container(color: Colors
                    .transparent), // o il colore di background che preferisci
              )
      )
                                                : Expanded(
                                                    child: LayoutBuilder(
                                                      builder: (context,
                                                          constraints) {
                                                        final double
                                                            rightContainerWidth =
                                                            constraints
                                                                .maxWidth;
                                                        final double
                                                            containerWidth =
                                                            (rightContainerWidth >
                                                                    800)
                                                                ? 800.0
                                                                : rightContainerWidth;

                                                        return Stack(children: [
                                                          ShaderMask(
                                                              shaderCallback:
                                                                  (Rect
                                                                      bounds) {
                                                                return const LinearGradient(
                                                                  begin: Alignment
                                                                      .topCenter,
                                                                  end: Alignment
                                                                      .bottomCenter,
                                                                  colors: [
                                                                    Colors
                                                                        .white,
                                                                    Colors
                                                                        .transparent,
                                                                    Colors
                                                                        .transparent,
                                                                    Colors
                                                                        .white,
                                                                  ],
                                                                  stops: [
                                                                    0.0,
                                                                    0.03,
                                                                    0.97,
                                                                    1.0
                                                                  ],
                                                                ).createShader(
                                                                    bounds);
                                                              },
                                                              blendMode:
                                                                  BlendMode
                                                                      .dstOut,
                                                              child: SingleChildScrollView(
                                                                  controller: _messagesScrollController,
                                                                  physics: const AlwaysScrollableScrollPhysics(),
                                                                  child: Center(
                                                                      // (2) Centra la colonna
                                                                      child: ConstrainedBox(
                                                                    // (3) Limita la larghezza della colonna a containerWidth
                                                                    constraints:
                                                                        BoxConstraints(
                                                                      maxWidth:
                                                                          containerWidth,
                                                                    ),
                                                                    child:
                                                                        Column(
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
                                                                    Alignment
                                                                        .center,
                                                                child:
                                                                    FloatingActionButton(
                                                                  mini: true,
                                                                  backgroundColor:
                                                                      Colors
                                                                          .white, // ← sfondo bianco
                                                                  elevation:
                                                                      4.0,
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    // ← bordo arrotondato con raggio 30
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            30),
                                                                  ), // ← ombra sottile
                                                                  child:
                                                                      const Icon(
                                                                    Icons
                                                                        .arrow_downward,
                                                                    color: Colors
                                                                        .blue, // ← freccia blu
                                                                  ),
                                                                  onPressed:
                                                                      () {
                                                                    _messagesScrollController
                                                                        .animateTo(
                                                                      _messagesScrollController
                                                                          .position
                                                                          .maxScrollExtent,
                                                                      duration: const Duration(
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

                                        ChatInputWidget(
                                          apiSdk: _apiSdk,
                                          inputScroll: _inputScroll,
                                          controller: _controller,
                                          inputFocus: _inputFocus,
                                          isListening: _isListening,
                                          isStreaming: _isStreaming,
                                          isCostLoading: _isCostLoading,
                                          liveCost: _liveCost,
                                          listen: _listen,
                                          stopStreaming: _stopStreaming,
                                          handleUserInput: _handleUserInput,
                                          updateLiveCost: _updateLiveCost,
                                          showContextDialog: _showContextDialog,
                                          uploadFileForChatAsync:
                                              _uploadFileForChatAsync,
                                          localizations:
                                              localizations, // la stessa variabile che usavi
                                          onAddImage: _addInputImage, // NEW
                                          onRemoveImage:
                                              _removeInputImageAt, // NEW
                                          pendingInputImages:
                                              _pendingInputImages, // NEW
                                          isSending: _isSending,
                                        ),
                                      ],
                                    ),
                        ),
                      )
                    ])),
              )
            ],
          ),
        ));
  }

  /// Riconfigura SEMPRE la chain con i contesti/model allo stato attuale.
  /// • assicura la KB di chat           (→ _prepareChainForCurrentChat)
  /// • chiama configureAndLoadChain     (→ nuovi ID)
  /// • aggiorna stato + localStorage
  /// • ricalcola la baseline dei costi
  Future<void> _reconfigureAndLoadChain() async {
    // evita corse concorrenti
    if (_isChainLoading) {
      while (_isChainLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    setState(() => _isChainLoading = true);
    try {
      // 1) KB esistente + chain “vuota” se serve
      await _prepareChainForCurrentChat();

      // 2) contesti effettivi (utente + KB chat) e modello
      final effectiveRaw = _stripUserPrefixList(
        buildRawContexts(
          _selectedContexts,
          chatKbPath: _chatKbPath,
          chatKbHasDocs: chatKbHasIndexedDocs(
            chatKbPath: _chatKbPath,
            messages: messages,
          ),
        ),
      );

      final resp = await _withRetry(
        () => _contextApiSdk.configureAndLoadChain(
          widget.user.username,
          widget.token.accessToken,
          effectiveRaw,
          _selectedModel,
          toolSpecs: _toolSpecs,
        ),
        retries: _maxSendRetries,
      );

      setState(() {
        _latestChainId = resp['load_result']?['chain_id'] as String?;
        _latestConfigId = resp['config_result']?['config_id'] as String?;
      });

      // persistenza leggera
      html.window.localStorage['latestChainId'] = _latestChainId ?? '';
      html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';

      // baseline costi ricalcolata ad ogni turno
      await _fetchInitialCost();
    } finally {
      setState(() => _isChainLoading = false);
    }
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
    _chatVars = {};
    _cancelActiveStreamAndPersist(); // 🔹 NEW
    setState(() {
      _activeChatIndex = null;
      messages.clear();
      _chatKbPath = null;
      _latestChainId = null; // reset id chain / config
      _latestConfigId = null;

      _selectedContexts = []; // ★★★  NUOVO  – niente K-Box ereditati
      _selectedModel = _defaultModel;

      showKnowledgeBase = false;
      showSettings = false;
    });

    //await _prepareChainForCurrentChat(); // creerà una chain VUOTA
    //await _fetchInitialCost();

    // ↙️ qui forzi: niente eredità, usa forced default se c'è
    await _restoreChainForCurrentChat(skipInheritance: true);
  }

  /// Carica i messaggi di `chatId`, riallinea la chain
  /// e ricalcola la baseline del costo.
  Future<void> _loadMessagesForChat(String chatId) async {
    // 1. interrompi eventuale stream in corso e svuota cache widget
    _cancelActiveStreamAndPersist();
    _widgetCache.clear();

    try {
      /* ──────────────────────────────────────────────────────────────
     * 2. recupero chat dal local‑state
     * ────────────────────────────────────────────────────────────── */
      final chat = _chatHistory.firstWhere(
        (c) => c['id'] == chatId,
        orElse: () => null,
      );
      if (chat == null) {
        debugPrint('[chat] Nessuna chat con ID $chatId');
        return;
      }

      _chatKbPath = chat['kb_path'] as String?;
      _syncedMsgIds.clear();

      /* ─────────────── messaggi ordinati cronologicamente ─────────── */
      final List<dynamic> chatMessages =
          List<dynamic>.from(chat['messages'] ?? []);
      chatMessages.sort((a, b) => DateTime.parse(a['createdAt'])
          .compareTo(DateTime.parse(b['createdAt'])));

      _chatVars = Map<String, dynamic>.from(chat['chatVars'] ?? {});

      /* ────────────────────────────── setState UI ─────────────────── */
      setState(() {
        _activeChatIndex = _chatHistory.indexWhere((c) => c['id'] == chatId);

        messages
          ..clear()
          ..addAll(chatMessages.map<Map<String, dynamic>>(
            (m) => Map<String, dynamic>.from(m),
          ));

        showKnowledgeBase = false;
        showSettings = false;

        /* ─────────── chain‑id / config‑id dal messaggio più recente ─── */
        if (messages.isNotEmpty) {
          final cfg = messages.last['agentConfig'] as Map<String, dynamic>?;
          _latestChainId = cfg?['chain_id'];
          _latestConfigId = cfg?['config_id'];
        } else {
          _latestChainId = null;
          _latestConfigId = null;
        }
      });

      await _restoreChainForCurrentChat(); // NEW

      /* ──────────────────────────────────────────────────────────────
     * 3. assicura che la KB‑chat sia inclusa nella chain
     *    (attendi il completamento)
     * ────────────────────────────────────────────────────────────── */
      /// Rimuove il prefisso "<username>-" dai context formattati
      String _stripUserPrefix(String ctx) {
        final prefix = "${widget.user.username}-";
        return ctx.startsWith(prefix) ? ctx.substring(prefix.length) : ctx;
      }

      await ensureChainIncludesChatKbPure(
        chatHistory: _chatHistory.cast<Map<String, dynamic>>(), // 👈
        chatId: chatId,
        username: widget.user.username,
        accessToken: widget.token.accessToken,
        defaultModel: _defaultModel,
        stripUserPrefix: _stripUserPrefix,
        configureChain: (u, t, ctx, m) => _contextApiSdk.configureAndLoadChain(
          u,
          t,
          ctx,
          m,
          toolSpecs: _toolSpecs,
        ),
        onVisibleChatChange: (chain, config) {
          setState(() {
            _latestChainId = chain;
            _latestConfigId = config;
          });
        },
        persistChatHistory: (history) {
          html.window.localStorage['chatHistory'] =
              jsonEncode({'chatHistory': history});
        },
      );

      /* ──────────────────────────────────────────────────────────────
     * 4. ricalcola baseline costo per la nuova chat‑history
     *    (attendi la fine per avere _baseCost valorizzata)
     * ────────────────────────────────────────────────────────────── */
      await _fetchInitialCost(); // spinner visibile in UI
      _updateLiveCost(""); // reset preview

      debugPrint('[chat] Caricata chat $chatId ‑ msg: ${messages.length}');
    } catch (e, st) {
      debugPrint('[chat] errore loadMessages: $e\n$st');
    }
  }

/*───────────────────────────────────────────────────────────*/
/* Deep‑copy di _pendingInputImages                          */
/*───────────────────────────────────────────────────────────*/
  List<Map<String, dynamic>> _clonePendingImages() {
    // jsonEncode/Decode è il modo più semplice e sicuro
    return (jsonDecode(jsonEncode(_pendingInputImages)) as List)
        .cast<Map<String, dynamic>>();
  }

  Future<void> _handleUserInput(
    String input, {
    String? sequenceId,
    String  visibility = kVisNormal,
    String? displayText,
  }) async {
    if (input.isEmpty) return;

    if (_isSending || _isStreaming) return; // debounce
    setState(() => _isSending = true);

    // ① copia PROFONDA delle immagini pending
    final inputImages = _clonePendingImages();

    try {
    await _reconfigureAndLoadChain();          // ora ha retry “a cascata”
  } catch (e) {
    setState(() => _isSending = false);        // sblocca spinner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore di configurazione: $e')),
    );
    return;                                    // abortisce l’invio
  }

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
         _userInputPrefix.isNotEmpty  ? '$_userInputPrefix $input'
     : input,
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
        kMsgVisibility : visibility,
        if (displayText != null)
         kMsgDisplayText : displayText,
        'createdAt': currentTime, // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
        'sequenceId': sequenceId,
        'input_images': inputImages
      });
      _retryCounts[assistantMessageId] = 0; // reset tentativi
      fullResponse = ""; // Reset della risposta completa

      // Aggiungi un placeholder per la risposta dell'assistente
      messages.add({
        'id': assistantMessageId, // ID univoco del messaggio dell'assistente
        'role': 'assistant', // Ruolo dell'assistente
        'content': '', // Placeholder per il contenuto
        'createdAt': DateTime.now().toIso8601String(), // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
        'sequenceId': sequenceId
      });

      _pendingInputImages.clear();
    });

    _updateLiveCost("");
    // Pulisce il campo di input
    _controller.clear();

    if (mounted) setState(() => _isSending = false);

    // Invia il messaggio all'API per ottenere la risposta

    await _sendMessageToAPI(modifiedInput, assistantMessageId, inputImages);

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
        _chatKbPath = await ensureChatKb(
          api: _contextApiSdk,
          userName: widget.user.username,
          accessToken: widget.token.accessToken,
          chatId: chatId,
          chatName: chatName,
          currentKbPath: _chatKbPath, // passa quello attuale (può essere null)
        );
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
              final Map<String, dynamic> widgetMap =
                  Map<String, dynamic>.from(element);

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
        'kb_path': _chatKbPath, // ← salva sempre il path,
        'chatVars': _chatVars
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

    final cleaned = _stripUserPrefixList(_selectedContexts);

    // Richiamiamo il dialog esterno
    showSelectContextDialog(
      chatHistory: _chatHistory,
      context: context,
      availableContexts: _availableContexts,
      initialSelectedContexts: cleaned,
      initialModel: _selectedModel,
      onConfirm: (List<String> newContexts, String newModel) async {
        setState(() {
          _selectedContexts = newContexts;
          _selectedModel = newModel;
        });
        // E se vuoi, chiami la funzione set_context
        await set_context(
            buildRawContexts(
              _selectedContexts,
              chatKbPath: _chatKbPath,
              chatKbHasDocs: chatKbHasIndexedDocs(
                chatKbPath: _chatKbPath,
                messages: messages,
              ),
            ),
            _selectedModel);
        await _fetchInitialCost(); // unica call al backend
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
      _selectedModel = model;

      // 2.  lista “effettiva” da passare al backend
      //     (= contesti scelti  +  KB-chat  senza doppi)
      final List<String> effectiveRaw = buildRawContexts(
        _selectedContexts,
        chatKbPath: _chatKbPath,
        chatKbHasDocs: chatKbHasIndexedDocs(
          chatKbPath: _chatKbPath,
          messages: messages,
        ),
      );

      // 3.  chiama l’SDK
final response = await _withRetry(
  () => _contextApiSdk.configureAndLoadChain(
        widget.user.username,
        widget.token.accessToken,
        effectiveRaw,
        model,
        toolSpecs: _toolSpecs,
      ),
  retries: _maxSendRetries,              // già = 5
);
      debugPrint('Chain configurata su: $effectiveRaw');

      // 4.  estrae gli ID restituiti
      final String? chainIdFromResponse =
          response['load_result']?['chain_id'] as String?;
      final String? configIdFromResponse =
          response['config_result']?['config_id'] as String?;

      // 5.  aggiorna stato + localStorage
      setState(() {
        _latestChainId = chainIdFromResponse;
        _latestConfigId = configIdFromResponse;
      });

      html.window.localStorage['latestChainId'] = _latestChainId ?? '';
      html.window.localStorage['latestConfigId'] = _latestConfigId ?? '';
    } catch (e, st) {
      debugPrint('❌  set_context error: $e\n$st');
    }
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

  // Funzione per copiare il messaggio negli appunti
  void _copyToClipboard(String message) {
    final localizations = LocalizationProvider.of(context);
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.copyMessage)),
    );
  }

  /// Restituisce il testo del messaggio con i placeholder dei widget
  /// sostituiti dalla stringa < TYPE='WIDGET' … > completa.
  ///
  /// • Rimuove eventuali "[WIDGET_SPINNER]" e "▌".
  /// • Rimuove la chiave `is_first_time` dal JSON prima di serializzare.
  String _contentWithWidgets(Map<String, dynamic> msg) {
    String out = (msg['content'] as String? ?? '')
        .replaceAll("[WIDGET_SPINNER]", "")
        .replaceAll("▌", "");

    final List<dynamic>? wList = msg['widgetDataList'] as List?;
    if (wList == null || wList.isEmpty) return out;

    for (final dynamic w in wList) {
      if (w is! Map) continue;

      final placeholder = w['placeholder'] as String? ?? '';
      final widgetId = w['widgetId'] as String? ?? 'UnknownWidget';
      final Map<String, dynamic> jsonData =
          Map<String, dynamic>.from(w['jsonData'] ?? const {});

      jsonData.remove('is_first_time'); // pulizia

      final block = "< TYPE='WIDGET' WIDGET_ID='$widgetId' | "
          "${jsonEncode(jsonData)} | "
          "TYPE='WIDGET' WIDGET_ID='$widgetId' >";

      out = out.replaceAll(placeholder, block);
    }
    return out;
  }

String? _readSubscriptionId(dynamic plan) {
  try {
    final v = plan?.subscriptionId;
    if (v is String) return v;
  } catch (_) {}
  try {
    if (plan is Map && plan['subscription_id'] is String) {
      return plan['subscription_id'] as String;
    }
  } catch (_) {}
  return null;
}

  Future<void> _sendMessageToAPI(
    String input,
    String assistantMsgId,
    List<Map<String, dynamic>> inputImages,
  ) async {
    final int currentRetry = _retryCounts[assistantMsgId] ?? 0;

    if (_nlpApiUrl == null) {
      await _loadConfig(); // Assicurati che l'URL sia caricato
    }

    // URL della chain API
    final url = "$_nlpApiUrl/stream_events_chain";

final curPlan = BillingGlobals.snap.plan;
final subId   = _readSubscriptionId(curPlan);

    final chainIdToUse = _latestChainId?.isNotEmpty == true
        ? _latestChainId!
        : 'default_agent_with_tools';

    // ① tronco sempre gli ultimi due messaggi
    final List<Map<String, dynamic>> historyTruncated = messages.length > 2
        ? messages.sublist(0, messages.length - 2)
        : <Map<String, dynamic>>[];

// Trasforma la chat history nel formato multimodale:
// ogni messaggio diventa { role: ..., parts: [ {type,text}, {type,image_url}, … ] }
    final transformedChatHistory = historyTruncated.map((message) {
      // 1) Ruolo del messaggio
      final String role = message['role'] as String;

      // 2) Testo puro del messaggio (già con i widget serializzati se c’erano)
      final content = _contentWithWidgets(message);

      // 3) Lista di parts: parte sempre con il testo
      final List<Map<String, dynamic>> parts = [
        {
          "type": "text",
          "text": content,
        }
      ];

// 4) Se ci sono immagini già normalizzate, aggiungile ai parts
      if (message.containsKey('input_images') &&
          message['input_images'] is List) {
        final List<dynamic> imgs = message['input_images'] as List;

        for (final dynamic item in imgs) {
          if (item is Map<String, dynamic>) {
            // Caso NUOVO: già nel formato
            // {
            //   "type": "image_url",
            //   "image_url": { "url": "...", "detail": "auto" }
            // }
            if (item['type'] == 'image_url' && item['image_url'] is Map) {
              parts.add(item);
              continue;
            }

            // Caso VECCHIO: { "url": "...", "detail": "auto" }  → normalizza
            /*if (item.containsKey('url')) {
        parts.add({
          "type": "image_url",
          "image_url": {
            "url": item['url'],
            "detail": item['detail'] ?? 'auto',
          },
        });
        continue;
      }*/
          }
          // Se arriva qualcosa di non valido lo ignoro (o logga a debug)
        }
      }

      // 5) Restituisci l’oggetto multimodale
      return {
        "role": role,
        "parts": parts,
      };
    }).toList();

// Trasforma la chat history sostituendo i placeholder dei widget con i JSON reali
    final transformedChatHistoryLegacy = historyTruncated.map((message) {
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
      "token": widget.token.accessToken,
      "subscription_id": subId,
      "chain_id": chainIdToUse,
      //"query": {"input": input, "chat_history": transformedChatHistoryLegacy},
      "input_text": input,
      "input_images": inputImages,
      /*[
        {"type": "image_url", 
        "image_url": {"url": 'https://static.tecnichenuove.it/animalidacompagnia/2024/04/gattino-che-miagola.jpg',
         "detail": "auto"}}],*/
      "chat_history": transformedChatHistory,
      "inference_kwargs": {}
    });

    try {
      setState(() => _isStreaming = true);
      // Esegui la fetch
// crea AbortController
      _abortController = js_util.callConstructor(
          js_util.getProperty(html.window, 'AbortController') as Object, []);

// fetch con la signal
      final response = await js_util.promiseToFuture(js_util.callMethod(
        html.window,
        'fetch',
        [
          url,
          js_util.jsify({
            'method': 'POST',
            'headers': {'Content-Type': 'application/json'},
            'body': payload,
            'signal': js_util.getProperty(_abortController, 'signal'),
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
      _streamReader = reader;

      
// ⬇⬇⬇  NEW — reset guard per “prima token”
_didRefreshCreditsOnFirstToken = false;

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
      int _toolDepth = 0; // { … }
      bool _inQuotes = false;
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

// ────────────────────  TOOL-EVENT PARSER STATE ────────────────────
      bool insideWidgetBlock = false;
      bool seenEndMarker = false;
      String? currentWidgetId; // ID del widget esterno in parsing
      String currentEndMarker = ""; // marker di chiusura su misura
      int endLen = 0; // lunghezza del marker dinamico
      final List<int> _ringEnd = <int>[]; // buffer circolare per comparison

      /// run_id per cui è già stata creata la card-spinner “provvisoria”
      final Set<String> _inFlightTools = <String>{};

      /// Consuma il chunk e intercetta TUTTI gli eventi tool.{start|end}.
      /// Ritorna `true` se *almeno un carattere* apparteneva ad un JSON-evento
      /// (così il chiamante non lo passerà a `processChunk`).
      bool _maybeHandleToolEvent(String chunk) {
        bool somethingHandled = false;

        /*─────────────────────────────────────────────────────────*/
        void _feed(int codeUnit) {
          final String c = String.fromCharCode(codeUnit);
          _toolBuf.write(c);

          /*── 1. escape & stringhe JSON ─────────────────────────*/
          if (_escapeNextChar) {
            _escapeNextChar = false;
            return;
          }
          if (c == r'\') {
            _escapeNextChar = true;
            return;
          }
          if (c == '"') _inQuotes = !_inQuotes;
          if (_inQuotes) return;

          /*── 2. bilanciamento graffe ───────────────────────────*/
          if (c == '{') _toolDepth++;
          if (c == '}') _toolDepth--;

          /*── 3. JSON completo  (_toolDepth == 0) ───────────────*/
          if (_toolDepth == 0) {
            final String rawJson = _toolBuf.toString().trim();
            _toolBuf.clear(); // reset buffer

            if (rawJson.isEmpty) return;
            Map<String, dynamic>? evt;
            try {
              evt = jsonDecode(rawJson) as Map<String, dynamic>;
            } catch (_) {
              return; // non era JSON valido
            }
            if (evt == null || evt['event'] == null) return;

            somethingHandled = true; // → gestito

            final String runId = evt['run_id'] as String;
            final String name = evt['name'] as String? ?? 'tool';

            switch (evt['event']) {
              /*──────────── on_tool_start ────────────*/
              case 'on_tool_start':
                // stub già creato? esci
                if (_inFlightTools.contains(runId)) break;

                _inFlightTools.add(runId);

                final String placeholder = "[TOOL_PLACEHOLDER_$runId]";

                _toolEvents[runId] = {
                  'name': name,
                  'input': evt['data']?['input'] ?? {},
                  'isRunning': true,
                  'placeholder': placeholder,
                };

                // ① placeholder nel testo visibile
                displayOutput.write(placeholder);

                // ② card provvisoria
                (messages.last['widgetDataList'] ??= <dynamic>[]).add({
                  "_id": runId,
                  "widgetId": "ToolEventWidget",
                  "jsonData": _toolEvents[runId],
                  "placeholder": placeholder,
                });

                // ③ refresh
                setState(
                    () => messages.last['content'] = displayOutput.toString());
                break;

              /*──────────── on_tool_end ──────────────*/
              case 'on_tool_end':
                final existing = _toolEvents[runId];
                if (existing == null) break;

                existing['output'] = evt['data']?['output'];
                existing['isRunning'] = false;

                // invalida cache → ricrea la card con output
                _widgetCache.remove(runId);
                setState(() {});
                break;
            }
          }
        }

        /*── 4. feed carattere per carattere ─────────────────────*/
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
        int endLen = endMarker.length;

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

          // ─────────────────────────────────────────────────────────────
// 2) siamo DENTRO un blocco widget (aperto da startPattern)
// ─────────────────────────────────────────────────────────────
          widgetBuffer.write(c);

// a) se non ho ancora l'ID del widget esterno, lo estraggo ora
          if (currentWidgetId == null) {
            final m = RegExp(r"WIDGET_ID='([^']+)'")
                .firstMatch(widgetBuffer.toString());
            if (m != null) {
              currentWidgetId = m.group(1);
              currentEndMarker = "| TYPE='WIDGET' WIDGET_ID='$currentWidgetId'";
              endLen = currentEndMarker.length;
            }
          }

// b) aggiorno il buffer circolare per cercare il mio endMarker
          // b) se widgetBuffer termina con "<endMarker> >", abbiamo chiusura
          final fullBuf = widgetBuffer.toString();
          if (!seenEndMarker &&
              currentWidgetId != null &&
              fullBuf.endsWith("$currentEndMarker >")) {
            seenEndMarker = true;
          }

// c) chiudo il blocco solo quando vedo il mio endMarker + '>'
          if (seenEndMarker && c == '>') {
            // rimuovo lo spinner
            final String withoutSpin =
                displayOutput.toString().replaceFirst(spinnerPlaceholder, "");
            displayOutput
              ..clear()
              ..write(withoutSpin);

            // finalize: converto il buffer in widget esterno
            final String placeholder =
                _finalizeWidgetBlock(widgetBuffer.toString());
            displayOutput.write(placeholder);

// elimina lo spinner e la sua entry nella widgetDataList
            final lastMsg = messages.last;
            displayOutput.write('');
            (lastMsg['widgetDataList'] as List)
                ?.removeWhere((w) => w['widgetId'] == 'SpinnerPlaceholder');
            _widgetCache.removeWhere((id, _) => id.startsWith('SpinnerFake_'));

            // 3) POPOLA IMMEDIATAMENTE widgetDataList (solo esterno)
            final rawJson = widgetBuffer
                .toString()
                .split('|')[1] // fra le due barre verticali
                .trim();
            Map<String, dynamic> widgetJson;
            try {
              widgetJson = jsonDecode(rawJson) as Map<String, dynamic>;
            } catch (_) {
              widgetJson = <String, dynamic>{};
            }
            final widgetUniqueId = uuid.v4();
            //final lastMsg = messages.last;
            (lastMsg['widgetDataList'] ??= <dynamic>[]).add({
              "_id": widgetUniqueId,
              "widgetId": currentWidgetId!,
              "jsonData": widgetJson,
              "placeholder": placeholder,
            });

            // reset parser state
            insideWidgetBlock = false;
            seenEndMarker = false;
            currentWidgetId = null;
            currentEndMarker = "";
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

              // ⬇⬇⬇  NEW — refresh crediti alla *prima* token di testo dell'agente
  if (!_didRefreshCreditsOnFirstToken  && chunkString.trim().isNotEmpty) {
    _didRefreshCreditsOnFirstToken = true;
    _scheduleCreditsRefresh(); // NON blocca lo stream
  }
  
            // Processa il chunk (token per token)
            final handled = _maybeHandleToolEvent(chunkString);

            if (!handled) {
              processChunk(chunkString);
            }

            // Continua a leggere
            readChunk();
          } else {
            // ─── FINE STREAMING – chiusura semplice ───────────────────────
            final generatedTok = _estimateTokens(fullOutput.toString()); // F‑4
            _advanceBaseline(input, generatedTok);
            setState(() {
              final msg = messages.last;
              // 1) rimuovo solo lo spinner textuale
              const String spinnerPh = "[WIDGET_SPINNER]";
              msg['content'] =
                  displayOutput.toString().replaceFirst(spinnerPh, "");
              // 2) NON rifaccio _parsePotentialWidgets:
              //    widgetDataList è già popolato dentro processChunk
            });

            assistantTurnCompleted.value++;

            print('$assistantTurnCompleted');

            // Salviamo la conversazione (DB/localStorage)
            _saveConversation(messages);
            // 🔻 STOP pulsante solo *qui*
            setState(() => _isStreaming = false);
            _streamReader = null;
            _abortController = null;
          }
        }).catchError((error) async {
          // 1️⃣ log + placeholder d’errore
          print('Errore durante la lettura del chunk: $error');

          final idx = messages.indexWhere((m) => m['id'] == assistantMsgId);
          if (idx != -1) {
            setState(() => messages[idx]['content'] = 'Errore: $error');
          }

          // 2️⃣ chiudi in modo CLEAN lo streaming corrente
          setState(() => _isStreaming = false); // ri‑abilita i controlli UI
          _streamReader = null; // libera il reader JS
          _abortController = null; // chiude la fetch

          // 3️⃣ tenta di rigenerare la risposta (max 5 volte)
          await _retrySendMessage(
              input, assistantMsgId, currentRetry, inputImages);
        });
      }

      // Avvia la lettura dei chunk
      readChunk();
    } catch (e) {
      // Errore PRIMA che lo stream inizi (o in fetch)
      print('Errore durante il fetch dei dati: $e');

      final idx = messages.indexWhere((m) => m['id'] == assistantMsgId);
      if (idx != -1) {
        // NEW

        setState(() => messages[idx]['content'] = 'Errore: $e');
      }

      // riprova finché non superi il limite maxRetry
      await _retrySendMessage(input, assistantMsgId, currentRetry, inputImages);
    }
  }

  Future<void> _retrySendMessage(String originalInput, String assistantMsgId,
      int previousRetry, List<Map<String, dynamic>> inputImages) async {
    if (previousRetry + 1 >= _maxRetries) return; // esauriti i tentativi

    _retryCounts[assistantMsgId] = previousRetry + 1;

    // sostituisci l’errore con lo spinner visivo
    setState(() {
      final idx = messages.indexWhere((m) => m['id'] == assistantMsgId);
      if (idx != -1) messages[idx]['content'] = "[WIDGET_SPINNER]";
      _isStreaming = false; // reset stato UI
    });

    // piccolo delay per evitare loop troppo rapidi
    await Future.delayed(const Duration(milliseconds: 300));

    // riprova
    await _sendMessageToAPI(originalInput, assistantMsgId, inputImages);
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

// ────────────────────────────────────────────────────────────────────
//  _SequenceCard  –  super‑messaggio che raggruppa la sequenza
//  PATCH 2025‑07‑24:
//    • _expandedIdx   → sempre sull’ultimo step
//    • niente PageStorageKey  (usiamo ValueKey che cambia a ogni rebuild)
// ────────────────────────────────────────────────────────────────────
class _SequenceCard extends StatefulWidget {
  const _SequenceCard({
    Key? key,
    required this.seqMsg,
    required this.containerWidth,
    required this.buildMixedContent,
  }) : super(key: key);

  final Map<String, dynamic> seqMsg;
  final double containerWidth;
  final Widget Function(Map<String, dynamic>) buildMixedContent;

  @override
  State<_SequenceCard> createState() => _SequenceCardState();
}

class _SequenceCardState extends State<_SequenceCard> {
  late List<Map<String, Map<String, dynamic>>> _steps;
  late int _expandedIdx; // indice aperto

  /*──────── init ───────────────*/
  @override
  void initState() {
    super.initState();
    _rebuildSteps(); // 1ª inizializzazione
  }

  /*──────── on widget‑update ────*/
  @override
  void didUpdateWidget(covariant _SequenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldLen = _steps.length;
    _rebuildSteps(); // riallinea sempre

    // nuovo step arrivato → apri l’ultimo
    if (_steps.length > oldLen) _expandedIdx = _steps.length - 1;
    // nessun setState: il framework ricostruisce comunque dopo didUpdateWidget
  }

  /*──────── helper ─────────────*/
  void _rebuildSteps() {
    _steps =
        List<Map<String, Map<String, dynamic>>>.from(widget.seqMsg['steps']);

    // ❶  sempre e comunque sull’ultimo
    _expandedIdx = _steps.isEmpty ? 0 : _steps.length - 1;
  }

  /*──────── build ──────────────*/
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.containerWidth,
              minWidth: 200,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*──────── intestazione ─────────*/
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: assistantAvatar,
                      ),
                      const SizedBox(width: 8),
                      const Text('Sequenza automatica',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  /*──────── elenco step ──────────*/
                  ..._steps.asMap().entries.map((e) {
                    final idx = e.key;
                    final instr = e.value['instruction']!;
                    final resp = e.value['response']!;

                    return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            // 👇 ValueKey ➔ forza la ricreazione se cambia lunghezza
                            key: ValueKey(
                                'seq_${widget.seqMsg['sequenceId']}_${idx}_${_steps.length}'),
                            maintainState: true,
                            initiallyExpanded: idx == _expandedIdx,
                            onExpansionChanged: (open) {
                              if (open) setState(() => _expandedIdx = idx);
                            },
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            title: Text(
                              '${idx + 1}. ${instr['content']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            children: [
                              // delega al builder esterno
                              widget.buildMixedContent(resp),
                            ],
                          ),
                        ));
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
