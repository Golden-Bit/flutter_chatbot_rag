import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import 'package:expressions/expressions.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
//import 'package:http/http.dart' as http;
import 'dart:html' as html;

/// Documento restituito da GET /documents/{collection_name}/
class DocumentModel {
  final String pageContent;
  final Map<String, dynamic>? metadata;
  final String type;

  DocumentModel({
    required this.pageContent,
    this.metadata,
    required this.type,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        pageContent: json['page_content'],
        metadata: json['metadata'],
        type: json['type'],
      );
}


// Eccezione personalizzata per errori API
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

// Modelli di dati
class ContextMetadata {
  final String path;
  final Map<String, dynamic>? customMetadata;

  ContextMetadata({
    required this.path,
    this.customMetadata,
  });

  factory ContextMetadata.fromJson(Map<String, dynamic> json) {
    return ContextMetadata(
      path: json['path'],
      customMetadata: json['custom_metadata'],
    );
  }
}

class FileUploadResponse {
  final String fileId;
  final List<String> contexts;

  FileUploadResponse({required this.fileId, required this.contexts});

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      fileId: json['file_id'],
      contexts: List<String>.from(json['contexts']),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MODELS  (aggiungi dopo quelli già presenti)
/// ---------------------------------------------------------------------------

/// risposta di /contexts/metadata (è identica a ContextMetadata, ma la isoliamo
/// per chiarezza – puoi ri-usare ContextMetadata se preferisci)
class ContextMetadataResponse extends ContextMetadata {
  ContextMetadataResponse({required super.path, super.customMetadata});
  factory ContextMetadataResponse.fromJson(Map<String, dynamic> json) =>
      ContextMetadataResponse(
        path: json['path'],
        customMetadata: json['custom_metadata'],
      );
}

/// risposta generica di /files/metadata { "updated": [...] }
class FileMetadataUpdateResult {
  final List<Map<String, dynamic>> updated;
  FileMetadataUpdateResult({required this.updated});
  factory FileMetadataUpdateResult.fromJson(Map<String, dynamic> json) =>
      FileMetadataUpdateResult(
        updated: List<Map<String, dynamic>>.from(json['updated']),
      );
}


/// NEW: risposta per /upload_async – include la mappa dei task
class TaskIdsPerContext {
  final String loaderTaskId;
  final String vectorTaskId;

  TaskIdsPerContext({
    required this.loaderTaskId,
    required this.vectorTaskId,
  });

  factory TaskIdsPerContext.fromJson(Map<String, dynamic> json) =>
      TaskIdsPerContext(
        loaderTaskId: json['loader_task_id'],
        vectorTaskId: json['vector_task_id'],
      );
}

class AsyncFileUploadResponse extends FileUploadResponse {
  final Map<String, TaskIdsPerContext> tasks; // key = context-name

  AsyncFileUploadResponse({
    required super.fileId,
    required super.contexts,
    required this.tasks,
  });

  factory AsyncFileUploadResponse.fromJson(Map<String, dynamic> json) {

    final raw = Map<String, dynamic>.from(json['tasks']);
    final parsed = raw.map(
      (ctx, t) => MapEntry(ctx, TaskIdsPerContext.fromJson(t)),
    );
    return AsyncFileUploadResponse(
      fileId: json['file_id'],
      contexts: List<String>.from(json['contexts']),
      tasks: parsed,
    );
  }
}

/// NEW: per /tasks_status
class TaskStatusItem {
  final String taskId;
  final String status;
  final String? error;

  TaskStatusItem({
    required this.taskId,
    required this.status,
    this.error,
  });

  factory TaskStatusItem.fromJson(String tid, Map<String, dynamic> json) =>
      TaskStatusItem(
        taskId: tid,
        status: json['status'],
        error: json['error'],
      );
}

class TasksStatusResponse {
  final DateTime timestamp;
  final Map<String, TaskStatusItem> statuses;

  TasksStatusResponse({required this.timestamp, required this.statuses});

  factory TasksStatusResponse.fromJson(Map<String, dynamic> json) {
    final rawStatuses = Map<String, dynamic>.from(json['statuses']);
    final parsed = rawStatuses.map(
      (tid, st) => MapEntry(tid, TaskStatusItem.fromJson(tid, st)),
    );
    return TasksStatusResponse(
      timestamp: DateTime.parse(json['timestamp']),
      statuses: parsed,
    );
  }
}

/// Stato task ⇢ notifica
enum TaskStage { pending, running, done, error }

/// ② TaskNotification ora è keyed su jobId, ma mantiene il contesto
class TaskNotification {
  final String jobId;
  final String contextPath;
 final String contextName;      // ← display name del contesto
  final String fileName;
        TaskStage stage;
        bool isVisible;

