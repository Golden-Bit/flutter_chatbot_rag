import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_app/codeblock_md_builder.dart';
import 'package:flutter_app/user_manager/auth_pages.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart'; // Aggiungi il pacchetto TTS
import 'package:flutter/services.dart'; // Per il pulsante di copia
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Per il color picker
import 'context_page.dart'; // Importa altri pacchetti necessari
import 'package:flutter/services.dart'
    show rootBundle; // Import necessario per caricare file JSON
import 'dart:convert'; // Per il parsing JSON
import 'context_api_sdk.dart'; // Importa lo script SDK
import 'package:flutter_app/user_manager/user_model.dart';
import 'databases_manager/database_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Importa il pacchetto UUID (assicurati di averlo aggiunto a pubspec.yaml)
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart'; // Per gestire il tap sui link
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> messages = [];

  final Uuid uuid = Uuid(); // Istanza di UUID (può essere globale nel file)

  final TextEditingController _controller = TextEditingController();
  String fullResponse = "";
  bool showKnowledgeBase = false;

  //String _selectedContext = "default";  // Variabile per il contesto selezionato
  List<String> _selectedContexts =
      []; // Variabile per memorizzare i contesti selezionati
  final ContextApiSdk _contextApiSdk =
      ContextApiSdk(); // Istanza dell'SDK per le API dei contesti
  List<ContextMetadata> _availableContexts =
      []; // Lista dei contesti caricati dal backend

  // Variabili per gestire la colonna espandibile e ridimensionabile
  bool isExpanded = false;
  double sidebarWidth = 0.0; // Impostata a 0 di default (collassata)
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

  String _selectedModel =
      "gpt-4o"; // Variabile per il modello selezionato, di default GPT-4O
  int? _buttonHoveredIndex; // Variabile per i pulsanti principali
  int? hoveredIndex; // Variabile per le chat salvate

  int? _activeChatIndex; // Chat attiva (null se si sta creando una nuova chat)
  final DatabaseService _databaseService = DatabaseService();
// Aggiungi questa variabile per contenere la chat history simulata
  List<dynamic> _chatHistory = [];
  String? _nlpApiUrl;
  int? _activeButtonIndex;
  Future<void> _loadConfig() async {
    try {
      //final String response = await rootBundle.loadString('assets/config.json');
      //final data = jsonDecode(response);
      final data = {
        "backend_api": "https://teatek-llm.theia-innovation.com/user-backend",
        "nlp_api": "https://teatek-llm.theia-innovation.com/llm-core",
        //"nlp_api": "http://35.195.200.211:8100",
        "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
        //"chatbot_nlp_api": "http://127.0.0.1:8100"
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
            widget.token.accessToken);

        // Imposta lo stato locale per indicare che non ci sono chat
        setState(() {
          _chatHistory = [];
        });

        print(
            "Collection 'chats' created successfully. No previous chat history found.");
      } else {
        // Log degli altri errori
        print("Error loading chat history from database: $e");
      }
    }
  }

  late Future<void> _chatHistoryFuture;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _chatHistoryFuture =
        _loadChatHistory(); // Carica la cronologia solo una volta
    _loadAvailableContexts();
  
    // Aggiungi questo per aggiornare la UI quando cambia il testo
  _controller.addListener(() {
    setState(() {});
  });
  }

  /*@override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();  // Inizializza FlutterTTS
    _loadAvailableContexts();  // Carica i contesti esistenti al caricamento della pagina
      _loadChatHistory();  // Carica la chat history simulata
  }*/

  // Funzione per caricare i contesti dal backend
  Future<void> _loadAvailableContexts() async {
    try {
      List<ContextMetadata> contexts = await _contextApiSdk.listContexts(
          widget.user.username, widget.token.accessToken);
      setState(() {
        _availableContexts = contexts; // Salva i contesti caricati nello stato
      });
    } catch (e) {
      print('Errore nel caricamento dei contesti: $e');
    }
  }

  // Funzione per aprire il dialog con il ColorPicker
  void _showColorPickerDialog(
      Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona il colore'),
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

  Widget _buildMessageContent_(String content, bool isUser) {
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
              color: Colors
                  .transparent, // Rende invisibile per non coprire Markdown
            ),
            enableInteractiveSelection: true, // Abilita la selezione
          ),
        ),
      ],
    );
  }

