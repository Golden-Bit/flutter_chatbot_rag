// database_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_model.dart';

class DatabaseService {
  final String baseUrl = "http://34.140.110.56:8095";

  Future<List<Database>> fetchDatabases(String token) async {
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
    final response = await http.post(
      Uri.parse("$baseUrl/mongo/create_user_database/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"db_name": dbName}),
    );

    if (response.statusCode != 200) {
      print("Failed to create database: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to create database');
    } else {
      print("Database created successfully");
    }
  }

  Future<void> deleteDatabase(String databaseName, String token) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/mongo/delete_database/$databaseName"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete database: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to delete database');
    } else {
      print("Database deleted successfully");
    }
  }

  Future<List<Collection>> fetchCollections(String dbName, String token) async {
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
      print("Failed to load collections: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to load collections');
    }
  }

  Future<void> createCollection(String dbName, String collectionName, String token) async {
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
      print("Failed to create collection: ${response.statusCode}"); //  - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to create collection');
    } else {
      print("Collection created successfully");
    }
  }

  Future<void> deleteCollection(String dbName, String collectionName, String token) async {
    final url = Uri.parse("$baseUrl/mongo/$dbName/delete_collection/$collectionName/");

    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete collection: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to delete collection: ${utf8.decode(response.bodyBytes)}');
    } else {
      print("Collection deleted successfully");
    }
  }

  Future<Map<String, dynamic>> addDataToCollection(String dbName, String collectionName, Map<String, dynamic> data, String token) async {
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
      print("Failed to add data to collection: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to add data to collection');
    }
  }

  Future<void> updateCollectionData(String dbName, String collectionName, String itemId, Map<String, dynamic> data, String token) async {
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
      print("Failed to update data in collection: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to update data in collection');
    } else {
      print("Data updated successfully in collection");
    }
  }

  Future<void> deleteCollectionData(String dbName, String collectionName, String itemId, String token) async {
    final url = Uri.parse("$baseUrl/mongo/$dbName/delete_item/$collectionName/$itemId");

    final response = await http.delete(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "accept": "application/json",
      },
    );

    if (response.statusCode != 200) {
      print("Failed to delete item: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to delete item: ${utf8.decode(response.bodyBytes)}');
    } else {
      print("Item deleted successfully");
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollectionData(String dbName, String collectionName, String token) async {
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
      print("Failed to load collection data: ${response.statusCode}"); // - ${utf8.decode(response.bodyBytes)}");
      throw Exception('Failed to load collection data');
    }
  }
}