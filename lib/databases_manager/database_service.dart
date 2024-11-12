import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'database_model.dart';

class DatabaseService {
  String? baseUrl;

  // Funzione per caricare la configurazione dal file config.json
  Future<void> loadConfig() async {
    //final String response = await rootBundle.loadString('assets/config.json');
    //final data = jsonDecode(response);
        final data = {
    "backend_api": "http://127.0.0.1:8095",
    "nlp_api": "http://127.0.0.1:8100" ,
    "chatbot_nlp_api": "http://127.0.0.1:8080",
    };
    baseUrl = data['backend_api'];
  }

  Future<List<Database>> fetchDatabases(String token) async {
    // Controlla se baseUrl è stato caricato
    if (baseUrl == null) await loadConfig();

    final response = await http.get(
      Uri.parse("$baseUrl/databases/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      print("FetchDatabases Response: ${response.body}");
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          .map((db) => Database.fromJson(db))
          .toList();
    } else {
      print("Failed to load databases: ${response.statusCode} - ${response.body}");
      throw Exception('Failed to load databases');
    }
  }

  Future<void> createDatabase(String dbName, String token) async {
    if (baseUrl == null) await loadConfig();

    final response = await http.post(
      Uri.parse("$baseUrl/mongo/create_user_database/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"db_name": dbName}),
    );

    if (response.statusCode != 200) {
      print("Failed to create database: ${response.statusCode}");
      throw Exception('Failed to create database');
    } else {
      print("Database created successfully");
    }
  }

  Future<void> deleteDatabase(String databaseName, String token) async {
    if (baseUrl == null) await loadConfig();

    final response = await http.delete(
      Uri.parse("$baseUrl/mongo/delete_database/$databaseName"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete database: ${response.statusCode}");
      throw Exception('Failed to delete database');
    } else {
      print("Database deleted successfully");
    }
  }

  Future<List<Collection>> fetchCollections(String dbName, String token) async {
    if (baseUrl == null) await loadConfig();

    final response = await http.get(
      Uri.parse("$baseUrl/mongo/$dbName/list_collections/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> collectionsJson = jsonResponse['collections'];
      print("FetchCollections Response: $jsonResponse");
      return collectionsJson.map((col) => Collection(name: col as String)).toList();
    } else {
      print("Failed to load collections: ${response.statusCode}");
      throw Exception('Failed to load collections');
    }
  }

  Future<void> createCollection(String dbName, String collectionName, String token) async {
    if (baseUrl == null) await loadConfig();

    final url = Uri.parse("$baseUrl/mongo/$dbName/create_collection/")
      .replace(queryParameters: {"collection_name": collectionName});

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to create collection: ${response.statusCode}");
      throw Exception('Failed to create collection');
    } else {
      print("Collection created successfully");
    }
  }

  Future<void> deleteCollection(String dbName, String collectionName, String token) async {
    if (baseUrl == null) await loadConfig();

    final url = Uri.parse("$baseUrl/mongo/$dbName/delete_collection/$collectionName/");

    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete collection: ${response.statusCode}");
      throw Exception('Failed to delete collection: ${utf8.decode(response.bodyBytes)}');
    } else {
      print("Collection deleted successfully");
    }
  }

  Future<Map<String, dynamic>> addDataToCollection(String dbName, String collectionName, Map<String, dynamic> data, String token) async {
    if (baseUrl == null) await loadConfig();

    final url = Uri.parse("$baseUrl/mongo/$dbName/$collectionName/add_item");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      print("AddDataToCollection Response: $jsonResponse");
      return jsonResponse;
    } else {
      print("Failed to add data to collection: ${response.statusCode}");
      throw Exception('Failed to add data to collection');
    }
  }

  Future<void> updateCollectionData(String dbName, String collectionName, String itemId, Map<String, dynamic> data, String token) async {
    if (baseUrl == null) await loadConfig();

    final url = Uri.parse("$baseUrl/mongo/$dbName/update_item/$collectionName/$itemId");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      print("Failed to update data in collection: ${response.statusCode}");
      throw Exception('Failed to update data in collection');
    } else {
      print("Data updated successfully in collection");
    }
  }

  Future<void> deleteCollectionData(String dbName, String collectionName, String itemId, String token) async {
    if (baseUrl == null) await loadConfig();

    final url = Uri.parse("$baseUrl/mongo/$dbName/delete_item/$collectionName/$itemId");

    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete item: ${response.statusCode}");
      throw Exception('Failed to delete item: ${utf8.decode(response.bodyBytes)}');
    } else {
      print("Item deleted successfully");
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollectionData(String dbName, String collectionName, String token) async {
    if (baseUrl == null) await loadConfig();

    final response = await http.post(
      Uri.parse("$baseUrl/mongo/$dbName/get_items/$collectionName"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = (jsonDecode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
      print("FetchCollectionData Response: ${response.statusCode}");
      return jsonResponse;
    } else {
      print("Failed to load collection data: ${response.statusCode}");
      throw Exception('Failed to load collection data');
    }
  }
}
