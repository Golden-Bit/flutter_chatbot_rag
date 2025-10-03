import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:boxed_ai/ui_components/dialogs/loader_config_dialog.dart';
import 'package:boxed_ai/ui_components/icons/cube.dart';
import 'package:boxed_ai/user_manager/state/billing_globals.dart';
import 'package:boxed_ai/utilities/localization.dart';
import 'package:universal_html/html.dart' as html;
import 'context_api_sdk.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // per jsonEncode / jsonDecode
import 'package:uuid/uuid.dart';
import 'dart:convert' show JsonEncoder;
import 'package:flutter/services.dart'; // ← per LengthLimitingTextInputFormatter
import 'dart:math' as math; // per min/max responsive

/// Ritorna true se la KB è stata creata automaticamente come archivio di una chat
bool _isChatContext(ContextMetadata ctx) {
  final chatId = ctx.customMetadata?['chat_id'];
  return chatId != null && chatId.toString().trim().isNotEmpty;
}

/*void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context API Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(),
    );
  }
}*/
class _PaginatedDocViewer extends StatefulWidget {
  final ContextApiSdk apiSdk;
  final String token;

  /// ► Modalità A (legacy): passo direttamente la collection
  final String? collection;

  /// ► Modalità B (nuova): passo sorgente per calcolare la collection lato server
  final String? ctx;
  final String? filename;

  final int pageSize;

  _PaginatedDocViewer({
    Key? key,
    required this.apiSdk,
    required this.token,
    this.collection, // ← opzionale
    this.ctx, // ← opzionale
    this.filename, // ← opzionale
    this.pageSize = 1,
  })  : assert(
          // almeno una delle due modalità deve essere valorizzata:
          (collection != null && collection!.isNotEmpty) ||
              ((ctx != null && ctx!.isNotEmpty) &&
                  (filename != null && filename!.isNotEmpty)),
          "Devi fornire 'collection' oppure la coppia 'ctx' + 'filename'.",
        ),
        super(key: key);

  @override
  State<_PaginatedDocViewer> createState() => _PaginatedDocViewerState();
}

class _PaginatedDocViewerState extends State<_PaginatedDocViewer> {
  late Future<List<DocumentModel>> _future;
  int _page = 0; // 0-based
  int? _total;

  @override
  void initState() {
    super.initState();
    _future = _fetch(); // ► prima pagina
  }

// ──────────────────────────────────────────────────────────────
// Helper: stringify di valori arbitrari (mappa/lista → JSON inline)
// ──────────────────────────────────────────────────────────────
  String _stringify(dynamic v) {
    try {
      if (v == null) return '';
      if (v is String) {
        // comprimi le nuove linee per tenerlo in singola riga
        return v.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
      }
      // qualsiasi altro tipo → JSON compatto (senza newline)
      return jsonEncode(v);
    } catch (_) {
      // fallback super difensivo
      return v.toString();
    }
  }

// ──────────────────────────────────────────────────────────────
// Widget valore monoriga selezionabile con scroll orizzontale
// tramite caret/drag (senza scrollbar visibile).
// ──────────────────────────────────────────────────────────────
  Widget _valueCell(String value) {
    // Controller effimero: ok perché il widget è read-only
    final controller = TextEditingController(text: value);

    return TextField(
      controller: controller,
      readOnly: true,
      maxLines: 1,
      minLines: 1,
      // niente wrap: la riga si estende orizzontalmente e scorre al caret
      expands: false,
      enableInteractiveSelection: true,
      // disabilita ogni "aiuto" di input (è solo display/copypaste)
      enableSuggestions: false,
      autocorrect: false,
      // fisica standard senza scrollbar
      scrollPhysics: const ClampingScrollPhysics(),
      // cursore testuale (web/desktop) e comportamento classico
      mouseCursor: SystemMouseCursors.text,
      // stile monospace come per il JSON
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: Colors.black87,
      ),
      // nessun bordo interno, padding minimo
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

// ──────────────────────────────────────────────────────────────
// RIGA chiave/valore con valore selezionabile (no wrap) e
// scorrimento orizzontale al movimento del cursore
// ──────────────────────────────────────────────────────────────
  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // colonna chiave a larghezza fissa con ellissi
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // colonna valore: singola riga selezionabile (senza scrollbar)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge, // evita overflow visivi
              child: _valueCell(value),
            ),
          ),
        ],
      ),
    );
  }

