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

// ───────────────────────────────────────────────────────────────────────────
// PAYMENTS ▸ Models & enums
// ───────────────────────────────────────────────────────────────────────────

/// Stato piano corrente (GET /payments/current_plan)
class CurrentPlanResponse {
  final String subscriptionId;
  final String? status;
  final String? planType;
  final String? variant;
  final String? pricingMethod;
  final String? activePriceId;
  final int? periodStart;   // epoch seconds
  final int? periodEnd;     // epoch seconds

  const CurrentPlanResponse({
    required this.subscriptionId,
    this.status,
    this.planType,
    this.variant,
    this.pricingMethod,
    this.activePriceId,
    this.periodStart,
    this.periodEnd,
  });

  factory CurrentPlanResponse.fromJson(Map<String, dynamic> j) =>
      CurrentPlanResponse(
        subscriptionId: j['subscription_id'],
        status        : j['status'],
        planType      : j['plan_type'],
        variant       : j['variant'],
        pricingMethod : j['pricing_method'],
        activePriceId : j['active_price_id'],
        periodStart   : j['period_start'] as int?,
        periodEnd     : j['period_end']   as int?,
      );
}

class UserCreditsResponse {
  final num? providedTotal;
  final num? usedTotal;
  final num? remainingTotal;

  const UserCreditsResponse({
    this.providedTotal,
    this.usedTotal,
    this.remainingTotal,
  });

  factory UserCreditsResponse.fromJson(Map<String, dynamic> j) =>
      UserCreditsResponse(
        providedTotal : j['provided_total'],
        usedTotal     : j['used_total'],
        remainingTotal: j['remaining_total'],
      );

  // ✅ aggiunto
  Map<String, dynamic> toJson() => {
    'providedTotal'  : providedTotal,
    'usedTotal'      : usedTotal,
    'remainingTotal' : remainingTotal,
  };
}


/// Intent per l’aggiornamento piano (POST /payments/deeplink/update)
enum ChangeIntent { upgrade, downgrade, both }

extension _ChangeIntentWire on ChangeIntent {
  String get wire {
    switch (this) {
      case ChangeIntent.upgrade:   return 'upgrade';
      case ChangeIntent.downgrade: return 'downgrade';
      case ChangeIntent.both:      return 'both';
    }
  }
  static ChangeIntent fromWire(String? s) {
    switch (s) {
      case 'upgrade':   return ChangeIntent.upgrade;
      case 'downgrade': return ChangeIntent.downgrade;
      case 'both':
      default:          return ChangeIntent.both;
    }
  }
}

/// Discriminated union: esito checkout vs redirect al Billing Portal
abstract class CheckoutOrPortal {
  const CheckoutOrPortal();
  factory CheckoutOrPortal.fromJson(Map<String, dynamic> j) {
    final status = j['status'] as String?;
    if (status == 'checkout')       return CheckoutSuccessResponse.fromJson(j);
    if (status == 'portal_redirect') return PortalRedirectResponse.fromJson(j);
    throw ApiException('Risposta inattesa da /payments/checkout: ${jsonEncode(j)}');
  }
}

/// Variante "checkout" (successo creazione Checkout Session)
class CheckoutSuccessResponse extends CheckoutOrPortal {
  final String checkoutSessionId;
  final String url;
  final String? customerId;
  final String? createdProductId;
  final String? createdPriceId;

  const CheckoutSuccessResponse({
    required this.checkoutSessionId,
    required this.url,
    this.customerId,
    this.createdProductId,
    this.createdPriceId,
  });

  factory CheckoutSuccessResponse.fromJson(Map<String, dynamic> j) =>
      CheckoutSuccessResponse(
        checkoutSessionId: j['checkout_session_id'],
        url              : j['url'],
        customerId       : j['customer_id'],
        createdProductId : j['created_product_id'],
        createdPriceId   : j['created_price_id'],
      );
}

/// Variante "portal_redirect"
class PortalRedirectResponse extends CheckoutOrPortal {
  final String reasonCode;
  final String message;
  final String portalUrl;
  final String subscriptionId;
  final String configurationId;

