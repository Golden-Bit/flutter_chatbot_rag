import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
//import 'package:http/http.dart' as http;
import 'dart:html' as html;

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

class FileUploadResponse {
  final String fileId;
  final List<String> contexts;

  FileUploadResponse({required this.fileId, required this.contexts});

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      fileId: json['file_id'],
      contexts: List<String>.from(json['contexts']),
    );
  }
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
    "chatbot_nlp_api": "https://teatek-llm.theia-innovation.com/llm-rag",
    //"chatbot_nlp_api": "http://127.0.0.1:8080"
    };
    baseUrl = data['chatbot_nlp_api']; // Carichiamo la chiave 'chatbot_nlp_api'
  }

  // Creare un nuovo contesto
Future<ContextMetadata> createContext(
    String contextName, String description, String username, String token) async {
  if (baseUrl == null) await loadConfig();

  final uri = Uri.parse('$baseUrl/contexts');

  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'context_name': contextName,
      'description': description,
      'username': username,  // Passa l'username nel body
      'token': token,        // Passa il token nel body
    }),
  );

  if (response.statusCode == 200) {
    return ContextMetadata.fromJson(jsonDecode(response.body));
  } else {
    throw ApiException('Errore durante la creazione del contesto: ${response.body}');
  }
}


  // Eliminare un contesto
Future<void> deleteContext(String contextName, String username, String token) async {
  if (baseUrl == null) await loadConfig();

  final fullContextName = '$username-$contextName';  // Usa il formato corretto

  final uri = Uri.parse('$baseUrl/contexts/$fullContextName');

  final response = await http.delete(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'  // Se il backend usa token di autorizzazione
    },
  );

  if (response.statusCode != 200) {
    throw ApiException('Errore durante l\'eliminazione del contesto: ${response.body}');
  }
}


Future<List<ContextMetadata>> listContexts(String username, String token) async {
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
    {String? description, required String fileName}
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
      'contexts': formattedContexts.join(','),
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
    String username, String token, List<String> contexts, String model) async {
  if (baseUrl == null) await loadConfig();

  // Aggiunge il prefisso 'username-' ai nomi dei contesti
  List<String> formattedContexts = contexts.map((ctx) => '$username-$ctx').toList();

  // Costruisci l'URI dell'endpoint
  final uri = Uri.parse('$baseUrl/configure_and_load_chain/');

  // Costruisci il corpo della richiesta (invio dati in formato JSON)
  final body = {
    //'username': username,      // Passiamo username per verifica lato server
    //'token': token,            // Passiamo il token per autenticazione
    'contexts': formattedContexts, // Contesti aggiornati con prefisso
    'model_name': model,
  };

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

  
  Future<void> downloadFile(String fileId) async {
    if (baseUrl == null) await loadConfig();

    // Costruisci l'URL di download
    final uri = Uri.parse('$baseUrl/download?file_id=$fileId');

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
  
}