  TaskNotification({
    required this.jobId,
    required this.contextPath,
   required this.contextName,
    required this.fileName,
    this.stage = TaskStage.pending,
    this.isVisible = true,
  });
}

// ───────────────────────────────────────────────────────────────────────────
//  MODELS → cost‑estimate
// ───────────────────────────────────────────────────────────────────────────
// ───────────────────────────────────────────────────────────────────────────
//  MODEL ▸ FileCost
// ───────────────────────────────────────────────────────────────────────────
class FileCost {
  // ── campi ----------------------------------------------------------------
  final String filename;
  final String kind;                        // "document" | "image" | "video"
  final int?    pages;
  final double? minutes;
  final String? strategy;
  final int?    sizeBytes;
  final int?    tokensEst;
  final double? costUsd;
  final String? formula;
  final Map<String, dynamic>? params;
  final Map<String, String>?  paramsConditions;
  final String? error;

  // ── ctor -----------------------------------------------------------------
  const FileCost({
    required this.filename,
    required this.kind,
    this.pages,
    this.minutes,
    this.strategy,
    this.sizeBytes,
    this.tokensEst,
    this.costUsd,
    this.formula,
    this.params,
    this.paramsConditions,
    this.error,
  });

  // ── JSON ↔︎ model --------------------------------------------------------
  factory FileCost.fromJson(Map<String, dynamic> j) => FileCost(
        filename        : j['filename']  as String,
        kind            : j['kind']      as String,
        pages           : j['pages']     as int?,
        minutes         : (j['minutes']  as num?)?.toDouble(),
        strategy        : j['strategy']  as String?,
        sizeBytes       : j['size_bytes']?? j['sizeBytes'] as int?, // doppia chiave safety
        tokensEst       : j['tokens_est']?? j['tokensEst'] as int?,
        costUsd         : (j['cost_usd'] ?? j['costUsd'] as num?)?.toDouble(),
        formula         : j['formula']   as String?,
        params          : (j['params']   as Map?)?.cast<String, dynamic>(),
        paramsConditions: (j['params_conditions'] ?? j['paramsConditions'] as Map?)
                            ?.cast<String, String>(),
        error           : j['error']     as String?,
      );

  Map<String, dynamic> toJson() => {
        'filename'        : filename,
        'kind'            : kind,
        if (pages          != null) 'pages'            : pages,
        if (minutes        != null) 'minutes'          : minutes,
        if (strategy       != null) 'strategy'         : strategy,
        if (sizeBytes      != null) 'size_bytes'       : sizeBytes,
        if (tokensEst      != null) 'tokens_est'       : tokensEst,
        if (costUsd        != null) 'cost_usd'         : costUsd,
        if (formula        != null) 'formula'          : formula,
        if (params         != null) 'params'           : params,
        if (paramsConditions != null) 'params_conditions': paramsConditions,
        if (error          != null) 'error'            : error,
      };

  // ── util: copyWith -------------------------------------------------------
  FileCost copyWith({
    String?               filename,
    String?               kind,
    int?                  pages,
    double?               minutes,
    String?               strategy,
    int?                  sizeBytes,
    int?                  tokensEst,
    double?               costUsd,
    String?               formula,
    Map<String, dynamic>? params,
    Map<String, String>?  paramsConditions,
    String?               error,
  }) =>
      FileCost(
        filename        : filename        ?? this.filename,
        kind            : kind            ?? this.kind,
        pages           : pages           ?? this.pages,
        minutes         : minutes         ?? this.minutes,
        strategy        : strategy        ?? this.strategy,
        sizeBytes       : sizeBytes       ?? this.sizeBytes,
        tokensEst       : tokensEst       ?? this.tokensEst,
        costUsd         : costUsd         ?? this.costUsd,
        formula         : formula         ?? this.formula,
        params          : params          ?? this.params,
        paramsConditions: paramsConditions?? this.paramsConditions,
        error           : error           ?? this.error,
      );

  // ── equality / hash ------------------------------------------------------
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileCost &&
          runtimeType == other.runtimeType &&
          filename == other.filename &&
          kind     == other.kind &&
          pages    == other.pages &&
          minutes  == other.minutes &&
          strategy == other.strategy &&
          sizeBytes== other.sizeBytes &&
          tokensEst== other.tokensEst &&
          costUsd  == other.costUsd &&
          formula  == other.formula &&
          error    == other.error;

  @override
  int get hashCode =>
      Object.hash(
        filename, kind, pages, minutes, strategy,
        sizeBytes, tokensEst, costUsd, formula, error,
      );

  @override
  String toString() => 'FileCost(${toJson()})';
}

class CostEstimateResponse {
  final List<FileCost> files;
  final double grandTotal;

  CostEstimateResponse({required this.files, required this.grandTotal});