// Funzione che restituisce il widget per il messaggio Markdown, con formattazione avanzata
  Widget _buildMessageContent(
    BuildContext context,
    String content,
    bool isUser, {
    Color? userMessageColor,
    double? userMessageOpacity,
    Color? assistantMessageColor,
    double? assistantMessageOpacity,
  }) {
    // Definisce il colore di sfondo in base al ruolo del mittente
    final bgColor = isUser
        ? (userMessageColor ?? Colors.blue[100])!
            .withOpacity(userMessageOpacity ?? 1.0)
        : (assistantMessageColor ?? Colors.grey[200])!
            .withOpacity(assistantMessageOpacity ?? 1.0);

    //final bgColor = Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: MarkdownBody(
        data: content,
        // Inserisci il builder personalizzato per i blocchi di codice
        builders: {
          'code': CodeBlockBuilder(context),
        },
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16.0, color: Colors.black87),
          h1: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          h2: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
          h3: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
          // Lo stile 'code' qui è usato per il rendering base (verrà sovrascritto dal nostro builder)
          code: TextStyle(
            fontFamily: 'Courier',
            backgroundColor: Colors.grey[300],
            fontSize: 14.0,
          ),
          blockquote: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.blueGrey,
            fontSize: 14.0,
          ),
        ),
        // Gestione opzionale del tap sui link
        onTapLink: (text, href, title) async {
          if (href != null && await canLaunch(href)) {
            await launch(href);
          }
        },
      ),
    );
  }

  void _showMessageInfoDialog(Map<String, dynamic> message) {
    final String role = message['role'] ?? 'unknown'; // Ruolo del messaggio
    final String createdAt = message['createdAt'] ?? 'N/A'; // Data di creazione
    final int contentLength =
        (message['content'] ?? '').length; // Lunghezza contenuto

    // Estrai la configurazione dell'agente dal messaggio, se presente
    final Map<String, dynamic>? agentConfig = message['agentConfig'];

    // Informazioni di configurazione dell'agente
    final String? model = agentConfig?['model']; // Modello selezionato
    final List<String>? contexts =
        List<String>.from(agentConfig?['contexts'] ?? []);
    final String? chainId = agentConfig?['chain_id'];

    // Altri dettagli (aggiustabili secondo il caso)
    final int tokensReceived =
        role == 'assistant' ? 0 : 0; // Modifica se disponi di dati token reali
    final int tokensGenerated =
        role == 'assistant' ? 0 : 0; // Modifica se disponi di dati token reali
    final double responseCost =
        role == 'assistant' ? 0.0 : 0.0; // Modifica se disponi di dati reali

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Dettagli del messaggio"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dettagli di base del messaggio
                Text(
                  "Ruolo: ${role == 'user' ? 'Utente' : 'Assistente'}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Data: $createdAt"),
                Text("Lunghezza in caratteri: $contentLength"),
                Text(
                    "Lunghezza in token: 0"), // Sostituisci se disponi di dati token

                // Divider per separare i dettagli base dai dettagli di configurazione
                if (role == 'assistant' || agentConfig != null) ...[
                  const Divider(),
                  Text("Dettagli della configurazione dell'agente:",
                      style: TextStyle(fontWeight: FontWeight.bold)),

                  // Mostra il modello selezionato
                  if (model != null) Text("Modello: $model"),
                  const SizedBox(height: 8),

                  // Mostra i contesti utilizzati
                  if (contexts != null && contexts.isNotEmpty) ...[
                    Text("Contesti selezionati:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...contexts.map((context) => Text("- $context")).toList(),
                  ],

                  const SizedBox(height: 8),

                  // Mostra l'ID della chain
                  if (chainId != null) Text("Chain ID: $chainId"),

                  // Divider aggiuntivo per eventuali altri dettagli
                  const Divider(),
                  Text("Metriche aggiuntive:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Token ricevuti: $tokensReceived"),
                  Text("Token generati: $tokensGenerated"),
                  Text("Costo risposta: \$${responseCost.toStringAsFixed(4)}"),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Chiudi il dialog
              },
              child: Text("Chiudi"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      /*appBar: AppBar(
  shadowColor: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
  elevation: 4.0, // Aggiungi ombreggiatura (default è 4.0, aumenta se necessario)
  title: Text(
    'Teatek Agent',
  style: TextStyle(color: Colors.black), // Cambia il testo in nero
  ),
  backgroundColor: Colors.white, // Bianco, // Imposta il colore personalizzato
  leading: IconButton(
    icon: Icon(Icons.menu, color: Colors.black),
    onPressed: () {
      setState(() {
        isExpanded = !isExpanded; // Alterna collasso ed espansione
        if (isExpanded) {
          sidebarWidth = MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width // Su schermi piccoli, occupa l'intera larghezza
              : 300.0; // Imposta la larghezza normale su schermi grandi
        } else {
          sidebarWidth = 0.0; // Collassa la barra laterale
        }
      });
    },
  ),
  actions: [
    PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundColor: Colors.black, // Sfondo bianco per l'avatar
        child: Text(
          widget.user.email.substring(0, 2).toUpperCase(), // Prime due lettere della mail in maiuscolo
          style: TextStyle(color: Colors.white), // Testo nero
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'Profilo':
            // Naviga alla pagina del profilo
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AccountSettingsPage(
                  user: widget.user,
                  token: widget.token,
                ),
              ),
            );
            break;
          case 'Utilizzo':
            // Naviga alla pagina di utilizzo
            // TODO: Implementa la pagina di utilizzo
            print('Naviga alla pagina di utilizzo');
            break;
          case 'Impostazioni':
            // Apri il pannello delle impostazioni
            setState(() {
              showSettings = true; // Mostra la sezione delle impostazioni
              showKnowledgeBase = false; // Nascondi il resto
            });
            break;
          case 'Logout':
            // Effettua il logout
            _logout(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem(
            value: 'Profilo',
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.black),
                SizedBox(width: 8.0),
                Text('Profilo'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'Utilizzo',
            child: Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.black),
                SizedBox(width: 8.0),
                Text('Utilizzo'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'Impostazioni',
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.black),
                SizedBox(width: 8.0),
                Text('Impostazioni'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'Logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 8.0),
                Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ];
      },
    ),
  ],
),*/
      body: Row(
        children: [
          // Barra laterale con possibilità di ridimensionamento
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (isExpanded) {
                setState(() {
                  sidebarWidth +=
                      details.delta.dx; // Ridimensiona la barra laterale
                  if (sidebarWidth < 200)
                    sidebarWidth = 200; // Larghezza minima
                  if (sidebarWidth > 900)
                    sidebarWidth = 900; // Larghezza massima
                });
              }
            },
            child: AnimatedContainer(
              margin: EdgeInsets.fromLTRB(isExpanded ? 16.0 : 0.0, 0, 0, 0),
              duration: Duration(
                  milliseconds:
                      300), // Animazione per l'espansione e il collasso
              width:
                  sidebarWidth, // Usa la larghezza calcolata (può essere 0 se collassato)
              decoration: BoxDecoration(
                color:
                    Colors.white, // Colonna laterale con colore personalizzato
                /*boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5), // Colore dell'ombra con trasparenza
        blurRadius: 8.0, // Sfocatura dell'ombra
        offset: Offset(2, 0), // Posizione dell'ombra (x, y)
      ),
    ],*/
              ),
              child: MediaQuery.of(context).size.width < 600 || sidebarWidth > 0
                  ? Column(
                      children: [
                        // Linea di separazione bianca tra AppBar e sidebar
                        Container(
                          width: double.infinity,
                          height: 2.0, // Altezza della linea
                          color: Colors.white, // Colore bianco per la linea
                        ),
                        // Padding verticale tra l'AppBar e le voci del menu
                        SizedBox(
                            height:
                                8.0), // Spazio verticale tra la linea e le voci del menu

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          color: Colors
                              .white, // oppure usa lo stesso colore del menu laterale
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Titolo a sinistra
                              Image.network(
                                'https://static.wixstatic.com/media/63b1fb_3e1530fd4a2e479983c1b3cd9f379290~mv2.png',
                                height:
                                    42, // Imposta l'altezza desiderata per il logo
                                fit: BoxFit.contain,
                                isAntiAlias: true,
                              ),
                              // Icona di espansione/contrazione a destra
                              IconButton(
                                icon: Icon(isExpanded
                                    ? Icons.close
                                    : Icons
                                        .menu), // Usa l'icona che preferisci (qui ad esempio menu/close)
                                onPressed: () {
                                  setState(() {
                                    isExpanded = !isExpanded;
                                    if (isExpanded) {
                                      sidebarWidth = MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600
                                          ? MediaQuery.of(context).size.width
                                          : 300.0;
                                    } else {
                                      sidebarWidth = 0.0;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

// Sezione fissa con le voci principali

// Pulsante "Nuova Chat"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  3; // Identifica "Nuova Chat" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              _startNewChat(); // Avvia una nuova chat
                              setState(() {
                                _activeButtonIndex =
                                    3; // Imposta "Nuova Chat" come attivo
                                showKnowledgeBase =
                                    false; // Deseleziona "Basi di conoscenza"
                                showSettings =
                                    false; // Deseleziona "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 3 ||
                                        _activeButtonIndex == 3
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Nuova Chat',
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

// Pulsante "Conversazione"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  0; // Identifica "Conversazione" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeButtonIndex =
                                    0; // Imposta "Conversazione" come attivo
                                showKnowledgeBase =
                                    false; // Deseleziona "Basi di conoscenza"
                                showSettings =
                                    false; // Deseleziona "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              _loadChatHistory(); // Carica la cronologia delle chat
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 0 ||
                                        _activeButtonIndex == 0
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline_outlined,
                                      color: Colors.black),
                                  /*Image.network(
                                      'https://static.wixstatic.com/media/63b1fb_4dbfd84d1b554c9bb8879550f47b97d8~mv2.png',
                                      width: 24,
                                      height: 24),*/
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Conversazione',
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

// Pulsante "Basi di conoscenza"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  1; // Identifica "Basi di conoscenza" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeButtonIndex =
                                    1; // Imposta "Basi di conoscenza" come attivo
                                showKnowledgeBase =
                                    true; // Mostra "Basi di conoscenza"
                                showSettings =
                                    false; // Deseleziona "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 1 ||
                                        _activeButtonIndex == 1
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.book_outlined,
                                      color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Knowledge Box',
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

// Pulsante "Impostazioni"
                        MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  2; // Identifica "Impostazioni" come in hover
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _buttonHoveredIndex =
                                  null; // Rimuove lo stato di hover
                            });
                          },
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeButtonIndex =
                                    2; // Imposta "Impostazioni" come attivo
                                showKnowledgeBase =
                                    false; // Deseleziona "Basi di conoscenza"
                                showSettings = true; // Mostra "Impostazioni"
                                _activeChatIndex =
                                    null; // Deseleziona qualsiasi chat
                              });
                              if (MediaQuery.of(context).size.width < 600) {
                                setState(() {
                                  sidebarWidth =
                                      0.0; // Collassa la barra laterale
                                });
                              }
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.all(4.0), // Margini laterali
                              decoration: BoxDecoration(
                                color: _buttonHoveredIndex == 2 ||
                                        _activeButtonIndex == 2
                                    ? const Color.fromARGB(255, 224, 224,
                                        224) // Colore scuro durante hover o selezione
                                    : Colors
                                        .transparent, // Sfondo trasparente quando non è attivo
                                borderRadius: BorderRadius.circular(
                                    4.0), // Arrotonda gli angoli
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.settings_outlined,
                                      color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Impostazioni',
                                    style: TextStyle(
                                        color: Colors
                                            .black), // Cambia colore in nero
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

// Lista delle chat salvate
                        Expanded(
                          child: FutureBuilder(
                            future:
                                _chatHistoryFuture, // Assicurati che le chat siano caricate
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              }

                              // Raggruppa le chat in base alla data di aggiornamento
                              final groupedChats =
                                  _groupChatsByDate(_chatHistory);

                              // Filtra le sezioni per rimuovere quelle vuote
                              final nonEmptySections = groupedChats.entries
                                  .where((entry) => entry.value.isNotEmpty)
                                  .toList();

                              if (nonEmptySections.isEmpty) {
                                return Center(
                                  child: Text(
                                    "Nessuna chat disponibile.",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                );
                              }

                              return ShaderMask(
  shaderCallback: (Rect bounds) {
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent, // Mantiene opaco
        Colors.transparent, // Ancora opaco
        Colors.white, // A partire da qui diventa trasparente
      ],
      stops: [0.0, 0.75, 1.0],
    ).createShader(bounds);
  },
  // Con dstOut, le parti del gradiente che sono bianche (o trasparenti) "tagliano" via il contenuto
  blendMode: BlendMode.dstOut,
  child: ListView.builder(
      padding: const EdgeInsets.only(bottom: 32.0), // Spazio extra in fondo
                                itemCount: nonEmptySections
                                    .length, // Numero delle sezioni non vuote
                                itemBuilder: (context, sectionIndex) {
                                  final section =
                                      nonEmptySections[sectionIndex];
                                  final sectionTitle = section
                                      .key; // Ottieni il titolo della sezione
                                  final chatsInSection = section
                                      .value; // Ottieni le chat di quella sezione

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Intestazione della sezione
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4.0),
                                        child: Text(
                                          sectionTitle, // Titolo della sezione
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      // Lista delle chat di questa sezione
                                      ...chatsInSection.map((chat) {
                                        final chatName = chat['name'] ??
                                            'Chat senza nome'; // Nome della chat
                                        final chatId =
                                            chat['id']; // ID della chat
                                        final isActive = _activeChatIndex ==
                                            _chatHistory
                                                .indexOf(chat); // Chat attiva
                                        final isHovered = hoveredIndex ==
                                            _chatHistory
                                                .indexOf(chat); // Chat in hover

                                        return MouseRegion(
                                          onEnter: (_) {
                                            setState(() {
                                              hoveredIndex =
                                                  _chatHistory.indexOf(
                                                      chat); // Aggiorna hover
                                            });
                                          },
                                          onExit: (_) {
                                            setState(() {
                                              hoveredIndex =
                                                  null; // Rimuovi hover
                                            });
                                          },
                                          child: GestureDetector(
                                            onTap: () {
                                              _loadMessagesForChat(
                                                  chatId); // Carica messaggi della chat
                                              setState(() {
                                                _activeChatIndex =
                                                    _chatHistory.indexOf(
                                                        chat); // Imposta la chat attiva
                                                _activeButtonIndex =
                                                    null; // Deseleziona i pulsanti principali
                                                showKnowledgeBase =
                                                    false; // Deseleziona "Basi di conoscenza"
                                                showSettings =
                                                    false; // Deseleziona "Impostazioni"
                                              });
                                              if (MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  600) {
                                                sidebarWidth =
                                                    0.0; // Collassa barra laterale
                                              }
                                            },
                                            child: Container(
                                              height: 40,
                                              margin: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 4,
                                                  vertical:
                                                      2), // Margini laterali
                                              decoration: BoxDecoration(
                                                color: isHovered || isActive
                                                    ? const Color.fromARGB(
                                                        255,
                                                        224,
                                                        224,
                                                        224) // Colore scuro per hover o selezione
                                                    : Colors
                                                        .transparent, // Sfondo trasparente quando non attivo
                                                borderRadius: BorderRadius.circular(
                                                    4.0), // Arrotonda gli angoli
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4.0,
                                                      horizontal: 16.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      chatName, // Mostra il nome della chat
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight: isActive
                                                            ? FontWeight
                                                                .bold // Evidenzia testo se attivo
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    icon: Icon(
                                                      Icons.more_horiz,
                                                      color: (isHovered ||
                                                              isActive)
                                                          ? Colors
                                                              .black // Colore bianco per l'icona in hover o selezione
                                                          : Colors
                                                              .transparent, // Nascondi icona se non attivo o in hover
                                                    ),
                                                    padding: EdgeInsets.only(
                                                        right:
                                                            4.0), // Riduci margine destro
                                                    onSelected: (String value) {
                                                      if (value == 'delete') {
                                                        _deleteChat(_chatHistory
                                                            .indexOf(
                                                                chat)); // Elimina la chat
                                                      } else if (value ==
                                                          'edit') {
                                                        _showEditChatDialog(
                                                            _chatHistory.indexOf(
                                                                chat)); // Modifica la chat
                                                      }
                                                    },
                                                    itemBuilder:
                                                        (BuildContext context) {
                                                      return [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child:
                                                              Text('Modifica'),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child:
                                                              Text('Elimina'),
                                                        ),
                                                      ];
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      const SizedBox(
                                          height:
                                              24), // Spaziatura tra le sezioni
                                    ],
                                  );
                                },
                              ));
                            },
                          ),
                        ),

// Mantieni il pulsante di logout in basso, senza Spacer
/*Align(
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
),*/

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
              clipBehavior: Clip.hardEdge,
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 1.0),
                borderRadius: BorderRadius.circular(16.0),
                gradient: const RadialGradient(
                  center: Alignment(0.5, 0.25),
                  radius: 1.2, // aumenta o diminuisci per rendere più o meno ampio il cerchio
                  colors: [
                    Color.fromARGB(255, 199, 230, 255), // Azzurro pieno al centro
                    Colors.white, // Bianco verso i bordi
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
              child: Column(
                children: [
                  // Nuova top bar per info e pulsante utente
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        // Lato sinistro: un Expanded per allineare a sinistra
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (sidebarWidth == 0.0) ...[
                                IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.black),
                                  onPressed: () {
                                    setState(() {
                                      isExpanded = true;
                                      sidebarWidth = MediaQuery.of(context).size.width < 600
                                          ? MediaQuery.of(context).size.width
                                          : 300.0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Image.network(
                                  'https://static.wixstatic.com/media/63b1fb_3e1530fd4a2e479983c1b3cd9f379290~mv2.png',
                                  height: 42,
                                  fit: BoxFit.contain,
                                  isAntiAlias: true,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Lato destro: azioni utente
                        PopupMenuButton<String>(
                          icon: CircleAvatar(
                            backgroundColor: Colors.black,
                            child: Text(
                              widget.user.email.substring(0, 2).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'Profilo':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AccountSettingsPage(
                                      user: widget.user,
                                      token: widget.token,
                                    ),
                                  ),
                                );
                                break;
                              case 'Utilizzo':
                                print('Naviga alla pagina di utilizzo');
                                break;
                              case 'Impostazioni':
                                setState(() {
                                  showSettings = true;
                                  showKnowledgeBase = false;
                                });
                                break;
                              case 'Logout':
                                _logout(context);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem(
                                value: 'Profilo',
                                child: Row(
                                  children: const [
                                    Icon(Icons.person, color: Colors.black),
                                    SizedBox(width: 8.0),
                                    Text('Profilo'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Utilizzo',
                                child: Row(
                                  children: const [
                                    Icon(Icons.bar_chart, color: Colors.black),
                                    SizedBox(width: 8.0),
                                    Text('Utilizzo'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Impostazioni',
                                child: Row(
                                  children: const [
                                    Icon(Icons.settings, color: Colors.black),
                                    SizedBox(width: 8.0),
                                    Text('Impostazioni'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Logout',
                                child: Row(
                                  children: const [
                                    Icon(Icons.logout, color: Colors.red),
                                    SizedBox(width: 8.0),
                                    Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    color: Colors.grey,
                    height: 0,
                  ),

                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12.0),
                      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                      color: Colors.transparent,
                      child: showKnowledgeBase
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DashboardScreen(
                                      username: widget.user.username,
                                      token: widget.token.accessToken,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : showSettings
                              ? Container(
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: AccountSettingsPage(
                                    user: widget.user,
                                    token: widget.token,
                                  ),
                                )
                              : Column(
                                  children: [
                                    // Sezione principale con i messaggi
                                    Expanded(
                                      // NOTA: applichiamo lo ShaderMask attorno alla ListView
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double rightContainerWidth = constraints.maxWidth;
                                          // se vuoi max 800, ad es.
                                          final double containerWidth = (rightContainerWidth > 800)
                                              ? 800.0
                                              : rightContainerWidth;

return ShaderMask(
  shaderCallback: (Rect bounds) {
    // Invece di passare [Colors.white, Colors.white, Colors.transparent],
    // inverti i colori usando nero (keeps area) -> bianco (removes area).
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        // In alto nero = mantieni i messaggi
        Colors.white,
        Colors.transparent,
        Colors.transparent,
        // In basso bianco = rimuovi gradualmente i messaggi
        Colors.white,
      ],
      stops: [0.0,0.03,0.97,1.0],
    ).createShader(bounds);
  },
  blendMode: BlendMode.dstOut,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: containerWidth,
                                              ),
                                              child: ListView.builder(
                                                itemCount: messages.length,
                                                itemBuilder: (context, index) {
                                                  final message = messages[index];
                                                  final isUser = message['role'] == 'user';
                                                  final DateTime parsedTime =
                                                      DateTime.tryParse(message['createdAt'] ?? '') ??
                                                          DateTime.now();
                                                  final String formattedTime =
                                                      DateFormat('h:mm a').format(parsedTime);

                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        ConstrainedBox(
                                                          constraints: BoxConstraints(
                                                            maxWidth: containerWidth,
                                                            minWidth: 200,
                                                          ),
                                                          child: Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.all(12.0),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(16.0),
                                                              boxShadow: const [
                                                                BoxShadow(
                                                                  color: Colors.black12,
                                                                  blurRadius: 4.0,
                                                                  offset: Offset(2, 2),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                // RIGA 1: Avatar, nome e orario
                                                                Row(
                                                                  children: [
                                                                    if (!isUser)
                                                                      CircleAvatar(
                                                                        backgroundColor: Colors.transparent,
                                                                        child: Image.network(
                                                                          'https://static.wixstatic.com/media/63b1fb_396f7f30ead14addb9ef5709847b1c17~mv2.png',
                                                                          height: 42,
                                                                          fit: BoxFit.contain,
                                                                          isAntiAlias: true,
                                                                        ),
                                                                      )
                                                                    else
                                                                      CircleAvatar(
                                                                        backgroundColor: _avatarBackgroundColor
                                                                            .withOpacity(_avatarBackgroundOpacity),
                                                                        child: Icon(
                                                                          Icons.person,
                                                                          color: _avatarIconColor
                                                                              .withOpacity(_avatarIconOpacity),
                                                                        ),
                                                                      ),
                                                                    const SizedBox(width: 8.0),
                                                                    Text(
                                                                      isUser ? widget.user.username : 'boxed-ai',
                                                                      style: const TextStyle(
                                                                        fontWeight: FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    const VerticalDivider(
                                                                      thickness: 1,
                                                                      color: Colors.black,
                                                                      width: 4,
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      formattedTime,
                                                                      style: const TextStyle(
                                                                        fontSize: 12,
                                                                        color: Colors.grey,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 8.0),
                                                                // RIGA 2: Contenuto del messaggio (Markdown)
                                                                _buildMessageContent(
                                                                  context,
                                                                  message['content'] ?? '',
                                                                  isUser,
                                                                  userMessageColor: Colors.white,
                                                                  assistantMessageColor: Colors.white,
                                                                ),
                                                                const SizedBox(height: 8.0),
                                                                // RIGA 3: Icone (copia, feedback, TTS, info)
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                                  children: [
                                                                    IconButton(
                                                                      icon: const Icon(Icons.copy, size: 14),
                                                                      tooltip: "Copia contenuto",
                                                                      onPressed: () {
                                                                        _copyToClipboard(
                                                                            message['content'] ?? '');
                                                                      },
                                                                    ),
                                                                    if (!isUser) ...[
                                                                      IconButton(
                                                                        icon: const Icon(Icons.thumb_up, size: 14),
                                                                        tooltip: "Feedback positivo",
                                                                        onPressed: () {
                                                                          print(
                                                                              "Feedback positivo per il messaggio: ${message['content']}");
                                                                        },
                                                                      ),
                                                                      IconButton(
                                                                        icon: const Icon(Icons.thumb_down, size: 14),
                                                                        tooltip: "Feedback negativo",
                                                                        onPressed: () {
                                                                          print(
                                                                              "Feedback negativo per il messaggio: ${message['content']}");
                                                                        },
                                                                      ),
                                                                    ],
                                                                    IconButton(
                                                                      icon: const Icon(Icons.volume_up, size: 14),
                                                                      tooltip: "Leggi il messaggio",
                                                                      onPressed: () {
                                                                        _speak(message['content'] ?? '');
                                                                      },
                                                                    ),
                                                                    IconButton(
                                                                      icon: const Icon(Icons.info_outline, size: 14),
                                                                      tooltip: "Informazioni sul messaggio",
                                                                      onPressed: () {
                                                                        _showMessageInfoDialog(message);
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // Container di input unificato (testo + icone + mic/invia)
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double availableWidth = constraints.maxWidth;
                                          final double containerWidth =
                                              (availableWidth > 800) ? 800 : availableWidth;

                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: containerWidth,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16.0),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4.0,
                                                    offset: Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // RIGA 1: Campo di input testuale
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                                                    child: TextField(
                                                      controller: _controller,
                                                      // onChanged: (_) => setState(() {}),
                                                      decoration: const InputDecoration(
                                                        hintText: 'Scrivi qui il tuo messaggio...',
                                                        border: InputBorder.none,
                                                      ),
                                                      onSubmitted: _handleUserInput,
                                                    ),
                                                  ),

                                                  // Divider sottile per separare input text e icone
                                                  const Divider(
                                                    height: 1,
                                                    thickness: 1,
                                                    color: Color(0xFFE0E0E0),
                                                  ),

                                                  // RIGA 2: Icone in basso (contesti, doc, media) + mic/freccia
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                                                    child: Row(
                                                      children: [
                                                        // Icona contesti
                                                        IconButton(
                                                          icon: const Icon(Icons.book_outlined),
                                                          tooltip: "Contesti",
                                                          onPressed: _showContextDialog,
                                                        ),
                                                        // Icona doc (inattiva)
                                                        IconButton(
                                                          icon: const Icon(Icons.description_outlined),
                                                          tooltip: "Carica documento (inattivo)",
                                                          onPressed: () {
                                                            // in futuro: logica di upload
                                                            print("Upload doc inattivo");
                                                          },
                                                        ),
                                                        // Icona media (inattiva)
                                                        IconButton(
                                                          icon: const Icon(Icons.image_outlined),
                                                          tooltip: "Carica media (inattivo)",
                                                          onPressed: () {
                                                            // in futuro: logica di upload
                                                            print("Upload media inattivo");
                                                          },
                                                        ),

                                                        const Spacer(),

                                                        (_controller.text.isEmpty)
                                                            ? IconButton(
                                                                icon: Icon(
                                                                  _isListening ? Icons.mic_off : Icons.mic,
                                                                ),
                                                                tooltip: "Attiva microfono",
                                                                onPressed: _listen,
                                                              )
                                                            : IconButton(
                                                                icon: const Icon(Icons.send),
                                                                tooltip: "Invia messaggio",
                                                                onPressed: () => _handleUserInput(_controller.text),
                                                              ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  )
                ])),
          )
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
    final TextEditingController _nameController =
        TextEditingController(text: chat['name']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Modifica Nome Chat'),
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
        return aCreatedAt
            .compareTo(bCreatedAt); // Ordina dal più vecchio al più recente
      });

      // Aggiorna lo stato
      setState(() {
        _activeChatIndex = _chatHistory.indexWhere(
            (c) => c['id'] == chatId); // Imposta l'indice della chat attiva
        messages.clear();
        messages.addAll(chatMessages.map((message) {
          // Assicura che ogni messaggio sia un Map<String, dynamic>
          return Map<String, dynamic>.from(message);
        }).toList());

        // Forza il passaggio alla schermata delle conversazioni
        showKnowledgeBase = false; // Nascondi KnowledgeBase
        showSettings = false; // Nascondi Impostazioni
      });

      // Debug: Messaggi caricati
      print(
          'Messaggi caricati per chat ID $chatId (${chat['name']}): $chatMessages');
    } catch (e) {
      print(
          'Errore durante il caricamento dei messaggi per chat ID $chatId: $e');
    }
  }

  Future<void> _handleUserInput(String input) async {
    if (input.isEmpty) return;

    final currentTime = DateTime.now().toIso8601String(); // Ora corrente
    final userMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio utente
    final assistantMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio dell'assistente
    final formattedContexts =
        _selectedContexts.map((c) => "${widget.user.username}-$c").toList();
    final chainId = "${formattedContexts.join('')}_agent_with_tools";

    // Configurazione dell'agente
    final agentConfiguration = {
      'model': _selectedModel, // Modello selezionato
      'contexts': formattedContexts, // Contesti selezionati
      'chain_id': chainId // ID della chain
    };

    setState(() {
      // Aggiungi il messaggio dell'utente con le informazioni di configurazione
      messages.add({
        'id': userMessageId, // ID univoco del messaggio utente
        'role': 'user', // Ruolo dell'utente
        'content': input, // Contenuto del messaggio
        'createdAt': currentTime, // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
      });

      fullResponse = ""; // Reset della risposta completa

      // Aggiungi un placeholder per la risposta dell'assistente
      messages.add({
        'id': assistantMessageId, // ID univoco del messaggio dell'assistente
        'role': 'assistant', // Ruolo dell'assistente
        'content': '', // Placeholder per il contenuto
        'createdAt': DateTime.now().toIso8601String(), // Timestamp
        'agentConfig': agentConfiguration, // Configurazione dell'agente
      });
    });

    // Pulisce il campo di input
    _controller.clear();

    // Invia il messaggio all'API per ottenere la risposta
    await _sendMessageToAPI(input);

    // Salva la conversazione con ID univoco per ogni messaggio
    _saveConversation(messages);
  }

  Map<String, List<Map<String, dynamic>>> _groupChatsByDate(
      List<dynamic> chats) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final sevenDaysAgo = today.subtract(Duration(days: 7));
    final thirtyDaysAgo = today.subtract(Duration(days: 30));

    Map<String, List<Map<String, dynamic>>> groupedChats = {
      'Oggi': [],
      'Ieri': [],
      'Ultimi 7 giorni': [],
      'Ultimi 30 giorni': [],
      'Chat passate': []
    };

    for (var chat in chats) {
      final chatDate = DateTime.parse(chat['updatedAt']);
      if (chatDate.isAfter(today)) {
        groupedChats['Oggi']?.add(chat);
      } else if (chatDate.isAfter(yesterday)) {
        groupedChats['Ieri']?.add(chat);
      } else if (chatDate.isAfter(sevenDaysAgo)) {
        groupedChats['Ultimi 7 giorni']?.add(chat);
      } else if (chatDate.isAfter(thirtyDaysAgo)) {
        groupedChats['Ultimi 30 giorni']?.add(chat);
      } else {
        groupedChats['Chat passate']?.add(chat);
      }
    }

    return groupedChats;
  }

  Future<void> _saveConversation(List<Map<String, dynamic>> messages) async {
    try {
      final currentTime =
          DateTime.now().toIso8601String(); // Ora corrente in formato ISO
      final chatId = _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['id'] // ID della chat esistente
          : uuid.v4(); // Genera un nuovo ID univoco per una nuova chat
      final chatName = _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['name'] // Nome della chat esistente
          : 'New Chat'; // Nome predefinito per le nuove chat

      // Prepara i messaggi con copia profonda per evitare riferimenti condivisi
      final List<Map<String, dynamic>> updatedMessages =
          messages.map((message) {
        return Map<String, dynamic>.from(message); // Copia ogni messaggio
      }).toList();

      // Integra le informazioni di configurazione dell'agente nei messaggi
      updatedMessages.forEach((message) {
        message['agentConfig'] = {
          'model': _selectedModel, // Modello selezionato (es. GPT-4)
          'contexts': _selectedContexts, // Contesti selezionati
          'chain_id':
              "${_selectedContexts.join('')}_agent_with_tools", // ID della chain
        };
      });

      // Crea o aggiorna la chat corrente con ID, timestamp e messaggi
      final currentChat = {
        'id': chatId, // ID della chat
        'name': chatName, // Nome della chat
        'createdAt': _activeChatIndex != null
            ? _chatHistory[_activeChatIndex!]
                ['createdAt'] // Mantieni la data di creazione originale
            : currentTime, // Timestamp di creazione per nuove chat
        'updatedAt': currentTime, // Aggiorna il timestamp di ultima modifica
        'messages': updatedMessages, // Lista dei messaggi aggiornati
      };

      if (_activeChatIndex != null) {
        // Aggiorna la chat esistente nella lista locale
        _chatHistory[_activeChatIndex!] =
            Map<String, dynamic>.from(currentChat); // Copia profonda della chat
      } else {
        // Aggiungi una nuova chat alla lista locale
        _chatHistory.insert(
            0,
            Map<String, dynamic>.from(
                currentChat)); // Inserisci in cima alla lista
        _activeChatIndex = 0; // Imposta l'indice della nuova chat
      }

      // Salva la cronologia delle chat nel Local Storage
      final String jsonString = jsonEncode({'chatHistory': _chatHistory});
      html.window.localStorage['chatHistory'] = jsonString;

      print('Chat salvata correttamente nel Local Storage.');

      // Salva o aggiorna la chat nel database
      final dbName =
          "${widget.user.username}-database"; // Nome del database basato sull'utente
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
          orElse: () =>
              <String, dynamic>{}, // Ritorna una mappa vuota se non trovata
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
          await _databaseService.createCollection(
              dbName, collectionName, widget.token.accessToken);

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

// Funzione per aprire il dialog di selezione dei contesti e del modello (supporta selezione multipla)
  void _showContextDialog() async {
    // Aggiorna i contesti dal backend prima di aprire il dialog
    await _loadAvailableContexts(); // Carica nuovamente i contesti disponibili dal backend

    // Inizializza la lista filtrata con tutti i contesti disponibili
    List<ContextMetadata> _filteredContexts = List.from(_availableContexts);

    // Controller per la barra di ricerca
    TextEditingController _searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Funzione per filtrare i contesti
            void _filterContexts(String query) {
              setState(() {
                _filteredContexts = _availableContexts.where((context) {
                  return context.path
                      .toLowerCase()
                      .contains(query.toLowerCase());
                }).toList();
              });
            }

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seleziona Contesti e Modello'),
                  SizedBox(
                      height:
                          20), // Aggiunto spazio maggiore tra il titolo e la barra di ricerca
                  // Barra di ricerca
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        _filterContexts(value), // Filtra i contesti
                    decoration: InputDecoration(
                      hintText: 'Cerca contesti...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 6, // Intensità dell'ombra
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(4), // Arrotondamento degli angoli
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 600), // Limita la larghezza massima del dialog
                child: SingleChildScrollView(
                  // Rende l'intero contenuto scrollabile
                  child: Container(
                    width: double
                        .maxFinite, // Consente al contenuto di occupare la larghezza disponibile
                    child: Column(
                      mainAxisSize: MainAxisSize
                          .min, // Dimensioni minime in base al contenuto
                      children: [
                        // Lista scrollabile con checkbox per la selezione multipla dei contesti
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.black54,
                                width: 1.0), // Bordo scuro sottile
                            borderRadius:
                                BorderRadius.circular(4), // Angoli arrotondati
                          ),
                          padding:
                              EdgeInsets.all(8), // Padding interno al riquadro
                          child: Container(
                            height:
                                300, // Altezza massima per la sezione scrollabile
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredContexts
                                  .length, // Usa i contesti filtrati
                              itemBuilder: (context, index) {
                                final contextMetadata =
                                    _filteredContexts[index];
                                final isSelected = _selectedContexts
                                    .contains(contextMetadata.path);

                                return CheckboxListTile(
                                  title: Text(
                                    contextMetadata.path,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors
                                              .black // Testo verde se selezionato
                                          : Colors
                                              .black, // Testo nero di default
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  value:
                                      isSelected, // Stato del checkbox (se selezionato o no)
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedContexts.add(contextMetadata
                                            .path); // Aggiungi alla lista selezionata
                                      } else {
                                        _selectedContexts.remove(contextMetadata
                                            .path); // Rimuovi dalla lista selezionata
                                      }
                                    });
                                  },
                                  activeColor: Colors
                                      .black, // Colore del checkbox selezionato
                                  checkColor: Colors
                                      .white, // Colore del segno di spunta
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                            height:
                                16.0), // Spaziatura tra la lista e il resto del contenuto
                        // Selettore del modello (es. GPT-4o, GPT-4o-mini)
                        /*Text(
                        'Seleziona Modello',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),*/
                        //SizedBox(height: 8.0),
                        // Pulsanti per selezionare il modello
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .spaceEvenly, // Distribuzione equa nella riga
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ChoiceChip(
                                  label: Center(child: Text('gpt-4o')),
                                  selected: _selectedModel == 'gpt-4o',
                                  onSelected: (bool selected) {
                                    setState(() {
                                      _selectedModel = 'gpt-4o';
                                      set_context(
                                          _selectedContexts, _selectedModel);
                                    });
                                  },
                                  selectedColor:
                                      Colors.grey[700], // Colore selezionato
                                  backgroundColor:
                                      Colors.grey[200], // Colore di default
                                  labelStyle: TextStyle(
                                    color: _selectedModel == 'gpt-4o'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ChoiceChip(
                                  label: Center(child: Text('gpt-4o-mini')),
                                  selected: _selectedModel == 'gpt-4o-mini',
                                  onSelected: (bool selected) {
                                    setState(() {
                                      _selectedModel = 'gpt-4o-mini';
                                      set_context(
                                          _selectedContexts, _selectedModel);
                                    });
                                  },
                                  selectedColor:
                                      Colors.grey[700], // Colore selezionato
                                  backgroundColor:
                                      Colors.grey[200], // Colore di default
                                  labelStyle: TextStyle(
                                    color: _selectedModel == 'gpt-4o-mini'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ChoiceChip(
                                  label: Center(child: Text('qwen2-7b')),
                                  selected: _selectedModel == 'qwen2-7b',
                                  onSelected: (bool selected) {
                                    setState(() {
                                      _selectedModel = 'qwen2-7b';
                                      set_context(
                                          _selectedContexts, _selectedModel);
                                    });
                                  },
                                  selectedColor:
                                      Colors.grey[700], // Colore selezionato
                                  backgroundColor:
                                      Colors.grey[200], // Colore di default
                                  labelStyle: TextStyle(
                                    color: _selectedModel == 'qwen2-7b'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  child: Text('Annulla'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Chiudi il dialog senza salvare
                  },
                ),
                ElevatedButton(
                  child: Text('Conferma'),
                  onPressed: () {
                    // Salva i contesti selezionati e il modello
                    set_context(_selectedContexts,
                        _selectedModel); // Chiama `set_context` con più contesti
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
              _selectedModel = model; // Aggiorna il modello selezionato
              // Passa anche il contesto selezionato ogni volta che cambia il modello
              set_context(_selectedContexts, _selectedModel);
            });
          },
          selectedColor: Colors.grey[700], // Colore selezionato
          backgroundColor: Colors.grey[200], // Colore di default
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.black, // Cambia il colore del testo quando selezionato
          ),
        );
      }).toList(),
    );
  }

  void set_context(List<String> contexts, String model) async {
    try {
      // Chiama la funzione dell'SDK per configurare e caricare la chain con i contesti selezionati
      final response = await _contextApiSdk.configureAndLoadChain(
          widget.user.username, widget.token.accessToken, contexts, model);
      print(
          'Chain configurata e caricata con successo per i contesti: $contexts');
      print('Risultato della configurazione: $response');

      setState(() {
        _selectedContexts =
            contexts; // Aggiorna la lista dei contesti selezionati
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
        width: double
            .infinity, // Imposta la larghezza per occupare tutto lo spazio disponibile
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
            Text("Impostazioni Text-to-Speech",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            Text(
                "Pausa tra frasi: ${_pauseBetweenSentences.toStringAsFixed(1)} sec"),
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
            Text("Personalizzazione grafica",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    if (_nlpApiUrl == null)
      await _loadConfig(); // Assicurati che l'URL sia caricato

    // URL della chain API
    final url = "$_nlpApiUrl/chains/stream_events_chain";
    final formattedContexts =
        _selectedContexts.map((c) => "${widget.user.username}-$c").toList();
    final chainId = "${formattedContexts.join('')}_agent_with_tools";
    // ID della chain basato sui contesti selezionati
    print('$chainId');
    // Configurazione dell'agente
    final agentConfiguration = {
      'model': _selectedModel, // Modello selezionato
      'contexts': _selectedContexts, // Contesti selezionati
      'chain_id': chainId // ID della chain
    };

    // Prepara il payload da inviare all'API
    final payload = jsonEncode({
      "chain_id": chainId,
      "query": {
        "input": input,
        "chat_history": messages.map((message) {
          // Filtra e converte i messaggi in un formato compatibile con l'API
          return {
            "id": message['id'],
            "role": message['role'],
            "content": message['content'],
            "createdAt": message['createdAt'],
            "agentConfig":
                message['agentConfig'], // Include la configurazione dell'agente
          };
        }).toList(),
      },
      "inference_kwargs": {}
    });

    try {
      // Invia la richiesta all'API
      final response = await js_util.promiseToFuture(js_util.callMethod(
        html.window,
        'fetch',
        [
          url,
          js_util.jsify({
            'method': 'POST',
            'headers': {'Content-Type': 'application/json'},
            'body': payload,
          }),
        ],
      ));

      // Controlla lo stato della risposta
      final ok = js_util.getProperty(response, 'ok') as bool;
      if (!ok) {
        throw Exception('Network response was not ok');
      }

      // Recupera il corpo della risposta
      final body = js_util.getProperty(response, 'body');
      if (body == null) {
        throw Exception('Response body is null');
      }

      // Ottieni il reader per leggere i chunk della risposta
      final reader = js_util.callMethod(body, 'getReader', []);

      String nonDecodedChunk = '';
      fullResponse = '';

      // Funzione per leggere i chunk della risposta
      void readChunk() {
        js_util
            .promiseToFuture(js_util.callMethod(reader, 'read', []))
            .then((result) {
          final done = js_util.getProperty(result, 'done') as bool;
          if (!done) {
            final value = js_util.getProperty(result, 'value');

            // Converti il chunk in una stringa
            final bytes = _convertJSArrayBufferToDartUint8List(value);
            final chunkString = utf8.decode(bytes);

            setState(() {
              // Accumula la risposta man mano che arriva
              fullResponse += chunkString;
              messages[messages.length - 1]['content'] = fullResponse + "▌";
            });

            try {
              // Gestione del buffer per il parsing
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
                nonDecodedChunk = ''; // Pulisci il buffer
              }
            } catch (e) {
              print("Errore durante il parsing del chunk: $e");
            }

            // Continua a leggere il prossimo chunk
            readChunk();
          } else {
            // Fine lettura: finalizza la risposta
            setState(() {
              messages[messages.length - 1]['content'] = fullResponse;

              // Associa la configurazione dell'agente alla risposta completata
              messages[messages.length - 1]['agentConfig'] = agentConfiguration;
            });

            // Salva la conversazione solo dopo che la risposta è stata completata
            _saveConversation(messages);
          }
        }).catchError((error) {
          // Gestione degli errori durante la lettura del chunk
          print('Errore durante la lettura del chunk: $error');
          setState(() {
            messages[messages.length - 1]['content'] = 'Errore: $error';
          });
        });
      }

      // Avvia la lettura dei chunk
      readChunk();
    } catch (e) {
      // Gestione degli errori durante la richiesta
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
