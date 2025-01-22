import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_app/user_manager/auth_pages.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';  // Aggiungi il pacchetto TTS
import 'package:flutter/services.dart';  // Per il pulsante di copia
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Per il color picker
import 'context_page.dart'; // Importa altri pacchetti necessari
import 'package:flutter/services.dart' show rootBundle;  // Import necessario per caricare file JSON
import 'dart:convert';  // Per il parsing JSON
import 'context_api_sdk.dart';  // Importa lo script SDK
import 'package:flutter_app/user_manager/user_model.dart';
import 'databases_manager/database_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Importa il pacchetto UUID (assicurati di averlo aggiunto a pubspec.yaml)

/*void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatbot Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatBotPage(),
    );
  }
}*/

class ChatBotPage extends StatefulWidget {
  final User user;
  final Token token;

  ChatBotPage({required this.user, required this.token});

  @override
  _ChatBotPageState createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  List<Map<String, String>> messages = [];
  
final Uuid uuid = Uuid(); // Istanza di UUID (può essere globale nel file)

  final TextEditingController _controller = TextEditingController();
  String fullResponse = "";
  bool showKnowledgeBase = false;

  String _selectedContext = "default";  // Variabile per il contesto selezionato
  final ContextApiSdk _contextApiSdk = ContextApiSdk();  // Istanza dell'SDK per le API dei contesti
  List<ContextMetadata> _availableContexts = [];  // Lista dei contesti caricati dal backend

  // Variabili per gestire la colonna espandibile e ridimensionabile
  bool isExpanded = false;
  double sidebarWidth = 0.0;  // Impostata a 0 di default (collassata)
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
  double _pauseBetweenSentences = 0.5; // Pausa tra le frasi

  // Variabili di customizzazione grafica
  Color _userMessageColor = Colors.blue[100]!;
  double _userMessageOpacity = 1.0;

  Color _assistantMessageColor = Colors.grey[200]!;
  double _assistantMessageOpacity = 1.0;

  Color _chatBackgroundColor = Colors.white;
  double _chatBackgroundOpacity = 1.0;

  Color _avatarBackgroundColor = Colors.grey[600]!;
  double _avatarBackgroundOpacity = 1.0;

  Color _avatarIconColor = Colors.white;
  double _avatarIconOpacity = 1.0;
  
  String _selectedModel = "gpt-4o-mini";  // Variabile per il modello selezionato, di default GPT-4O
int? hoveredIndex; // Variabile di stato per tracciare l'hover
int? _activeChatIndex; // Chat attiva (null se si sta creando una nuova chat)
final DatabaseService _databaseService = DatabaseService();
// Aggiungi questa variabile per contenere la chat history simulata
List<dynamic> _chatHistory = [];
String? _nlpApiUrl;

Future<void> _loadConfig() async {
  try {
    //final String response = await rootBundle.loadString('assets/config.json');
    //final data = jsonDecode(response);
     final data = {
    "backend_api": "https://teatek-llm.theia-innovation.com/user-backend",
    "nlp_api": "https://teatek-llm.theia-innovation.com/llm-core",
    "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag"

    };
    _nlpApiUrl = data['nlp_api'];
  } catch (e) {
    print("Errore nel caricamento del file di configurazione: $e");
  }
}

// Funzione di logout
void _logout(BuildContext context) {
  // Rimuove il token dal localStorage
  html.window.localStorage.remove('token');
  html.window.localStorage.remove('user');

  // Reindirizza l'utente alla pagina di login
  Navigator.pushReplacementNamed(context, '/login');
}

Future<void> __loadChatHistory() async {
  try {
    String? chatHistoryJson = html.window.localStorage['chatHistory'];
    if (chatHistoryJson != null) {
      final data = json.decode(chatHistoryJson);
      setState(() {
        _chatHistory = data['chatHistory'];
      });
      print('Chat history caricata: $_chatHistory');
    } else {
      print('Nessuna chat salvata trovata nel Local Storage');
    }
  } catch (e) {
    print('Errore nel caricamento della chat history: $e');
  }
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
        widget.token.accessToken
      );

      // Imposta lo stato locale per indicare che non ci sono chat
      setState(() {
        _chatHistory = [];
      });