  const PortalRedirectResponse({
    required this.reasonCode,
    required this.message,
    required this.portalUrl,
    required this.subscriptionId,
    required this.configurationId,
  });

  factory PortalRedirectResponse.fromJson(Map<String, dynamic> j) =>
      PortalRedirectResponse(
        reasonCode      : j['reason_code'],
        message         : j['message'],
        portalUrl       : j['portal_url'],
        subscriptionId  : j['subscription_id'],
        configurationId : j['configuration_id'],
      );
}

/// Output POST /payments/portal_session
class PortalSessionResponse {
  final String portalSessionId;
  final String url;
  final String configurationId;

  const PortalSessionResponse({
    required this.portalSessionId,
    required this.url,
    required this.configurationId,
  });

  factory PortalSessionResponse.fromJson(Map<String, dynamic> j) =>
      PortalSessionResponse(
        portalSessionId : j['portal_session_id'],
        url             : j['url'],
        configurationId : j['configuration_id'],
      );
}

/// Output deeplink (update/cancel)
class DeeplinkResponse {
  final String deeplinkId;
  final String url;
  final String configurationId;

  const DeeplinkResponse({
    required this.deeplinkId,
    required this.url,
    required this.configurationId,
  });

  factory DeeplinkResponse.fromJson(Map<String, dynamic> j) =>
      DeeplinkResponse(
        deeplinkId      : j['deeplink_id'],
        url             : j['url'],
        configurationId : j['configuration_id'],
      );
}

/// Output deeplink upgrade/downgrade
enum ChangeKind { upgrade, downgrade }

class DeeplinkUpgradeResponse extends DeeplinkResponse {
  final String subscriptionId;
  final ChangeKind changeKind;
  final double? appliedDiscountPercent;

  DeeplinkUpgradeResponse({
    required super.deeplinkId,
    required super.url,
    required super.configurationId,
    required this.subscriptionId,
    required this.changeKind,
    this.appliedDiscountPercent,
  });

  factory DeeplinkUpgradeResponse.fromJson(Map<String, dynamic> j) =>
      DeeplinkUpgradeResponse(
        deeplinkId             : j['deeplink_id'],
        url                    : j['url'],
        configurationId        : j['configuration_id'],
        subscriptionId         : j['subscription_id'],
        changeKind             : (j['change_kind'] == 'downgrade')
                                    ? ChangeKind.downgrade
                                    : ChangeKind.upgrade,
        appliedDiscountPercent : (j['applied_discount_percent'] as num?)?.toDouble(),
      );
}


class ImageBase64ResponseDto {
  final String url;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final String sha256;
  final String base64Raw;
  final String dataUri;

  ImageBase64ResponseDto({
    required this.url,
    required this.contentType,
    required this.sizeBytes,
    this.width,
    this.height,
    required this.sha256,
    required this.base64Raw,
    required this.dataUri,
  });

  factory ImageBase64ResponseDto.fromJson(Map<String, dynamic> j) {
    return ImageBase64ResponseDto(
      url         : j['url'],
      contentType : j['content_type'],
      sizeBytes   : j['size_bytes'],
      width       : j['width'],
      height      : j['height'],
      sha256      : j['sha256'],
      base64Raw   : j['base64_raw'],
      dataUri     : j['data_uri'],
    );
  }

  /// Comodo se vuoi passare direttamente i bytes a Image.memory
  Uint8List get bytes => base64Decode(base64Raw);
}


// ── enum allineato al backend ────────────────────────────────────────────
enum ParamType { string, integer, number, boolean, array, object }

// ── Parametri (ricorsivi) ────────────────────────────────────────────────
class ToolParamSpec {
  final String       name;
  final ParamType    paramType;
  final ParamType?   itemsType;
  final ParamType?   keyType;
  final ParamType?   valueType;
  final String       description;
  final dynamic      example;
  final dynamic      defaultValue;
  final List<dynamic>? allowedValues;
  final double?      minValue, maxValue;
  final int?         minLength, maxLength;
  final List<ToolParamSpec>? properties;

  const ToolParamSpec({
    required this.name,
    required this.paramType,
    this.itemsType,
    this.keyType,
    this.valueType,
    required this.description,
    this.example,
    this.defaultValue,
    this.allowedValues,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.properties,
  });