  factory CostEstimateResponse.fromJson(Map<String, dynamic> j) =>
      CostEstimateResponse(
        files      : (j['files'] as List).map((e) => FileCost.fromJson(e)).toList(),
        grandTotal : (j['grand_total'] as num).toDouble(),
      );
     Map<String, dynamic> toJson() => {
        'files'       : files.map((f) => f.toJson()).toList(),
        'grand_total' : grandTotal,
      };
    
}

// ───────────────────────────────────────────────────────────────────────────
//  MODEL ▸ InteractionCost
// ───────────────────────────────────────────────────────────────────────────
class InteractionCost {
  final String  modelName;
  final int     inputTokens;
  final int     outputTokens;
  final int     totalTokens;
  final double  costInputUsd;
  final double  costOutputUsd;
  final double  costTotalUsd;
  final String  formula;
  final Map<String, dynamic> params;
  final Map<String, String>  paramsConditions;

  InteractionCost({
    required this.modelName,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.costInputUsd,
    required this.costOutputUsd,
    required this.costTotalUsd,
    required this.formula,
    required this.params,
    required this.paramsConditions,
  });

  /*────────────── JSON helpers ─────────────*/
  factory InteractionCost.fromJson(Map<String, dynamic> j) => InteractionCost(
        modelName        : j['model_name'],
        inputTokens      : j['input_tokens'],
        outputTokens     : j['output_tokens'],
        totalTokens      : j['total_tokens'],
        costInputUsd     : (j['cost_input_usd']  as num).toDouble(),
        costOutputUsd    : (j['cost_output_usd'] as num).toDouble(),
        costTotalUsd     : (j['cost_total_usd']  as num).toDouble(),
        formula          : j['formula'],
        params           : Map<String,dynamic>.from(j['params']),
        paramsConditions : Map<String,String>.from(j['params_conditions']),
      );

  Map<String, dynamic> toJson() => {
        'model_name'       : modelName,
        'input_tokens'     : inputTokens,
        'output_tokens'    : outputTokens,
        'total_tokens'     : totalTokens,
        'cost_input_usd'   : costInputUsd,
        'cost_output_usd'  : costOutputUsd,
        'cost_total_usd'   : costTotalUsd,
        'formula'          : formula,
        'params'           : params,
        'params_conditions': paramsConditions,
      };

  /*────────────── copyWith (patch F‑1) ─────────────*/
  InteractionCost copyWith({
    String?                modelName,
    int?                   inputTokens,
    int?                   outputTokens,
    int?                   totalTokens,
    double?                costInputUsd,
    double?                costOutputUsd,
    double?                costTotalUsd,
    String?                formula,
    Map<String,dynamic>?   params,
    Map<String,String>?    paramsConditions,
  }) =>
      InteractionCost(
        modelName       : modelName       ?? this.modelName,
        inputTokens     : inputTokens     ?? this.inputTokens,
        outputTokens    : outputTokens    ?? this.outputTokens,
        totalTokens     : totalTokens     ?? this.totalTokens,
        costInputUsd    : costInputUsd    ?? this.costInputUsd,
        costOutputUsd   : costOutputUsd   ?? this.costOutputUsd,
        costTotalUsd    : costTotalUsd    ?? this.costTotalUsd,
        formula         : formula         ?? this.formula,
        params          : params          ?? this.params,
        paramsConditions: paramsConditions?? this.paramsConditions,
      );
}




// SDK per le API
class ContextApiSdk {
  String? baseUrl;

  // Carica la configurazione dal file config.json
  Future<void> loadConfig() async {
    //final String response = await rootBundle.loadString('assets/config.json');
    //final data = jsonDecode(response);
     final data = {
    "backend_api": "https://teatek-llm.theia-innovation.com/user-backend",
    "nlp_api": "https://teatek-llm.theia-innovation.com/llm-core",
    "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
    //"chatbot_nlp_api": "http://127.0.0.1:8777"
    //"chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag-with-auth"
    };
    baseUrl = data['chatbot_nlp_api']; // Carichiamo la chiave 'chatbot_nlp_api'
  }

Future<ContextMetadata> createContext(
  String contextNameUuid,
  String description,
  String displayName, 
  String username,
  String token,
  {Map<String, dynamic>? extraMetadata,}       // ⬅️ nuovo
) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/contexts');

  final body = {
    'context_name' : contextNameUuid,   // path = UUID
    'description'  : description,
    'display_name' : displayName,
    if (extraMetadata != null) 'extra_metadata': extraMetadata,       // ⬅️ nuovo campo
    'username'     : username,
    'token'        : token,
  };

  final res = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body));

  if (res.statusCode == 200) {
    return ContextMetadata.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore creazione contesto: ${res.body}');
}



