import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
  
  // Variabili per gestire la colonna espandibile e ridimensionabile
  bool isExpanded = false;
  double sidebarWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chatbot Flutter'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            setState(() {
              isExpanded = !isExpanded; // Espandi o collassa la colonna
            });
          },
        ),
      ),
      body: Row(
        children: [
          // Colonna laterale espandibile e ridimensionabile
          if (isExpanded)
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  sidebarWidth += details.delta.dx; // Ridimensiona la larghezza
                  if (sidebarWidth < 100) sidebarWidth = 100; // Limite minimo
                  if (sidebarWidth > 300) sidebarWidth = 300; // Limite massimo
                });
              },
              child: Container(
                width: sidebarWidth,
                color: Colors.blue[900],
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.zero,
                      color: Colors.blue[900], // Imposta il colore blu notte
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Menu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.chat, color: Colors.white),
                            title: Text('Conversazioni', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              // Azione per gestire le conversazioni
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.book, color: Colors.white),
                            title: Text('Basi di conoscenza', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              // Azione per gestire le basi di conoscenza
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.settings, color: Colors.white),
                            title: Text('Impostazioni', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              // Azione per gestire le impostazioni
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Corpo della chat
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 1000),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
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
                                      child: Icon(Icons.android),
                                    ),
                                  ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    margin: isUser
                                        ? const EdgeInsets.only(left: 50.0)
                                        : const EdgeInsets.only(right: 50.0),
                                    child: MarkdownBody(data: message['content'] ?? ''),
                                  ),
                                ),
                                if (isUser)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: CircleAvatar(
                                      child: Icon(Icons.person),
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
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                labelText: 'Say something...',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: _handleUserInput,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send),
                            onPressed: () => _handleUserInput(_controller.text),
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

    _controller.clear();

    await _sendMessageToAPI(input);
  }

  Future<void> _sendMessageToAPI(String input) async {
    final url = "http://34.140.110.56:8100/chains/stream_chain";

    final payload = jsonEncode({
      "chain_id": "hf-embeddings__chat-openai_qa-chain",
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
