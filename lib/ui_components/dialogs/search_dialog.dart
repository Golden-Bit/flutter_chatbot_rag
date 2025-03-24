// search_dialog.dart
import 'package:flutter/material.dart';

/// Questa funzione mostra un Dialog di ricerca.
/// [chatHistory] è la lista di chat; ognuna è una mappa con chiave 'messages'
/// [context] serve per mostrare il dialog
/// [onNavigateToMessage] è la callback da chiamare quando l'utente
/// clicca sul pulsante per andare a uno specifico messaggio (chatId, messageId).
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

/// Questo widget interno gestisce la UI e la logica di ricerca
class _SearchDialogContent extends StatefulWidget {
  final List<dynamic> chatHistory;

  // Aggiungiamo la callback
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

  /// Funzione che esegue la ricerca in tutti i messaggi
  void _performSearch(String query) {
    final results = <Map<String, dynamic>>[];

    // 1) Scorri tutte le chat
    for (final chat in widget.chatHistory) {
      final chatName = chat['name'] ?? 'Chat Sconosciuta';
      final chatId = chat['id'];

      // 2) Ottieni la lista di messaggi di questa chat
      final messages = chat['messages'] as List<dynamic>? ?? [];

      // 3) Per ogni messaggio, verifica se contiene la query
      for (final msg in messages) {
        final content = (msg['content'] ?? '') as String;
        if (content.toLowerCase().contains(query.toLowerCase())) {
          // Aggiungiamo un risultato
          results.add({
            'chatId': chatId,
            'chatName': chatName,
            'messageContent': content,
            'messageId': msg['id'],
          });
        }
      }
    }

    // 4) Aggiorna la lista locale dei risultati
    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Angoli a 16
      ),
      title: Text(
        'Cerca nei messaggi',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Container(
        width: 500, // Larghezza massima del dialog
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo di testo per la ricerca
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Inserisci testo da cercare...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black), // Bordi neri
                  ),
    enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
                ),
                onChanged: (value) {
                  _performSearch(value.trim());
                },
              ),
              const SizedBox(height: 16),

              // Se ci sono risultati, li mostriamo in una listView “shrinkWrap”
              if (_searchResults.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final chatName = result['chatName'];
                    final content = result['messageContent'];

                    // Troncamento a 200 caratteri
                    final truncatedContent = content.length > 200
                        ? content.substring(0, 200) + '...'
                        : content;

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.chat),
                        title: Text(
                          chatName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(truncatedContent),

                        // Pulsante a destra per "navigare" al messaggio
                        trailing: IconButton(
                          icon: Icon(Icons.arrow_forward),
                          onPressed: () {
                            // Esegui la callback passandogli chatId e messageId
                            widget.onNavigateToMessage(
                              result['chatId'],
                              result['messageId'],
                            );
                            // Chiudi il dialog
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nessun risultato.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Chiudi'),
        )
      ],
    );
  }
}