  // Eliminare un contesto
Future<void> deleteContext(String contextName, String username, String token) async {
  if (baseUrl == null) await loadConfig();

  final fullContextName = '$username-$contextName';  // Usa il formato corretto

final uri = Uri.parse('$baseUrl/contexts/$fullContextName?token=$token');

final response = await http.delete(
  uri,
  headers: {
    'Content-Type': 'application/json',
  },
);

  if (response.statusCode != 200) {
    throw ApiException('Errore durante l\'eliminazione del contesto: ${response.body}');
  }
}


Future<List<ContextMetadata>> listContexts(String username, String token) async {


  print('$username');


  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/list_contexts');

  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'username': username,  // Passa l'username nel body
      'token': token,        // Passa il token nel body
    }),
  );

  if (response.statusCode == 200) {
    final List<dynamic> jsonData = jsonDecode(response.body);
    return jsonData.map((json) => ContextMetadata.fromJson(json)).toList();
  } else {
    throw ApiException('Errore durante il recupero dei contesti: ${response.body}');
  }
}


  // Caricare un file su più contesti
Future<void> uploadFileToContexts(
    Uint8List fileBytes,
    List<String> contexts,
    String username,
    String token, // Aggiungiamo username e token
    {String? description, required String fileName, Map<String, dynamic>? extraMetadata,} 
) async {
  if (baseUrl == null) await loadConfig();

  try {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

    // Aggiungi username al nome del contesto
    List<String> formattedContexts = contexts.map((ctx) => '$username-$ctx').toList();
    request.fields['contexts'] = formattedContexts.join(',');

    // Aggiungi la descrizione e credenziali
    if (description != null) {
      request.fields['description'] = description;
    }
    request.fields['username'] = username;  // Nuovo campo
    request.fields['token'] = token;  // Nuovo campo
    if (extraMetadata != null) request.fields['extra_metadata'] = jsonEncode(extraMetadata);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('File caricato con successo');
    } else {
      throw ApiException('Errore durante il caricamento del file: ${response.body}');
    }
  } catch (e) {
    print('Errore caricamento file: $e');
  }
}




  Future<AsyncFileUploadResponse> uploadFileToContextsAsync(
    Uint8List fileBytes,
    List<String> contexts,
    String username,
    String token, {
    String? description,
    required String fileName,
    Map<String, dynamic>? loaders,   
   Map<String, dynamic>? loaderKwargs,   
  }) async {
    if (baseUrl == null) await loadConfig();

    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/upload_async'));

    final formatted = contexts.map((c) => '$username-$c').toList();
    request.fields['contexts'] = formatted.join(',');
    if (description != null) request.fields['description'] = description;
    request.fields['username'] = username;
    request.fields['token'] = token;



  if (loaders      != null) request.fields['loaders']       = jsonEncode(loaders);
  if (loaderKwargs != null) request.fields['loader_kwargs'] = jsonEncode(loaderKwargs);

  request.files.add(
    http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
  );
  
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return AsyncFileUploadResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
          'Errore durante il caricamento async: ${response.body}');
    }
  }




 /// Ritorna lo stato di più task; accetta la mappa proveniente da upload_async
  ///
  /// ```dart
  /// final status = await sdk.getTasksStatus(
  ///      tasksMap.values.toList(),  // oppure costruisci tu i TaskIdsPerContext
  /// );
  /// ```
  Future<TasksStatusResponse> getTasksStatus(
      Iterable<TaskIdsPerContext> taskIds) async {
    if (baseUrl == null) await loadConfig();

    // costruiamo lista "loader:uuid,vector:uuid"
    final List<String> queryItems = [];
    for (final ids in taskIds) {
      queryItems.add('loader:${ids.loaderTaskId}');
      queryItems.add('vector:${ids.vectorTaskId}');
    }

    final uri = Uri.parse('$baseUrl/tasks_status')
        .replace(queryParameters: {'tasks': queryItems.join(',')});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return TasksStatusResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
          'Errore durante il polling status: ${response.body}');
    }


    
  }






  // Elencare file per contesti
Future<List<Map<String, dynamic>>> listFiles(String username, String token, {List<String>? contexts}) async {
  if (baseUrl == null) await loadConfig();

  // Inizializza formattedContexts per evitare errori di riferimento
  List<String> formattedContexts = [];

  Uri uri;
  if (contexts != null && contexts.isNotEmpty) {
    // Aggiunge il prefisso 'username-' ai nomi dei contesti
    formattedContexts = contexts.map((ctx) => '$username-$ctx').toList();

uri = Uri.parse('$baseUrl/files').replace(queryParameters: {
  if (formattedContexts.isNotEmpty) 'contexts': formattedContexts.join(','),
  'token': token,
});

  } else {
    uri = Uri.parse('$baseUrl/files');
  }

  final response = await http.get(
    uri,
    headers: {
      'Content-Type': 'application/json',
      //'Authorization': 'Bearer $token'  // Aggiunto per autenticazione
    },
  );

  if (response.statusCode == 200) {
    List<Map<String, dynamic>> files = List<Map<String, dynamic>>.from(jsonDecode(response.body));

    if (contexts != null && contexts.isNotEmpty) {
      files = files.where((file) {
        String filePath = file['path'] ?? '';
        List<String> pathSegments = filePath.split('/');

        if (pathSegments.length < 2) {
          return false;
        }

        // Ora il segmento penultimo include il prefisso `username-`
        String penultimateSegment = pathSegments[pathSegments.length - 2];

        return formattedContexts.contains(penultimateSegment);
      }).toList();
    }

    return files;
  } else {
    throw ApiException('Errore durante il recupero dei file: ${response.body}');
  }
}


  // Eliminare file tramite UUID o path
