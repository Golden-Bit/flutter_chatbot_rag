import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_app/ui_components/chat/empty_chat_content.dart';
import 'package:flutter_app/ui_components/chat/utilities_functions/rename_chat_instructions.dart';
import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/ui_components/message/codeblock_md_builder.dart';
import 'package:flutter_app/llm_ui_tools/tools.dart';
import 'package:flutter_app/ui_components/buttons/blue_button.dart';
import 'package:flutter_app/ui_components/dialogs/search_dialog.dart';
import 'package:flutter_app/ui_components/dialogs/select_contexts_dialog.dart';
import 'package:flutter_app/utilities/localization.dart';
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
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'databases_manager/database_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart'; // Importa il pacchetto UUID (assicurati di averlo aggiunto a pubspec.yaml)
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart'; // Per gestire il tap sui link
import 'package:intl/intl.dart';
import 'dart:async'; // Assicurati di importare il package Timer
import 'package:flutter_svg/flutter_svg.dart';


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
/// Risultato del parsing del testo chatbot:
/// text:   il testo "pulito" (senza la parte di <...>)
/// widgetData: se esiste un widget, i dati necessari (altrimenti null)
class ParsedWidgetResult {
  final String text;
  final List<Map<String, dynamic>> widgetList;

  ParsedWidgetResult(this.text, this.widgetList);
}


/// Classe di appoggio per segmenti di testo o placeholder
class _Segment {
  final String? text;
  final String? placeholder;
  _Segment({this.text, this.placeholder});
}


class ChatBotPage extends StatefulWidget {
  final User user;
  final Token token;

  ChatBotPage({required this.user, required this.token});

  @override
  _ChatBotPageState createState() => _ChatBotPageState();
}


class _ChatBotPageState extends State<ChatBotPage> {


String spinnerPlaceholder = "[WIDGET_IN_CARICAMENTO]";
int _widgetCounter = 0; // Contatore globale nella classe per i placeholder

String _finalizeWidgetBlock(String widgetBlock) {
  // 1) Trovi la parte JSON (tra le due barre verticali)
  final firstBar = widgetBlock.indexOf("|");
  final secondBar = widgetBlock.indexOf("|", firstBar + 1);
  if (firstBar == -1 || secondBar == -1) {
    // Errore di formattazione => Ritorna un placeholder fisso o stringa vuota
    return "[WIDGET_PLACEHOLDER_ERROR]";
  }

  final jsonString = widgetBlock.substring(firstBar + 1, secondBar).trim();
  // 2) Trova WIDGET_ID='...'
  final widgetIdSearch = "WIDGET_ID='";
  final widgetIdStart = widgetBlock.indexOf(widgetIdSearch);
  if (widgetIdStart == -1) {
    return "[WIDGET_PLACEHOLDER_ERROR]";
  }
  final widgetIdStartAdjusted = widgetIdStart + widgetIdSearch.length;
  final widgetIdEnd = widgetBlock.indexOf("'", widgetIdStartAdjusted);
  if (widgetIdEnd == -1) {
    return "[WIDGET_PLACEHOLDER_ERROR]";
  }
  final widgetId = widgetBlock.substring(widgetIdStartAdjusted, widgetIdEnd);

  // 3) Decodifica JSON
  Map<String, dynamic>? widgetJson;
  try {
    widgetJson = jsonDecode(jsonString);
  } catch(e) {
    return "[WIDGET_PLACEHOLDER_ERROR]";
  }
  if (widgetJson == null) {
    return "[WIDGET_PLACEHOLDER_ERROR]";
  }

  // 4) Eventuale gestione is_first_time
  if (!widgetJson.containsKey('is_first_time')) {
    widgetJson['is_first_time'] = true;
  } else {
    // se esiste ed è true, metti false, ecc.
  }

  // 5) Genera un ID univoco
  final widgetUniqueId = uuid.v4();

  // 6) Costruisce un segnaposto
  final placeholder = "[WIDGET_PLACEHOLDER_$_widgetCounter]";
  _widgetCounter++;

  // 7) Aggiungiamo questo widget alla widgetDataList dell'ULTIMO messaggio
  final lastMsg = messages[messages.length - 1];
  List<dynamic> wList = lastMsg['widgetDataList'] ?? [];
  wList.add({
    "_id": widgetUniqueId,
    "widgetId": widgetId,
    "jsonData": widgetJson,
    "placeholder": placeholder,
  });
  lastMsg['widgetDataList'] = wList;

  // 8) Ritorniamo il placeholder
  return placeholder;
}


Future<void> _renameChat(String chatId, String newName) async {
  // Trova l'indice della chat in base all'ID
  int index = _chatHistory.indexWhere((chat) => chat['id'] == chatId);
  if (index != -1) {
    // Richiama la funzione già esistente per aggiornare il nome della chat
    await _editChatName(index, newName);
    // Facoltativo: mostra un messaggio di conferma
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat renamed to "$newName"')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat with ID "$chatId" not found.')),
    );
  }
}
  List<Map<String, dynamic>> messages = [];


  final Map<String, Widget> _widgetCache = {}; // Cache dei widget
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

  String? _latestChainId;
  String? _latestConfigId;



/// Risultato del parsing del testo chatbot:
/// text: testo "pulito" dopo la rimozione dei blocchi widget, 
///       in cui ogni widget è sostituito da un segnaposto [WIDGET_PLACEHOLDER_X]
/// widgetList: lista di dati dei widget estratti