  Map<String, dynamic> toJson() => {
        'name'        : name,
        'param_type'  : _enum2str(paramType),
        if (itemsType != null) 'items_type' : _enum2str(itemsType!),
        if (keyType   != null) 'key_type'   : _enum2str(keyType!),
        if (valueType != null) 'value_type' : _enum2str(valueType!),
        'description' : description,
        if (example        != null) 'example'        : example,
        if (defaultValue   != null) 'default'        : defaultValue,
        if (allowedValues  != null) 'allowed_values' : allowedValues,
        if (minValue       != null) 'min_value'      : minValue,
        if (maxValue       != null) 'max_value'      : maxValue,
        if (minLength      != null) 'min_length'     : minLength,
        if (maxLength      != null) 'max_length'     : maxLength,
        if (properties     != null)
          'properties' : properties!.map((p) => p.toJson()).toList(),
      };

/* helper enum→string */
static String _enum2str(ParamType t) {
  switch (t) {
    case ParamType.string:  return 'string';
    case ParamType.integer: return 'int';     // <-- backend vuole "int"
    case ParamType.number:  return 'float';   // <-- backend vuole "float"
    case ParamType.boolean: return 'bool';    // <-- backend vuole "bool"
    case ParamType.array:   return 'list';    // <-- backend vuole "list"
    case ParamType.object:  return 'dict';    // <-- backend vuole "dict"
  }
}
}

// ── ToolSpec  (solo i campi richiesti dal backend) ────────────────────────
class ToolSpec {
  final String toolName;
  final String description;
  final List<ToolParamSpec> params;

  const ToolSpec({
    required this.toolName,
    required this.description,
    this.params = const [],
  });

  Map<String, dynamic> toJson() => {
        'tool_name'  : toolName,
        'description': description,
        'params'     : params.map((p) => p.toJson()).toList(),
      };
}

// vicino agli altri model/sdk
class ChainConfiguration {
  final String chainId;
  final String configId;
  final String? llmId;
  final List<dynamic>? tools;
  final Map<String, dynamic>? extraMetadata;
  final List<dynamic>? contexts;

  ChainConfiguration({
    required this.chainId,
    required this.configId,
    this.llmId,
    this.tools,
    this.extraMetadata,
    this.contexts,
  });

  factory ChainConfiguration.fromJson(Map<String, dynamic> j) {
    return ChainConfiguration(
      chainId: j['chain_id'] ?? '',
      configId: j['config_id'] ?? '',
      llmId: j['llm_id'] as String?,
      tools: j['tools'] as List<dynamic>?,
      extraMetadata: j['extra_metadata'] as Map<String, dynamic>?,
      contexts: (j['contexts'] as List?)?.cast<dynamic>(),
    );
  }
}


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
// NEW: 404 "nessun piano attivo" → eccezione funzionale, non errore bloccante
class NoActiveSubscriptionException extends ApiException {
  NoActiveSubscriptionException([String message = 'No active subscription'])
      : super(message);
}

// CHANGED: aggiunto uploadTaskId (opzionale per retro-compat)
class FileUploadResponse {
  final String fileId;
  final List<String> contexts;
  final String? uploadTaskId;                  // NEW

  FileUploadResponse({required this.fileId, required this.contexts, this.uploadTaskId});

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      fileId       : json['file_id'],
      contexts     : List<String>.from(json['contexts']),
      uploadTaskId : json['upload_task_id'],   // NEW (può essere null per /upload)
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

// ==========================
// TASKS (upload aggregato)
// ==========================

// NEW
class PerContextStatusDto {
  final String context;
  final String loaderTaskId;
  final String vectorTaskId;
  final String loaderStatus;   // "PENDING" | "RUNNING" | "DONE" | "ERROR" | "COMPLETED"
  final String vectorStatus;   // idem
  final String? error;

  const PerContextStatusDto({
    required this.context,
    required this.loaderTaskId,
    required this.vectorTaskId,
    required this.loaderStatus,
    required this.vectorStatus,
    this.error,
  });