Future<void> deleteFile(String username, String token, {String? fileId, String? filePath}) async {
  if (baseUrl == null) await loadConfig();

  if (filePath != null) {
    List<String> pathSegments = filePath.split('/');
    if (pathSegments.length >= 2) {
      filePath = '$username-${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
    } else {
      throw ApiException('Errore: il percorso fornito non ha abbastanza segmenti.');
    }
  }

Uri uri = Uri.parse('$baseUrl/files').replace(queryParameters: {
  if (fileId != null) 'file_id': fileId,
  if (filePath != null) 'file_path': filePath,
  'token': token, // 💡 Aggiunto correttamente
});

  final response = await http.delete(
    uri,
    headers: {
      'Content-Type': 'application/json',
      //'Authorization': 'Bearer $token'  // Se necessario
    },
  );

  if (response.statusCode != 200) {
    throw ApiException('Errore durante l\'eliminazione del file: ${response.body}');
  }
}


/// Metodo aggiornato per supportare la nuova versione dell'endpoint con autenticazione
Future<Map<String, dynamic>> configureAndLoadChain(
    String username, String token, List<String> contexts, String model) async {
  if (baseUrl == null) await loadConfig();

  // Aggiunge il prefisso 'username-' ai nomi dei contesti
  List<String> formattedContexts = contexts.map((ctx) => '$username-$ctx').toList();

  // Costruisci l'URI dell'endpoint
  final uri = Uri.parse('$baseUrl/configure_and_load_chain/');

  // Costruisci il corpo della richiesta (invio dati in formato JSON)
  final body = {
    //'username': username,      // Passiamo username per verifica lato server
    'token': token,            // Passiamo il token per autenticazione
    'contexts': formattedContexts, // Contesti aggiornati con prefisso
    'model_name': model,
  };

  try {
    // Effettua la richiesta POST
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        //'Authorization': 'Bearer $token' // Aggiunto token nell'header per sicurezza
      },
      body: jsonEncode(body), // Serializza il body come JSON
    );

    if (response.statusCode == 200) {
      // Restituisce il risultato della configurazione e caricamento della chain
      return jsonDecode(response.body);
    } else {
      // Gestisce errori di configurazione e caricamento
      final errorResponse = jsonDecode(response.body);
      throw ApiException(
          'Errore durante la configurazione e il caricamento della chain: ${errorResponse['detail'] ?? response.body}');
    }
  } catch (e) {
    // Gestione errori generali
    throw ApiException('Errore durante la chiamata all\'API: $e');
  }
}

  
  Future<void> downloadFile(String fileId, {String? token}) async {
    if (baseUrl == null) await loadConfig();

    // Costruisci l'URL di download
    //final uri = Uri.parse('$baseUrl/download?file_id=$fileId');

  final uri = Uri.parse('$baseUrl/download').replace(queryParameters: {
    'file_id': fileId,
    if (token != null) 'token': token,
  });

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      if (kIsWeb) {
        final blob = html.Blob([response.bodyBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        // Crea un elemento di ancoraggio per simulare il download
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileId)
          ..click();

        // Rilascia l'URL dell'oggetto
        html.Url.revokeObjectUrl(url);
      } else {
        throw UnsupportedError('La funzione è supportata solo per il Web.');
      }
    } else {
      throw ApiException('Errore durante il download del file: ${response.body}');
    }
  }
  




  /* ---------------------------------------------------------------------- */
/*                           METADATA UPDATE                              */
/* ---------------------------------------------------------------------- */

/// NEW – aggiorna la descrizione e/o custom-metadata di un **contesto**
///
/// - `contextName` è la parte **senza** prefisso `username-` (il metodo lo
///   aggiunge da solo).
/// - se lasci `description` o `extraMetadata` a `null` verranno ignorati
///   (merge parziale lato server).
Future<ContextMetadataResponse> updateContextMetadata(
  String username,
  String token, {
  required String contextName,
  String? description,
  Map<String, dynamic>? extraMetadata,
}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/contexts/metadata');

  final body = {
    'username': username,
    'context_name': contextName,
    'token': token,
    if (description != null) 'description': description,
    if (extraMetadata != null) 'extra_metadata': extraMetadata,
  };

  final response = await http.put(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return ContextMetadataResponse.fromJson(jsonDecode(response.body));
  } else {
    throw ApiException(
        'Errore update context-metadata: ${response.body}');
  }
}

