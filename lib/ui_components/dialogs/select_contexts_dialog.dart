import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/utilities/localization.dart';
import 'package:intl/intl.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  Mostra il dialog di selezione contesti + modello
/// ─────────────────────────────────────────────────────────────────────────────
Future<void> showSelectContextDialog({
  required BuildContext context,
  required List<ContextMetadata> availableContexts,
  required List<String> initialSelectedContexts,
  required String initialModel,
  required List<dynamic> chatHistory,                   // ⬅️  NUOVO
  required void Function(List<String> selectedContexts, String model) onConfirm,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SelectContextDialogContent(
      availableContexts: availableContexts,
      initialSelectedContexts: initialSelectedContexts,
      initialModel: initialModel,
      chatHistory: chatHistory,                         // ⬅️  NUOVO
      onConfirm: onConfirm,
    ),
  );
}

/// ════════════════════════════════════════════════════════════════════════════
///  CONTENT
/// ════════════════════════════════════════════════════════════════════════════
class _SelectContextDialogContent extends StatefulWidget {
  final List<ContextMetadata> availableContexts;
  final List<String>          initialSelectedContexts;
  final String                initialModel;
  final List<dynamic>         chatHistory;             // ⬅️  NUOVO
  final void Function(List<String>, String) onConfirm;