  factory PerContextStatusDto.fromJson(Map<String, dynamic> j) => PerContextStatusDto(
    context       : j['context'],
    loaderTaskId  : j['loader_task_id'],
    vectorTaskId  : j['vector_task_id'],
    loaderStatus  : j['loader_status'] ?? 'PENDING',
    vectorStatus  : j['vector_status'] ?? 'PENDING',
    error         : j['error'],
  );

  Map<String, dynamic> toJson() => {
    'context'       : context,
    'loader_task_id': loaderTaskId,
    'vector_task_id': vectorTaskId,
    'loader_status' : loaderStatus,
    'vector_status' : vectorStatus,
    if (error != null) 'error': error,
  };
}

// NEW
class UploadTaskDto {
  final String taskId;
  final String kind;                 // "upload"
  final String userId;
  final String fileId;
  final String originalFilename;
  final String filenameSafe;
  final List<String> contexts;
  final Map<String, PerContextStatusDto> perContext;
  final String status;               // "PENDING" | "RUNNING" | "ERROR" | "COMPLETED"
  final double progress;             // 0.0 .. 100.0
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool read;
  final String? error;

  const UploadTaskDto({
    required this.taskId,
    required this.kind,
    required this.userId,
    required this.fileId,
    required this.originalFilename,
    required this.filenameSafe,
    required this.contexts,
    required this.perContext,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    required this.read,
    this.error,
  });

  factory UploadTaskDto.fromJson(Map<String, dynamic> j) {
    final perCtxRaw = (j['per_context'] as Map<String, dynamic>? ?? {});
    final perCtx = perCtxRaw.map((k, v) => MapEntry(k, PerContextStatusDto.fromJson(Map<String, dynamic>.from(v))));
    return UploadTaskDto(
      taskId           : j['task_id'],
      kind             : j['kind'] ?? 'upload',
      userId           : j['user_id'],
      fileId           : j['file_id'],
      originalFilename : j['original_filename'],
      filenameSafe     : j['filename_safe'],
      contexts         : List<String>.from(j['contexts'] ?? const []),
      perContext       : perCtx,
      status           : j['status'] ?? 'PENDING',
      progress         : (j['progress'] as num? ?? 0).toDouble(),
      createdAt        : DateTime.parse(j['created_at']),
      updatedAt        : DateTime.parse(j['updated_at']),
      read             : j['read'] == true,
      error            : j['error'],
    );
  }

  Map<String, dynamic> toJson() => {
    'task_id'          : taskId,
    'kind'             : kind,
    'user_id'          : userId,
    'file_id'          : fileId,
    'original_filename': originalFilename,
    'filename_safe'    : filenameSafe,
    'contexts'         : contexts,
    'per_context'      : perContext.map((k, v) => MapEntry(k, v.toJson())),
    'status'           : status,
    'progress'         : progress,
    'created_at'       : createdAt.toIso8601String(),
    'updated_at'       : updatedAt.toIso8601String(),
    'read'             : read,
    if (error != null) 'error': error,
  };
}

// NEW
class UserTasksResponseDto {
  final List<UploadTaskDto> tasks;

  const UserTasksResponseDto({required this.tasks});

