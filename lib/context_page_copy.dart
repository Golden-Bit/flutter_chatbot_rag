import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_app/ui_components/dialogs/loader_config_dialog.dart';
import 'package:flutter_app/ui_components/icons/cube.dart';
import 'package:flutter_app/user_manager/state/billing_globals.dart';
import 'package:flutter_app/utilities/localization.dart';
import 'package:universal_html/html.dart' as html;
import 'context_api_sdk.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // per jsonEncode / jsonDecode
import 'package:uuid/uuid.dart';
import 'dart:convert' show JsonEncoder;

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
  final String        token;
  final String        collection;
  final int           pageSize;

  const _PaginatedDocViewer({
    Key? key,
    required this.apiSdk,
    required this.token,
    required this.collection,
    this.pageSize = 1,
  }) : super(key: key);

  @override
  State<_PaginatedDocViewer> createState() => _PaginatedDocViewerState();
}

class _PaginatedDocViewerState extends State<_PaginatedDocViewer> {
  late Future<List<DocumentModel>> _future;
  int  _page  = 0;        // 0‑based
  int? _total;

  @override
  void initState() {
    super.initState();
    _future = _fetch();           // ► prima pagina
  }

  /*──────── helper API (skip / limit fissi) ────────*/
  Future<List<DocumentModel>> _fetch() async {
    return widget.apiSdk.listDocuments(
      widget.collection,
      token : widget.token,
      skip  : _page * widget.pageSize,
      limit : widget.pageSize,        // sempre = pageSize
      onTotal: (t) => _total = t,
    );
  }

  /*──────── cambio pagina (con guard‑rail) ────────*/
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

          final docs    = snap.data!;
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
                      ? 'Pagina ${_page + 1}'
                      : 'Pagina ${_page + 1} / ${(_total! / widget.pageSize).ceil()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  IconButton(
                    tooltip : 'Pagina successiva',
                    icon    : const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: (isEmpty || docs.length < widget.pageSize)
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
  final String jobId;                       // id univoco del job
  final String chatId;                      // id della chat a cui appartiene
  final String contextPath;                 // path KB
  final String fileName;                    // nome file
  final Map<String, TaskIdsPerContext> tasksPerCtx;

  PendingUploadJob({
    required this.jobId,
    required this.chatId,
    required this.contextPath,
    required this.fileName,
    required this.tasksPerCtx,
  });