  const _SelectContextDialogContent({
    Key? key,
    required this.availableContexts,
    required this.initialSelectedContexts,
    required this.initialModel,
    required this.chatHistory,                         // ⬅️  NUOVO
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<_SelectContextDialogContent> createState() =>
      _SelectContextDialogContentState();
}

class _SelectContextDialogContentState
    extends State<_SelectContextDialogContent> {

      bool _isSaving = false;  
  // ───────────────────────────────  STATE
  late List<ContextMetadata> _filteredContexts;
  late TextEditingController _searchController;
  late List<String>          _selectedContexts;
  late String                _selectedModel;
  String _viewMode = 'kb'; // "kb" | "chat"

// ═════════ CHAT-INFO MAP { chatId → {name, updatedAt} } + cache
late Map<String, Map<String, String>> _chatInfo;     // ← non più final
final Map<String, String>    _chatNameCache      = {};
final Map<String, DateTime?> _chatUpdatedAtCache = {};


  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════
  bool _isChatContext(ContextMetadata ctx) =>
      (ctx.customMetadata?['chat_id']?.toString().trim().isNotEmpty ?? false);
// ───────── helpers letti SEMPRE da localStorage ─────────
String _chatNameById(String chatId) {
  // solo lookup in cache/map, niente jsonDecode né localStorage qui
  return _chatNameCache[chatId] ?? _chatInfo[chatId]?['name'] ?? '';
}
Map<String, Map<String, String>> _buildChatInfoOnce() {
  final result = <String, Map<String, String>>{};

  // 1) fonte: widget.chatHistory (più fresca lato app)
  for (final c in widget.chatHistory) {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) continue;
    final name = (c['name'] ?? '').toString();
    final updatedAt = (c['updatedAt'] ?? '').toString();

    result[id] = {'name': name, 'updatedAt': updatedAt};
    if (name.isNotEmpty) _chatNameCache[id] = name;
    if (updatedAt.isNotEmpty) {
      _chatUpdatedAtCache[id] = DateTime.tryParse(updatedAt);
    }
  }

  // 2) merge UNA VOLTA con localStorage (fallback)
  try {
    final raw = html.window.localStorage['chatHistory'];
    if (raw != null) {
      final decoded = jsonDecode(raw);
      final List list = decoded is Map ? (decoded['chatHistory'] ?? const []) : (decoded as List);

      for (final c in list) {
        final id = (c['id'] ?? '').toString();
        if (id.isEmpty) continue;

        final name = (c['name'] ?? '').toString();
        String updatedAt = (c['updatedAt'] ?? '').toString();

        // se manca updatedAt, prova dall’ultimo messaggio
        if (updatedAt.isEmpty) {
          final List msgs = (c['messages'] ?? const []) as List;
          if (msgs.isNotEmpty) {
            final last = msgs.last;
            updatedAt = (last['createdAt'] ?? '').toString();
          }
        }

        final cur = Map<String, String>.from(result[id] ?? const {});
        if ((cur['name'] ?? '').isEmpty && name.isNotEmpty) {
          cur['name'] = name;
          _chatNameCache[id] = name;
        }
        if ((cur['updatedAt'] ?? '').isEmpty && updatedAt.isNotEmpty) {
          cur['updatedAt'] = updatedAt;
          _chatUpdatedAtCache[id] = DateTime.tryParse(updatedAt);
        }
        result[id] = cur;
      }
    }
  } catch (_) {
    // ignora errori di parsing/localStorage
  }

  return result;
}

DateTime? _chatLastMsgDate(String chatId) {
  // usa cache; se manca prova a parsare una volta la stringa in _chatInfo e memorizza
  final cached = _chatUpdatedAtCache[chatId];
  if (cached != null) return cached;

  final raw = _chatInfo[chatId]?['updatedAt'] ?? '';
  final dt  = raw.isNotEmpty ? DateTime.tryParse(raw) : null;
  _chatUpdatedAtCache[chatId] = dt;     // memoize
  return dt;
}


/// Ritorna il nome da mostrare. Se è una chat-KB ma la chat non esiste più,
/// restituisce null → la KBox verrà esclusa dalla lista.
String? _displayName(ContextMetadata ctx) {
  if (_isChatContext(ctx)) {
    final chatId = ctx.customMetadata?['chat_id']?.toString() ?? '';
    if (chatId.isEmpty) return null;

    final chatName = _chatNameById(chatId).trim();
    if (chatName.isEmpty) return null; // chat non trovata → drop

    // nome base della KB
    //final kbBase = ctx.customMetadata?['display_name']?.toString().trim();
    //final base = (kbBase?.isNotEmpty ?? false) ? kbBase! : ctx.path;

    return 'Chat ($chatName)';
  }

  // KB “normale”
  final disp = ctx.customMetadata?['display_name']?.toString().trim();
  return (disp?.isNotEmpty ?? false) ? disp! : ctx.path;
}


  String? _lastMessageDate(ContextMetadata ctx) {
    if (!_isChatContext(ctx)) return null;
    final chatId = ctx.customMetadata?['chat_id'];
    final raw    = _chatInfo[chatId]?['updatedAt'] ?? '';
    if (raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
             '${dt.month.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:'
             '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  INIT
  // ════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedContexts = List.from(widget.initialSelectedContexts);
    _selectedModel    = widget.initialModel;
    _chatInfo = _buildChatInfoOnce();   // ← costruisce mappe e cache una sola volta
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════
  //  FILTER
  // ════════════════════════════════════════════════════════════════════════
void _applyFilters() {
  final q = _searchController.text.toLowerCase();

  setState(() {
    _filteredContexts = widget.availableContexts.where((ctx) {
      // Filtra per tipo (kb/chat)
      final keepType = (_viewMode == 'kb') ? !_isChatContext(ctx) : _isChatContext(ctx);
      if (!keepType) return false;

      // Calcola displayName (può essere null ⇒ drop)
      final dispName = _displayName(ctx);
      if (dispName == null) return false;

      final name = ctx.path.toLowerCase();
      final disp = dispName.toLowerCase();

      return name.contains(q) || disp.contains(q);
    }).toList();

    // Se un contesto selezionato è stato rimosso (chat cancellata), toglilo
    _selectedContexts.removeWhere((p) {
      final ctx = widget.availableContexts.firstWhere(
        (c) => c.path == p,
        orElse: () => ContextMetadata(path: '', customMetadata: const {}),
      );
      if (ctx.path.isEmpty) return true;
      return _isChatContext(ctx) && _displayName(ctx) == null;
    });
  });
}


  // ════════════════════════════════════════════════════════════════════════
  //  CALLBACK
  // ════════════════════════════════════════════════════════════════════════
 Future<void> _handleConfirm() async {
   setState(() => _isSaving = true);              // mostra loader

   try {
     // cast a `dynamic` per poter catturare l’eventuale Future
     final dynamic ret =
         (widget.onConfirm as dynamic)(_selectedContexts, _selectedModel);

     if (ret is Future) await ret;                // aspetta se serve
   } finally {
     if (mounted) {
       setState(() => _isSaving = false);
       Navigator.of(context).pop();               // chiudi dialog
     }
   }
 }
  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc = LocalizationProvider.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
    children: [ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ───── titolo
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                loc.select_contexts_and_model,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // ───── barra di ricerca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: loc.search_contexts,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ───── toggle KB / CHAT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _modeButton(
                    label: 'Knowledge Boxes',
                    selected: _viewMode == 'kb',
                    onTap: () {
                      _viewMode = 'kb';
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _modeButton(
                    label: 'Chats',
                    selected: _viewMode == 'chat',
                    onTap: () {
                      _viewMode = 'chat';
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ───── lista contesti
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  height: 220,
                  child: widget.availableContexts.isEmpty
    ? const Center(child: CircularProgressIndicator())
    : ListView.builder(
                    itemCount: _filteredContexts.length,
                    itemBuilder: (_, i) {
  final ctx = _filteredContexts[i];
  final sel = _selectedContexts.contains(ctx.path);
  final dispName = _displayName(ctx); // nuovo

  // Se null, non renderizzare (scartata perché chat non trovata)
  if (dispName == null) return const SizedBox.shrink();

  final dt = _isChatContext(ctx)
      ? _chatLastMsgDate(ctx.customMetadata?['chat_id'] ?? '')
      : null;

  return CheckboxListTile(
    dense: true,
    title: Text(
      dispName,
      style: TextStyle(
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    subtitle: (dt != null)
        ? Text(DateFormat('dd/MM/yyyy  HH:mm').format(dt))
        : null,
    value: sel,
    onChanged: (v) {
      setState(() {
        if (v == true) {
          _selectedContexts.add(ctx.path);
        } else {
          _selectedContexts.remove(ctx.path);
        }
      });
    },
    activeColor: Colors.blue,
    checkColor: Colors.white,
  );
},

                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ───── modello
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildModelSelector(),
            ),
            const SizedBox(height: 24),

            // ───── azioni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(loc.cancel),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _handleConfirm,
                    child: Text(loc.confirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),      // ── loader centrato ─────────────────────────────
      if (_isSaving)
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black26,               // semi-trasparente
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),]),
    );
  }

  // ───────────────────────────────  HELPERS UI
  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    final models = ['gpt-4o', 'gpt-4o-mini'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: models.map((m) {
        final selected = (_selectedModel == m);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedModel = m),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey[200]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: Image.network(
                        'https://static.wixstatic.com/media/63b1fb_48896f0cf8684eb7805d2b5a980e2d19~mv2.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(m, style: const TextStyle(color: Colors.black)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