  factory UserTasksResponseDto.fromJson(Map<String, dynamic> j) => UserTasksResponseDto(
    tasks: (j['tasks'] as List<dynamic>? ?? const [])
        .map((e) => UploadTaskDto.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

// CHANGED: aggiunto uploadTaskId
class AsyncFileUploadResponse extends FileUploadResponse {
  final Map<String, TaskIdsPerContext> tasks; // key = context-name
  final String? uploadTaskId; // shadow per comodità d’uso (eredita già, ma esplicitiamo)

  AsyncFileUploadResponse({
    required super.fileId,
    required super.contexts,
    required this.tasks,
    this.uploadTaskId,                               // NEW
  }) : super(uploadTaskId: uploadTaskId);

  factory AsyncFileUploadResponse.fromJson(Map<String, dynamic> json) {
    final raw = Map<String, dynamic>.from(json['tasks'] ?? const {});
    final parsed = raw.map((ctx, t) => MapEntry(ctx, TaskIdsPerContext.fromJson(Map<String, dynamic>.from(t))));
    return AsyncFileUploadResponse(
      fileId       : json['file_id'],
      contexts     : List<String>.from(json['contexts'] ?? const []),
      tasks        : parsed,
      uploadTaskId : json['upload_task_id'],         // NEW
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
    //"chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
    "chatbot_nlp_api": "http://127.0.0.1:8888"
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
   String? subscriptionId,   
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
  // Dentro il metodo, vicino agli altri fields:
if (subscriptionId != null && subscriptionId.isNotEmpty) {
  request.fields['subscription_id'] = subscriptionId;   // << NEW
}

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
   String username,
   String token,
   List<String> contexts,
   String model, {
   String? systemMessageContent,                      // ← nuovo
   List<Map<String, dynamic>>? customServerTools,           // ← nuovo
   List<ToolSpec> toolSpecs = const [],      // ⬅️  nuovo parametro opzionale
 }) async {
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
        // Se è stato fornito un system message extra, lo includo
    if (systemMessageContent != null && systemMessageContent.isNotEmpty)
      'system_message_content': systemMessageContent,
    // Se ci sono tool custom da sovrascrivere o aggiungere
    if (customServerTools != null && customServerTools.isNotEmpty)
      'custom_tools': customServerTools,
    // Se vogliamo anche inviare widget-instructions dei tool per documentazione
    if (toolSpecs.isNotEmpty)
    'client_tool_specs': toolSpecs.map((t) => t.toJson()).toList(),
  };

  print("#"*120);
  print(body);
  print("#"*120);

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
/* ────────────────────────────────────────────────────────────────
 * SDK ▸ listDocuments  ▶︎  restituisce anche il totale record
 * ──────────────────────────────────────────────────────────────── */
/*───────────────────────────────────────────────────────────────────────────
  API SDK ▸ lista documenti con callback onTotal
───────────────────────────────────────────────────────────────────────────*/
Future<List<DocumentModel>> listDocuments(
  String collectionName, {
  String? prefix,
  int skip = 0,
  int limit = 10,
  String? token,
  void Function(int total)? onTotal,       // ← NEW (totale record server)
}) async {
  if (baseUrl == null) await loadConfig();

  final query = <String, String>{
    'skip' : skip.toString(),
    'limit': limit.toString(),
    if (prefix != null) 'prefix': prefix,
    if (token  != null) 'token' : token,
  };

  final uri = Uri.parse('$baseUrl/documents/$collectionName/')
      .replace(queryParameters: query);

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    /* il backend espone il totale in una response‑header
       “X-Total-Count: 57” (→ adattare se diverso) */
    if (onTotal != null &&
        response.headers.containsKey('x-total-count')) {
      onTotal(int.tryParse(response.headers['x-total-count']!) ?? 0);
    }

    final utf8Body = utf8.decode(response.bodyBytes);   // forza UTF‑8
    final data     = jsonDecode(utf8Body) as List<dynamic>;
    return data.map((j) => DocumentModel.fromJson(j)).toList();
  }

  throw ApiException('Errore elenco documenti: ${response.body}');
}

Future<List<DocumentModel>> listDocumentsResolved({
  String? collectionName,
  String? ctx,
  String? filename,
  String? prefix,
  int skip = 0,
  int limit = 10,
  String? token,
  void Function(int total)? onTotal,
}) async {
  if (baseUrl == null) await loadConfig();

  if ((collectionName == null || collectionName.isEmpty) &&
      (ctx == null || filename == null)) {
    throw ArgumentError("Serve 'collectionName' oppure 'ctx' + 'filename'.");
  }

  final query = <String, String>{
    'skip' : skip.toString(),
    'limit': limit.toString(),
    if (prefix != null) 'prefix': prefix,
    if (token  != null) 'token' : token,
    if (collectionName != null && collectionName.isNotEmpty) 'collection_name': collectionName,
    if (ctx != null) 'ctx': ctx!,
    if (filename != null) 'filename': filename!,
  };

  final uri = Uri.parse('$baseUrl/documents').replace(queryParameters: query);
  final response = await http.get(uri);

  if (response.statusCode == 200) {
    if (onTotal != null && response.headers.containsKey('x-total-count')) {
      onTotal(int.tryParse(response.headers['x-total-count']!) ?? 0);
    }
    final utf8Body = utf8.decode(response.bodyBytes);
    final data     = jsonDecode(utf8Body) as List<dynamic>;
    return data.map((j) => DocumentModel.fromJson(j)).toList();
  }

  throw ApiException('Errore elenco documenti: ${response.body}');
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

  /// Recupera la configurazione di una chain.
  ///
  /// Puoi passare:
  ///   - [chainId] (senza _config) oppure direttamente l'id config con suffisso
  ///   - [chainConfigId] (se già noto)
  /// Uno dei due è obbligatorio. Se entrambi presenti ha priorità `chainId`.
  ///
  /// Restituisce un oggetto [ChainConfiguration] (o lancia ApiException).
  Future<ChainConfiguration> getChainConfiguration({
    String? chainId,
    String? chainConfigId,
    String? token,
  }) async {
    if (baseUrl == null) await loadConfig();

    if ((chainId == null || chainId.isEmpty) &&
        (chainConfigId == null || chainConfigId.isEmpty)) {
      throw ApiException(
          'Devi fornire chainId oppure chainConfigId per recuperare la configurazione.');
    }

    // determina il config_id finale
    String configId;
    if (chainId != null && chainId.isNotEmpty) {
      configId = chainId.endsWith('_config') ? chainId : '${chainId}_config';
    } else {
      configId = chainConfigId!.endsWith('_config')
          ? chainConfigId
          : '${chainConfigId}_config';
    }

    final uri = Uri.parse('$baseUrl/get_chain_configuration');

    final body = <String, dynamic>{
      if (chainId != null) 'chain_id': chainId,
      if (chainConfigId != null) 'chain_config_id': chainConfigId,
      if (token != null) 'token': token,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      return ChainConfiguration.fromJson(jsonMap);
    } else {
      throw ApiException(
          'Errore get_chain_configuration: ${res.body}');
    }
  }


Future<ImageBase64ResponseDto> fetchImageAsBase64(
  String imageUrl, {
  bool includeDimensions = true,
  int maxBytes = 10 * 1024 * 1024,
}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/image/base64').replace(queryParameters: {
    'url': imageUrl,
    'include_dimensions': includeDimensions.toString(),
    'max_bytes': maxBytes.toString(),
  });

  final res = await http.get(uri);

  if (res.statusCode == 200) {
    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    return ImageBase64ResponseDto.fromJson(jsonMap);
  } else {
    throw ApiException('Errore /image/base64: ${res.body}');
  }
}


// context_api_sdk.dart  (aggiungi dopo downloadFile)
Future<Uint8List> fetchFileBytes(String fileId, {String? token}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/download').replace(queryParameters: {
    'file_id': fileId,
    if (token != null) 'token': token,
  });

  final response = await http.get(uri);
  if (response.statusCode == 200) {
    return response.bodyBytes;                // 👈 restituiamo i bytes
  } else {
    throw ApiException(
        'Errore durante il download del file: ${response.body}');
  }
}


