// ensure_chain_includes_chat_kb.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:uuid/uuid.dart';

/// ─────────────────── type-alias usati come callback ────────────────────
typedef StripUserPrefix = String Function(String ctx);
typedef ConfigureChain  = Future<Map<String, dynamic>> Function(
  String username,
  String accessToken,
  List<String> contexts,
  String model,
);
typedef PersistChatHistory = FutureOr<void> Function(
  List<Map<String, dynamic>> chatHistory,
);

class EnsureChainOutcome {
  final String? chainId;
  final String? configId;
  const EnsureChainOutcome({required this.chainId, required this.configId});
}

/// ───────────────────────────────────────────────────────────────────────
///  Controlla se la chat possiede **almeno** un documento indicizzato e,
///  qualora la sua KB *non* fosse ancora inclusa nella chain, riconfigura
///  la chain aggiungendo quella KB.
///
///  * Ritorna `null` se non c’è nulla da fare.
///  * Altrimenti ritorna i nuovi `chainId` e `configId`.
///
///  Tutti gli “effetti collaterali” (refresh UI, persistenza, ecc.) vengono
///  delegati a callback opzionali, così la funzione rimane pura e testabile.
/// ───────────────────────────────────────────────────────────────────────
Future<EnsureChainOutcome?> ensureChainIncludesChatKbPure({
  required List<dynamic>             chatHistory,          // <─ input flessibile
  required String                    chatId,
  required String                    username,
  required String                    accessToken,
  required String                    defaultModel,
  required StripUserPrefix           stripUserPrefix,
  required ConfigureChain            configureChain,
  void Function(String?, String?)?   onVisibleChatChange,
  PersistChatHistory?                persistChatHistory,
}) async {
  /* 1 ── recupera la chat target */
  final chat = chatHistory.firstWhere(
    (c) => c['id'] == chatId,
    orElse: () => <String, dynamic>{},
  );
  if (chat.isEmpty) return null;

  /* 2 ── verifica se esiste una KB *e* ha doc indicizzati */
  final String? kbPath = chat['kb_path'] as String?;
  if (kbPath == null || kbPath.isEmpty) return null;

  final bool hasIndexedDocs = (chat['messages'] as List).any((m) {
    final fu = m['fileUpload'] as Map<String, dynamic>?;
    return fu != null &&
           fu['ctxPath'] == kbPath &&
           fu['stage']  == 'done';                 // = TaskStage.done.name
  });
  if (!hasIndexedDocs) return null;

  /* 3 ── estrai modello e contesti dall’ultima agent-config */
  String        model = defaultModel;
  List<String>  ctx   = [];
  if ((chat['messages'] as List).isNotEmpty) {
    final cfg = (chat['messages'].last['agentConfig'] ?? const {})
                as Map<String, dynamic>;
    model = (cfg['model'] ?? defaultModel) as String;
    ctx   = List<String>.from(cfg['contexts'] ?? const []);
  }

  /* 4 ── rimuovi il prefisso "<user>-…" dai contesti salvati  */
  final List<String> rawCtx = ctx.map(stripUserPrefix).toList();
  if (rawCtx.contains(kbPath)) return null;          // KB già inclusa

  /* 5 ── nuova lista contesti + call backend */
  final List<String> newCtx = [...rawCtx, kbPath];
  final resp = await configureChain(username, accessToken, newCtx, model);

  final String? newChainId  = resp['load_result']?['chain_id'];
  final String? newConfigId = resp['config_result']?['config_id'];

  /* 6 ── aggiorna la chat *in-place* */
  chat['latestChainId']  = newChainId;
  chat['latestConfigId'] = newConfigId;

  if ((chat['messages'] as List).isNotEmpty) {
    final cfg = (chat['messages'].last['agentConfig'] ?? <String, dynamic>{})
                as Map<String, dynamic>;
    cfg['chain_id']  = newChainId;
    cfg['config_id'] = newConfigId;
    cfg['contexts']  = newCtx.map((c) => "$username-$c").toList();
    chat['messages'].last['agentConfig'] = cfg;
  }

  /* 7 ── callback UI (chat attualmente visibile) */
  onVisibleChatChange?.call(newChainId, newConfigId);

  /* 8 ── persistenza esterna */
  await persistChatHistory?.call(
    chatHistory.cast<Map<String, dynamic>>()     // 👈 fix del tipo!
  );

  return EnsureChainOutcome(chainId: newChainId, configId: newConfigId);
}


/// Ritorna `true` se `ctxPath` è presente tra i contesti disponibili.
///
/// È la stessa logica di `_contextIsKnown`, ma ora è una funzione libera
/// ri-usabile ovunque.
bool contextIsKnown(String ctxPath, List<ContextMetadata> contexts) =>
    contexts.any((c) => c.path == ctxPath);