ParsedWidgetResult _parsePotentialWidgets(String fullText) {
  String updatedText = fullText;
  final List<Map<String, dynamic>> widgetList = [];
  int widgetCounter = 0;

  while (true) {
    // 1) Trova l'indice di inizio del pattern "< TYPE='WIDGET'"
    final startIndex = updatedText.indexOf("< TYPE='WIDGET'");
    if (startIndex == -1) {
      // Se non troviamo più il pattern, interrompi
      break;
    }

    // 2) Trova l'indice di chiusura ">"
    final endIndex = updatedText.indexOf(">", startIndex);
    if (endIndex == -1) {
      // Se manca '>', il blocco non è valido: interrompi
      break;
    }

    // Estrarre il sottoblocco
    final widgetBlock = updatedText.substring(startIndex, endIndex + 1);

    // 3) Cerchiamo la prima e la seconda barra verticale "|"
    final firstBar = widgetBlock.indexOf("|");
    final secondBar = widgetBlock.indexOf("|", firstBar + 1);

    if (firstBar == -1 || secondBar == -1) {
      // Pattern non valido, rimuoviamo e proseguiamo
      updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
      continue;
    }

    // 4) Estrarre la parte JSON
    final jsonString = widgetBlock.substring(firstBar + 1, secondBar).trim();

    // 5) Estrarre widgetId (dopo WIDGET_ID=' ... ')
    final widgetIdSearch = "WIDGET_ID='";
    final widgetIdStart = widgetBlock.indexOf(widgetIdSearch);
    if (widgetIdStart == -1) {
      // Pattern non valido
      updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
      continue;
    }
    final widgetIdStartAdjusted = widgetIdStart + widgetIdSearch.length;
    final widgetIdEnd = widgetBlock.indexOf("'", widgetIdStartAdjusted);
    if (widgetIdEnd == -1 || widgetIdEnd <= widgetIdStartAdjusted) {
      // Pattern non valido
      updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
      continue;
    }

    final widgetId = widgetBlock.substring(widgetIdStartAdjusted, widgetIdEnd);

    // 6) Decodifica del JSON
    Map<String, dynamic>? widgetJson;
    try {
      widgetJson = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print("Errore parse JSON widget: $e");
      widgetJson = null;
    }

    if (widgetJson == null) {
      // Pattern non valido, rimuoviamo
      updatedText = updatedText.replaceRange(startIndex, endIndex + 1, "");
      continue;
    }

    // -------------- Integrazione logica is_first_time --------------
    if (!widgetJson.containsKey('is_first_time')) {
      // Se la chiave non esiste, la creiamo con valore true
      widgetJson['is_first_time'] = true;
    } else {
      // Se esiste, controlliamo il valore
      if (widgetJson['is_first_time'] == true) {
        // Se era true, la mettiamo a false
        widgetJson['is_first_time'] = false;
      }
      // Se è già false, non facciamo nulla
    }
    // ---------------------------------------------------------------

    // 7) Genera un _id univoco per il widget
    final widgetUniqueId = uuid.v4();
    // Assicurati di aver dichiarato "final Uuid uuid = Uuid();" nella classe

    // 8) Costruisci un segnaposto univoco
    final placeholder = "[WIDGET_PLACEHOLDER_$widgetCounter]";

    // 9) Aggiungi questo widget alla lista
    widgetList.add({
      "_id": widgetUniqueId,
      "widgetId": widgetId,
      "jsonData": widgetJson,
      "placeholder": placeholder,
    });

    // 10) Sostituisci nel testo
    updatedText = updatedText.replaceRange(
      startIndex,
      endIndex + 1,
      placeholder,
    );

    widgetCounter++;
  }

  // Restituisci il testo aggiornato e la lista di widget
  return ParsedWidgetResult(updatedText, widgetList);
}


String _getCurrentChatId() {
  if (_activeChatIndex != null && _chatHistory.isNotEmpty) {
    return _chatHistory[_activeChatIndex!]['id'] as String;
  }
  return "";
}

// Mappa di funzioni: un widget ID -> funzione che crea il Widget corrispondente
Map<String, Widget Function(Map<String, dynamic> data, void Function(String) onReply)> get widgetMap {
  return {
    "NButtonWidget": (data, onReply) => NButtonWidget(data: data, onReply: onReply),
    "RadarChart": (data, onReply) => RadarChartWidgetTool(jsonData: data, onReply: onReply),
    "TradingViewAdvancedChart": (data, onReply) => TradingViewAdvancedChartWidget(jsonData: data, onReply: onReply),
    "TradingViewMarketOverview": (data, onReply) => TradingViewMarketOverviewWidget(jsonData: data, onReply: onReply),
    "CustomChartWidget": (data, onReply) => CustomChartWidgetTool(jsonData: data, onReply: onReply),
    "ChangeChatNameWidget": (data, onReply) => ChangeChatNameWidgetTool(
      jsonData: data,
      // Modifica qui il callback onRenameChat per usare _getCurrentChatId se chatId risulta vuoto
      onRenameChat: (chatId, newName) async {
        // Se il chatId passato è vuoto, usiamo il metodo _getCurrentChatId
        final effectiveChatId = chatId.isEmpty ? await _getCurrentChatId() : chatId;

        if (effectiveChatId.isNotEmpty) {
          await _renameChat(effectiveChatId, newName);
          // Puoi eventualmente chiamare onReply per dare feedback all'utente
          print('Chat renamed to "$newName"');
        } else {
          // Gestione dell'errore: nessuna chat selezionata
          print('Errore: nessuna chat selezionata');
        }
      },
      getCurrentChatId: () async => _getCurrentChatId(),
    ),
        "SpinnerPlaceholder": (data, onReply) => const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text("Caricamento widget in corso..."),
          SizedBox(width: 8),
          CircularProgressIndicator(),
        ],
      ),
    ),
  };
}