  // ────────────────────────────────────────────────────────────────────────
  // PAYMENTS ▸ API
  // ────────────────────────────────────────────────────────────────────────

/// GET /payments/current_plan
Future<CurrentPlanResponse> getCurrentPlan(String token) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/payments/current_plan')
      .replace(queryParameters: {'token': token});

  final res = await http.get(uri);

  if (res.statusCode == 200) {
    return CurrentPlanResponse.fromJson(jsonDecode(res.body));
  }

  if (res.statusCode == 404) {
    // NEW: 404 = nessuna subscription attiva → caso funzionale
    // lo facciamo distinguere con una eccezione tipizzata
    
   print("#"*120);
   print(res.statusCode);
   print("#"*120);
    throw NoActiveSubscriptionException();
  }

  // altre casistiche (401/403/500/…): errore reale
  throw ApiException(
    'Errore /payments/current_plan '
    '(status=${res.statusCode}): ${res.body}',
  );
}

/// GET /payments/current_plan  → null se non c’è un piano (404)
Future<CurrentPlanResponse?> getCurrentPlanOrNull(String token) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/payments/current_plan')
      .replace(queryParameters: {'token': token});

  final res = await http.get(uri);

  if (res.statusCode == 200) {
    return CurrentPlanResponse.fromJson(jsonDecode(res.body));
  }
  if (res.statusCode == 404) {
    // “nessuna subscription attiva” → caso funzionale
    return null;
  }