/// Ritorna i context-path “grezzi” (senza il prefisso <user>-)
/// da passare a `configureAndLoadChain`.
///
/// * [selected]  – i contesti scelti manualmente dall’utente.
/// * [chatKbPath] – la KB legata alla chat corrente (null se non creata).
/// * [chatKbHasDocs] – `true` se quella KB ha almeno 1 documento indicizzato.
///
/// Se `chatKbHasDocs` è `true` aggiunge la KB-chat alla lista, evitando doppioni.
List<String> buildRawContexts(
  List<String> selected, {
  String? chatKbPath,
  bool chatKbHasDocs = false,
}) {
  final set = <String>{...selected};

  if (chatKbHasDocs && chatKbPath != null && chatKbPath.isNotEmpty) {
    set.add(chatKbPath);
  }
  return set.toList();
}

/// Restituisce la lista dei context-path **formattati** con il prefisso
/// "<username>-", come si aspettano i metadati che salvi nei messaggi.
///
/// - [selected]        → contesti scelti manualmente dall’utente.
/// - [username]        → lo user name da anteporre.
/// - [chatKbPath]      → path della KB di chat (facoltativo).
/// - [chatKbHasDocs]   → `true` se la KB di chat contiene almeno 1 documento.
///
/// La funzione ri-usa `buildRawContexts` per evitare duplicazione logica.
List<String> buildFormattedContextsForAgent(
  String username,
  List<String> selected, {
  String? chatKbPath,
  bool chatKbHasDocs = false,
}) {
  final raw = buildRawContexts(
    selected,
    chatKbPath: chatKbPath,
    chatKbHasDocs: chatKbHasDocs,
  );

  return raw.map((c) => '$username-$c').toList();
}


/// Scarica **tutti** i contesti dell’utente e li restituisce.
///
/// Non conosce alcuno stato UI, quindi è testabile ed utilizzabile
/// ovunque (anche in un service o in un bloc/cubit).
Future<List<ContextMetadata>> fetchAvailableContexts(
  ContextApiSdk api, {
  required String username,
  required String accessToken,
}) async {
  try {
    return await api.listContexts(username, accessToken);
  } catch (e, st) {
    debugPrint('[contexts] fetch error: $e\n$st');
    rethrow;                     // il caller decide come gestire l’errore
  }
}



/// Crea (una sola volta) la KB collegata alla chat e ne restituisce il path.
///
/// Se `currentKbPath` è già valorizzato lo riusa direttamente.
///
/// ──────────────────────────────────────────────────────────────────────
/// • [api]          istanza di `ContextApiSdk` per le chiamate REST  
/// • [userName]     username dell’utente loggato  
/// • [accessToken]  bearer token dell’utente  
/// • [chatId]       id univoco della chat  
/// • [chatName]     nome visuale della chat  
/// • [currentKbPath] (opz.) path già noto della KB  
/// ──────────────────────────────────────────────────────────────────────
Future<String> ensureChatKb({
  required ContextApiSdk api,
  required String userName,
  required String accessToken,
  required String chatId,
  required String chatName,
  String? currentKbPath,
}) async {
  // 1. se la KB esiste già, restituiscila subito
  if (currentKbPath != null && currentKbPath.isNotEmpty) return currentKbPath;

  print('#'*120);
  print(chatId);
  print(currentKbPath);
print('#'*120);

  // 2. nuovo path “corto” casuale
  final String uuid = const Uuid().v4().substring(0, 9);

  // 3. chiamata di creazione al backend
  await api.createContext(
    uuid,
    'Archivio messaggi chat $chatName',   // descrizione
    'Chat-$chatName',                     // display-name
    userName,
    accessToken,
    extraMetadata: {'chat_id': chatId},   // associa la chat
  );

  // 4. restituisci il path appena creato
  return uuid;
}

/// Restituisce `true` se in `messages` esiste almeno un messaggio di tipo
/// “fileUpload” riferito alla KB indicata **e** con `stage == TaskStage.done`.
///
/// ──────────────────────────────────────────────────────────────────────
/// • [chatKbPath]  path (grezzo) della KB-chat.  
/// • [messages]    lista dei messaggi (Map<String,dynamic>).  
///                 Ogni messaggio può contenere la chiave 'fileUpload'.  
/// ──────────────────────────────────────────────────────────────────────
bool chatKbHasIndexedDocs({
  required String? chatKbPath,
  required List<Map<String, dynamic>> messages,
}) {
  if (chatKbPath == null || chatKbPath.isEmpty) return false;

  return messages.any((m) {
    final fu = m['fileUpload'] as Map<String, dynamic>?;
    return fu != null &&
        fu['ctxPath'] == chatKbPath &&
        fu['stage'] == TaskStage.done.name;
  });
}