// ──────────────────────────────────────────────────────────────
// Card del documento: page_content in alto + righe metadati
// ──────────────────────────────────────────────────────────────
  Widget _docCard(DocumentModel d) {
    final Map<String, dynamic> md =
        (d.metadata ?? {}) as Map<String, dynamic>; // difensivo

    // Prepara coppie chiave/valore: includi anche "type" come riga iniziale
    final List<MapEntry<String, String>> rows = [
      MapEntry('type', _stringify(d.type)),
      ...md.entries.map(
        (e) => MapEntry(e.key, _stringify(e.value)),
      ),
    ];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PAGE CONTENT ───────────────────────────────────────
            const Text(
              'page_content',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white, // grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: SelectableText(
                    d.pageContent ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── METADATA ───────────────────────────────────────────
            const Text(
              'metadata',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // righe auto-generate per OGNI meta presente
            ...rows.map((kv) => _metaRow(kv.key, kv.value)),
          ],
        ),
      ),
    );
  }

  /*──────── helper API (skip / limit fissi) ────────*/
  Future<List<DocumentModel>> _fetch() async {
    final skip = _page * widget.pageSize;
    final limit = widget.pageSize;

    // ► Se ho ctx+filename → nuova API che risolve lato server (hash 15 + "_collection")
    if ((widget.ctx != null && widget.ctx!.isNotEmpty) &&
        (widget.filename != null && widget.filename!.isNotEmpty)) {
      return widget.apiSdk.listDocumentsResolved(
        ctx: widget.ctx,
        filename: widget.filename,
        token: widget.token,
        skip: skip,
        limit: limit,
        onTotal: (t) => _total = t,
      );
    }

    // ► Altrimenti fallback legacy su collection (compatibilità)
    return widget.apiSdk.listDocuments(
      widget.collection!,
      token: widget.token,
      skip: skip,
      limit: limit, // sempre = pageSize
      onTotal: (t) => _total = t,
    );
  }

  /*──────── cambio pagina (con guard-rail) ────────*/
  void _go(int delta) {
    final next = _page + delta;
    if (next < 0) return; // < 0
    if (_total != null && next * widget.pageSize >= _total!)
      return; // oltre fine

    setState(() {
      _page = next;
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 400,
      child: FutureBuilder<List<DocumentModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Text('Errore caricamento documenti: ${snap.error}');
          }

          final docs = snap.data ?? const <DocumentModel>[];
          final isEmpty = docs.isEmpty;

          final jsonStr = isEmpty
              ? ''
              : const JsonEncoder.withIndent('  ').convert(
                  docs
                      .map((d) => {
                            'page_content': d.pageContent,
                            'metadata': d.metadata,
                            'type': d.type,
                          })
                      .toList(),
                );

          /*───────── UI completa ─────────*/
          return Column(
            children: [
              /*───── frecce + contatore ─────*/
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Pagina precedente',
                    icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                    onPressed: _page == 0 ? null : () => _go(-1),
                  ),
                  Text(
                    _total == null
                        ? 'Pagina ${_page + 1}'
                        : 'Pagina ${_page + 1} / ${(_total! / widget.pageSize).ceil()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  IconButton(
                    tooltip: 'Pagina successiva',
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: (isEmpty ||
                            (_total != null &&
                                (_page + 1) * widget.pageSize >= _total!))
                        ? null
                        : () => _go(1),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              /*───── riquadro scroll / placeholder ─────*/
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                          child: ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, i) => _docCard(docs[i]),
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

/// Restituisce {icon, color} in base all’estensione del file.
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

/// Info persistente sui job di indicizzazione ancora in corso
/// ①  aggiungi il campo `jobId`
/// Info persistente sui job di indicizzazione ancora in corso
class PendingUploadJob {
  final String jobId; // id univoco del job
  final String chatId; // id della chat a cui appartiene
  final String contextPath; // path KB
  final String fileName; // nome file
  final Map<String, TaskIdsPerContext> tasksPerCtx;

  PendingUploadJob({
    required this.jobId,
    required this.chatId,
    required this.contextPath,
    required this.fileName,
    required this.tasksPerCtx,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'chatId': chatId,
        'context': contextPath,
        'fileName': fileName,
        'tasks': tasksPerCtx.map((k, v) => MapEntry(k, {
              'loader': v.loaderTaskId,
              'vector': v.vectorTaskId,
            })),
      };

  static PendingUploadJob fromJson(Map<String, dynamic> j) {
    final tasks =
        (j['tasks'] as Map<String, dynamic>).map((ctx, ids) => MapEntry(
            ctx,
            TaskIdsPerContext(
              loaderTaskId: ids['loader'],
              vectorTaskId: ids['vector'],
            )));

    return PendingUploadJob(
      jobId: j['jobId'],
      chatId: j['chatId'],
      contextPath: j['context'],
      fileName: j['fileName'],
      tasksPerCtx: tasks,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String username;
  final String token;

  // ▼ AGGIUNGI
  final void Function(String jobId, String chatId, String ctx, String fileName,
      Map<String, TaskIdsPerContext> tasks)? onNewPendingJob;

  const DashboardScreen({
    Key? key,
    required this.username,
    required this.token,
    this.onNewPendingJob, // ◀︎ facoltativo
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ContextApiSdk _apiSdk = ContextApiSdk();

// --- elenco “visibile” filtrato (senza KB-di-chat)
  List<ContextMetadata> _contexts = [];

  FilePickerResult? _selectedFile;
  final Map<String, Timer> _pollers = {}; // in cima allo State
// ──────────────────────────────────────────────────────────────
//  🔧  UTILITY: dal record "file" ⇒ fileId e collectionName
// ──────────────────────────────────────────────────────────────
  String _fileIdFrom(Map<String, dynamic> file) => file['name'] ?? '';

  String _extractCtx(String rawPath) {
    final i = rawPath.indexOf('/');
    return i < 0 ? rawPath : rawPath.substring(0, i);
  }

  String _extractFilename(String rawPath, String fallbackUiName) {
    // rawPath tipicamente "ctx/filename.ext"; se manca "/", ripiega su titolo UI
    final i = rawPath.indexOf('/');
    return i < 0 ? fallbackUiName : rawPath.substring(i + 1);
  }

// → tutte le KB, comprese quelle-chat (già esistente)
  List<ContextMetadata> _allContexts = [];

// → solo KB “visibili”: senza quelle-chat
  List<ContextMetadata> _gridContexts = [];

  bool _isCtxLoading = false;
  /* ────────────────────────────────────────────────────────────────
 * UI ▸ _showFilePreviewDialog  ▶︎  dialog con paginazione client
 * ──────────────────────────────────────────────────────────────── */
/*───────────────────────────────────────────────────────────────────────────
  UI ▸ dialog di anteprima file con paginazione (freccia ← / →)
───────────────────────────────────────────────────────────────────────────*/
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
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

        /*──────────────────────── titolo + pulsante download ─────────────────────*/
        title: Row(
          children: [
            Expanded(
              child: Text(
                fileName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Scarica JSON documenti',
              icon: const Icon(Icons.download),
              onPressed: () =>
                  _downloadDocumentsJsonByName(ctx, fname, fileName),
            ),
          ],
        ),

        /*──────────────────────── corpo paginato (Stateful) ──────────────────────*/
        content: _PaginatedDocViewer(
          apiSdk: _apiSdk,
          token: widget.token,
          ctx: ctx, // ← NEW
          filename: fname, // ← NEW
          pageSize: 1,
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

// convenience
  String _displayName(ContextMetadata ctx) =>
      ctx.customMetadata?['display_name'] ?? ctx.path;

  bool _isLoading =
      false; // Variabile di stato per indicare il caricamento generale
  String? _loadingContext; // Contesto corrente per l'upload
  String? _loadingFileName; // Nome del file in fase di caricamento

  Map<String, bool> _isLoadingMap =
      {}; // Stato di caricamento per ciascun contesto
  Map<String, String?> _loadingFileNamesMap =
      {}; // Nome del file in caricamento per ciascun contesto
// Controller per le due barre di ricerca
  TextEditingController _nameSearchController =
      TextEditingController(); // Per la ricerca per nome
  TextEditingController _descriptionSearchController =
      TextEditingController(); // Per la ricerca per descrizione

// Lista dei contesti filtrati
  List<ContextMetadata> _filteredContexts = [];

// ──────────────────────────────────────────────────────────────
// 🔄  USIAMO jobId come chiave nella mappa persistita
// ──────────────────────────────────────────────────────────────
  static const _prefsKey = 'kb_pending_jobs';

  Future<void> _savePendingJobs(Map<String, PendingUploadJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jobs.map((_, job) => MapEntry(job.jobId, job.toJson()));
    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }

  Future<Map<String, PendingUploadJob>> _loadPendingJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map(
      (_, j) {
        final job = PendingUploadJob.fromJson(j);
        return MapEntry(job.jobId, job); // ⇠ chiave = jobId
      },
    );
  }

  late Map<String, PendingUploadJob> _pendingJobs;

  @override
  void initState() {
    super.initState();
    _restorePendingState(); // ①
    _loadContexts(); // carica i contesti appena parte la pagina
  }

  @override
  void dispose() {
    // annulla eventuali timer di polling ancora attivi
    for (final t in _pollers.values) {
      t.cancel();
    }
    super.dispose(); // ⬅️ sempre per ultimo
  }

  Future<void> _restorePendingState() async {
    _pendingJobs = await _loadPendingJobs();

    // (re)-inizia spinner e polling per i job ancora attivi
    for (final entry in _pendingJobs.values) {
      setState(() {
        _isLoadingMap[entry.contextPath] = true;
        _loadingFileNamesMap[entry.contextPath] = entry.fileName;
      });

      _monitorUploadTasks(entry.jobId, entry.tasksPerCtx); // 👈 jobId
    }

    await _loadContexts(); // carica la lista KB dopo aver sistemato gli spinner
  }

  /// Restituisce un'icona basata sull'estensione del file.
  Map<String, dynamic> _getIconForFileType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
      case 'docx':
      case 'doc':
        return {'icon': Icons.article, 'color': Colors.blue};
      case 'xlsx':
      case 'xls':
        return {'icon': Icons.table_chart, 'color': Colors.green};
      case 'pptx':
      case 'ppt':
        return {'icon': Icons.slideshow, 'color': Colors.orange};
      case 'txt':
        return {'icon': Icons.text_snippet, 'color': Colors.grey};
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

  // ▼▼▼ 2.  _loadContexts: imposta/ripristina il flag
  Future<void> _loadContexts() async {
    if (mounted) setState(() => _isCtxLoading = true);

    try {
      final all = await _apiSdk.listContexts(
        widget.username,
        widget.token,
      );

      if (!mounted) return;

      setState(() {
        _allContexts = all;
        _gridContexts = all.where((c) => !_isChatContext(c)).toList();
        _contexts = List.from(_gridContexts);
        _filteredContexts = List.from(_gridContexts);
        _isCtxLoading = false; // ✓ fine caricamento
      });
    } catch (e) {
      debugPrint('Errore nel recupero dei contesti: $e');
      if (mounted) setState(() => _isCtxLoading = false);
    }
  }

  /// Filtra la lista dei contesti in base al testo immesso.
  ///
  /// ‣ Il filtro cerca sia nel “nome visualizzato” (`display_name` dentro
  ///   `customMetadata`) sia nel campo `description`.
  /// ‣ Se `display_name` non esiste (vecchi contesti) usa `path` come
  void _filterContexts() {
    final query = _nameSearchController.text.toLowerCase().trim();

    setState(() {
      _filteredContexts = _gridContexts.where((ctx) {
        final displayName = (ctx.customMetadata?['display_name'] ?? ctx.path)
            .toString()
            .toLowerCase();
        final description =
            (ctx.customMetadata?['description'] ?? '').toString().toLowerCase();
        return displayName.contains(query) || description.contains(query);
      }).toList();
    });
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

  // Funzione per caricare i file di un contesto specifico
  Future<List<Map<String, dynamic>>> _loadFilesForContext(
      String contextPath) async {
    try {
      final files = await _apiSdk
          .listFiles(widget.username, widget.token, contexts: [contextPath]);
      return files;
    } catch (e) {
      print('Errore nel recupero dei file per il contesto $contextPath: $e');
      return [];
    }
  }

  // Funzione per caricare un file in più contesti
  Future<void> _uploadFile(Uint8List fileBytes, List<String> contexts,
      {String? description, required String fileName}) async {
    try {
      await _apiSdk.uploadFileToContexts(
          fileBytes, contexts, widget.username, widget.token,
          description: description, fileName: fileName);

      // ⬇⬇⬇ NEW: refresh crediti non-bloccante (fine upload sync)
      _scheduleCreditsRefresh();
    } catch (e) {
      print('Errore caricamento file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingContext = null;
          _loadingFileName = null;
        });
      }
    }
  }

  /// Restituisce la mappa <context → taskIds> così chi la chiama può
  /// avviare il polling.  Ora accetta anche `loaders` e `loaderKwargs`
  /// per passare le configurazioni personalizzate al backend.
  Future<Map<String, TaskIdsPerContext>> _uploadFileAsync(
    Uint8List fileBytes,
    List<String> contexts, {
    String? description,
    required String fileName,
    Map<String, dynamic>? loaders, // ⬅️ NEW
    Map<String, dynamic>? loaderKwargs, // ⬅️ NEW
  }) async {
    final curPlan = BillingGlobals.snap.plan;
    final subId = _readSubscriptionId(curPlan);

    final resp = await _apiSdk.uploadFileToContextsAsync(
      fileBytes,
      contexts,
      widget.username,
      widget.token,
      subscriptionId: subId,
      description: description,
      fileName: fileName,
      loaders: loaders, // ⬅️ pass-through
      loaderKwargs: loaderKwargs, // ⬅️ pass-through
    );

    // ⬇⬇⬇ NEW: refresh crediti non-bloccante (fine upload async)
    _scheduleCreditsRefresh();

    return resp.tasks; // 〈context, TaskIdsPerContext〉
  }

  /// Polla /tasks_status ogni 3 s finché tutti i task sono DONE/ERROR.
  /// Polla /tasks_status ogni 3 s finché TUTTI i task del job sono DONE/ERROR.
  /// Alla fine rimuove lo spinner dal Knowledge-Box collegato
  /// e cancella il job da `_pendingJobs`.
  void _monitorUploadTasks(
    String jobId,
    Map<String, TaskIdsPerContext> tasksPerCtx,
  ) {
    const pollInterval = Duration(seconds: 3);
    Timer? timer;

    timer = Timer.periodic(pollInterval, (_) async {
      try {
        // 1. – richiede lo stato di TUTTI i task del job
        final statusResp = await _apiSdk.getTasksStatus(tasksPerCtx.values);

        // 2. – log minimale di debug
        statusResp.statuses.forEach((id, st) => debugPrint(
            '[$id] → ${st.status}${st.error != null ? " | ${st.error}" : ""}'));

        // 3. – verifica se tutti sono DONE o ERROR
        final allDoneOrError = statusResp.statuses.values
            .every((s) => s.status == 'DONE' || s.status == 'ERROR');

        if (!allDoneOrError) return; // → continua a pollare

        // 4. – se siamo qui, il job è completato/errore  ► stop timer
        timer?.cancel();

        // 5. – dati utili
        final job = _pendingJobs[jobId];
        final ctxPath = job?.contextPath ?? '<unknown>';

        debugPrint('📁  Upload completato su $ctxPath (jobId=$jobId)');

        if (mounted) {
          setState(() {
            // rimuove lo spinner dal KB interessato
            _isLoadingMap.remove(ctxPath);
            _loadingFileNamesMap.remove(ctxPath);

            // elimina il job da memoria + SharedPreferences
            _pendingJobs.remove(jobId);
            _savePendingJobs(_pendingJobs);
          });
        }
      } catch (e) {
        debugPrint('Errore polling status: $e');
        timer?.cancel();

        final job = _pendingJobs[jobId];
        final ctxPath = job?.contextPath ?? '<unknown>';

        // rimuove comunque lo spinner in caso di eccezione
        if (mounted) {
          setState(() {
            _isLoadingMap.remove(ctxPath);
            _loadingFileNamesMap.remove(ctxPath);
            _pendingJobs.remove(jobId);
            _savePendingJobs(_pendingJobs);
          });
        }
      }
    });

    // salva il timer per eventuale cancellazione manuale
    _pollers[jobId] = timer!;
  }

  // Funzione per eliminare un contesto
  Future<void> _deleteContext(String contextName) async {
    try {
      await _apiSdk.deleteContext(contextName, widget.username, widget.token);
      _loadContexts();
    } catch (e) {
      print('Errore eliminazione contesto: $e');
    }
  }

  // Funzione per eliminare un file
  Future<void> _deleteFile(String fileId) async {
    try {
      await _apiSdk.deleteFile(widget.username, widget.token, fileId: fileId);
    } catch (e) {
      print('Errore eliminazione file: $e');
    }
  }

// _DashboardScreenState

  bool _creditsRefreshInFlight = false;

  /// Refresh "leggero" dei crediti (non blocca la UI).
  Future<void> _refreshCreditsFast() async {
    if (_creditsRefreshInFlight) return;
    _creditsRefreshInFlight = true;
    try {
      final tok = widget.token;

      // 1) Piano: preferisci quello già in BillingGlobals, altrimenti chiedi al backend
      var plan = BillingGlobals.snap.plan;
      plan ??= await _apiSdk.getCurrentPlanOrNull(tok);

      if (plan == null) {
        BillingGlobals.setNoPlan();
        if (mounted) setState(() {}); // opzionale
        return;
      }

      // 2) Crediti: passa subscription_id se disponibile (più veloce)
      final subId = _readSubscriptionId(plan);
      final credits = await _apiSdk.getUserCredits(tok, subscriptionId: subId);

      // 3) Aggiorna il notifier globale (la Top-Bar si aggiorna da sola)
      BillingGlobals.setData(plan: plan, credits: credits);
      if (mounted) setState(() {}); // opzionale
    } catch (e) {
      BillingGlobals.setError(e); // errore "soft"
    } finally {
      _creditsRefreshInFlight = false;
    }
  }

  /// Schedula senza await (non blocca nulla)
  void _scheduleCreditsRefresh() {
    unawaited(_refreshCreditsFast());
  }

// ──────────────────────────────────────────────────────────────────────────────
// UPLOAD “bloccante”: la pagina resta in attesa (niente polling)
// ──────────────────────────────────────────────────────────────────────────────
  void _uploadFileForContext(String contextPath) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.first.bytes == null) {
      debugPrint('Nessun file selezionato');
      return;
    }

    setState(() {
      _isLoadingMap[contextPath] = true;
      _loadingFileNamesMap[contextPath] = result.files.first.name;
    });

    try {
      await _uploadFile(
        result.files.first.bytes!,
        [contextPath],
        fileName: result.files.first.name,
      );
    } catch (e) {
      debugPrint('Errore durante il caricamento: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMap.remove(contextPath);
          _loadingFileNamesMap.remove(contextPath);
        });
      }
    }
  }

// ──────────────────────────────────────────────────────────────────────────────
// UPLOAD “async”: ottiene i task-id, li traccia con un jobId univoco
// ──────────────────────────────────────────────────────────────────────────────
  void _uploadFileForContextAsync(String contextPath) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.first.bytes == null) {
      debugPrint('Nessun file selezionato');
      return;
    }

    // ① apre dialog di configurazione
    final cfg = await showLoaderConfigDialog(
      context,
      result.files.first.name,
      result.files.first.bytes!,
    );
    if (cfg == null) return; // utente ha annullato

    // 0. Spinner sul KB
    setState(() {
      _isLoadingMap[contextPath] = true;
      _loadingFileNamesMap[contextPath] = result.files.first.name;
    });

    try {
      // 1. Genera un UUID v4 per l’intero job
      final String jobId = const Uuid().v4();

      // 2. Chiamata POST /upload_async
      final tasksPerCtx = await _uploadFileAsync(
        result.files.first.bytes!,
        [contextPath],
        fileName: result.files.first.name,
        loaders: cfg['loaders'],
        loaderKwargs: cfg['loader_kwargs'],
      );

      // 3. Salva in memoria + SharedPreferences (keyed su jobId)
      _pendingJobs[jobId] = PendingUploadJob(
        jobId: jobId,
        chatId: '',
        contextPath: contextPath,
        fileName: result.files.first.name,
        tasksPerCtx: tasksPerCtx,
      );
      await _savePendingJobs(_pendingJobs);

      // 4. Notifica il padre (Dashboard / ChatBotPage, ecc.)
      widget.onNewPendingJob?.call(
        jobId,
        '',
        contextPath,
        result.files.first.name,
        tasksPerCtx,
      );

      // 5. Avvia il polling finché tutti i task sono DONE/ERROR
      _monitorUploadTasks(jobId, tasksPerCtx);
    } catch (e) {
      debugPrint('Errore durante il caricamento async: $e');
      if (mounted) {
        setState(() {
          _isLoadingMap.remove(contextPath);
          _loadingFileNamesMap.remove(contextPath);
        });
      }
    }
  }

  Widget _buildSearchAreaWithTitle() {
    final localizations = LocalizationProvider.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          // Se la larghezza disponibile è maggiore di 900,
          // mostra titolo e campo di ricerca in riga, con spazio tra di loro
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Titolo allineato a sinistra
              Text(
                localizations.knowledgeBoxes,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              // Campo di ricerca con larghezza massima fissata (ad es. 600)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600),
                child: TextField(
                  controller: _nameSearchController,
                  onChanged: (value) {
                    _filterContexts();
                  },
                  decoration: InputDecoration(
                    hintText: localizations.search_by_name_or_description,
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          // Se la larghezza disponibile è inferiore a 900,
          // mostra il titolo sopra il campo di ricerca
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo allineato a sinistra
              Text(
                localizations.knowledgeBoxes,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              // Campo di ricerca centrato e che occupa tutta la larghezza disponibile
              Center(
                child: TextField(
                  controller: _nameSearchController,
                  onChanged: (value) {
                    _filterContexts();
                  },
                  decoration: InputDecoration(
                    hintText: localizations.search_by_name_or_description,
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.black), // Bordi neri
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color:
                              Colors.black), // Bordi neri per lo stato normale
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: Colors.black,
                          width:
                              2.0), // Bordi neri più spessi per lo stato attivo
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

// UI constraints dialog
  final double _kDialogMaxWidth =
      600; // larghezza massima del contenuto del dialog
  final double _kDescMaxHeight = 200; // altezza massima area descrizione
  final double _kViewDialogMaxHeight = 800;

  InputDecoration _outlinedDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white, // campo su fondo bianco
      // bordo di default (utile per stati non esplicitati)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide:
            const BorderSide(width: 0.8, color: Colors.black54), // più sottile
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide:
            const BorderSide(width: 0.8, color: Colors.black54), // più sottile
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(
            width: 1.2, color: Colors.black), // sottile anche in focus
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // Funzione per mostrare il dialog per creare un contesto con caricamento obbligatorio di un file
  // Funzione per mostrare il dialog per creare un contesto senza obbligo di caricare un file subito
  void _showCreateContextDialog() {
    final localizations = LocalizationProvider.of(context);
    TextEditingController contextNameController = TextEditingController();
    TextEditingController contextDescriptionController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.create_new_knowledge_box),
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
          content: ConstrainedBox(
            constraints: BoxConstraints(
              // massimo 600 di larghezza, ma si restringe se lo schermo è più stretto
              maxWidth: _kDialogMaxWidth,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // occupa tutta la larghezza
                children: [
                  // ► Campo NOME (max 20 char, una riga)
                  TextField(
                    controller: contextNameController,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    maxLength: 20, // opzionale: mostra il contatore
                    decoration:
                        _outlinedDecoration(localizations.knowledge_box_name),
                  ),
                  const SizedBox(height: 12),

                  // ► Campo DESCRIZIONE (multiline, wrap, scroll con altezza max)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      // limita l’altezza visibile: oltre scorre
                      maxHeight: _kDescMaxHeight,
                    ),
                    child: TextField(
                      controller: contextDescriptionController,
                      keyboardType: TextInputType.multiline,
                      minLines: 3, // altezza minima
                      maxLines: 8, // oltre questa soglia il TextField scrolla
                      decoration: _outlinedDecoration(
                          localizations.knowledge_box_description),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              child: Text(localizations.create_knowledge_box),
              // ──────────────────────────────────────────────────────────────
              //  PULSANTE “CREA” COMPLETAMENTE RISCRITTO
              //  • chiude il dialog subito
              //  • crea la KB via API
              //  • poi ricarica l’elenco dal server con _loadContexts()
              // ──────────────────────────────────────────────────────────────
              onPressed: () async {
                final friendly = contextNameController.text.trim();

                // 1) validazione minima
                if (friendly.isEmpty) {
                  debugPrint('Errore: nome del contesto obbligatorio.');
                  return;
                }

                Navigator.of(context).pop(); // chiude il popup

                // 2) genera un uuid (primi 9 caratteri)
                final String fullUuid = const Uuid().v4();
                final String uuid = fullUuid.substring(0, 9);

                // 3) chiamata API per creare la KB
                await _apiSdk.createContext(
                  uuid, // path / ID interno
                  contextDescriptionController.text.trim(), // description
                  friendly, // display_name
                  widget.username,
                  widget.token,
                );

                // 4) ricarica l’elenco completo delle KB dal backend
                await _loadContexts(); // aggiorna griglia + filtri
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _downloadDocumentsJsonByName(
      String ctx, String fname, String baseFileName) async {
    final docs = await _apiSdk.listDocumentsResolved(
      ctx: ctx,
      filename: fname,
      token: widget.token,
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

  void _showFilesForContextDialog(String contextPath) async {
    final localizations = LocalizationProvider.of(context);
    // Carica i file per il contesto selezionato
    List<Map<String, dynamic>> filesForContext =
        await _loadFilesForContext(contextPath);
    bool isDeleting = false; // mostra overlay se true
    String? deletingFileName; // opzionale: nome mostrato accanto allo spinner
    // Trova la descrizione associata al contesto corrente
    final selectedContext = _allContexts.firstWhere(
      (context) => context.path == contextPath,
      orElse: () => ContextMetadata(path: '', customMetadata: {}),
    );
    final description = selectedContext.customMetadata?['description'] ?? null;

    // Controller per la barra di ricerca
    TextEditingController searchController = TextEditingController();

    // Lista dei file filtrati
    List<Map<String, dynamic>> filteredFiles = List.from(filesForContext);

    // Funzione per filtrare i file
    void _filterFiles(String query) {
      filteredFiles = filesForContext.where((file) {
        final fileName = (file['path'] ?? '').toLowerCase();
        return fileName.contains(query.toLowerCase());
      }).toList();
    }

    // Mostra il dialog
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // ⇩⇩⇩ calcola limiti responsivi in base allo schermo
            final mq = MediaQuery.of(context);
            final double maxW = math.min(
                _kDialogMaxWidth, mq.size.width - 32); // 16px margine per lato
            final double maxH =
                math.min(_kViewDialogMaxHeight, mq.size.height * 0.85);

            return Stack(children: [
              AlertDialog(
                backgroundColor: Colors.white,
                elevation: 6,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16, // margine laterale per schermi piccoli
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: SizedBox(
                    width:
                        maxW, // ⬅️ vincolo duro di larghezza anche per il titolo
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          WireframeCubeIcon(
                            size: 36.0,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8.0),
                          Text(
                            selectedContext.customMetadata?["display_name"] ??
                                selectedContext.path,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        ]),
                        SizedBox(height: 8.0),
                        if (description != null &&
                            description.trim().isNotEmpty)
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey, // ← identico alla card
                              fontWeight: FontWeight.normal,
                            ),
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        SizedBox(height: 16.0),
                        // Barra di ricerca
                        TextField(
                          controller: searchController,
                          onChanged: (value) {
                            // Aggiorna i risultati del filtro
                            setState(() {
                              _filterFiles(value);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: localizations.search_file,
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.black), // Bordi neri
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors
                                      .black), // Bordi neri per lo stato normale
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Colors.black,
                                  width:
                                      2.0), // Bordi neri più spessi per lo stato attivo
                            ),
                          ),
                        ),
                      ],
                    )),
                //shape: RoundedRectangleBorder(
                //  borderRadius: BorderRadius.circular(8),
                //),
// ⇩⇩⇩ vincola larghezza/altezza massime in modo responsivo
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxW,
                    maxHeight: maxH,
                  ),
                  child: SizedBox(
                    width: double
                        .maxFinite, // occupa tutta la larghezza disponibile entro i vincoli
                    child: filteredFiles.isEmpty
                        ? const Text('Nessun file trovato per questo contesto.')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredFiles.length,
                            itemBuilder: (context, index) {
                              String filePath = filteredFiles[index]['path'];
                              List<String> pathSegments = filePath.split('/');
                              String fileName = pathSegments.isNotEmpty
                                  ? pathSegments.last
                                  : 'Sconosciuto';
                              String fileUUID = filteredFiles[index]
                                      ['custom_metadata']['file_uuid'] ??
                                  'Sconosciuto';
                              String fileType = filteredFiles[index]
                                      ['custom_metadata']['type'] ??
                                  'Sconosciuto';
                              String uploadDate = filteredFiles[index]
                                      ['custom_metadata']['upload_date'] ??
                                  'Sconosciuto';
                              String fileSize = filteredFiles[index]
                                      ['custom_metadata']['size'] ??
                                  'Sconosciuto';

                              return Card(
                                color: Colors.white,
                                elevation: 6,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Riga superiore: Nome file e icona rappresentativa
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Nome del file
                                          Expanded(
                                            child: Text(
                                              fileName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Icona del file
                                          Icon(
                                            _getIconForFileType(fileName)[
                                                'icon'], // Ottieni l'icona
                                            size: 32,
                                            color: _getIconForFileType(
                                                    fileName)[
                                                'color'], // Ottieni il colore
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 5),
                                      // Dettagli aggiuntivi del file
                                      Text(
                                          '${localizations.file_type}: $fileType'),
                                      Text(
                                          '${localizations.file_size}: $fileSize'),
                                      Text(
                                          '${localizations.upload_date}: $uploadDate'),
                                      // Spazio per spostare il cestino in basso
                                      Spacer(),
                                      // Cestino in basso a destra
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          // 🆕 Download file sorgente
                                          IconButton(
                                            tooltip: 'Scarica',
                                            icon: const Icon(Icons.download,
                                                color: Colors.black),
                                            onPressed: () {
                                              final fileId =
                                                  filteredFiles[index]
                                                          ['name'] ??
                                                      '';
                                              _apiSdk.downloadFile(fileId,
                                                  token: widget.token);
                                            },
                                          ),
                                          // Visualizza anteprima + JSON
                                          IconButton(
                                            tooltip: 'Visualizza',
                                            icon: const Icon(Icons.visibility,
                                                color: Colors.black),
                                            onPressed: () {
                                              _showFilePreviewDialog(
                                                filteredFiles[index],
                                                fileName,
                                              );
                                            },
                                          ),
                                          // Elimina
                                          IconButton(
                                            tooltip: 'Elimina',
                                            icon: const Icon(Icons.delete,
                                                color: Colors.black),
                                            onPressed: () async {
                                              // Mostra overlay
                                              setState(() {
                                                isDeleting = true;
                                                deletingFileName =
                                                    fileName; // opzionale
                                              });

                                              try {
                                                await _deleteFile(
                                                    fileUUID); // chiamata esistente
                                                // Aggiorna lista dopo la cancellazione
                                                setState(() {
                                                  filesForContext.removeWhere(
                                                    (f) =>
                                                        f['custom_metadata']
                                                            ['file_uuid'] ==
                                                        fileUUID,
                                                  );
                                                  _filterFiles(
                                                      searchController.text);
                                                });
                                              } catch (e) {
                                                // feedback minimo in caso di errore
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text(
                                                            'Errore eliminazione: $e')),
                                                  );
                                                }
                                              } finally {
                                                // Nascondi overlay
                                                setState(() {
                                                  isDeleting = false;
                                                  deletingFileName = null;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.close),
                  ),
                ],
              ),
              // ─────────────────────────────────────────────
              // OVERLAY BLOCCANTE + SPINNER
              // ─────────────────────────────────────────────
              if (isDeleting)
                Positioned.fill(
                  child: AbsorbPointer(
                    // intercetta i tap e blocca l'interazione sotto
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        color: Colors.black
                            .withOpacity(0.20), // oscura leggermente
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(blurRadius: 12, color: Colors.black26)
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                deletingFileName == null
                                    ? 'Eliminazione in corso…'
                                    : 'Eliminazione di "$deletingFileName"…',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]);
          },
        );
      },
    );
  }

  void _showEditContextDialog(ContextMetadata ctx) {
    final localizations = LocalizationProvider.of(context);

    final TextEditingController nameCtrl = TextEditingController(
      text: ctx.customMetadata?['display_name'] ?? ctx.path,
    );
    final TextEditingController descCtrl = TextEditingController(
      text: ctx.customMetadata?['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(localizations.edit_knowledge_box),
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _kDialogMaxWidth,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ► Campo NOME (max 20 char)
                  TextField(
                    controller: nameCtrl,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                    maxLength: 20, // opzionale
                    decoration:
                        _outlinedDecoration(localizations.knowledge_box_name),
                  ),
                  const SizedBox(height: 12),

                  // ► Campo DESCRIZIONE multilinea con altezza massima e scroll
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: _kDescMaxHeight,
                    ),
                    child: TextField(
                      controller: descCtrl,
                      keyboardType: TextInputType.multiline,
                      minLines: 3,
                      maxLines: 8,
                      decoration: _outlinedDecoration(
                          localizations.knowledge_box_description),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newDesc = descCtrl.text.trim();

                await _apiSdk.updateContextMetadata(
                  widget.username,
                  widget.token,
                  contextName: ctx.path,
                  description: newDesc,
                  extraMetadata: {'display_name': newName},
                );

                // ⬇⬇⬇ ricarica la lista completa dal backend
                await _loadContexts();

                // (opzionale) se c’è un testo nel search box, riapplica il filtro
                if (_nameSearchController.text.trim().isNotEmpty) {
                  _filterContexts();
                }

                Navigator.of(context).pop();
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    return Scaffold(
      //appBar: //AppBar(
      //title: Text('Context API Dashboard'),
      //),
      backgroundColor: Colors.transparent, // Imposta lo sfondo bianco
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAreaWithTitle(),
            SizedBox(height: 10),
            SizedBox(height: 10),
            _isCtxLoading // ▼▼▼ 4. show/hide
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    flex: 1,
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            300, // Dimensione massima per ciascuna scheda
                        crossAxisSpacing: 10, // Spaziatura tra le colonne
                        mainAxisSpacing: 10, // Spaziatura tra le righe
                        childAspectRatio:
                            1.5, // Proporzione larghezza/altezza delle schede
                      ),
                      itemCount: _filteredContexts.length +
                          1, // Aggiungiamo una card in più
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap:
                                _showCreateContextDialog, // Apre il dialog per creare il contesto
                            child: Card(
                              color: Colors.blue, // Sfondo grigio
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  localizations.create_new_knowledge_box,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Testo bianco
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

// Dopo questa parte, lascia il resto invariato
                        final contextMetadata = _filteredContexts[index -
                            1]; // Offset perché il primo è la scheda grigia

                        Map<String, dynamic>? metadata =
                            contextMetadata.customMetadata;
                        List<Widget> metadataWidgets = [];
                        final desc =
                            metadata?['description']?.toString().trim();

                        if (desc != null && desc.isNotEmpty) {
                          metadataWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: Text(
                                desc, // ← solo valore, niente prefisso
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors
                                      .grey, // stesso colore della mini-card
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: () {
                            _showFilesForContextDialog(contextMetadata.path);
                          },
                          child: Stack(children: [
                            Card(
                              color: Colors.white,
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  WireframeCubeIcon(
                                                      size: 36.0,
                                                      color: Colors.blue),
                                                  const SizedBox(width: 8.0),
                                                  Expanded(
                                                    // ⬅️ AGGIUNTO: impone un vincolo di larghezza → ellissi funziona
                                                    child: Text(
                                                      _displayName(
                                                          contextMetadata),
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      softWrap:
                                                          false, // ⬅️ evita l’andata a capo
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Rotella di caricamento e nome del file (se in caricamento)
                                            ],
                                          ),
                                        ),
                                        // Menu popup per azioni (Carica File ed Elimina Contesto)
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    // Metadati del contesto
                                    ...metadataWidgets,
                                    SizedBox(height: 16),
                                    if (_isLoadingMap[contextMetadata.path] ==
                                            true &&
                                        _loadingFileNamesMap[
                                                contextMetadata.path] !=
                                            null)
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 16.0,
                                            height: 16.0,
                                            child: CircularProgressIndicator(
                                              strokeWidth:
                                                  2.0, // Rotella più sottile
                                              color: Colors
                                                  .blue, // Colore della rotella
                                            ),
                                          ),
                                          SizedBox(width: 8.0),
                                          Expanded(
                                            child: Text(
                                              _loadingFileNamesMap[
                                                      contextMetadata.path] ??
                                                  '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ), // MENU ⋮ IN BASSO A DESTRA
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  popupMenuTheme: PopupMenuThemeData(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    color: Colors.white,
                                  ),
                                ),
                                child: PopupMenuButton<String>(
                                  tooltip: 'Azioni',
                                  offset: const Offset(0,
                                      -8), // apre leggermente sopra il bottone
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteContext(contextMetadata.path);
                                    } else if (value == 'upload') {
                                      _uploadFileForContextAsync(
                                          contextMetadata.path);
                                    } else if (value == 'edit') {
                                      _showEditContextDialog(contextMetadata);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'upload',
                                      child: Text(localizations.upload_file),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Text(localizations.edit),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text(localizations.delete),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