      print("Collection 'chats' created successfully. No previous chat history found.");
    } else {
      // Log degli altri errori
      print("Error loading chat history from database: $e");
    }
  }
}



  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();  // Inizializza FlutterTTS
    _loadAvailableContexts();  // Carica i contesti esistenti al caricamento della pagina
      _loadChatHistory();  // Carica la chat history simulata
  }

  // Funzione per caricare i contesti dal backend
  Future<void> _loadAvailableContexts() async {
    try {
      List<ContextMetadata> contexts = await _contextApiSdk.listContexts();
      setState(() {
        _availableContexts = contexts;  // Salva i contesti caricati nello stato
      });
    } catch (e) {
      print('Errore nel caricamento dei contesti: $e');
    }
  }

  // Funzione per aprire il dialog con il ColorPicker
  void _showColorPickerDialog(Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona il colore'),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                setState(() {
                  onColorChanged(color);
                });
              },
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text('Chiudi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
  return Stack(
    children: [
      // Markdown renderer (sotto)
      MarkdownBody(
        data: content, // Mostra il contenuto Markdown2
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
            fontSize: 14.0,
            color: isUser ? Colors.black : Colors.black,
          ),
        ),
      ),
      // Selectable layer (sopra)
      IgnorePointer(
        ignoring: false, // Permette la selezione del testo
        child: SelectableText(
          content, // Testo selezionabile
          style: TextStyle(
            fontSize: 14.0,
            color: Colors.transparent, // Rende invisibile per non coprire Markdown
          ),
          enableInteractiveSelection: true, // Abilita la selezione
        ),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shadowColor: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
        elevation: 8.0, // Aggiungi ombreggiatura (default è 4.0, aumenta se necessario)
        title: Text(
          'Teatek Agent',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color.fromARGB(255, 85, 107, 37), // Imposta il colore personalizzato
        leading: IconButton(
  icon: Icon(Icons.menu, color: Colors.white),
  onPressed: () {
    setState(() {
      isExpanded = !isExpanded;  // Alterna collasso ed espansione
      if (isExpanded) {
        sidebarWidth = MediaQuery.of(context).size.width < 600 
            ? MediaQuery.of(context).size.width // Su schermi piccoli, occupa l'intera larghezza
            : 300.0;  // Imposta la larghezza normale su schermi grandi
      } else {
        sidebarWidth = 0.0;  // Collassa la barra laterale
      }
    });
  },
),
      ),
      body: Row(
        children: [
          // Barra laterale con possibilità di ridimensionamento
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (isExpanded) {
                setState(() {
                  sidebarWidth += details.delta.dx;  // Ridimensiona la barra laterale
                  if (sidebarWidth < 100) sidebarWidth = 100;  // Larghezza minima
                  if (sidebarWidth > 900) sidebarWidth = 900;  // Larghezza massima
                });
              }
            },
            child:AnimatedContainer(
  duration: Duration(milliseconds: 300), // Animazione per l'espansione e il collasso
  width: sidebarWidth, // Usa la larghezza calcolata (può essere 0 se collassato)
  decoration: BoxDecoration(
    color: Color.fromARGB(255, 85, 107, 37), // Colonna laterale con colore personalizzato
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
        blurRadius: 8.0, // Sfocatura dell'ombra
        offset: Offset(2, 0), // Posizione dell'ombra (x, y)
      ),
    ],
  ),
  child: MediaQuery.of(context).size.width < 600 || sidebarWidth > 0
    ? Column(
        children: [
          // Linea di separazione bianca tra AppBar e sidebar
          Container(
            width: double.infinity,
            height: 2.0,  // Altezza della linea
            color: Colors.white,  // Colore bianco per la linea
          ),
          // Padding verticale tra l'AppBar e le voci del menu
          SizedBox(height: 16.0),  // Spazio verticale tra la linea e le voci del menu
          
          // Sezione fissa con le voci principali
  // Pulsante per creare una nuova chat
ListTile(
  leading: Icon(Icons.add, color: Colors.white),
  title: Text('Nuova Chat', style: TextStyle(color: Colors.white)),
  onTap: () {
    _startNewChat(); // Esegui l'azione del pulsante
    if (MediaQuery.of(context).size.width < 600) {
      setState(() {
        sidebarWidth = 0.0; // Collassa la barra laterale
      });
    }
  },
),
         ListTile(
  leading: Icon(Icons.chat, color: Colors.white),
  title: Text('Conversazione', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showKnowledgeBase = false;  // Nascondi la pagina di gestione dei contesti
      showSettings = false;
      _loadChatHistory();  // Carica la chat history simulata
    });
        if (MediaQuery.of(context).size.width < 600) {
      setState(() {
        sidebarWidth = 0.0; // Collassa la barra laterale
      });
    }
  },
),
ListTile(
  leading: Icon(Icons.book, color: Colors.white),
  title: Text('Basi di conoscenza', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showKnowledgeBase = true;  // Visualizza la pagina di gestione dei contesti
      showSettings = false;
      
    });
        if (MediaQuery.of(context).size.width < 600) {
      setState(() {
        sidebarWidth = 0.0; // Collassa la barra laterale
      });
    }
  },
),
ListTile(
  leading: Icon(Icons.settings, color: Colors.white),
  title: Text('Impostazioni', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showSettings = true;
      showKnowledgeBase = false;
    });
        if (MediaQuery.of(context).size.width < 600) {
      setState(() {
        sidebarWidth = 0.0; // Collassa la barra laterale
      });
    }
  },
),
/*ListTile(
  leading: Icon(Icons.history, color: Colors.white),
  title: Text('Conversazioni salvate', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showKnowledgeBase = false;
      showSettings = false;
      // Carica la lista delle chat salvate
      _loadChatHistory();
    });
  },
),*/
// Visualizza la lista delle chat salvate e rendila scrollabile
SizedBox(height: 16.0),  // Spazio verticale di 16.0px