Widget _buildMixedContent(Map<String, dynamic> message) {
  // Se il messaggio non contiene nessuna lista di widget, rendiamo il testo direttamente
  final widgetDataList = message['widgetDataList'] as List<dynamic>?;
  if (widgetDataList == null || widgetDataList.isEmpty) {
    final isUser = (message['role'] == 'user');
    return _buildMessageContent(
      context,
      message['content'] ?? '',
      isUser,
      userMessageColor: Colors.white,
      assistantMessageColor: Colors.white,
    );
  }

  // Costante per lo spinner
  const spinnerPlaceholder = "[WIDGET_SPINNER]";

  // Otteniamo il testo completo “pulito” (con i placeholder) dal messaggio
  final textContent = message['content'] ?? '';

  // Ordiniamo i widgetData in base al nome/numero del placeholder
  widgetDataList.sort((a, b) {
    final pa = a['placeholder'] as String;
    final pb = b['placeholder'] as String;
    return pa.compareTo(pb);
  });

  // Costruiamo un array di segmenti di testo o "placeholder"
  final segments = <_Segment>[];
  String temp = textContent;

  while (true) {
    // Troviamo il placeholder che compare prima nel testo
    int foundPos = temp.length;
    String foundPh = "";
    for (final w in widgetDataList) {
      final ph = w['placeholder'] as String;
      final idx = temp.indexOf(ph);
      if (idx != -1 && idx < foundPos) {
        foundPos = idx;
        foundPh = ph;
      }
    }

    if (foundPos == temp.length) {
      // Nessun placeholder trovato
      if (temp.isNotEmpty) {
        segments.add(_Segment(text: temp));
      }
      break;
    }

    // Aggiungiamo l’eventuale testo prima del placeholder
    if (foundPos > 0) {
      final beforeText = temp.substring(0, foundPos);
      segments.add(_Segment(text: beforeText));
    }

    // Aggiungiamo il placeholder come segment
    segments.add(_Segment(placeholder: foundPh));

    // Rimuoviamo la parte elaborata
    temp = temp.substring(foundPos + foundPh.length);
  }

  // Ora costruiamo i widget finali
  final contentWidgets = <Widget>[];

  for (final seg in segments) {
    // Se non è un placeholder (testo normale)
    if (seg.placeholder == null) {
      final isUser = (message['role'] == 'user');
      if (seg.text != null && seg.text!.isNotEmpty) {
        contentWidgets.add(
          _buildMessageContent(
            context,
            seg.text!,
            isUser,
            userMessageColor: Colors.white,
            assistantMessageColor: Colors.white,
          ),
        );
      }
    }
    // Altrimenti, è un placeholder
    else {
      final ph = seg.placeholder!;
      
      // (1) Se è lo spinner "[WIDGET_SPINNER]", mostriamo la rotella di caricamento
      if (ph == spinnerPlaceholder) {
        contentWidgets.add(
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Caricamento widget in corso..."),
                const SizedBox(width: 8),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      }

      // (2) Altrimenti, potrebbe essere un segnaposto di un widget reale
      else {
        // Cerchiamo i dati del widget corrispondente
        final wdata = widgetDataList.firstWhere((x) => x['placeholder'] == ph);
        final widgetUniqueId = wdata['_id'] as String;
        final widgetId = wdata['widgetId'] as String;
        final jsonData = wdata['jsonData'] as Map<String, dynamic>? ?? {};

        // Verifichiamo se abbiamo già un widget in cache
        Widget? embeddedWidget = _widgetCache[widgetUniqueId];
        if (embeddedWidget == null) {
          // Creiamo il widget adesso
          final widgetBuilder = widgetMap[widgetId];
          if (widgetBuilder != null) {
            embeddedWidget = widgetBuilder(jsonData, (reply) => _handleUserInput(reply));
          } else {
            embeddedWidget = Text("Widget sconosciuto: $widgetId");
          }
          _widgetCache[widgetUniqueId] = embeddedWidget;
        }

        // Inseriamo il widget, centrato orizzontalmente
        contentWidgets.add(
          Container(
            width: double.infinity,
            child: Align(
              alignment: Alignment.center,
              child: embeddedWidget,
            ),
          ),
        );
      }
    }
  }

  // Restituiamo i widget sotto forma di colonna
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: contentWidgets,
  );
}


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

Future<void> _animateChatNameChange(int index, String finalName) async {
  String currentName = "";
  int charIndex = 0;
  const duration = Duration(milliseconds: 100);
  final completer = Completer<void>();

  Timer.periodic(duration, (timer) {
    if (charIndex < finalName.length) {
      currentName += finalName[charIndex];
      setState(() {
        _chatHistory[index]['name'] = currentName;
      });
      charIndex++;
    } else {
      timer.cancel();
      completer.complete();
    }
  });

  return completer.future;
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

    



    _databaseService.createDatabase('database', widget.token.accessToken);




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
        final localizations = LocalizationProvider.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona il colore'),
          backgroundColor: Colors.white, // Sfondo del popup
          elevation: 6, // Intensità dell'ombra
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8), // Arrotondamento degli angoli
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
              child: Text(localizations.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
    final localizations = LocalizationProvider.of(context);
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
          title: Text(localizations.message_details),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dettagli di base del messaggio
                Text(
                  "${localizations.roleLabel} ${role == 'user' ? localizations.userRole : localizations.assistantRole}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("${localizations.dateLabel} $createdAt"),
                Text("${localizations.charLength} $contentLength"),
                Text(
                    "${localizations.tokenLength} 0"), // Sostituisci se disponi di dati token

                // Divider per separare i dettagli base dai dettagli di configurazione
                if (role == 'assistant' || agentConfig != null) ...[
                  const Divider(),
                  Text(localizations.agentConfigDetails,
                      style: TextStyle(fontWeight: FontWeight.bold)),

                  // Mostra il modello selezionato
                  if (model != null) Text("${localizations.modelLabel} $model"),
                  const SizedBox(height: 8),

                  // Mostra i contesti utilizzati
                  if (contexts != null && contexts.isNotEmpty) ...[
                    Text(localizations.selectedContextsLabel,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...contexts.map((context) => Text("- $context")).toList(),
                  ],

                  const SizedBox(height: 8),

                  // Mostra l'ID della chain
                  if (chainId != null) Text("${localizations.chainIdLabel} $chainId"),

                  // Divider aggiuntivo per eventuali altri dettagli
                  const Divider(),
                  Text(localizations.additionalMetrics,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${localizations.tokensGenerated} $tokensReceived"),
                  Text("${localizations.tokensReceived} $tokensGenerated"),
                  Text("${localizations.responseCost} \$${responseCost.toStringAsFixed(4)}"),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Chiudi il dialog
              },
              child: Text(localizations.close)
            ),
          ],
        );
      },
    );
  }

bool _isSameDay(DateTime d1, DateTime d2) {
  return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}

String _getDateSeparator(DateTime date) {
  final today = DateTime.now();
  final yesterday = today.subtract(Duration(days: 1));
  if (_isSameDay(date, today)) {
    return "Today";
  } else if (_isSameDay(date, yesterday)) {
    return "Yesterday";
  } else {
    return DateFormat('dd MMM yyyy').format(date);
  }
}


