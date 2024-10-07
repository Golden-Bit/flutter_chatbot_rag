import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// Base URL per il server (modificabile per localhost o remoto)
const String BASE_URL = 'http://34.140.110.56:8080';

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
  final String baseUrl;

  ContextApiSdk({this.baseUrl = BASE_URL});

  // Creare un nuovo contesto
  Future<ContextMetadata> createContext(String contextName, {String? description}) async {
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

  // Eliminare un contesto
  Future<void> deleteContext(String contextName) async {
    final uri = Uri.parse('$baseUrl/contexts/$contextName');
    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw ApiException('Errore durante l\'eliminazione del contesto: ${response.body}');
    }
  }

  // Elencare tutti i contesti
  Future<List<ContextMetadata>> listContexts() async {
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

// Metodo per configurare e caricare una chain basata su un contesto
Future<Map<String, dynamic>> configureAndLoadChain(String context, String model) async {
  // Costruiamo l'URL con il parametro context nella query string
  final uri = Uri.parse('$BASE_URL/configure_and_load_chain/?context=$context&model=$model');
  
  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',  // Impostiamo l'header per l'invio di JSON
    },
  );

  if (response.statusCode == 200) {
    // Restituiamo la risposta in formato JSON se la richiesta ha successo
    return jsonDecode(response.body);
  } else {
    // Gestiamo l'errore nel caso in cui lo stato della risposta non sia 200
    throw ApiException('Errore durante la configurazione e il caricamento della chain: ${response.body}');
  }
}

}