  Map<String, dynamic> toJson() => {
        'jobId'  : jobId,
        'chatId' : chatId,
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
      jobId       : j['jobId'],
      chatId      : j['chatId'],
      contextPath : j['context'],
      fileName    : j['fileName'],
      tasksPerCtx : tasks,
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

  String _collectionNameFrom(Map<String, dynamic> file) {
    final raw = file['name'] ?? '';
    // es.: "ctx/filename.pdf"  →  "ctxfilename.pdf_collection"
    return raw.replaceAll('/', '') + '_collection';
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
  final collection = _collectionNameFrom(file);

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
            onPressed: () => _downloadDocumentsJson(collection, fileName),
          ),
        ],
      ),

      /*──────────────────────── corpo paginato (Stateful) ──────────────────────*/
      content: _PaginatedDocViewer(
        apiSdk     : _apiSdk,
        token      : widget.token,              // stringa token
        collection : collection,
        pageSize   : 1,                         // mostra 1 doc per pagina
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

/*// NEW – cache locale per evitare round-trip ripetuti
Map<String, List<String>>? _extToLoaders;
Map<String, dynamic>?      _kwargsSchema;

Future<void> _ensureLoaderCatalog() async {
  if (_extToLoaders != null && _kwargsSchema != null) return;
  _extToLoaders = await _apiSdk.getLoadersCatalog();
  _kwargsSchema = await _apiSdk.getLoaderKwargsSchema();
}// ───────────────────────────────────────────────────────────────────────────
//  DROPDOWN stile material‑v3 ri‑utilizzabile
// ───────────────────────────────────────────────────────────────────────────
Widget _styledDropdown({
  required String value,
  required List<String> items,
  required void Function(String?) onChanged,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: value,
          items: items
              .map((it) => DropdownMenuItem(value: it, child: Text(it)))
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.black87),
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.zero,
            height: 48,
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ),
  );
}
// ───────────────────────────────────────────────────────────────────────────
//  Riquadro grigio che contiene i parametri dinamici del loader
// ───────────────────────────────────────────────────────────────────────────
// ───────────────────────────────────────────────────────────────────────────
//  Riquadro grigio che contiene i parametri dinamici del loader
// ───────────────────────────────────────────────────────────────────────────
Widget _kwargsPanel(List<Widget> fields) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Column(children: fields),
  );
}


/// helper per una riga “chiave: valore”
/// (ritorna SizedBox.shrink se `value` è null / vuoto)
Widget _kvCell(String key, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 13),
        children: [
          TextSpan(
            text: '$key: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

/// box riassuntivo della stima costo (pre‑processing)
Widget _buildCostBox(FileCost fc) {
  /* ──────────────────────────────────────────────────────────
     Helper: converte [[k,v], …] in righe a 2 colonne           */
  List<TableRow> _rows2cols(List<List<String?>> kv) {
    final rows = <TableRow>[];
    for (var i = 0; i < kv.length; i += 2) {
      final left  = kv[i];
      final right = (i + 1 < kv.length) ? kv[i + 1] : ['', null];
      rows.add(TableRow(children: [
        _kvCell(left[0]!,  left[1]),
        _kvCell(right[0]!, right[1]),
      ]));
    }
    return rows;
  }

  /* 1️⃣  campi principali */
  final primaryKv = <List<String?>>[
    ['Filename',    fc.filename],
    ['Kind',        fc.kind],
    ['Pages',       fc.pages?.toString()],
    ['Minutes',     fc.minutes?.toStringAsFixed(2)],
    ['Strategy',    fc.strategy],
    ['Size (B)',    fc.sizeBytes.toString()],
    ['Tokens est.', fc.tokensEst?.toString()],
  ]..removeWhere((e) => e[1] == null);          // solo valori presenti

  /* 2️⃣  parametri risolti (fc.params) */
  final paramKv = (fc.params ?? {})
      .entries
      .map((e) => [e.key, e.value.toString()])
      .toList();

  /* 3️⃣  formula + condizioni */
  final List<Widget> formulaSection = [];
  if (fc.formula != null || (fc.paramsConditions?.isNotEmpty ?? false)) {
    formulaSection
      ..add(const SizedBox(height: 12))
      ..add(const Divider(height: 1))
      ..add(const SizedBox(height: 6));

    if (fc.formula != null) {
      formulaSection.add(_kvCell('Cost', fc.formula!.split('=').last));
    }
    fc.paramsConditions?.forEach((k, v) {
      formulaSection.add(_kvCell(k, v));
    });
  }

  /* 4️⃣  UI finale */
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      /* tabella core */
      Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
        children: _rows2cols(primaryKv),
      ),

      /* tabella parametri */
      if (paramKv.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 6),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
          children: _rows2cols(paramKv),
        ),
      ],

      /* formula & condizioni  */
      ...formulaSection,

      const SizedBox(height: 8),
      const Divider(height: 1),
      const SizedBox(height: 6),

      /* costo finale */
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '\$${fc.costUsd!.toStringAsFixed(4)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    ],
  );
}