// Rendi la lista delle chat espandibile
// Widget per visualizzare la lista delle chat salvate con menù a tre pallini
// Widget per visualizzare la lista delle chat salvate con menù a tre pallini
Expanded(
  child: ListView.builder(
    itemCount: _chatHistory.length, // Numero totale delle chat caricate
    itemBuilder: (context, index) {
      final chat = _chatHistory[index]; // Estrai i dettagli della chat corrente
      final chatName = chat['name'] ?? 'Chat senza nome'; // Fallback per chat senza nome
      final chatId = chat['id']; // Identificatore univoco della chat
      final isHovered = hoveredIndex == index; // Controlla se la chat è in hover
      final isActive = _activeChatIndex == index; // Controlla se la chat è attiva

      return MouseRegion(
        onEnter: (_) {
          setState(() {
            hoveredIndex = index; // Imposta l'indice per l'hover
          });
        },
        onExit: (_) {
          setState(() {
            hoveredIndex = null; // Rimuovi l'hover quando il mouse esce
          });
        },
        child: ListTile(
          title: Text(
            chatName, // Nome della chat
            style: TextStyle(
              color: Colors.white, // Testo bianco
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal, // Grassetto per la chat attiva
            ),
          ),
          subtitle: Text(
            'ID: $chatId', // Mostra l'ID della chat come sottotitolo
            style: TextStyle(color: Colors.white70, fontSize: 12.0),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: (isHovered || isActive) ? Colors.white : Colors.transparent, // Visibile solo in hover o attivo
            ),
            padding: EdgeInsets.only(right: 4.0), // Margine ridotto a destra
            onSelected: (String value) {
              if (value == 'delete') {
                _deleteChat(index); // Elimina la chat
              } else if (value == 'edit') {
                _showEditChatDialog(index); // Mostra il dialog per la modifica
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifica'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Elimina'),
                ),
              ];
            },
          ),
          onTap: () {
            _loadMessagesForChat(chatId); // Passa l'ID della chat (String) anziché l'indice
            if (MediaQuery.of(context).size.width < 600) {
              setState(() {
                sidebarWidth = 0.0; // Collassa la barra laterale su schermi piccoli
              });
            }
          },
        ),
      );
    },
  ),
),


// Mantieni il pulsante di logout in basso, senza Spacer
Align(
  alignment: Alignment.bottomCenter,
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: ElevatedButton.icon(
      icon: Icon(Icons.logout, color: Colors.red), // Icona rossa
      label: Text(
        'Logout',
        style: TextStyle(color: Colors.red), // Testo rosso
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // Riempimento bianco
      ),
      onPressed: () => _logout(context), // Chiama la funzione di logout
    ),
  ),
),