List<Widget> _buildMessagesList(double containerWidth) {
  final localizations = LocalizationProvider.of(context);
  List<Widget> widgets = [];
  for (int i = 0; i < messages.length; i++) {
    final message = messages[i];
    final bool isUser = (message['role'] == 'user');
    final DateTime parsedTime = DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
    final String formattedTime = DateFormat('h:mm a').format(parsedTime);

    // Se è il primo messaggio o se la data del messaggio corrente è diversa da quella del precedente,
    // aggiungi un separatore.
    if (i == 0) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              _getDateSeparator(parsedTime),
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    } else {
      final DateTime previousTime = DateTime.tryParse(messages[i - 1]['createdAt'] ?? '') ?? parsedTime;
      if (!_isSameDay(parsedTime, previousTime)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                _getDateSeparator(parsedTime),
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Aggiungi il widget del messaggio (codice originale invariato)
    widgets.add(
      Padding(
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
                            child: assistantAvatar,
                          )
                        else
                          CircleAvatar(
                            backgroundColor: _avatarBackgroundColor.withOpacity(_avatarBackgroundOpacity),
                            child: Icon(
                              Icons.person,
                              color: _avatarIconColor.withOpacity(_avatarIconOpacity),
                            ),
                          ),
                        const SizedBox(width: 8.0),
                        Text(
                          isUser ? widget.user.username : assistantName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // RIGA 2: Contenuto del messaggio (Markdown)
                    _buildMixedContent(message),
                    const SizedBox(height: 8.0),
                    // RIGA 3: Icone (copia, feedback, TTS, info)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14),
                          tooltip: localizations.copy,
                          onPressed: () {
                            _copyToClipboard(message['content'] ?? '');
                          },
                        ),
                        if (!isUser) ...[
                          IconButton(
                            icon: const Icon(Icons.thumb_up, size: 14),
                            tooltip: localizations.positive_feedback,
                            onPressed: () {
                              print("Feedback positivo per il messaggio: ${message['content']}");
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.thumb_down, size: 14),
                            tooltip: localizations.negative_feedback,
                            onPressed: () {
                              print("Feedback negativo per il messaggio: ${message['content']}");
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 14),
                          tooltip: localizations.volume,
                          onPressed: () {
                            _speak(message['content'] ?? '');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 14),
                          tooltip: localizations.messageInfoTitle,
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
      ),
    );
  }
  return widgets;
}

  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
   
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
                              fullLogo,
                              // Icona di espansione/contrazione a destra
                              IconButton(
                                icon:SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
            width: 24,
            height: 24,
            color: Colors.grey),

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

// Pulsante "Cerca"
MouseRegion(
  onEnter: (_) {
    setState(() {
      _buttonHoveredIndex = 99; // un indice qualsiasi per l'hover
    });
  },
  onExit: (_) {
    setState(() {
      _buttonHoveredIndex = null;
    });
  },
  child: GestureDetector(
    onTap: () {
      // Quando clicco, apro il dialog di ricerca
showSearchDialog(
  context: context,
  chatHistory: _chatHistory,
  onNavigateToMessage: (String chatId, String messageId) {
    // Carica la chat corrispondente
    _loadMessagesForChat(chatId);
    // Se vuoi scrollare al messaggio specifico, puoi salvare
    // un "targetMessageId" e poi gestire lo scroll/spostamento
    // dopo che i messaggi sono stati caricati.
  },
);
    },
    child: Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: _buttonHoveredIndex == 99
            ? const Color.fromARGB(255, 224, 224, 224)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        children: [
          const Icon(Icons.search,  size: 24.0,
            color: Colors.black),
          const SizedBox(width: 8.0),
          Text(
            localizations.searchButton,
            style: TextStyle(color: Colors.black),
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
                                  //Icon(Icons.chat_bubble_outline_outlined,
                                  //    color: Colors.black),
SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element.svg',
            width: 24,
            height: 24,
            color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    localizations.conversation,
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
SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element2.svg',
            width: 24,
            height: 24,
            color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                      localizations.knowledgeBoxes,
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
SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Icon.svg',
            width: 24,
            height: 24,
            color: Colors.black),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    localizations.settings,
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
                                    localizations.noChatAvailable,
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
                                        Colors
                                            .white, // A partire da qui diventa trasparente
                                      ],
                                      stops: [0.0, 0.75, 1.0],
                                    ).createShader(bounds);
                                  },
                                  // Con dstOut, le parti del gradiente che sono bianche (o trasparenti) "tagliano" via il contenuto
                                  blendMode: BlendMode.dstOut,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                        bottom: 32.0), // Spazio extra in fondo
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
                                                _chatHistory.indexOf(
                                                    chat); // Chat attiva
                                            final isHovered = hoveredIndex ==
                                                _chatHistory.indexOf(
                                                    chat); // Chat in hover

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
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4.0), // Arrotonda gli angoli
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
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
                                                                : FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                      ),
                                                      Theme(
  data: Theme.of(context).copyWith(
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
    ),
  ),
  child: 
PopupMenuButton<String>(
  offset: const Offset(0, 32),
                                                          borderRadius: BorderRadius.circular(16), // Imposta un raggio di 8
                                                        color: Colors.white,
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
                                                        onSelected:
                                                            (String value) {
                                                          if (value ==
                                                              'delete') {
                                                            _deleteChat(_chatHistory
                                                                .indexOf(
                                                                    chat)); // Elimina la chat
                                                          } else if (value ==
                                                              'edit') {
                                                            _showEditChatDialog(
                                                                _chatHistory
                                                                    .indexOf(
                                                                        chat)); // Modifica la chat
                                                          }
                                                        },
                                                        itemBuilder:
                                                            (BuildContext
                                                                context) {
                                                          return [
                                                            PopupMenuItem(
                                                              value: 'edit',
                                                              child: Text(
                                                                  localizations.edit),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'delete',
                                                              child: Text(
                                                                  localizations.delete),
                                                            ),
                                                          ];
                                                        },
                                                      )),
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
                            const SizedBox(height: 8),