/// Dialog «Configura loader» con stima costo live e recalcolo immediato
/// ----------------------------------------------------------------------
/// Restituisce una mappa `{loaders, loader_kwargs}` pronta da passare
/// al backend oppure `null` se l’utente annulla.
Future<Map<String, dynamic>?> _showLoaderConfigDialog(
  BuildContext ctx,
  String       fileName,
  Uint8List    fileBytes,
) async {
  /* 1️⃣  Cataloghi & schema */
  await _ensureLoaderCatalog();

  final ext     = fileName.split('.').last.toLowerCase();
  final loaders = _extToLoaders![ext] ?? _extToLoaders!['default']!;
  String selectedLoader = loaders.first;

  /* 2️⃣  Controller dinamici per i kwargs */
  final Map<String, TextEditingController> ctrls = {};

  Map<String, dynamic> _editableSchema() {
    final raw = _kwargsSchema![selectedLoader] as Map<String, dynamic>;
    return Map.fromEntries(
      raw.entries.where((e) => (e.value['editable'] ?? true) == true),
    );
  }

  void _initCtrls() {
    ctrls.clear();
    for (final e in _editableSchema().entries) {
      ctrls[e.key] = TextEditingController(
        text: jsonEncode(e.value['default']),
      );
    }
  }

  _initCtrls(); // prima inizializzazione

  /* 3️⃣  Stima costo iniziale dal backend */
  late FileCost _baseCost;
  final ValueNotifier<FileCost?> costVN = ValueNotifier(null);

  Future<void> _fetchInitialCost() async {
    final kwargsMap = {
      ext: ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
    };

    final estimate = await _apiSdk.estimateFileProcessingCost(
      [fileBytes],
      [fileName],
      loaderKwargs: kwargsMap,
    );

    _baseCost      = estimate.files.first;
  }

  await _fetchInitialCost(); // blocca finché non arrivano i dati

  /* 4️⃣  Ricalcolo locale (live) */
  void _applyChange() {
    final override = {
      ext: selectedLoader,
      ...ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
    };

    final newCost = _apiSdk.recomputeFileCost(
      _baseCost,
      configOverride: override,
    );

      // forza sempre il rebuild del ValueListenableBuilder
  costVN
    ..value = null                       // step 1: valore diverso
    ..value = newCost;                   // step 2: quello vero
  }

  // ricalcolo immediato prima di mostrare il dialog
  _applyChange();

  /* ═════════════════════ Dialog ═════════════════════ */
  return showDialog<Map<String, dynamic>>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (c, setSt) {
        /* Cambio loader */
        Future<void> _onLoaderChanged(String? v) async {
          if (v == null) return;
          selectedLoader = v;
          _initCtrls();
          setSt(() {});      // forza rebuild dei campi
          _applyChange();    // aggiorna costo
        }

        /* Costruzione dei campi dinamici */
        List<Widget> _buildFieldWidgets() {
          return _editableSchema().entries.map((e) {
            final fld   = e.value as Map<String, dynamic>;
            final typ   = fld['type'] as String;
            final items = fld['items'];
            final label = fld['name'];

            Widget _label() => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (fld['description'] != null)
                  Tooltip(
                    message: fld['description'],
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.help_outline, size: 16),
                    ),
                  ),
              ],
            );

            /* ENUM */
            if (items is List && items.isNotEmpty) {
              final curr = jsonDecode(ctrls[e.key]!.text) ?? items.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _label(),
                  _styledDropdown(
                    value: curr.toString(),
                    items: items.map((v) => v.toString()).toList(),
                    onChanged: (v) {
                      ctrls[e.key]!.text = jsonEncode(v);
                      _applyChange();
                      setSt(() {});
                    },
                  ),
                ],
              );
            }

            /* BOOL */
            if (typ == 'boolean' || typ == 'bool') {
              final curr = jsonDecode(ctrls[e.key]!.text) as bool;
              return CheckboxListTile(
                title: _label(),
                value: curr,
                onChanged: (v) {
                  ctrls[e.key]!.text = jsonEncode(v);
                  _applyChange();
                  setSt(() {});
                },
              );
            }

            /* TEXT / NUMBER */
            return TextField(
              controller: ctrls[e.key],
              decoration: InputDecoration(label: _label()),
  onChanged: (_) {
    _applyChange();
    setSt(() {});          // 🔹 idem (utile per formattazione live)
  },
            );
          }).toList();
        }

        /* UI finale */
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Configura loader – $fileName'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Loader dropdown
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('Loader', style: TextStyle(color: Colors.black54)),
                  ),
                  _styledDropdown(
                    value: selectedLoader,
                    items: loaders,
                    onChanged: _onLoaderChanged,
                  ),
                  const SizedBox(height: 16),

                  // Campi kwargs dinamici
                  _kwargsPanel(_buildFieldWidgets()),
                  const SizedBox(height: 20),

                  // Titolo sezione costo
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Stima costo preprocessing',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),

                  // Box costo reattivo
                  ValueListenableBuilder<FileCost?>(
                    valueListenable: costVN,
                    builder: (_, fc, __) {
                      if (fc == null) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _buildCostBox(fc),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(c).pop(null),
            ),
            ElevatedButton(
              child: const Text('Procedi'),
              onPressed: () {
                final loadersMap = {ext: selectedLoader};
                final kwargsMap  = {
                  ext: ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
                };
                Navigator.of(c).pop({
                  'loaders'      : loadersMap,
                  'loader_kwargs': kwargsMap,
                });
              },
            ),
          ],
        );
      },
    ),
  );
}
*/



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
        _loadContexts();               // carica i contesti appena parte la pagina
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
        _allContexts      = all;
        _gridContexts     = all.where((c) => !_isChatContext(c)).toList();
        _contexts         = List.from(_gridContexts);
        _filteredContexts = List.from(_gridContexts);
        _isCtxLoading     = false;                 // ✓ fine caricamento
      });
      if (_nameSearchController.text.trim().isNotEmpty) {
  _filterContexts();
}
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
      final displayName =
          (ctx.customMetadata?['display_name'] ?? ctx.path).toString().toLowerCase();
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
  Map<String, dynamic>? loaders,        // ⬅️ NEW
  Map<String, dynamic>? loaderKwargs,   // ⬅️ NEW
}) async {

          final curPlan = BillingGlobals.snap.plan;
final subId   = _readSubscriptionId(curPlan);

  final resp = await _apiSdk.uploadFileToContextsAsync(
    fileBytes,
    contexts,
    widget.username,
    widget.token,
    subscriptionId: subId,
    description: description,
    fileName: fileName,
    loaders: loaders,                   // ⬅️ pass-through
    loaderKwargs: loaderKwargs,         // ⬅️ pass-through
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
    final subId   = _readSubscriptionId(plan);
    final credits = await _apiSdk.getUserCredits(tok, subscriptionId: subId);

    // 3) Aggiorna il notifier globale (la Top-Bar si aggiorna da sola)
    BillingGlobals.setData(plan: plan, credits: credits);
    if (mounted) setState(() {}); // opzionale
  } catch (e) {
    BillingGlobals.setError(e);   // errore "soft"
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contextNameController,
                decoration: InputDecoration(
                    labelText: localizations.knowledge_box_name),
              ),
              TextField(
                controller: contextDescriptionController,
                decoration: InputDecoration(
                    labelText: localizations.knowledge_box_description),
              ),
            ],
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

    Navigator.of(context).pop();                  // chiude il popup

    // 2) genera un uuid (primi 9 caratteri)
    final String fullUuid = const Uuid().v4();
    final String uuid     = fullUuid.substring(0, 9);

    // 3) chiamata API per creare la KB
    await _apiSdk.createContext(
      uuid,                                       // path / ID interno
      contextDescriptionController.text.trim(),   // description
      friendly,                                   // display_name
      widget.username,
      widget.token,
    );

    // 4) ricarica l’elenco completo delle KB dal backend
    await _loadContexts();                        // aggiorna griglia + filtri
  },
)

          ],
        );
      },
    );
  }

  Future<void> _downloadDocumentsJson(
      String collection, String baseFileName) async {
    // 1) scarica i documenti
    final docs = await _apiSdk.listDocuments(collection, token: widget.token);

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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16), // Arrotondamento degli angoli
                //side: BorderSide(
                //  color: Colors.blue, // Colore del bordo
                //  width: 2, // Spessore del bordo
                //),
              ),
              title: Column(
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
                  if (description != null && description.trim().isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey, // ← identico alla card
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 2,
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
              ),
              backgroundColor: Colors.white,
              elevation: 6,
              //shape: RoundedRectangleBorder(
              //  borderRadius: BorderRadius.circular(8),
              //),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400, maxHeight: 800),
                child: Container(
                  width: double.maxFinite,
                  child: filteredFiles.isEmpty
                      ? Text('Nessun file trovato per questo contesto.')
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          color: _getIconForFileType(fileName)[
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
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // 🆕 Download file sorgente
                                        IconButton(
                                          tooltip: 'Scarica',
                                          icon: const Icon(Icons.download,
                                              color: Colors.black),
                                          onPressed: () {
                                            final fileId = filteredFiles[index]
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
                                            await _deleteFile(fileUUID);
                                            setState(() {
                                              filesForContext.removeWhere((f) =>
                                                  f['custom_metadata']
                                                      ['file_uuid'] ==
                                                  fileUUID);
                                              _filterFiles(
                                                  searchController.text);
                                            });
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
            );
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: localizations.knowledge_box_name),
              ),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                    labelText: localizations.knowledge_box_description),
              ),
            ],
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

                // ① chiamata API
                await _apiSdk.updateContextMetadata(
                  widget.username,
                  widget.token,
                  contextName: ctx.path,
                  description: newDesc,
                  extraMetadata: {'display_name': newName},
                );

                // ② sincronizza stato locale
                final idx = _contexts.indexWhere((c) => c.path == ctx.path);
                if (idx != -1) {
                  setState(() {
                    _contexts[idx] = ContextMetadata(
                      path: ctx.path,
                      customMetadata: {
                        ...?ctx.customMetadata,
                        'display_name': newName,
                        'description': newDesc,
                      },
                    );
                    _filterContexts(); // aggiorna vista filtrata
                  });
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
            _isCtxLoading                    // ▼▼▼ 4. show/hide
                      ? const Expanded(child: Center(child: CircularProgressIndicator()))
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
                itemCount:
                    _filteredContexts.length + 1, // Aggiungiamo una card in più
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
                  final contextMetadata = _filteredContexts[
                      index - 1]; // Offset perché il primo è la scheda grigia

                  Map<String, dynamic>? metadata =
                      contextMetadata.customMetadata;
                  List<Widget> metadataWidgets = [];
                  final desc = metadata?['description']?.toString().trim();

                  if (desc != null && desc.isNotEmpty) {
                    metadataWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Text(
                          desc, // ← solo valore, niente prefisso
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey, // stesso colore della mini-card
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
                    child: Card(
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            // 1) ICONA CUBO
                                            WireframeCubeIcon(
                                              size: 36.0,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 8.0),
                                            // Nome del contesto
                                            Text(
                                              _displayName(contextMetadata),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          ]),
                                      // Rotella di caricamento e nome del file (se in caricamento)
                                    ],
                                  ),
                                ),
                                // Menu popup per azioni (Carica File ed Elimina Contesto)
                                Theme(
                                    data: Theme.of(context).copyWith(
                                      popupMenuTheme: PopupMenuThemeData(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: PopupMenuButton<String>(
                                      offset: const Offset(0, 32),
                                      borderRadius: BorderRadius.circular(
                                          16), // Imposta un raggio di 8
                                      color: Colors.white,
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deleteContext(contextMetadata.path);
                                        } else if (value == 'upload') {
                                          _uploadFileForContextAsync(
                                              contextMetadata.path);
                                        } else if (value == 'edit') {
                                          // ③
                                          _showEditContextDialog(
                                              contextMetadata); // ④
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'upload',
                                          child:
                                              Text(localizations.upload_file),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'edit', // ① nuova voce
                                          child: Text(localizations
                                              .edit), // ② nuova label (aggiungi nelle i18n)
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text(localizations.delete),
                                        ),
                                      ],
                                    )),
                              ],
                            ),
                            SizedBox(height: 5),
                            // Metadati del contesto
                            ...metadataWidgets,
                            SizedBox(height: 16),
                            if (_isLoadingMap[contextMetadata.path] == true &&
                                _loadingFileNamesMap[contextMetadata.path] !=
                                    null)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16.0,
                                    height: 16.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0, // Rotella più sottile
                                      color:
                                          Colors.blue, // Colore della rotella
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
                    ),
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