// Aggiungi qui il Container con padding leggero, bordi bianchi e angoli arrotondati
/*Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0), // Leggero padding orizzontale e verticale
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white), // Bordi bianchi
        color: Colors.transparent, // Sfondo trasparente
        borderRadius: BorderRadius.circular(12.0), // Curvatura degli angoli
      ),
      child: Center(
        child: Text(
          'Spazio disponibile',
          style: TextStyle(color: Colors.white), // Testo bianco, se necessario
        ),
      ),
    ),
  ),
),*/
          // Contenuto scrollabile
          /*Expanded(
            child: SingleChildScrollView(
              child: showSettings
                  ? _buildSettingsSection() // Mostra impostazioni TTS e customizzazione grafica
                  : SizedBox.shrink(), // Placeholder per altre sezioni
            ),
          )*/
        ],
      )
                  : SizedBox.shrink(),
            ),
          ),
          // Area principale
Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),  // Aggiungi padding orizzontale e verticale
    color: _chatBackgroundColor.withOpacity(_chatBackgroundOpacity),  // Sfondo della pagina generale
    child: Center(
      child: showKnowledgeBase 
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),  // Aggiungi padding orizzontale e verticale
            decoration: BoxDecoration(
              color: Colors.white,  // Sfondo bianco all'interno del riquadro
              //border: Border.all(color: Color.fromARGB(255, 85, 107, 37), width: 2.0),  // Bordi dello stesso colore dell'AppBar
              borderRadius: BorderRadius.circular(4.0),  // Arrotonda i bordi
            ),
            constraints: BoxConstraints(maxWidth: 800),  // Limita la larghezza del riquadro
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //Text(
                //  'Gestione dei Contesti', 
                //  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                //),
                //SizedBox(height: 20),  // Spaziatura sotto il titolo
                Expanded(
                  child: DashboardScreen(),  // Contenuto della gestione dei contesti
                ),
              ],
            ),
        ) : showSettings
          ? Container(
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Colors.white,  // Sfondo bianco
                //border: Border.all(color: Color.fromARGB(255, 85, 107, 37), width: 2.0),  // Bordi colorati
                borderRadius: BorderRadius.circular(2.0),
              ),
              constraints: BoxConstraints(maxWidth: 600),  // Limita la larghezza della pagina delle impostazioni
              child: AccountSettingsPage(
                user: widget.user,   // Passa l'oggetto User
                token: widget.token, // Passa l'oggetto Token
              ),
          )
          : Column(  // Altrimenti mostra la pagina del chatbot
              children: [
                Expanded(
  child: ListView.builder(
    itemCount: messages.length,
    itemBuilder: (context, index) {
      final message = messages[index];
      final isUser = message['role'] == 'user';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundColor: _avatarBackgroundColor.withOpacity(_avatarBackgroundOpacity),
                  child: Icon(Icons.android, color: _avatarIconColor.withOpacity(_avatarIconOpacity)),
                ),
              ),
            Flexible(
  child: Container(
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(
      color: isUser
          ? _userMessageColor.withOpacity(_userMessageOpacity)
          : _assistantMessageColor.withOpacity(_assistantMessageOpacity),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: _buildMessageContent(message['content'] ?? '', isUser),
  ),
),
            if (isUser)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: CircleAvatar(
                  backgroundColor: _avatarBackgroundColor.withOpacity(_avatarBackgroundOpacity),
                  child: Icon(Icons.person, color: _avatarIconColor.withOpacity(_avatarIconOpacity)),
                ),
              ),
          ],
        ),
      );
    },
  ),
),

               Padding(
  padding: const EdgeInsets.all(8.0),
  child: Row(
    children: [
      // Aggiungi il nuovo pulsante per aprire il dialog del contesto
      GestureDetector(
        onTap: _showContextDialog,  // Apre il dialog di selezione del contesto
        child: CircleAvatar(
          backgroundColor: Color.fromARGB(255, 85, 107, 37),
          child: Icon(
            Icons.book,  // Usa l'icona analoga alla base di conoscenza
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(width: 8.0),

      // Campo di input della chat
      Expanded(
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Say something...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0), // Smussa gli angoli
              borderSide: BorderSide(color: Color.fromARGB(255, 85, 107, 37)), // Bordi colorati
            ),
          ),
          onSubmitted: _handleUserInput,
        ),
      ),
      SizedBox(width: 8.0),
      
      // Pulsante Microfono
      GestureDetector(
        onTap: _listen, // Attiva o disattiva la registrazione vocale
        child: CircleAvatar(
          backgroundColor: Color.fromARGB(255, 85, 107, 37),
          child: Icon(
            _isListening ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(width: 8.0),
      
      // Pulsante Invia
      GestureDetector(
        onTap: () => _handleUserInput(_controller.text),
        child: CircleAvatar(
          backgroundColor: Color.fromARGB(255, 85, 107, 37),
          child: Icon(
            Icons.send,
            color: Colors.white,
          ),
        ),
      ),
    ],
  ),
),
              ],
            ),
      ),
    ),
  ),

        ],
      ),
    );
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
  final chat = _chatHistory[index];
  final TextEditingController _nameController = TextEditingController(text: chat['name']);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Modifica Nome Chat'),
                   backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Nome della Chat'),
        ),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Salva'),
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
    final chatToUpdate = _chatHistory[index];
    
    // Aggiorna il nome nello stato locale
    setState(() {
      chatToUpdate['name'] = newName;
    });
    
    // Aggiorna il nome nel localStorage
    final String jsonString = jsonEncode({'chatHistory': _chatHistory});
    html.window.localStorage['chatHistory'] = jsonString;

    // Aggiorna il nome nel database
    if (chatToUpdate.containsKey('_id')) {
      await _databaseService.updateCollectionData(
        "${widget.user.username}-database",
        'chats',
        chatToUpdate['_id'],
        {'name': newName},
        widget.token.accessToken,
      );
      print('Nome chat aggiornato con successo nel database.');
    }
  } catch (e) {
    print('Errore durante l\'aggiornamento del nome della chat: $e');
  }
}

// Funzione per caricare una nuova chat
void _startNewChat() {
  setState(() {
    _activeChatIndex = null; // Reset della chat attiva
    messages.clear(); // Pulisci i messaggi per una nuova chat
    showKnowledgeBase = false; // Nascondi KnowledgeBase
    showSettings = false; // Nascondi Impostazioni
  });
}