/// NEW – aggiorna metadati di un **file** (per path o per file_id globale)
///
/// Devi fornire almeno `filePath` **oppure** `fileId`.
Future<FileMetadataUpdateResult> updateFileMetadata(
  String username,
  String token, {
  String? filePath,   // es. "<context>/<filename>" **senza** prefisso username-
  String? fileId,     // UUID globale
  String? description,
  Map<String, dynamic>? extraMetadata,
}) async {
  if (baseUrl == null) await loadConfig();

  if (filePath == null && fileId == null) {
    throw ApiException('Devi specificare filePath oppure fileId');
  }

  // se è stato passato un percorso, prepend del prefisso username-
  String? fullPath;
  if (filePath != null) {
    final segments = filePath.split('/');
    if (segments.length >= 2) {
      fullPath = '$username-${segments[segments.length - 2]}/${segments.last}';
    } else {
      throw ApiException('filePath non valido: $filePath');
    }
  }

  final uri = Uri.parse('$baseUrl/files/metadata');
  final body = {
    'token': token,
    if (fullPath != null) 'file_path': fullPath,
    if (fileId != null) 'file_id': fileId,
    if (description != null) 'description': description,
    if (extraMetadata != null) 'extra_metadata': extraMetadata,
  };

  final response = await http.put(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return FileMetadataUpdateResult.fromJson(jsonDecode(response.body));
  } else {
    throw ApiException('Errore update file-metadata: ${response.body}');
  }
}

/// Elenca i documenti di una collezione.
///
/// - `collectionName`  = nome della collezione MongoDB.
/// - `prefix`          = filtra gli `_id` che iniziano con questo prefisso (opzionale).
/// - `skip/limit`      = paginazione.
/// - `token`           = Access-token (se il backend lo richiede).
Future<List<DocumentModel>> listDocuments(
  String collectionName, {
  String? prefix,
  int skip = 0,
  int limit = 10,
  String? token,
}) async {
  if (baseUrl == null) await loadConfig();

  final query = <String, String>{
    'skip':  skip.toString(),
    'limit': limit.toString(),
    if (prefix != null) 'prefix': prefix,
    if (token  != null) 'token' : token,
  };

  final uri = Uri.parse('$baseUrl/documents/$collectionName/')
      .replace(queryParameters: query);

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final utf8Body = utf8.decode(response.bodyBytes);       // <— forziamo UTF-8
    final data   = jsonDecode(utf8Body) as List<dynamic>;
    return data.map((j) => DocumentModel.fromJson(j)).toList();
  } else {
    throw ApiException(
        'Errore elenco documenti: ${response.body}');
  }
}

/// Ritorna { estensione : [loader1, loader2, …] }
Future<Map<String, List<String>>> getLoadersCatalog() async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/loaders_catalog');
  final res  = await http.get(uri);

  if (res.statusCode == 200) {
    final raw = jsonDecode(res.body) as Map<String, dynamic>;
    // cast in Map<String, List<String>>
    return raw.map((k, v) => MapEntry(k, List<String>.from(v)));
  }
  throw ApiException('Errore loaders_catalog: ${res.body}');
}


/// Ritorna { loaderName : { field : {name,type,default,items,example}, … } }
Future<Map<String, dynamic>> getLoaderKwargsSchema() async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/loader_kwargs_schema');
  final res  = await http.get(uri);

  if (res.statusCode == 200) {
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
  throw ApiException('Errore loader_kwargs_schema: ${res.body}');
}

