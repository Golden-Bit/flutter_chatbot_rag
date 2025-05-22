import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_app/ui_components/icons/cube.dart';
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
            future: _apiSdk.listDocuments(collection, token: widget.token),
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

Future<void> _loadContexts() async {
  try {
    final all = await _apiSdk.listContexts(widget.username, widget.token);

    if (!mounted) return;

    setState(() {
      _allContexts    = all;                              // tutto, chat incluse
      _gridContexts   = all.where((c) => !_isChatContext(c)).toList();

            _contexts       = List.from(_gridContexts);  

      _filteredContexts = List.from(_gridContexts);
    });
  } catch (e) {
    debugPrint('Errore nel recupero dei contesti: $e');
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

  /// Restituisce la mappa <context → taskIds> così chi la chiama può avviare il polling
  Future<Map<String, TaskIdsPerContext>> _uploadFileAsync(
    Uint8List fileBytes,
    List<String> contexts, {
    String? description,
    required String fileName,
  }) async {
    final resp = await _apiSdk.uploadFileToContextsAsync(
      fileBytes,
      contexts,
      widget.username,
      widget.token,
      description: description,
      fileName: fileName,
    );
    return resp.tasks; // <── RITORNA
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

  // Mostra il dialog per caricare file in contesti multipli
  /*void _showUploadFileToMultipleContextsDialog() {
    final localizations = LocalizationProvider.of(context);
    TextEditingController descriptionController = TextEditingController();
    List<String> selectedContexts = [];
    FilePickerResult? fileResult;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(localizations.upload_file_in_multiple_knowledge_boxes),
              backgroundColor: Colors.white, // Sfondo del popup
              elevation: 6, // Intensità dell'ombra
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(4), // Arrotondamento degli angoli
                //side: BorderSide(
                //  color: Colors.blue, // Colore del bordo
                //  width: 2, // Spessore del bordo
                //),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      fileResult = await FilePicker.platform.pickFiles();
                      if (fileResult != null) {
                        setState(() {
                          selectedFileName = fileResult!.files.first.name;
                        });
                      }
                    },
                    child: Text(selectedFileName != null
                        ? '${localizations.selected_file}: $selectedFileName'
                        : localizations.select_file ),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: 'Seleziona le Knowledge Boxes'),
                    items: _contexts.map((context) {
                      return DropdownMenuItem<String>(
                        value: context.path,
                        child: Text(context.path),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && !selectedContexts.contains(value)) {
                        setState(() {
                          selectedContexts.add(value);
                        });
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 6.0,
                    children: selectedContexts.map((context) {
                      return Chip(
                        label: Text(context),
                        onDeleted: () {
                          setState(() {
                            selectedContexts.remove(context);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        InputDecoration(labelText: 'Descrizione del File'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (fileResult != null && selectedContexts.isNotEmpty) {
                      // Chiudi il dialog prima di iniziare il caricamento
                      Navigator.of(context).pop();
                      setState(() {
                        _isLoading = true;
                        _loadingContext = selectedContexts.join(", ");
                        _loadingFileName = fileResult!.files.first.name;
                      });

                      // Caricamento file
                      _uploadFile(
                        fileResult!.files.first.bytes!,
                        selectedContexts,
                        description: descriptionController.text,
                        fileName: fileResult!.files.first.name,
                      ).then((_) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                            _loadingContext = null;
                            _loadingFileName = null;
                          });
                        }
                      });
                    } else {
                      print('Errore: seleziona almeno un contesto e un file.');
                    }
                  },
                  child: Text(localizations.upload_file),
                ),
              ],
            );
          },
        );
      },
    );
  }*/

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
            /*Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
            //Text('Gestione dei Contesti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            //SizedBox(height: 10),
// Titolo e pulsante "Nuovo Contesto"
            Text('Knowledge Boxes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// Barre di ricerca
const SizedBox(width: 16),
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 250), // Limite di larghezza
      child: TextField(
        controller: _nameSearchController,
        onChanged: (value) {
          _filterContexts(); // Aggiorna i risultati del filtro
        },
        decoration: InputDecoration(
          hintText: 'Cerca per nome o descrizione...',
          prefixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(vertical: 8.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    ),
  ],
),*/
            _buildSearchAreaWithTitle(),
            SizedBox(height: 10),
            SizedBox(height: 10),
            Expanded(
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