void _loadMessagesForChat(String chatId) {
  try {
    // Trova la chat corrispondente all'ID
    final chat = _chatHistory.firstWhere(
      (chat) => chat['id'] == chatId,
      orElse: () => null, // Se la chat non esiste, ritorna null
    );

    if (chat == null) {
      print('Errore: Nessuna chat trovata con ID $chatId');
      return;
    }

    // Estrai e ordina i messaggi della chat
    List<dynamic> chatMessages = chat['messages'] ?? [];
    chatMessages.sort((a, b) {
      final aCreatedAt = DateTime.parse(a['createdAt']);
      final bCreatedAt = DateTime.parse(b['createdAt']);
      return aCreatedAt.compareTo(bCreatedAt); // Ordina dal più vecchio al più recente
    });

    // Aggiorna lo stato
    setState(() {
      _activeChatIndex = _chatHistory.indexWhere((c) => c['id'] == chatId); // Imposta l'indice della chat attiva
      messages.clear();
      messages.addAll(chatMessages.map((message) {
        // Assicura che ogni messaggio sia un Map<String, dynamic>
        return Map<String, String>.from(message);
      }).toList());

      // Forza il passaggio alla schermata delle conversazioni
      showKnowledgeBase = false; // Nascondi KnowledgeBase
      showSettings = false; // Nascondi Impostazioni
    });

    // Debug: Messaggi caricati
    print('Messaggi caricati per chat ID $chatId (${chat['name']}): $chatMessages');
  } catch (e) {
    print('Errore durante il caricamento dei messaggi per chat ID $chatId: $e');
  }
}



Future<void> _handleUserInput(String input) async {
  if (input.isEmpty) return;

  final currentTime = DateTime.now().toIso8601String(); // Ora corrente
  final userMessageId = uuid.v4(); // Genera un ID univoco per il messaggio utente

  setState(() {
    // Aggiungi il messaggio dell'utente con ID e timestamp
    messages.add({
      'id': userMessageId, // ID univoco del messaggio
      'role': 'user',
      'content': input,
      'createdAt': currentTime, // Timestamp
    });
    fullResponse = ""; // Reset della risposta completa
  });

  // Genera un ID per il messaggio placeholder dell'assistente
  final assistantMessageId = uuid.v4();

  setState(() {
    // Placeholder per la risposta del bot
    messages.add({
      'id': assistantMessageId, // ID univoco del messaggio dell'assistente
      'role': 'assistant',
      'content': '',
      'createdAt': DateTime.now().toIso8601String(), // Timestamp
    });
  });

  _controller.clear(); // Pulisce il campo di input

  // Invia il messaggio all'API
  await _sendMessageToAPI(input);

  // Salva la conversazione con ID univoco per ogni messaggio
  _saveConversation(messages);
}



Future<void> __saveConversation(List<Map<String, String>> messages) async {
  try {
    if (_activeChatIndex != null) {
      // Fai una copia profonda dei messaggi per evitare riferimenti condivisi
      _chatHistory[_activeChatIndex!]['messages'] = List<Map<String, String>>.from(
        messages.map((message) => Map<String, String>.from(message))
      );
    } else {
      final currentTime = DateTime.now();
      final chatName = 'Chat ${_chatHistory.length + 1}';

      // Crea una nuova chat con copia profonda dei messaggi
      final newChat = {
        'name': chatName,
        'date': currentTime.toIso8601String(),
        'messages': List<Map<String, String>>.from(
          messages.map((message) => Map<String, String>.from(message))
        ),
      };

      _chatHistory.add(newChat);
      _activeChatIndex = _chatHistory.length - 1;
    }

    // Salva la cronologia delle chat nel Local Storage
    final String jsonString = jsonEncode({'chatHistory': _chatHistory});
    html.window.localStorage['chatHistory'] = jsonString;

    print('Chat salvata correttamente: $jsonString');
  } catch (e) {
    print('Errore durante il salvataggio della conversazione: $e');
  }
}