  throw ApiException(
    'Errore /payments/current_plan (status=${res.statusCode}): ${res.body}',
  );
}


  /// GET /payments/credits
  Future<UserCreditsResponse> getUserCredits(String token, {String? subscriptionId}) async {
    if (baseUrl == null) await loadConfig();

    final qp = <String, String>{'token': token};
    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      qp['subscription_id'] = subscriptionId;
    }

    final uri = Uri.parse('$baseUrl/payments/credits').replace(queryParameters: qp);
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      return UserCreditsResponse.fromJson(jsonDecode(res.body));
    }
    throw ApiException('Errore /payments/credits: ${res.body}');
  }

  /// POST /payments/checkout  → può tornare "checkout" o "portal_redirect"
  Future<CheckoutOrPortal> createCheckoutSessionVariant({
    required String token,
    required String planType,
    required String variant,
    String locale = 'it',
    String? successUrl,
    String? cancelUrl,
  }) async {
    if (baseUrl == null) await loadConfig();

    final uri = Uri.parse('$baseUrl/payments/checkout');
    final body = {
      'token'      : token,
      'plan_type'  : planType,
      'variant'    : variant,
      'locale'     : locale,
      if (successUrl != null) 'success_url': successUrl,
      if (cancelUrl  != null) 'cancel_url' : cancelUrl,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return CheckoutOrPortal.fromJson(j);
    }
    throw ApiException('Errore /payments/checkout: ${res.body}');
  }