// ───────────────────────────────────────────────────────────────────────────
//  2.1  Calcola costo di preprocessing file
// ───────────────────────────────────────────────────────────────────────────
Future<CostEstimateResponse> estimateFileProcessingCost(
  List<Uint8List> fileBytes,
  List<String>    fileNames, {
  Map<String, dynamic>? loaderKwargs,
}) async {
  if (baseUrl == null) await loadConfig();
  if (fileBytes.length != fileNames.length) {
    throw ArgumentError('fileBytes e fileNames devono avere la stessa length');
  }

  final uri = Uri.parse('$baseUrl/estimate_file_processing_cost');
  final req = http.MultipartRequest('POST', uri);

  for (int i = 0; i < fileBytes.length; ++i) {
    req.files.add(http.MultipartFile.fromBytes(
      'files',
      fileBytes[i],
      filename: fileNames[i],
    ));
  }

  if (loaderKwargs != null && loaderKwargs.isNotEmpty) {
    req.fields['loader_kwargs'] = jsonEncode(loaderKwargs);
  }

  final streamed = await req.send();
  final res      = await http.Response.fromStream(streamed);

  if (res.statusCode == 200) {
    return CostEstimateResponse.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore estimate_file_processing_cost: ${res.body}');
}

// ───────────────────────────────────────────────────────────────────────────
//  2.2  Calcola costo di un singolo turn di chat
// ───────────────────────────────────────────────────────────────────────────
Future<InteractionCost> estimateChainInteractionCost({
  String? chainId,
  Map<String, dynamic>? chainConfig,
  required String message,
  List<List<String>> chatHistory = const [],
}) async {
  if (baseUrl == null) await loadConfig();

  final uri  = Uri.parse('$baseUrl/estimate_chain_interaction_cost');
  final body = {
    if (chainId     != null) 'chain_id'    : chainId,
    if (chainConfig != null) 'chain_config': chainConfig,
    'message'      : message,
    'chat_history' : chatHistory,
  };

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (res.statusCode == 200) {
    return InteractionCost.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore estimate_chain_interaction_cost: ${res.body}');
}

///  Ricalcola locally il costo di un FileCost.
///  Restituisce **SEMPRE** un nuovo oggetto (non muta l’originale).
/*  ────────────────────────────────────────────────────────────────────────
    Ricalcola il costo di preprocessing **localmente** (senza round‑trip).
    - original …… FileCost ricevuto dal backend
    - configOverride … parametri che l’utente modifica a runtime
   ─────────────────────────────────────────────────────────────────────── */

FileCost recomputeFileCost(
  FileCost original, {
  Map<String, dynamic> configOverride = const {},
}) {
  // ── helper log cross‑platform ─────────────────────────────────────────
  void _log(Object msg) =>
      (const bool.fromEnvironment('dart.vm.product')) ? print(msg) : debugPrint(msg.toString());

  if (original.formula == null) {
    throw ArgumentError('FileCost.formula mancante.');
  }

  // 1️⃣  Ambiente iniziale ------------------------------------------------
  final env = <String, dynamic>{
    ...?original.params,          // parametri noti
    ...configOverride,            // override dell’utente
    // funzioni utili che la formula potrebbe chiamare
    'ceil' : (num x) => x.ceil(),
    'round': (num x) => x.round(),
    'min'  : math.min,
    'max'  : math.max,
  };
  _log('[cost‑eval] ENV iniziale  → ${_pretty(env)}');

  // 2️⃣  Risolvi i parametri NULL usando paramsConditions -----------------
  bool _resolvedSomething() {
    var changed = false;

    original.paramsConditions?.forEach((key, condRaw) {
      if (env[key] != null) return;                      // già valorizzato

      // Python‑style «A if cond else B» → ternario Dart
      final cond = condRaw
          .replaceAllMapped(RegExp(r'(.+?)\s+if\s+(.+?)\s+else\s+(.+)'),
              (m) => '(${m[2]}) ? (${m[1]}) : (${m[3]})')
          .replaceAll('{', '')
          .replaceAll('}', '');

      try {
        final val = const ExpressionEvaluator()
            .eval(Expression.parse(cond), env);
        env[key] = val;
        _log('[cost‑eval]   ✔  $key = $val   (via condition)');
        changed = true;
      } catch (e) {
        // dipendenza non ancora risolta – riprovare al giro successivo
        _log('[cost‑eval]   ⏳  $key in attesa (deps mancanti)');
      }
    });

    return changed;
  }

  // max 5 passate per evitare loop infiniti
  for (var i = 0; i < 5 && _resolvedSomething(); i++) {}

  // 3️⃣  Prepara la formula per l’evaluator -------------------------------
  var exprSrc = original.formula!
      .split('=').last                    // rimuove "cost ="
      .replaceAll('×', '*')               // unicode × → *
      .replaceAllMapped(
          RegExp(r'{([^}]+)}'), (m) => m[1]!); // {var} → var
  _log('[cost‑eval] FORMULA finale → $exprSrc');

  // 4️⃣  Valuta l’espressione --------------------------------------------
  final result = const ExpressionEvaluator()
      .eval(Expression.parse(exprSrc), env);
  _log('[cost‑eval] RESULT → $result USD');

  // 5️⃣  Aggiorna i params senza includere Funzioni -----------------------
  final cleaned = <String, dynamic>{};
  env.forEach((k, v) {
    if (v is! Function) cleaned[k] = v;
  });

  // NB:  copyWith deve già esistere nel tuo modello FileCost
  return original.copyWith(
    costUsd: (result as num).toDouble(),
    params : cleaned,
  );
}

/* ────────────────────────────────────────────────────────────────────────
   Pretty‑printer che scarta le Funzioni (JsonEncoder fallisce altrimenti)
   ─────────────────────────────────────────────────────────────────────── */
String _pretty(Object obj) {
  dynamic _sanitize(dynamic v) {
    if (v is Map) {
      final m = <String, dynamic>{};
      v.forEach((k, val) {
        if (val is! Function) m[k.toString()] = _sanitize(val);
      });
      return m;
    }
    if (v is Iterable) return v.map(_sanitize).toList();
    if (v is Function)  return '<fn>';
    return v;
  }

  return const JsonEncoder.withIndent('  ').convert(_sanitize(obj));
}
/* ─────────────────────────────────────────────────────────────────────────────
   Ricalcola **in locale** il costo di UNA interazione chat.

   • `original` … oggetto `InteractionCost` restituito dal backend
   • `configOverride`
       – qualunque parametro che l’utente voglia forzare a runtime
         (es.: {"price_in": 0.012, "price_out": 0.036})
       – viene fuso dentro `original.params` PRIMA di valutare la formula

   Il metodo funziona con la **nuova** formula:

     cost_total = (({tokens_system} + {tokens_user} +
                    {tokens_history} + {tokens_tools}) / 1000) * {price_in}
                  + ({output_tokens} / 1000) * {price_out}

   Restituisce SEMPRE un nuovo oggetto (immutabile).
   ───────────────────────────────────────────────────────────────────────── */
InteractionCost recomputeInteractionCost(
  InteractionCost original, {
  Map<String, dynamic> configOverride = const {},
}) {
  /*────────────────── logger cross‑platform ──────────────────*/
  void _log(Object msg) =>
      (const bool.fromEnvironment('dart.vm.product'))
          ? print(msg)
          : debugPrint(msg.toString());

  if (original.formula.isEmpty) {
    throw ArgumentError('InteractionCost.formula mancante.');
  }

  /* 1️⃣  Ambiente iniziale (params + override + util‑fn) */
  final env = <String, dynamic>{
    ...original.params,            // valori dal backend
    ...configOverride,             // override dell’utente
    'ceil' : (num x) => x.ceil(),
    'round': (num x) => x.round(),
    'min'  : math.min,
    'max'  : math.max,
  };
  _log('[chat‑eval] ENV iniziale  → ${_pretty(env)}');

  /* 2️⃣  Risolvi parametri NULL tramite paramsConditions */
  bool _resolveLoop() {
    var changed = false;
    original.paramsConditions.forEach((key, condRaw) {
      if (env[key] != null) return;                // già risolto

      // if … else …  →  ternario Dart
      final ternary = condRaw
          .replaceAllMapped(
              RegExp(r'(.+?)\s+if\s+(.+?)\s+else\s+(.+)'),
              (m) => '(${m[2]}) ? (${m[1]}) : (${m[3]})')
          .replaceAll('{', '')
          .replaceAll('}', '');

      try {
        final val = const ExpressionEvaluator()
            .eval(Expression.parse(ternary), env);
        env[key] = val;
        _log('[chat‑eval]   ✔  $key = $val   (via condition)');
        changed = true;
      } catch (_) {
        _log('[chat‑eval]   ⏳  $key in attesa');
      }
    });
    return changed;
  }

  // risoluzione iterativa
  for (var i = 0; i < 5 && _resolveLoop(); i++) {}

  /* 3️⃣  Formula finale da valutare */
  final expr = original.formula
      .split('=').last
      .replaceAll('×', '*')
      .replaceAllMapped(RegExp(r'{([^}]+)}'), (m) => m[1]!);
  _log('[chat‑eval] FORMULA finale → $expr');

  /* 4️⃣  Valuta il costo totale */
  final total = const ExpressionEvaluator()
      .eval(Expression.parse(expr), env) as num;

  /* 5️⃣  Ricalcola token e costi */
  final newInTok  = (env['tokens_system']   as int) +
                    (env['tokens_user']     as int) +
                    (env['tokens_history']  as int);

  final newOutTok = env['output_tokens']    as int;

  final priceIn   = env['price_in']  as num;
  final priceOut  = env['price_out'] as num;

  final newCostIn  = (newInTok  / 1000) * priceIn;
  final newCostOut = (newOutTok / 1000) * priceOut;

  /* 6️⃣  Pulisci env da eventuali funzioni  */
  final cleaned = <String, dynamic>{};
  env.forEach((k, v) {
    if (v is! Function) cleaned[k] = v;
  });

  /* 7️⃣  Restituisci la nuova InteractionCost */
  return original.copyWith(
    inputTokens    : newInTok,
    outputTokens   : newOutTok,
    totalTokens    : newInTok + newOutTok,
    costInputUsd   : newCostIn.toDouble(),
    costOutputUsd  : newCostOut.toDouble(),
    costTotalUsd   : total.toDouble(),
    params         : cleaned,
  );
}

}