// Pulsante "Nuova Chat"
HoverableNewChatButton(
  label: localizations.newChat,
  onPressed: () {
    _startNewChat();
    setState(() {
      _activeButtonIndex = 3;
      showKnowledgeBase = false;
      showSettings = false;
      _activeChatIndex = null;
    });}),
                            const SizedBox(height: 56),

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
                    radius:
                        1.2, // aumenta o diminuisci per rendere più o meno ampio il cerchio
                    colors: [
                      Color.fromARGB(
                          255, 199, 230, 255), // Azzurro pieno al centro
                      Colors.white, // Bianco verso i bordi
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: Column(children: [
                  // Nuova top bar per info e pulsante utente
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                                  icon: SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element3.svg',
            width: 24,
            height: 24,
            color: Colors.grey),//const Icon(Icons.menu,
                                      //color: Colors.black),
                                  onPressed: () {
                                    setState(() {
                                      isExpanded = true;
                                      sidebarWidth = MediaQuery.of(context)
                                                  .size
                                                  .width <
                                              600
                                          ? MediaQuery.of(context).size.width
                                          : 300.0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                              fullLogo,
                              ],
                            ],
                          ),
                        ),
Theme(
  data: Theme.of(context).copyWith(
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
    ),
  ),
  child: 
PopupMenuButton<String>(
  offset: const Offset(0, 50),
  borderRadius: BorderRadius.circular(16), // Imposta un raggio di 8
  color: Colors.white,
  icon: Builder(
    builder: (context) {
      // Recupera la larghezza disponibile usando MediaQuery
      final availableWidth = MediaQuery.of(context).size.width;
      return Row(
        mainAxisSize: MainAxisSize.min, // Occupa solo lo spazio necessario
        children: [
          CircleAvatar(
            backgroundColor: Colors.black,
            child: Text(
              widget.user.email.substring(0, 2).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // Mostra nome ed email solo se la larghezza è almeno 450
          if (availableWidth >= 450)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.username,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.email,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Aggiungi icona della lingua
          //const SizedBox(width: 8.0),
          //Icon(Icons.language, color: Colors.blue),
        ],
      );
    },
  ),
  onSelected: (value) {
    if (value == 'language') {
      // Mostra un dialogo per selezionare la lingua
showDialog(
  context: context,
  builder: (context) {
    final selectedLanguage = LocalizationProviderWrapper.of(context).currentLanguage;

    Widget languageOption({
      required String label,
      required Language language,
      required String countryCode, // es: "it", "us", "es"
    }) {
      final isSelected = selectedLanguage == language;
      return SimpleDialogOption(
        onPressed: () {
          LocalizationProviderWrapper.of(context).setLanguage(language);
          Navigator.pop(context);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade200 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  'https://flagcdn.com/w40/$countryCode.png',
                  width: 24,
                  height: 18,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.flag),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SimpleDialog(
      backgroundColor: Colors.white,
      title: Text(localizations.select_language),
      children: [
        languageOption(
          label: 'Italiano',
          language: Language.italian,
          countryCode: 'it',
        ),
        languageOption(
          label: 'English',
          language: Language.english,
          countryCode: 'us',
        ),
        languageOption(
          label: 'Español',
          language: Language.spanish,
          countryCode: 'es',
        ),
      ],
    );
  },
);


    } else {
      // Altri casi di selezione
      switch (value) {
        case 'Profilo':
          //Navigator.push(
            //context,
            //MaterialPageRoute(
            //  builder: (context) => AccountSettingsPage(
            //    user: widget.user,
            //    token: widget.token,
            //  ),
            //),
          //);
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
    }
  },
  itemBuilder: (BuildContext context) {
    return [

      PopupMenuItem(
        value: 'Profilo',
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.black),
            const SizedBox(width: 8.0),
            Text(localizations.profile),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'Utilizzo',
        child: Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.black),
            const SizedBox(width: 8.0),
            Text(localizations.usage),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'Impostazioni',
        child: Row(
          children: [
            Icon(Icons.settings, color: Colors.black),
            const SizedBox(width: 8.0),
            Text(localizations.settings),
          ],
        ),
      ),
            // Elemento per la selezione della lingua
      PopupMenuItem(
        value: 'language',
        child: Row(
          children: [
            Icon(Icons.language, color: Colors.black),
            const SizedBox(width: 8.0),
            Text(localizations.select_language),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'Logout',
        child: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8.0),
            Text(
              localizations.logout,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    ];
  },
))



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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0.0, vertical: 0.0),
                      color: Colors.transparent,
                      child: showKnowledgeBase
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 4.0),
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
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  //child: AccountSettingsPage(
                                  //  user: widget.user,
                                  //  token: widget.token,
                                  //),
                                )
                              : Column(
                                  children: [
                                    // Sezione principale con i messaggi




messages.isEmpty
                      ? buildEmptyChatScreen(context, _handleUserInput)
                      : Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final double rightContainerWidth = constraints.maxWidth;
      final double containerWidth =
          (rightContainerWidth > 800) ? 800.0 : rightContainerWidth;

      return ShaderMask(
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
        child: SingleChildScrollView(
          // (1) Lo scroll avviene su tutta la larghezza
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            // (2) Centra la colonna
            child: ConstrainedBox(
              // (3) Limita la larghezza della colonna a containerWidth
              constraints: BoxConstraints(
                maxWidth: containerWidth,
              ),
              child: Column(
                children: _buildMessagesList(containerWidth),
                                            ),
                                          ))));
                                        },
                                      ),
                                    ),

                                    // Container di input unificato (testo + icone + mic/invia)
                                    Container(
                                      margin: const EdgeInsets.fromLTRB(
                                          0, 16, 0, 0),
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double availableWidth =
                                              constraints.maxWidth;
                                          final double containerWidth =
                                              (availableWidth > 800)
                                                  ? 800
                                                  : availableWidth;

                                          return ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: containerWidth,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16.0),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  // RIGA 1: Campo di input testuale
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .fromLTRB(
                                                        16.0, 8.0, 16.0, 8.0),
                                                    child: TextField(
                                                      controller: _controller,
                                                      // onChanged: (_) => setState(() {}),
                                                      decoration:
                                                           InputDecoration(
                                                        hintText:
                                                            localizations.write_here_your_message,
                                                        border:
                                                            InputBorder.none,
                                                      ),
                                                      onSubmitted:
                                                          _handleUserInput,
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
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 0.0),
                                                    child: Row(
                                                      children: [
                                                        // Icona contesti
                                                        IconButton(
                                                          icon: SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element2.svg',
            width: 24,
            height: 24,
            color: Colors.grey),
                                                          tooltip: localizations.knowledgeBoxes,
                                                          onPressed:
                                                              _showContextDialog,
                                                        ),
                                                        // Icona doc (inattiva)
                                                        IconButton(
                                                          icon: SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element7.svg',
            width: 24,
            height: 24,
            color: Colors.grey),
                                                          tooltip:
                                                              localizations.upload_document,
                                                          onPressed: () {
                                                            // in futuro: logica di upload
                                                            print(
                                                                localizations.upload_document);
                                                          },
                                                        ),
                                                        // Icona media (inattiva)
                                                        IconButton(
                                                          icon: SvgPicture.network('https://raw.githubusercontent.com/Golden-Bit/boxed-ai-assets/refs/heads/main/icons/Element8.svg',
            width: 24,
            height: 24,
            color: Colors.grey),
                                                          tooltip:
                                                              localizations.upload_media,
                                                          onPressed: () {
                                                            // in futuro: logica di upload
                                                            print(
                                                                localizations.upload_media);
                                                          },
                                                        ),

                                                        const Spacer(),

                                                        (_controller
                                                                .text.isEmpty)
                                                            ? IconButton(
                                                                icon: Icon(
                                                                  _isListening
                                                                      ? Icons
                                                                          .mic_off
                                                                      : Icons
                                                                          .mic,
                                                                ),
                                                                tooltip:
                                                                    localizations.enable_mic,
                                                                onPressed:
                                                                    _listen,
                                                              )
                                                            : IconButton(
                                                                icon: const Icon(
                                                                    Icons.send),
                                                                tooltip:
                                                                    localizations.send_message,
                                                                onPressed: () =>
                                                                    _handleUserInput(
                                                                        _controller
                                                                            .text),
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
    final localizations = LocalizationProvider.of(context);
    final chat = _chatHistory[index];
    final TextEditingController _nameController =
        TextEditingController(text: chat['name']);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.edit_chat_name),
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
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: localizations.chat_name),
          ),
          actions: [
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(localizations.save),
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
    // Avvia l'animazione per cambiare il nome
    await _animateChatNameChange(index, newName);

    // Dopo l'animazione, aggiorna il nome nel localStorage e nel database
    final chatToUpdate = _chatHistory[index];

    // Aggiorna il localStorage
    final String jsonString = jsonEncode({'chatHistory': _chatHistory});
    html.window.localStorage['chatHistory'] = jsonString;

    // Aggiorna il database, se disponibile
    if (chatToUpdate.containsKey('_id')) {
      await _databaseService.updateCollectionData(
        "${widget.user.username}-database",
        'chats',
        chatToUpdate['_id'],
        {'name': newName},
        widget.token.accessToken,
      );
      print('Nome chat aggiornato con successo nel database.');
    }  else {
      // Se _id non è presente (caso di modifica tramite tool Chatbot)
      // Chiamiamo _saveConversation per forzare la creazione/aggiornamento del record nel DB.
      print('Nessun _id presente, forzo il salvataggio tramite _saveConversation.');
      await _saveConversation(messages);
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
      // Svuota la cache dei widget per forzare la ricostruzione con i nuovi dati
  _widgetCache.clear();
    try {
final chat = _chatHistory.firstWhere(
  (chat) => chat['id'] == chatId,
  orElse: () => null, // se non trova nulla, restituisce null
);

if (chat == null) {
  // gestisci il caso in cui la chat NON esiste
} else {
  // gestisci la chat trovata
}

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

if (messages.isNotEmpty) {
  // L'ultimo messaggio è in messages[messages.length - 1]
  final lastMsg = messages[messages.length - 1];
  final lastConfig = lastMsg['agentConfig'];
  if (lastConfig != null) {
    setState(() {
      _latestChainId = lastConfig['chain_id'];
      _latestConfigId = lastConfig['config_id'];
    });
    print("Ricaricata chain_id=$_latestChainId, config_id=$_latestConfigId dalla chat salvata.");
  }
}

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

    
  // Determina il nome corrente della chat (se non esiste, il default è "New Chat")
  String currentChatName = "New Chat";
  if (_activeChatIndex != null && _chatHistory.isNotEmpty) {
    currentChatName = _chatHistory[_activeChatIndex!]['name'] as String;
  }
  
  // Qui decidiamo quanti messaggi sono già stati inviati
  // Puoi utilizzare messages.length oppure tenere un contatore separato
  final int currentMessageCount = messages.length; 
  
  // Ottieni l'input modificato usando la funzione esterna
  final modifiedInput = appendChatInstruction(
    input,
    currentChatName: currentChatName,
    messageCount: currentMessageCount,
  );



    final currentTime = DateTime.now().toIso8601String(); // Ora corrente
    final userMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio utente
    final assistantMessageId =
        uuid.v4(); // Genera un ID univoco per il messaggio dell'assistente
    final formattedContexts =
        _selectedContexts.map((c) => "${widget.user.username}-$c").toList();

// Usa i contesti formattati se ti servono in debug, ma la vera chain la prendi dallo state:
final agentConfiguration = {
  'model': _selectedModel,                      // Modello
  'contexts': formattedContexts,                // Teniamo traccia dei contesti
  'chain_id': _latestChainId,                   // Usa la chain ID reale dal backend
  'config_id': _latestConfigId,                 // Salva anche il config ID
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
    await _sendMessageToAPI(modifiedInput);

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
    final currentTime = DateTime.now().toIso8601String(); // Ora corrente in formato ISO
    final chatId = _activeChatIndex != null
        ? _chatHistory[_activeChatIndex!]['id'] // ID della chat esistente
        : uuid.v4(); // Genera un nuovo ID univoco per una nuova chat
    final chatName = _activeChatIndex != null
        ? _chatHistory[_activeChatIndex!]['name'] // Nome della chat esistente
        : 'New Chat'; // Nome predefinito per le nuove chat

    // Effettua una copia profonda di tutti i messaggi
    final List<Map<String, dynamic>> updatedMessages = messages.map((originalMessage) {
      // Cloniamo l'intero messaggio (struttura annidata) con jsonDecode(jsonEncode(...))
      final newMsg = jsonDecode(jsonEncode(originalMessage)) as Map<String, dynamic>;

      // Se il messaggio ha dei widget, forziamo is_first_time = false in ognuno
      if (newMsg['widgetDataList'] != null) {
        final List widgetList = newMsg['widgetDataList'];
        for (int i = 0; i < widgetList.length; i++) {
          final Map<String, dynamic> widgetMap =
              widgetList[i] as Map<String, dynamic>;
          final Map<String, dynamic> jsonData =
              (widgetMap['jsonData'] ?? {}) as Map<String, dynamic>;

          // Se non esiste la chiave, la creiamo con false,
          // altrimenti la forziamo a false
          jsonData['is_first_time'] = false;
          widgetMap['jsonData'] = jsonData;
          widgetList[i] = widgetMap;
        }
        newMsg['widgetDataList'] = widgetList;
      }

      // Aggiorniamo la agentConfig per riflettere contesti e modello
      final Map<String, dynamic> oldAgentConfig = (newMsg['agentConfig'] ?? {}) as Map<String, dynamic>;
      oldAgentConfig['model'] = _selectedModel;
      oldAgentConfig['contexts'] = _selectedContexts;
      newMsg['agentConfig'] = oldAgentConfig;

      return newMsg;
    }).toList();

    // Crea o aggiorna la chat corrente con ID, timestamp e messaggi
    final Map<String, dynamic> currentChat = {
      'id': chatId, // ID della chat
      'name': chatName, // Nome della chat
      'createdAt': _activeChatIndex != null
          ? _chatHistory[_activeChatIndex!]['createdAt']
          : currentTime, // Se esisteva già, mantengo la data di creazione, altrimenti quella attuale
      'updatedAt': currentTime,      // Aggiorna il timestamp di ultima modifica
      'messages': updatedMessages,   // Lista di messaggi clonati e modificati
    };

    if (_activeChatIndex != null) {
      // Aggiorna la chat esistente nella lista locale
      _chatHistory[_activeChatIndex!] = jsonDecode(jsonEncode(currentChat)) as Map<String, dynamic>;
    } else {
      // Aggiungi una nuova chat alla lista locale
      _chatHistory.insert(0, jsonDecode(jsonEncode(currentChat)) as Map<String, dynamic>);
      _activeChatIndex = 0; // Imposta l'indice della nuova chat
    }

    // Salva la cronologia delle chat nel Local Storage
    final String jsonString = jsonEncode({'chatHistory': _chatHistory});
    html.window.localStorage['chatHistory'] = jsonString;
    print('Chat salvata correttamente nel Local Storage.');

    // Salva o aggiorna la chat nel database
    final dbName = "${widget.user.username}-database"; // Nome del DB basato sull'utente
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
        (chat) => chat['id'] == chatId,
        orElse: () => <String, dynamic>{}, // Ritorna una mappa vuota se non trovata
      );

      if (existingChat.isNotEmpty && existingChat.containsKey('_id')) {
        // Chat esistente: aggiorniamo i campi
        await _databaseService.updateCollectionData(
          dbName,
          collectionName,
          existingChat['_id'], // ID del documento esistente
          {
            'name': currentChat['name'],   // Aggiorna il nome della chat
            'updatedAt': currentTime,      // Aggiorna la data di ultima modifica
            'messages': updatedMessages,   // Aggiorna i messaggi
          },
          widget.token.accessToken,
        );
        print('Chat aggiornata nel database.');
      } else {
        // Chat non esistente, aggiungiamone una nuova
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
        // Se la collection non esiste, la creiamo e aggiungiamo la chat
        print('Collection "chats" non esistente. Creazione in corso...');
        await _databaseService.createCollection(dbName, collectionName, widget.token.accessToken);

        // Aggiungi la nuova chat
        await _databaseService.addDataToCollection(
          dbName,
          collectionName,
          currentChat,
          widget.token.accessToken,
        );

        print('Collection "chats" creata e chat aggiunta al database.');
      } else {
        throw e; // Propaga eventuali altri errori
      }
    }
  } catch (e) {
    print('Errore durante il salvataggio della conversazione: $e');
  }
}