/// POST /payments/portal_session
Future<PortalSessionResponse> createPortalSession({
  required String token,
  String? returnUrl,
  // [NEW] hint per saltare list/resources su L2
  String? currentSubscriptionId,
  String? currentPlanType,
}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/payments/portal_session');
  final body = {
    'token': token,
    if (returnUrl != null) 'return_url': returnUrl,
    // [NEW] hint → L2 li userà per evitare 2 round-trip a L1
    if (currentSubscriptionId != null && currentSubscriptionId.isNotEmpty)
      'current_subscription_id': currentSubscriptionId,
    if (currentPlanType != null && currentPlanType.isNotEmpty)
      'current_plan_type': currentPlanType,
  };

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (res.statusCode == 200) {
    return PortalSessionResponse.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore /payments/portal_session: ${res.body}');
}


/// POST /payments/deeplink/update
Future<DeeplinkResponse> createUpdateDeeplink({
  required String token,
  String? returnUrl,
  ChangeIntent changeIntent = ChangeIntent.both,
  List<String>? variantsOverride,
  List<String>? variantsCatalog,
  // [NEW] hint per saltare list/resources su L2
  String? currentSubscriptionId,
  String? currentPlanType,
  String? currentVariant,
}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/payments/deeplink/update');
  final body = {
    'token': token,
    if (returnUrl != null) 'return_url': returnUrl,
    'change_intent': changeIntent.wire,
    if (variantsOverride != null) 'variants_override': variantsOverride,
    if (variantsCatalog  != null) 'variants_catalog' : variantsCatalog,

    // [NEW] hint → L2 li userà per evitare 2 round-trip a L1
    if (currentSubscriptionId != null && currentSubscriptionId.isNotEmpty)
      'current_subscription_id': currentSubscriptionId,
    if (currentPlanType != null && currentPlanType.isNotEmpty)
      'current_plan_type': currentPlanType,
    if (currentVariant != null && currentVariant.isNotEmpty)
      'current_variant': currentVariant,
  };

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (res.statusCode == 200) {
    return DeeplinkResponse.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore /payments/deeplink/update: ${res.body}');
}


/// POST /payments/deeplink/upgrade
///
/// Specifica EITHER `targetPriceId` OR (`targetPlanType` + `targetVariant`)
Future<DeeplinkUpgradeResponse> createUpgradeDeeplink({
  required String token,
  String? returnUrl,
  String? targetPriceId,
  String? targetPlanType,
  String? targetVariant,
  // [NEW] hint per saltare list/resources su L2
  String? currentSubscriptionId,
  String? currentPlanType,
  String? currentVariant,
}) async {
  if (baseUrl == null) await loadConfig();

  // Validazione client-side allineata al server
  final hasPrice = (targetPriceId != null && targetPriceId.isNotEmpty);
  final hasPlanAndVariant =
      (targetPlanType != null && targetPlanType.isNotEmpty) &&
      (targetVariant   != null && targetVariant.isNotEmpty);
  if (!hasPrice && !hasPlanAndVariant) {
    throw ApiException(
      'Devi fornire targetPriceId oppure targetPlanType + targetVariant.',
    );
  }

  final uri = Uri.parse('$baseUrl/payments/deeplink/upgrade');
  final body = {
    'token': token,
    if (returnUrl != null) 'return_url': returnUrl,

    // target by price OR by plan+variant
    if (targetPriceId  != null) 'target_price_id'  : targetPriceId,
    if (targetPlanType != null) 'target_plan_type' : targetPlanType,
    if (targetVariant  != null) 'target_variant'   : targetVariant,

    // [NEW] hint → L2 li userà per evitare 2 round-trip a L1
    if (currentSubscriptionId != null && currentSubscriptionId.isNotEmpty)
      'current_subscription_id': currentSubscriptionId,
    if (currentPlanType != null && currentPlanType.isNotEmpty)
      'current_plan_type': currentPlanType,
    if (currentVariant != null && currentVariant.isNotEmpty)
      'current_variant': currentVariant,
  };

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (res.statusCode == 200) {
    return DeeplinkUpgradeResponse.fromJson(jsonDecode(res.body));
  }
  throw ApiException('Errore /payments/deeplink/upgrade: ${res.body}');
}

  /// POST /payments/deeplink/cancel
  Future<DeeplinkResponse> createCancelDeeplink({
    required String token,
    String? returnUrl,
    bool immediate = true,
    String? portalPreset,           // opzionale, per compatibilità
    List<String>? variantsCatalog,  // opzionale
  }) async {
    if (baseUrl == null) await loadConfig();

    final uri = Uri.parse('$baseUrl/payments/deeplink/cancel');
    final body = {
      'token'     : token,
      'immediate' : immediate,
      if (returnUrl   != null) 'return_url'     : returnUrl,
      if (portalPreset!= null) 'portal_preset'  : portalPreset,
      if (variantsCatalog != null) 'variants_catalog': variantsCatalog,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return DeeplinkResponse.fromJson(jsonDecode(res.body));
    }
    throw ApiException('Errore /payments/deeplink/cancel: ${res.body}');
  }

// ==========================
// USER TASKS ENDPOINTS
// ==========================

// NEW: GET /user_tasks/{user_id}?unread_only=true|false
Future<UserTasksResponseDto> getUserTasks(String userId, {bool unreadOnly = false}) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/user_tasks/$userId')
      .replace(queryParameters: {
        if (unreadOnly) 'unread_only': 'true',
      });

  final res = await http.get(uri);
  if (res.statusCode == 200) {
    return UserTasksResponseDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
  throw ApiException('Errore GET /user_tasks/$userId: ${res.body}');
}

// NEW: GET /user_tasks/{user_id}/unread  (auto-mark as read)
Future<UserTasksResponseDto> getUserUnreadTasksAndMarkRead(String userId) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/user_tasks/$userId/unread');
  final res = await http.get(uri);
  if (res.statusCode == 200) {
    return UserTasksResponseDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
  throw ApiException('Errore GET /user_tasks/$userId/unread: ${res.body}');
}

// NEW: GET /user_tasks/{user_id}/{task_id}  (ispezione singolo task)
Future<UploadTaskDto> getSingleUserTask(String userId, String taskId) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/user_tasks/$userId/$taskId');
  final res = await http.get(uri);
  if (res.statusCode == 200) {
    return UploadTaskDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
  throw ApiException('Errore GET /user_tasks/$userId/$taskId: ${res.body}');
}

}