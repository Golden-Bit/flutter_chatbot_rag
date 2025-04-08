import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_model.dart';

class DatabaseService {
  // Attenzione: metti l'URL del tuo FastAPI reale
  //String baseUrl = 'https://teatek-llm.theia-innovation.com/database/v1/mongo';
  String baseUrl = 'https://teatek-llm.theia-innovation.com/database/v1/mongo';

  Future<List<Database>> fetchDatabases(String token) async {
    // Passiamo il token come query param: ?token=$token
    final uri = Uri.parse('$baseUrl/list_databases/?token=$token');
    
    // (facoltativo) potresti tenere l'header di Authorization
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token', // eventuale, se la tua API lo usa
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Errore nel recupero dei database: ${res.body}');
    }
final rawBytes = res.bodyBytes;
final rawString = utf8.decode(rawBytes);
print("fetchCollections raw JSON: $rawString");
final data = jsonDecode(rawString);
    return (data['databases'] as List)
        .map((e) => Database.fromJson(e))
        .toList();
  }

  Future<void> createDatabase(String dbName, String token) async {
    // ?token=$token nella query
    final uri = Uri.parse('$baseUrl/create_user_database/?token=$token');
    final body = jsonEncode({'db_name': dbName});

    final res = await http.post(
      uri,
      headers: {
        //'Authorization': 'Bearer $token', // se non serve, puoi toglierlo
        'Content-Type': 'application/json',
      },
      body: body,
    );
    print(res.body);
    if (res.statusCode != 200) {
      throw Exception('Errore nella creazione del database: ${res.body}');
    }
  }

  Future<void> deleteDatabase(String databaseName, String token) async {
    final uri = Uri.parse('$baseUrl/delete_database/$databaseName/?token=$token');
    final res = await http.delete(uri/*, headers: {'Authorization': 'Bearer $token'}*/);
    if (res.statusCode != 200) {
      throw Exception('Errore nell\'eliminazione del database: ${res.body}');
    }
  }

  Future<List<Collection>> fetchCollections(String dbName, String token) async {
    final uri = Uri.parse('$baseUrl/$dbName/list_collections/?token=$token');
    final res = await http.get(uri/*, headers: {'Authorization': 'Bearer $token'}*/);
    if (res.statusCode != 200) {
      throw Exception('Errore nel recupero delle collezioni: ${res.body}');
    }
final rawBytes = res.bodyBytes;
final rawString = utf8.decode(rawBytes);
print("fetchCollections raw JSON: $rawString");
final data = jsonDecode(rawString);
    return (data as List).map((e) => Collection(name: e)).toList();
  }

  Future<void> createCollection(String dbName, String collectionName, String token) async {
    // Passiamo la query: /{db_name}/create_collection/?collection_name=XYZ&token=...
    final uri = Uri.parse('$baseUrl/$dbName/create_collection/?collection_name=$collectionName&token=$token');
    final res = await http.post(uri/*, headers: {'Authorization': 'Bearer $token'}*/);
    if (res.statusCode != 200) {
      throw Exception('Errore nella creazione della collezione: ${res.body}');
    }
  }

  Future<void> deleteCollection(String dbName, String collectionName, String token) async {
    final uri = Uri.parse('$baseUrl/$dbName/delete_collection/$collectionName/?token=$token');
    final res = await http.delete(uri/*, headers: {'Authorization': 'Bearer $token'}*/);
    if (res.statusCode != 200) {
      throw Exception('Errore nell\'eliminazione della collezione: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> addDataToCollection(
    String dbName, String collectionName, Map<String, dynamic> data, String token) async {
    final uri = Uri.parse('$baseUrl/$dbName/$collectionName/add_item/?token=$token');


final body = jsonEncode(data);
print('Sending: ${utf8.decode(utf8.encode(body))}'); // debug: forzatura UTF-8 visiva

final res = await http.post(
  uri,
  headers: {
    'Content-Type': 'application/json; charset=utf-8', // FORZA charset
  },
  body: utf8.encode(body), // <-- encode in UTF-8 esplicitamente
);
    if (res.statusCode != 200) {
      throw Exception('Errore nell\'aggiunta del dato: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<void> updateCollectionData(
    String dbName, String collectionName, String itemId, Map<String, dynamic> data, String token) async {

final body = jsonEncode(data);
print('Sending: ${utf8.decode(utf8.encode(body))}'); // debug: forzatura UTF-8 visiva


      
    final uri = Uri.parse('$baseUrl/$dbName/update_item/$collectionName/$itemId/?token=$token');

    final res = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: utf8.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Errore nell\'aggiornamento del dato: ${res.body}');
    }
  }

  Future<void> deleteCollectionData(
    String dbName, String collectionName, String itemId, String token) async {
    final uri = Uri.parse('$baseUrl/$dbName/delete_item/$collectionName/$itemId/?token=$token');

    final res = await http.delete(uri/*, headers: {'Authorization': 'Bearer $token'}*/);
    if (res.statusCode != 200) {
      throw Exception('Errore nell\'eliminazione del dato: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollectionData(
    String dbName, String collectionName, String token) async {
    // Per get_items, passiamo token e inviamo un body con un filtro vuoto
    final uri = Uri.parse('$baseUrl/$dbName/get_items/$collectionName/?token=$token');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}), // Nessun filtro
    );
    if (res.statusCode != 200) {
      throw Exception('Errore nel recupero dei dati della collezione: ${res.body}');
    }
final rawBytes = res.bodyBytes;
final rawString = utf8.decode(rawBytes);
print("fetchCollections raw JSON: $rawString");
final data = jsonDecode(rawString);
    return List<Map<String, dynamic>>.from(data);
  }
}
