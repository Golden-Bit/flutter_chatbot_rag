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
    //"chatbot_nlp_api": "http://127.0.0.1:8100"
    };
    baseUrl = data['chatbot_nlp_api']; // Carichiamo la chiave 'chatbot_nlp_api'
  }

  // Creare un nuovo contesto
  Future<ContextMetadata> createContext(String contextName, {String? description}) async {
    if (baseUrl == null) await loadConfig();

    final uri = Uri.parse('$baseUrl/contexts');
    final response = await http.post(
      uri,
      body: {
        'context_name': contextName,
        if (description != null) 'description': description,
      },
    );

    if (response.statusCode == 200) {
      return ContextMetadata.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException('Errore durante la creazione del contesto: ${response.body}');
    }
  }

// Eliminare un contesto con autenticazione nell'header
Future<void> deleteContext(String username, String token, String contextName) async {
  if (baseUrl == null) await loadConfig();

  // Aggiunge il prefisso 'username-' al nome del contesto
  String formattedContextName = '$username-$contextName';

  // Costruisce l'URI dell'endpoint con il nome del contesto aggiornato
  final uri = Uri.parse('$baseUrl/contexts/$formattedContextName');

  // Effettua la richiesta DELETE con autenticazione solo negli header
  final response = await http.delete(
    uri,
    headers: {
      'Content-Type': 'application/json',
      //'Authorization': 'Bearer $token', // Aggiunto token per sicurezza
    },
  );

  if (response.statusCode != 200) {
    throw ApiException('Errore durante l\'eliminazione del contesto: ${response.body}');
  }
}


  // Elencare tutti i contesti
  Future<List<ContextMetadata>> listContexts() async {
    if (baseUrl == null) await loadConfig();

    final uri = Uri.parse('$baseUrl/contexts');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = jsonDecode(response.body);
      return jsonData.map((json) => ContextMetadata.fromJson(json)).toList();
    } else {
      throw ApiException('Errore durante il recupero dei contesti: ${response.body}');
    }
  }

  // Caricare un file su più contesti
  Future<void> uploadFileToContexts(Uint8List fileBytes, List<String> contexts, {String? description, required String fileName}) async {
    if (baseUrl == null) await loadConfig();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      // Aggiungi i contesti come parte dei campi
      request.fields['contexts'] = contexts.join(',');

      // Aggiungi la descrizione, se presente
      if (description != null) {
        request.fields['description'] = description;
      }

      // Usa il nome reale del file selezionato
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName  // Qui passiamo il nome reale del file
      ));

      // Esegui la richiesta
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
  Future<List<Map<String, dynamic>>> listFiles({List<String>? contexts}) async {
    if (baseUrl == null) await loadConfig();

    Uri uri;
    if (contexts != null && contexts.isNotEmpty) {
      uri = Uri.parse('$baseUrl/files').replace(queryParameters: {
        'contexts': contexts.join(','),
      });
    } else {
      uri = Uri.parse('$baseUrl/files');
    }

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      List<Map<String, dynamic>> files = List<Map<String, dynamic>>.from(jsonDecode(response.body));

      if (contexts != null && contexts.isNotEmpty) {
        files = files.where((file) {
          String filePath = file['path'] ?? '';
          List<String> pathSegments = filePath.split('/');

          if (pathSegments.length < 2) {
            return false;
          }

          String penultimateSegment = pathSegments[pathSegments.length - 2];

          return contexts.contains(penultimateSegment);
        }).toList();
      }

      return files;
    } else {
      throw ApiException('Errore durante il recupero dei file: ${response.body}');
    }
  }

  // Eliminare file tramite UUID o path
  Future<void> deleteFile({String? fileId, String? filePath}) async {
    if (baseUrl == null) await loadConfig();

    if (filePath != null) {
      // Estrai gli ultimi due elementi del percorso
      List<String> pathSegments = filePath.split('/');
      if (pathSegments.length >= 2) {
        filePath = '${pathSegments[pathSegments.length - 2]}/${pathSegments.last}';
      } else {
        throw ApiException('Errore: il percorso fornito non ha abbastanza segmenti.');
      }
    }

    // Costruisci l'URI con i parametri di query
    Uri uri = Uri.parse('$baseUrl/files').replace(queryParameters: {
      if (fileId != null) 'file_id': fileId,
      if (filePath != null) 'file_path': filePath,
    });

    // Effettua la richiesta DELETE con i parametri di query
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw ApiException('Errore durante l\'eliminazione del file: ${response.body}');
    }
  }

  /// Metodo aggiornato per supportare la nuova versione dell'endpoint
  Future<Map<String, dynamic>> configureAndLoadChain(List<String> contexts, String model) async {
    if (baseUrl == null) await loadConfig();

    // Costruisci l'URI dell'endpoint
    final uri = Uri.parse('$baseUrl/configure_and_load_chain/');

    // Costruisci il corpo della richiesta (invio dati in formato JSON)
    final body = {
      'contexts': contexts,
      'model_name': model,
    };

    try {
      // Effettua la richiesta POST
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json', // Cambia il Content-Type per supportare JSON
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