void _showContextDialog() async {
  // Carichiamo i contesti (se serve farlo qui) ...
  await _loadAvailableContexts();

  // Richiamiamo il dialog esterno
  await showSelectContextDialog(
    context: context,
    availableContexts: _availableContexts,
    initialSelectedContexts: _selectedContexts,
    initialModel: _selectedModel,
    onConfirm: (List<String> newContexts, String newModel) {
      setState(() {
        _selectedContexts = newContexts;
        _selectedModel = newModel;
      });
      // E se vuoi, chiami la funzione set_context
      set_context(_selectedContexts, _selectedModel);
    },
  );
}



void set_context(List<String> contexts, String model) async {
  try {
    final response = await _contextApiSdk.configureAndLoadChain(
      widget.user.username,
      widget.token.accessToken,
      contexts,
      model,
    );
    print('Chain configurata e caricata con successo per i contesti: $contexts');
    print('Risultato della configurazione: $response');

    // Estrai i dati dal JSON restituito
    final chainIdFromResponse =
        response['load_result'] != null ? response['load_result']['chain_id'] : null;
    final configIdFromResponse =
        response['config_result'] != null ? response['config_result']['config_id'] : null;

    setState(() {
      _selectedContexts = contexts; 
      _latestChainId = chainIdFromResponse;
      _latestConfigId = configIdFromResponse;
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
    final localizations = LocalizationProvider.of(context);
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.copyMessage)),
    );
  }

  Future<void> _sendMessageToAPI(String input) async {
  if (_nlpApiUrl == null) {
    await _loadConfig(); // Assicurati che l'URL sia caricato
  }

  // URL della chain API
  final url = "$_nlpApiUrl/chains/stream_events_chain";

  // Prepara i contesti
  final formattedContexts = _selectedContexts.map((c) => "${widget.user.username}-$c").toList();
  final chainIdToUse = _latestChainId ?? "${formattedContexts.join('')}_agent_with_tools";

  // Configurazione dell'agente
  final agentConfiguration = {
    'model': _selectedModel,       // Modello selezionato
    'contexts': _selectedContexts, // Contesti selezionati
    'chain_id': chainIdToUse,      // Usa la chain ID dal backend (oppure fallback)
    'config_id': _latestConfigId,  // Memorizza anche la config ID
  };


// Trasforma la chat history sostituendo i placeholder dei widget con i JSON reali
final transformedChatHistory = messages.map((message) {
  String content = message['content'] as String;
  if (message.containsKey('widgetDataList')) {
    final List widgetList = message['widgetDataList'];
    for (final widgetEntry in widgetList) {
      final String placeholder = widgetEntry['placeholder'] as String;
      // Sostituisce il placeholder nel contenuto con il JSON serializzato
      final String widgetJsonStr = jsonEncode(widgetEntry['jsonData']);
      final String widgetFormattedStr = "< TYPE='WIDGET' WIDGET_ID='${widgetEntry['widgetId'] as String}' | $widgetJsonStr | TYPE='WIDGET' WIDGET_ID='${widgetEntry['widgetId'] as String}' >";
      content = content.replaceAll(placeholder, widgetFormattedStr);
    }
  }
  return {
    "id": message['id'],
    "role": message['role'],
    "content": content,
    "createdAt": message['createdAt'],
    "agentConfig": message['agentConfig'],
  };
}).toList();

  // Prepara il payload per l'API
  final payload = jsonEncode({
    "chain_id": chainIdToUse,
    "query": {
      "input": input,
      "chat_history": transformedChatHistory
    },
    "inference_kwargs": {}
  });

  try {
    // Esegui la fetch
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

    // Verifica lo stato della risposta
    final ok = js_util.getProperty(response, 'ok') as bool;
    if (!ok) {
      throw Exception('Network response was not ok');
    }

    // Recupera il body dello stream
    final body = js_util.getProperty(response, 'body');
    if (body == null) {
      throw Exception('Response body is null');
    }

    // Ottieni un reader per leggere lo stream chunk-by-chunk
    final reader = js_util.callMethod(body, 'getReader', []);

    // Qui memorizziamo l'intero testo completo (con i widget originali)
    final StringBuffer fullOutput = StringBuffer();

    // Qui memorizziamo solo ciò che mostriamo in tempo reale
    final StringBuffer displayOutput = StringBuffer();

    // Variabili per la logica di scanning
    bool insideWidgetBlock = false;      // Siamo dentro < TYPE='WIDGET' ... > ?
    final StringBuffer widgetBuffer = StringBuffer(); // Accumula i caratteri mentre siamo dentro il blocco widget

    final String startPattern = "< TYPE='WIDGET'";
    final int patternLength = startPattern.length;

    // Un piccolo buffer circolare per rilevare retroattivamente la comparsa di startPattern
    final List<int> ringBuffer = [];

    // Funzione locale che processa un chunk di testo
void processChunk(String chunk) {
  // Costante per mostrare la rotella di caricamento durante la costruzione del widget
  const String spinnerPlaceholder = "[WIDGET_SPINNER]";

  for (int i = 0; i < chunk.length; i++) {
    final c = chunk[i];

    // Aggiungiamo SEMPRE il carattere al fullOutput (testo completo, inclusi widget)
    fullOutput.write(c);

    if (!insideWidgetBlock) {
      // Non siamo ancora dentro un blocco < TYPE='WIDGET', quindi:
      // 1) Aggiorniamo il ringBuffer
      ringBuffer.add(c.codeUnitAt(0));
      if (ringBuffer.length > 32) {
        ringBuffer.removeAt(0);
      }

      // 2) Aggiungiamo il carattere visibile al displayOutput
      displayOutput.write(c);

      // 3) Controlliamo se negli ultimi caratteri di ringBuffer compare la stringa "< TYPE='WIDGET'"
      if (ringBuffer.length >= patternLength) {
        final startIndex = ringBuffer.length - patternLength;
        final recent = String.fromCharCodes(ringBuffer.sublist(startIndex));
        if (recent == startPattern) {
          // Abbiamo riconosciuto retroattivamente l'inizio di un blocco widget

          // a) Rimuoviamo dal displayOutput i caratteri del pattern
          final newLength = displayOutput.length - patternLength;
          if (newLength >= 0) {
            final soFar = displayOutput.toString();
            displayOutput.clear();
            displayOutput.write(soFar.substring(0, newLength));
          }

          // b) Entriamo nel blocco widget e puliamo il widgetBuffer
          insideWidgetBlock = true;
          widgetBuffer.clear();
          widgetBuffer.write(startPattern);

          // c) Mostriamo subito una rotella di caricamento
          displayOutput.write(spinnerPlaceholder);

            // d) AGGIUNGI anche un “fake widget” in widgetDataList, associato allo stesso placeholder
  final lastMsg = messages[messages.length - 1];
  List<dynamic> wList = lastMsg['widgetDataList'] ?? [];
  wList.add({
    "_id": "SpinnerFake_" + DateTime.now().millisecondsSinceEpoch.toString(),
    "widgetId": "SpinnerPlaceholder",
    "jsonData": {}, // Nessun dato extra
    "placeholder": spinnerPlaceholder
  });
  lastMsg['widgetDataList'] = wList;

  // e) setState per ridisegnare subito
  setState(() {
    messages[messages.length - 1]['content'] = displayOutput.toString() + "▌";
  });

        }
      }
    } else {
      // Siamo dentro un blocco < TYPE='WIDGET' ... >
      widgetBuffer.write(c);

      // Se incontriamo il carattere di chiusura '>', consideriamo il blocco completato
      if (c == '>') {
        // 1) Rimuoviamo subito la rotella di caricamento dal displayOutput
        String currentText = displayOutput.toString();
        if (currentText.contains(spinnerPlaceholder)) {
          currentText = currentText.replaceFirst(spinnerPlaceholder, "");
          displayOutput.clear();
          displayOutput.write(currentText);
        }

        // 2) Finalizziamo subito il blocco widget chiamando la funzione di parsing
        final widgetBlock = widgetBuffer.toString();
        final placeholder = _finalizeWidgetBlock(widgetBlock);
        // Inseriamo il placeholder restituito al posto dello spinner
        displayOutput.write(placeholder);

        // 3) Uscita dal blocco widget
        insideWidgetBlock = false;
      }
    }
  }

  // Aggiorniamo la UI con il contenuto visibile corrente (aggiungendo un cursore "▌")
  setState(() {
    messages[messages.length - 1]['content'] = displayOutput.toString();
  });
}


    // Legge ricorsivamente i chunk
    void readChunk() {
      js_util
          .promiseToFuture(js_util.callMethod(reader, 'read', []))
          .then((result) {
        final done = js_util.getProperty(result, 'done') as bool;
        if (!done) {
          final value = js_util.getProperty(result, 'value');
          // Converte in stringa
          final bytes = _convertJSArrayBufferToDartUint8List(value);
          final chunkString = utf8.decode(bytes);

          // Processa il chunk (token per token)
          processChunk(chunkString);

          // Continua a leggere
          readChunk();
        } else {
          // Fine streaming
          // A questo punto, fullOutput contiene TUTTO il testo (inclusi < TYPE='WIDGET'...>)
          // displayOutput conteneva la parte "visibile" durante lo stream
          // Ora finalizziamo
          setState(() {
            // Mettiamo dentro 'content' tutto il displayOutput
            messages[messages.length - 1]['content'] = displayOutput.toString();
            // Associa la configurazione dell'agente al messaggio
            messages[messages.length - 1]['agentConfig'] = agentConfiguration;
          });

          // Ora effettuiamo il parse effettivo di fullOutput
          final parsed = _parsePotentialWidgets(fullOutput.toString());

          // Sovrascriviamo il content finale con il testo pulito e la widgetDataList
          setState(() {
            messages[messages.length - 1]['content'] = parsed.text;
            messages[messages.length - 1]['widgetDataList'] = parsed.widgetList;
          });

          // Salviamo la conversazione (DB/localStorage)
          _saveConversation(messages);
        }
      }).catchError((error) {
        // Errore durante la lettura del chunk
        print('Errore durante la lettura del chunk: $error');
        setState(() {
          messages[messages.length - 1]['content'] = 'Errore: $error';
        });
      });
    }

    // Avvia la lettura dei chunk
    readChunk();

  } catch (e) {
    // Gestione errori fetch
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

class NButtonWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String) onReply;

  const NButtonWidget({Key? key, required this.data, required this.onReply})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttons = data["buttons"] as List<dynamic>? ?? [];
    return Wrap(
      alignment: WrapAlignment.center, // Centra i pulsanti orizzontalmente
      spacing: 8.0, // Spazio orizzontale tra i pulsanti
      runSpacing: 8.0, // Spazio verticale tra le righe
      children: buttons.map((btn) {
        return ElevatedButton(
          onPressed: () {
            final replyText = btn["reply"] ?? "Nessuna reply definita";
            onReply(replyText);
          },
          style: ButtonStyle(
            // Sfondo di default blu, hover bianco
            backgroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return Colors.white;
                return Colors.blue;
              },
            ),
            // Testo di default bianco, hover blu
            foregroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return Colors.blue;
                return Colors.white;
              },
            ),
            // Bordo visibile solo in hover (blu) altrimenti nessun bordo
            side: MaterialStateProperty.resolveWith<BorderSide>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered))
                  return const BorderSide(color: Colors.blue);
                return BorderSide.none;
              },
            ),
            // Angoli arrotondati a 8
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: Text(btn["label"] ?? "Senza etichetta"),
        );
      }).toList(),
    );
  }
}
