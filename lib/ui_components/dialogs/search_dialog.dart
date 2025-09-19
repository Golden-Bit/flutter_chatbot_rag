// search_dialog.dart
import 'package:flutter/material.dart';
import 'package:boxed_ai/utilities/localization.dart';
import 'package:intl/intl.dart';


/// Questa funzione mostra un Dialog di ricerca.
/// [chatHistory] è la lista di chat; ognuna è una mappa con chiave 'messages'
/// [context] serve per mostrare il dialog
/// [onNavigateToMessage] è la callback da chiamare quando l'utente
/// clicca su un risultato per andare a uno specifico messaggio (chatId, messageId).
Future<void> showSearchDialog({
  required BuildContext context,
  required List<dynamic> chatHistory,
  required void Function(String chatId, String messageId) onNavigateToMessage,
}) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return _SearchDialogContent(
        chatHistory: chatHistory,
        onNavigateToMessage: onNavigateToMessage,
      );
    },
  );
}

/// Questo widget interno gestisce la UI e la logica di ricerca.
class _SearchDialogContent extends StatefulWidget {
  final List<dynamic> chatHistory;
  // Callback per navigare al messaggio specifico.
  final void Function(String chatId, String messageId) onNavigateToMessage;

  const _SearchDialogContent({
    Key? key,
    required this.chatHistory,
    required this.onNavigateToMessage,
  }) : super(key: key);

  @override
  State<_SearchDialogContent> createState() => _SearchDialogContentState();
}

class _SearchDialogContentState extends State<_SearchDialogContent> {

  late TextEditingController _searchController;
  // Lista dei risultati di ricerca. Ogni risultato contiene: chatId, chatName, messageContent, messageId, createdAt.
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
      super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Esegue la ricerca nei messaggi di ogni chat in base alla query.
  void _performSearch(String query) {
    final localizations = LocalizationProvider.of(context);
    final results = <Map<String, dynamic>>[];

    // Scorri tutte le chat.
    for (final chat in widget.chatHistory) {
      final chatName = chat['name'] ?? localizations.unknownChat;
      final chatId = chat['id'];

      // Ottieni la lista di messaggi di questa chat.
      final messages = chat['messages'] as List<dynamic>? ?? [];

      // Per ogni messaggio, verifica se contiene la query (case insensitive).
      for (final msg in messages) {
        final content = (msg['content'] ?? '') as String;
        if (content.toLowerCase().contains(query.toLowerCase())) {
          results.add({
            'chatId': chatId,
            'chatName': chatName,
            'messageContent': content,
            'messageId': msg['id'],
            // Se presente, includiamo anche la data di creazione per il raggruppamento.
            'createdAt': msg['createdAt'] ?? '',
          });
        }
      }
    }

    // Aggiorna la lista locale dei risultati.
    setState(() {
      _searchResults = results;
    });
  }

  /// Verifica se due DateTime rappresentano lo stesso giorno.
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  /// Ritorna un'etichetta per la data:
  /// - "Oggi" se la data è oggi,
  /// - "Ieri" se la data è ieri,
  /// - altrimenti la data formattata come "dd MMM yyyy".
  String _getDateLabel(DateTime date) {
    final localizations = LocalizationProvider.of(context);
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return localizations.today;
    } else if (_isSameDay(date, now.subtract(Duration(days: 1)))) {
      return localizations.yesterday;
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  /// Costruisce una ListView con i risultati raggruppati per data, inserendo separatori.
  Widget _buildGroupedResults() {
    final localizations = LocalizationProvider.of(context);
    // Ordina i risultati in ordine decrescente in base a createdAt.
    final sortedResults = List<Map<String, dynamic>>.from(_searchResults);
    sortedResults.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    final List<Widget> widgets = [];
    String? currentLabel;

    for (var result in sortedResults) {
      DateTime date = DateTime.tryParse(result['createdAt'] ?? '') ?? DateTime.now();
      String label = _getDateLabel(date);
      // Inserisce il separatore se cambia il gruppo.
      if (currentLabel != label) {
        widgets.add(
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
        currentLabel = label;
      }

      final chatName = result['chatName'] ?? localizations.unknownChat;
      final content = result['messageContent'] ?? '';
      // Troncamento a 200 caratteri.
      final truncatedContent = content.length > 200 ? content.substring(0, 200) + '...' : content;

      widgets.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              chatName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(truncatedContent),
            onTap: () {
              // Chiama la callback passando chatId e messageId.
              widget.onNavigateToMessage(
                result['chatId'],
                result['messageId'],
              );
              // Chiude il dialog.
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    return AlertDialog(
      // Lo sfondo del dialog rimane bianco per le azioni e il titolo.
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Angoli a 16
      ),
      title: Text(
        localizations.searchTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Container(
        width: 500, // Larghezza massima del dialog
        height: 400, // Altezza fissa per gestire lo scroll della lista
        child: Column(
          children: [
            // Campo di testo per la ricerca.
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black), // Bordi neri
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black), // Bordi neri per lo stato normale
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
                ),
              ),
              onChanged: (value) {
                _performSearch(value.trim());
              },
            ),
            const SizedBox(height: 16),
            // Area dei risultati con effetto Shader (fade sopra e sotto) e gradient di sfondo.
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.5, 0.25),
                    radius: 1.2,
                    colors: [
                      Color.fromARGB(255, 199, 230, 255),
                      Colors.white,
                    ],
                    stops: [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: _searchResults.isNotEmpty
                    ? ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white,
                            ],
                            stops: [0.0, 0.03, 0.97, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstOut,
                        child: _buildGroupedResults(),
                      )
                    : Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          localizations.noResults,
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.close),
        )
      ],
    );
  }
}
