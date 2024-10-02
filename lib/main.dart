import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';  // Aggiungi il pacchetto TTS
import 'package:flutter/services.dart';  // Per il pulsante di copia
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Per il color picker
import 'context_page.dart'; // Importa altri pacchetti necessari
import 'package:flutter/services.dart' show rootBundle;  // Import necessario per caricare file JSON
import 'dart:convert';  // Per il parsing JSON
import 'context_api_sdk.dart';  // Importa lo script SDK

void main() {
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
}

class ChatBotPage extends StatefulWidget {
  @override
  _ChatBotPageState createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final List<Map<String, String>> messages = [];
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

// Aggiungi questa variabile per contenere la chat history simulata
List<dynamic> _chatHistory = [];

// Metodo per caricare la chat history dal file JSON
Future<void> _loadChatHistory() async {
  try {
    final String response = await rootBundle.loadString('assets/chat_history.json');  // Assicurati che il file JSON sia in 'assets'
    final data = await json.decode(response);
    setState(() {
      _chatHistory = data['chatHistory'];  // Assumi che il JSON abbia una chiave 'chatHistory'
    });
  } catch (e) {
    print('Errore nel caricamento della chat history: $e');
  }
}

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();  // Inizializza FlutterTTS
    _loadAvailableContexts();  // Carica i contesti esistenti al caricamento della pagina
 
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ChatBot',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF435566), // Imposta il colore personalizzato
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            setState(() {
              isExpanded = !isExpanded;  // Alterna collasso ed espansione
              if (isExpanded) {
                sidebarWidth = 500.0;  // Imposta la larghezza a 500 pixel alla prima espansione
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
                  if (sidebarWidth > 500) sidebarWidth = 500;  // Larghezza massima
                });
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),  // Animazione per l'espansione e il collasso
              width: sidebarWidth,
              color: Color(0xFF435566), // Colonna laterale con colore personalizzato
              child: sidebarWidth > 0
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
         ListTile(
  leading: Icon(Icons.chat, color: Colors.white),
  title: Text('Conversazioni', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showKnowledgeBase = false;  // Nascondi la pagina di gestione dei contesti
      showSettings = false;
      _loadChatHistory();  // Carica la chat history simulata
    });
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
  },
),
ListTile(
  leading: Icon(Icons.settings, color: Colors.white),
  title: Text('Impostazioni', style: TextStyle(color: Colors.white)),
  onTap: () {
    setState(() {
      showSettings = true;
    });
  },
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
          Expanded(
            child: SingleChildScrollView(
              child: showSettings
                  ? _buildSettingsSection() // Mostra impostazioni TTS e customizzazione grafica
                  : SizedBox.shrink(), // Placeholder per altre sezioni
            ),
          )
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
              border: Border.all(color: Color(0xFF435566), width: 2.0),  // Bordi dello stesso colore dell'AppBar
              borderRadius: BorderRadius.circular(8.0),  // Arrotonda i bordi
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
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
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
                                margin: isUser
                                    ? const EdgeInsets.only(left: 50.0)
                                    : const EdgeInsets.only(right: 50.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MarkdownBody(data: message['content'] ?? ''),
                                    if (!isUser && message['content'] != null && message['content']!.isNotEmpty) // Se è un messaggio del chatbot e c'è contenuto
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.volume_up,
                                              size: 20.0, // Ridimensiona l'icona
                                            ),
                                            onPressed: () {
                                              if (_isPlaying) {
                                                _stopSpeaking();
                                              } else {
                                                _speak(message['content'] ?? ''); // Text-to-Speech
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.thumb_up,
                                              size: 20.0,
                                            ),
                                            onPressed: () {
                                              // Placeholder per feedback positivo
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.thumb_down,
                                              size: 20.0,
                                            ),
                                            onPressed: () {
                                              // Placeholder per feedback negativo
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy,
                                              size: 20.0,
                                            ),
                                            onPressed: () {
                                              _copyToClipboard(message['content'] ?? '');
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
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
          backgroundColor: Color(0xFF435566),
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
              borderSide: BorderSide(color: Color(0xFF435566)), // Bordi colorati
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
          backgroundColor: Color(0xFF435566),
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
          backgroundColor: Color(0xFF435566),
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

// Funzione per aprire il dialog di selezione del contesto e modello
void _showContextDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          // Utilizziamo StateSetter per mantenere lo stato locale all'interno del dialog
          return AlertDialog(
            title: Text('Seleziona Contesto e Modello'),
            content: SingleChildScrollView(  // Aggiungi uno scroll se il contenuto eccede l'altezza
              child: Container(
                width: double.maxFinite,  // Permette alla finestra di dialogo di adattarsi alla larghezza disponibile
                child: Column(
                  mainAxisSize: MainAxisSize.min,  // Imposta le dimensioni minime in base al contenuto
                  children: [
                    // Sezione per la selezione del contesto
                    SizedBox(
                      height: 200,  // Limita l'altezza per evitare overflow
                      child: _buildContextList((String selected) {
                        setState(() {
                          _selectedContext = selected;  // Aggiorna immediatamente il contesto selezionato
                          // Passa anche il modello selezionato ogni volta che cambia il contesto
                          set_context(_selectedContext, _selectedModel);
                        });
                      }),
                    ),
                    //SizedBox(height: 16.0),  // Spaziatura tra la sezione contesto e la sezione modello
                    //Text('Seleziona Modello', style: TextStyle(fontWeight: FontWeight.bold)),
                    //_buildModelSelector(setState),  // Aggiungi il selettore di modelli
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                child: Text('Annulla'),
                onPressed: () {
                  Navigator.of(context).pop();  // Chiudi il dialog senza salvare
                },
              ),
              ElevatedButton(
                child: Text('Conferma'),
                onPressed: () {
                  // Salva il contesto e il modello selezionato
                  set_context(_selectedContext, _selectedModel);  // Invoca la funzione set_context con entrambi i valori aggiornati
                  Navigator.of(context).pop();  // Chiudi il dialog
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
        selectedColor: Color(0xFF435566),  // Colore selezionato
        backgroundColor: Colors.grey[200],  // Colore di default
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,  // Cambia il colore del testo quando selezionato
        ),
      );
    }).toList(),
  );
}


 // Funzione per creare la lista di contesti visualizzati come schede
Widget _buildContextList(Function(String) onContextSelected) {
  return GridView.builder(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,  // Numero di colonne nel grid
      mainAxisSpacing: 5.0,  // Spaziatura verticale tra le schede
      crossAxisSpacing: 5.0,  // Spaziatura orizzontale tra le schede
      childAspectRatio: 4.0,  // Rapporto tra larghezza e altezza delle schede
    ),
    itemCount: _availableContexts.length,
    shrinkWrap: true,
    itemBuilder: (context, index) {
      final contextMetadata = _availableContexts[index];
      final isSelected = _selectedContext == contextMetadata.path;

      return GestureDetector(
        onTap: () {
          // Quando si clicca su una scheda, aggiorna lo stato e chiama il callback
          onContextSelected(contextMetadata.path);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Color(0xFF435566) : Colors.transparent,  // Bordi colorati solo se selezionato
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.white,  // Sfondo bianco per tutte le schede
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),  // Aggiunge un'ombra leggera
                blurRadius: 5.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              contextMetadata.path,  // Mostra il nome del contesto
              style: TextStyle(
                color: isSelected ? Color(0xFF435566) : Colors.black,  // Cambia colore del testo se selezionato
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,  // Grassetto se selezionato
              ),
            ),
          ),
        ),
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

  Future<void> _handleUserInput(String input) async {
    if (input.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': input});
      fullResponse = ""; // Reset della risposta completa
    });

    // Placeholder per la risposta del bot
    setState(() {
      messages.add({'role': 'assistant', 'content': ''});
    });

    // Pulisce il campo di input dopo l'invio del messaggio
    _controller.clear();

    await _sendMessageToAPI(input);
  }

  Future<void> _sendMessageToAPI(String input) async {

    final url = "http://34.140.110.56:8100/chains/stream_chain";
    // Usa il contesto selezionato per configurare il chain_id
    final chainId = "${_selectedContext}_qa_chain";  // Costruisce il chain_id basato sul contesto

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
            print(nonDecodedChunk);

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
            // Fine lettura
            setState(() {
              // Rimuove il cursore "▌" e finalizza la risposta
              messages[messages.length - 1]['content'] = fullResponse;
            });
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