Future<void> _saveConversation(List<Map<String, dynamic>> messages) async {
  try {
    final currentTime = DateTime.now().toIso8601String(); // Ora corrente in formato ISO
    final chatId = _activeChatIndex != null
        ? _chatHistory[_activeChatIndex!]['id'] // ID della chat esistente
        : uuid.v4(); // Genera un nuovo ID univoco per una nuova chat
    final chatName = _activeChatIndex != null
        ? _chatHistory[_activeChatIndex!]['name'] // Nome della chat esistente
        : 'New Chat'; // Nome predefinito per le nuove chat

    // Prepara i messaggi con copia profonda per evitare riferimenti condivisi
    final List<Map<String, dynamic>> updatedMessages = messages.map((message) {
      return Map<String, dynamic>.from(message); // Copia ogni messaggio
    }).toList();

    // Crea o aggiorna la chat corrente con ID, timestamp e messaggi
    final currentChat = {
      'id': chatId, // ID della chat
      'name': chatName, // Nome della chat
      'createdAt': _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['createdAt'] // Mantieni la data di creazione originale
          : currentTime, // Timestamp di creazione per nuove chat
      'updatedAt': currentTime, // Aggiorna il timestamp di ultima modifica
      'messages': updatedMessages, // Lista dei messaggi aggiornati
    };

    if (_activeChatIndex != null) {
      // Aggiorna la chat esistente nella lista locale
      _chatHistory[_activeChatIndex!] = Map<String, dynamic>.from(currentChat); // Copia profonda della chat
    } else {
      // Aggiungi una nuova chat alla lista locale
      _chatHistory.add(Map<String, dynamic>.from(currentChat)); // Copia profonda della chat
      _activeChatIndex = _chatHistory.length - 1;
    }

    // Salva la cronologia delle chat nel Local Storage
    final String jsonString = jsonEncode({'chatHistory': _chatHistory});
    html.window.localStorage['chatHistory'] = jsonString;

    print('Chat salvata correttamente nel Local Storage.');

    // Salva o aggiorna la chat nel database
    final dbName = "${widget.user.username}-database"; // Nome del database basato sull'utente
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
        (chat) => chat['id'] == chatId, // Cerca in base all'ID della chat
        orElse: () => <String, dynamic>{}, // Ritorna una mappa vuota se non trovata
      );

      if (existingChat.isNotEmpty && existingChat.containsKey('_id')) {
        // La chat esiste, aggiorna i campi nel database
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
        // La chat non esiste nel database, aggiungi una nuova
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
        // Se la collection non esiste, creala e aggiungi la chat
        print('Collection "chats" non esistente. Creazione in corso...');
        await _databaseService.createCollection(dbName, collectionName, widget.token.accessToken);

        // Aggiungi la nuova chat alla collection appena creata
        await _databaseService.addDataToCollection(
          dbName,
          collectionName,
          currentChat,
          widget.token.accessToken,
        );

        print('Collection "chats" creata e chat aggiunta al database.');
      } else {
        throw e; // Propaga altri errori
      }
    }
  } catch (e) {
    print('Errore durante il salvataggio della conversazione: $e');
  }
}



Future<void> _writeToFile(String jsonString) async {
  // Simulazione di scrittura (poiché non è possibile scrivere direttamente negli assets)
  print("JSON aggiornato: $jsonString");
  // In un'app reale, userebbe la memorizzazione locale o un backend per memorizzare i dati.
}


// Funzione per aprire il dialog di selezione del contesto e modello
void _showContextDialog() async {
  // Aggiorna i contesti dal backend prima di aprire il dialog
  await _loadAvailableContexts(); // Carica di nuovo i contesti disponibili dal database

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text('Seleziona Contesto e Modello'),
            backgroundColor: Colors.white,
            elevation: 6, // Intensità dell'ombra
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
            ),
            content: SingleChildScrollView( // Rende l'intero contenuto scrollabile
              child: Container(
                width: double.maxFinite, // Permette alla finestra di dialogo di adattarsi alla larghezza disponibile
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Imposta le dimensioni minime in base al contenuto
                  children: [
                    // Lista scrollabile con schede distribuite verticalmente
                    Container(
                      height: 300, // Altezza massima per la sezione scrollabile
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableContexts.length,
                        itemBuilder: (context, index) {
                          final contextMetadata = _availableContexts[index];
                          final isSelected = _selectedContext == contextMetadata.path;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedContext = contextMetadata.path; // Aggiorna immediatamente il contesto selezionato
                                set_context(_selectedContext, _selectedModel); // Passa il contesto e il modello selezionati
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4.0), // Spaziatura tra le schede
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Color.fromARGB(255, 85, 107, 37) // Colore del bordo se selezionato
                                      : Colors.transparent,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(4.0), // Bordi arrotondati
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 2.5,
                                    spreadRadius: 1.0,
                                  ),
                                ],
                              ),
                              width: 300, // Larghezza fissa per ogni scheda
                              child: Text(
                                contextMetadata.path,
                                style: TextStyle(
                                  color: isSelected
                                      ? Color.fromARGB(255, 85, 107, 37) // Colore del testo se selezionato
                                      : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16.0), // Spaziatura tra la lista e il resto del contenuto
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                child: Text('Annulla'),
                onPressed: () {
                  Navigator.of(context).pop(); // Chiudi il dialog senza salvare
                },
              ),
              ElevatedButton(
                child: Text('Conferma'),
                onPressed: () {
                  set_context(_selectedContext, _selectedModel); // Salva il contesto e il modello selezionato
                  Navigator.of(context).pop(); // Chiudi il dialog
                },
              ),
            ],
          );
        },
      );
    },
  );
}


// Funzione per creare il selettore di modelli
Widget _buildModelSelector(StateSetter setState) {
  final List<String> models = ['gpt-4o', 'gpt-4o-mini', 'qwen2-7b'];

  return Wrap(
    spacing: 10.0,
    children: models.map((model) {
      final bool isSelected = _selectedModel == model;
      return ChoiceChip(
        label: Text(model),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedModel = model;  // Aggiorna il modello selezionato
            // Passa anche il contesto selezionato ogni volta che cambia il modello
            set_context(_selectedContext, _selectedModel);
          });
        },
        selectedColor: Color.fromARGB(255, 85, 107, 37),  // Colore selezionato
        backgroundColor: Colors.grey[200],  // Colore di default
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,  // Cambia il colore del testo quando selezionato
        ),
      );
    }).toList(),
  );
}

// Funzione per creare la lista di contesti visualizzati come schede
// Funzione per creare la lista di contesti visualizzati come schede
Widget _buildContextList(Function(String) onContextSelected) {
  final double cardHeight = 80.0; // Altezza fissa per ogni scheda

  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      return Align(
  alignment: Alignment.topLeft, // Allinea il contenuto a sinistra
  child: Wrap(
        spacing: 10.0, // Spaziatura orizzontale tra le schede
        runSpacing: 10.0, // Spaziatura verticale tra le righe
        children: _availableContexts.map((contextMetadata) {
          final isSelected = _selectedContext == contextMetadata.path;

          return GestureDetector(
            onTap: () {
              onContextSelected(contextMetadata.path); // Seleziona il contesto
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Color.fromARGB(255, 85, 107, 37)
                      : Colors.transparent,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(4.0),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: Text(
                contextMetadata.path, // Testo completo del contesto
                style: TextStyle(
                  color: isSelected
                      ? Color.fromARGB(255, 85, 107, 37)
                      : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      ));
    },
  );
}


// Funzione per mostrare il dialog con il nome completo
void _showFullNameDialog(BuildContext context, String fullName) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Nome Completo'),
        content: Text(fullName), // Mostra il nome completo
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Chiudi il dialog
            },
            child: Text('Chiudi'),
          ),
        ],
      );
    },
  );
}


void set_context(String context, String model) async {
  try {
    // Chiama la funzione dell'SDK per configurare e caricare la chain con il contesto selezionato
    final response = await _contextApiSdk.configureAndLoadChain(context, model);
    print('Chain configurata e caricata con successo per il contesto: $context');
    print('Risultato della configurazione: $response');

    setState(() {
      _selectedContext = context;  // Aggiorna la variabile con il contesto selezionato
    });
  } catch (e) {
    print('Errore nella configurazione e caricamento della chain: $e');
  }
}


  // Sezione impostazioni TTS e customizzazione grafica nella barra laterale
  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,  // Imposta la larghezza per occupare tutto lo spazio disponibile
        decoration: BoxDecoration(
          color: Colors.white, // Colore di sfondo bianco
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6.0,
              spreadRadius: 1.0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Impostazioni Text-to-Speech", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.0),
            // Dropdown per la lingua
            Text("Seleziona lingua"),
            DropdownButton<String>(
              value: _selectedLanguage,
              items: [
                DropdownMenuItem(
                  value: "en-US",
                  child: Text("English (US)"),
                ),
                DropdownMenuItem(
                  value: "it-IT",
                  child: Text("Italian"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Slider per la velocità di lettura
            Text("Velocità lettura: ${_speechRate.toStringAsFixed(2)}"),
            Slider(
              value: _speechRate,
              min: 0.1,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _speechRate = value;
                });
              },
            ),
            // Slider per il pitch
            Text("Intonazione (Pitch): ${_pitch.toStringAsFixed(1)}"),
            Slider(
              value: _pitch,
              min: 0.5,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _pitch = value;
                });
              },
            ),
            // Slider per il volume
            Text("Volume: ${_volume.toStringAsFixed(2)}"),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _volume = value;
                });
              },
            ),
            // Slider per la pausa tra le frasi
            Text("Pausa tra frasi: ${_pauseBetweenSentences.toStringAsFixed(1)} sec"),
            Slider(
              value: _pauseBetweenSentences,
              min: 0.0,
              max: 2.0,
              onChanged: (value) {
                setState(() {
                  _pauseBetweenSentences = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            Text("Personalizzazione grafica", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            // Colore del messaggio dell'utente
            Text("Colore messaggio utente"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _userMessageColor),
                onPressed: () {
                  _showColorPickerDialog(_userMessageColor, (color) {
                    _userMessageColor = color;
                  });
                },
              ),
            ),
            // Opacità messaggio utente
            Slider(
              value: _userMessageOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _userMessageOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore del messaggio dell'assistente
            Text("Colore messaggio assistente"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _assistantMessageColor),
                onPressed: () {
                  _showColorPickerDialog(_assistantMessageColor, (color) {
                    _assistantMessageColor = color;
                  });
                },
              ),
            ),
            // Opacità messaggio assistente
            Slider(
              value: _assistantMessageOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _assistantMessageOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore dello sfondo della chat
            Text("Colore sfondo chat"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _chatBackgroundColor),
                onPressed: () {
                  _showColorPickerDialog(_chatBackgroundColor, (color) {
                    _chatBackgroundColor = color;
                  });
                },
              ),
            ),
            // Opacità sfondo chat
            Slider(
              value: _chatBackgroundOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _chatBackgroundOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore avatar
            Text("Colore avatar"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _avatarBackgroundColor),
                onPressed: () {
                  _showColorPickerDialog(_avatarBackgroundColor, (color) {
                    _avatarBackgroundColor = color;
                  });
                },
              ),
            ),
            // Opacità avatar
            Slider(
              value: _avatarBackgroundOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _avatarBackgroundOpacity = value;
                });
              },
            ),
            SizedBox(height: 16.0),
            // Colore icona avatar
            Text("Colore icona avatar"),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.color_lens, color: _avatarIconColor),
                onPressed: () {
                  _showColorPickerDialog(_avatarIconColor, (color) {
                    _avatarIconColor = color;
                  });
                },
              ),
            ),
            // Opacità icona avatar
            Slider(
              value: _avatarIconOpacity,
              min: 0.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  _avatarIconOpacity = value;
                });
              },
            ),
          ],
        ),
      ),
    );
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

  // Funzione per fermare il Text-to-Speech
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // Funzione per copiare il messaggio negli appunti
  void _copyToClipboard(String message) {
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Messaggio copiato negli appunti')),
    );
  }

Future<void> _sendMessageToAPI(String input) async {
  if (_nlpApiUrl == null) await _loadConfig();  // Assicurati di caricare l'URL se non è già stato caricato

final url = "$_nlpApiUrl/chains/stream_chain";  // Usa l'URL caricato dal JSON
  final chainId = "${_selectedContext}_qa_chain";

  final payload = jsonEncode({
    "chain_id": chainId,
    "query": {
      "input": input,
      "chat_history": messages,
    },
    "inference_kwargs": {}
  });

  try {
    final response = await js_util.promiseToFuture(js_util.callMethod(
      html.window,
      'fetch',
      [
        url,
        js_util.jsify({
          'method': 'POST',
          'headers': {'Content-Type': 'application/json'},
          'body': payload,
        })
      ],
    ));

    final ok = js_util.getProperty(response, 'ok') as bool;
    if (!ok) {
      throw Exception('Network response was not ok');
    }

    final body = js_util.getProperty(response, 'body');
    if (body == null) {
      throw Exception('Response body is null');
    }

    final reader = js_util.callMethod(body, 'getReader', []);

    String nonDecodedChunk = '';
    fullResponse = '';

    void readChunk() {
      js_util
          .promiseToFuture(js_util.callMethod(reader, 'read', []))
          .then((result) {
        final done = js_util.getProperty(result, 'done') as bool;
        if (!done) {
          final value = js_util.getProperty(result, 'value');

          final bytes = _convertJSArrayBufferToDartUint8List(value);
          final chunkString = utf8.decode(bytes);
          nonDecodedChunk += chunkString;

          try {
            if (nonDecodedChunk.contains('"answer":')) {
              final splitChunks = nonDecodedChunk.split('\n');
              for (var line in splitChunks) {
                if (line.contains('"answer":')) {
                  line = '{' + line.trim() + '}';
                  final decodedChunk = jsonDecode(line);
                  final answerChunk = decodedChunk['answer'] as String;

                  setState(() {
                    fullResponse += answerChunk;
                    messages[messages.length - 1]['content'] =
                        fullResponse + "▌";
                  });
                }
              }
              nonDecodedChunk = ''; // Pulisce il buffer
            }
          } catch (e) {
            print("Errore durante il parsing del chunk: $e");
          }

          readChunk(); // Legge il chunk successivo
        } else {
          // Fine lettura: rimuove il cursore "▌" e finalizza la risposta
          setState(() {
            messages[messages.length - 1]['content'] = fullResponse;
          });

          // Salva la conversazione solo dopo che la risposta è stata completata
          _saveConversation(messages);
        }
      }).catchError((error) {
        print('Errore durante la lettura del chunk: $error');
        setState(() {
          messages[messages.length - 1]['content'] = 'Errore: $error';
        });
      });
    }

    readChunk();
  } catch (e) {
    print('Errore durante il fetch dei dati: $e');
    setState(() {
      messages[messages.length - 1]['content'] = 'Errore: $e';
    });
  }
}


  Uint8List _convertJSArrayBufferToDartUint8List(dynamic jsArrayBuffer) {
    final buffer = js_util.getProperty(jsArrayBuffer, 'buffer') as ByteBuffer;
    final byteOffset = js_util.getProperty(jsArrayBuffer, 'byteOffset') as int;
    final byteLength = js_util.getProperty(jsArrayBuffer, 'byteLength') as int;
    return Uint8List.view(buffer, byteOffset, byteLength);
  }
}
