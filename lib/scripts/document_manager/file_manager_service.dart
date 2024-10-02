import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_app/databases_manager/database_service.dart';
import 'package:flutter_app/databases_manager/database_model.dart';

class FileManagerService {
  final DatabaseService _databaseService;
  final String dbName;
  final String folderCollection = "folders";
  final String documentCollection = "documents";

  FileManagerService(this.dbName) : _databaseService = DatabaseService();

  // Fetch the entire folder tree
  Future<FolderInfo> fetchFolderTree(String token) async {
    // Fetch folders and documents data
    List<Map<String, dynamic>> folderData = await _databaseService.fetchCollectionData(dbName, folderCollection, token);
    List<Map<String, dynamic>> documentData = await _databaseService.fetchCollectionData(dbName, documentCollection, token);

    // Deserialize the data into FolderInfo and DocumentInfo objects
    List<FolderInfo> folders = folderData.map((json) => FolderInfo.fromJson(json)).toList();
    List<DocumentInfo> documents = documentData.map((json) => DocumentInfo.fromJson(json)).toList();

    // Build and return the folder tree
    return buildFolderTree(folders, documents);
  }

  // Save a document to the database
  Future<Map<String, dynamic>> saveDocument(DocumentInfo document, String token) async {
    return await _databaseService.addDataToCollection(dbName, documentCollection, document.toJson(), token);
  }

  // Save a folder to the database
  Future<Map<String, dynamic>> saveFolder(FolderInfo folder, String token) async {
    return await _databaseService.addDataToCollection(dbName, folderCollection, folder.toJson(), token);
  }

 // Update an existing document in the database
  Future<void> updateDocument(String documentId, DocumentInfo document, String token) async {
    await _databaseService.updateCollectionData(dbName, documentCollection, documentId, document.toJson(), token);
  }

  // Update an existing folder in the database
  Future<void> updateFolder(String folderId, FolderInfo folder, String token) async {
    await _databaseService.updateCollectionData(dbName, folderCollection, folderId, folder.toJson(), token);
  }

  // Delete a document from the database
  Future<void> deleteDocument(String documentId, String token) async {
    await _databaseService.deleteCollectionData(dbName, documentCollection, documentId, token);
  }

  // Delete a folder from the database
  Future<void> deleteFolder(String folderId, String token) async {
    await _databaseService.deleteCollectionData(dbName, folderCollection, folderId, token);
  }
  
// Metodo per costruire l'albero delle cartelle e documenti
Future<FolderInfo> buildFolderTree(List<FolderInfo> folders, List<DocumentInfo> documents) async {
  // Creiamo la cartella Root manualmente
  FolderInfo root = FolderInfo.root();

  // Mappa per tenere traccia delle cartelle in base al loro percorso assoluto
  Map<String, FolderInfo> folderMap = {for (var folder in folders) folder.absolutePath!: folder};
  
  // Aggiungiamo la cartella root alla mappa
  folderMap['Root'] = root;

  print("#" * 120);
  print("Folder Map iniziale: ${folderMap}");
  print("#" * 120);

  // Aggiunge i documenti alle rispettive cartelle
  for (var document in documents) {
    // Individua la cartella a cui appartiene il documento basato sul percorso assoluto
    String? parentPath = document.absolutePath?.substring(0, document.absolutePath!.lastIndexOf('/'));
    
    if (parentPath != null && folderMap.containsKey(parentPath)) {
      folderMap[parentPath]!.addDocuments([document]);
    } else {
      // Se non troviamo la cartella genitore, possiamo aggiungere il documento alla root
      root.addDocuments([document]);
    }
  }

  print("#" * 120);
  print("Folder Map dopo aver aggiunto i documenti: ${folderMap}");
  print("#" * 120);

  // Costruisce la gerarchia delle cartelle
  for (var folder in folders) {
    if (folder.absolutePath != null) {
      String parentPath = folder.absolutePath!.substring(0, folder.absolutePath!.lastIndexOf('/'));

      if (folderMap.containsKey(parentPath)) {
        folderMap[parentPath]!.addFolder(folder);
      } else {
        // Se la cartella non ha un genitore, la aggiungiamo alla root
        root.addFolder(folder);
      }
    }
  }

  print("#" * 120);
  print("Folder Map finale: ${folderMap}");
  print("#" * 120);

  // Restituiamo la root popolata con le sue sottocartelle e documenti
  return root;
}

}


class DocumentInfo {
  final String name;
  final String type;
  String? databaseId; // ID univoco nel database
  final String? documentId; // ID univoco del documento
  String? absolutePath; // Percorso assoluto del documento
  int size;
  Uint8List bytes;
  DateTime uploadDate;
  DateTime lastModifiedDate;

  DocumentInfo({
    required this.name,
    required this.type,
    this.databaseId, // Valore di default null
    this.documentId, // Valore di default null
    this.absolutePath, // Valore di default null
    required this.size,
    required this.bytes,
    required this.uploadDate,
    required this.lastModifiedDate,
  });

// Serializzazione in JSON per il database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'document_id': documentId,
      'databaseId': databaseId,
      'absolute_path': absolutePath,
      'size': size,
      'bytes': base64Encode(bytes),
      'upload_date': uploadDate.toIso8601String(),
      'last_modified_date': lastModifiedDate.toIso8601String(),
    };
  }

  // Deserializzazione da JSON dal database
  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      name: json['name'] as String,
      type: json['type'] as String,
      databaseId: json['_id'] as String?,
      documentId: json['document_id'] as String?,
      absolutePath: json['absolute_path'] as String?,
      size: json['size'] as int,
      bytes: base64Decode(json['bytes'] as String),
      uploadDate: DateTime.parse(json['upload_date'] as String),
      lastModifiedDate: DateTime.parse(json['last_modified_date'] as String),
    );
  }
  
  static DocumentInfo clone(DocumentInfo document) {
    return DocumentInfo(
      name: document.name,
      type: document.type,
      databaseId: document.databaseId,
      documentId: document.documentId,
      absolutePath: document.absolutePath,
      size: document.size,
      bytes: document.bytes,
      uploadDate: document.uploadDate,
      lastModifiedDate: document.lastModifiedDate,
    );
  }

  // Salva un documento nel database
  Future<Map<String, dynamic>> saveDocument(String token) async {
  return await FileManagerService("sans7-database_0").saveDocument(this, token);
}

// Aggiorna un documento esistente nel database
Future<void> updateDocument(String token) async {
  if (databaseId != null) {
    await FileManagerService("sans7-database_0").updateDocument(databaseId!, this, token);
  } else {
    throw Exception("Document ID non può essere nullo");
  }
}

// Elimina un documento dal database
Future<void> deleteDocument(String token) async {
  if (databaseId != null) {
    await FileManagerService("sans7-database_0").deleteDocument(databaseId!, token);
  } else {
    throw Exception("Document ID non può essere nullo");
  }
}
}

class FolderInfo {
  String name;
  String? databaseId; // ID univoco nel database
  final String? folderId; // ID univoco della cartella
  String? absolutePath; // Percorso assoluto della cartella
  List<DocumentInfo> documents = [];
  List<FolderInfo> subFolders = [];
  DateTime creationDate;
  DateTime lastModifiedDate;
  FolderInfo? _parent;  // Riferimento alla cartella genitore (privato per evitare modifiche esterne)

  FolderInfo({
    required this.name,
    this.databaseId, // Valore di default null
    this.folderId, // Valore di default null
    this.absolutePath, // Valore di default null
    required this.creationDate,
    required this.lastModifiedDate,
    FolderInfo? parent,
  }) : _parent = parent;

// Serializzazione in JSON per il database
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'folder_id': folderId,
      'databaseId': databaseId,
      'absolute_path': absolutePath,
      'creation_date': creationDate.toIso8601String(),
      'last_modified_date': lastModifiedDate.toIso8601String(),
      'parent_id': _parent?.folderId,
    };
  }

  void setParent(FolderInfo? parent) {
    _parent = parent;
  }

  // Deserializzazione da JSON dal database
  factory FolderInfo.fromJson(Map<String, dynamic> json) {
    return FolderInfo(
      name: json['name'] as String,
      databaseId: json['_id'] as String?,
      folderId: json['folder_id'] as String?,
      absolutePath: json['absolute_path'] as String?,
      creationDate: DateTime.parse(json['creation_date'] as String),
      lastModifiedDate: DateTime.parse(json['last_modified_date'] as String),
    );
  }

  // Getter per il parent, con controllo contro cicli
  FolderInfo? get parent => _parent;

  // Metodo per ottenere il percorso completo della cartella
  String get fullPath {
    if (_parent == null) {
      return absolutePath ?? name; // Se è la root, ritorna il percorso assoluto o solo il nome
    } else {
      return '${_parent!.fullPath}/$name'; // Concatenazione ricorsiva dei nomi dei genitori
    }
  }

  static FolderInfo root() {
    return FolderInfo(
      name: "Root",
      creationDate: DateTime.now(),
      lastModifiedDate: DateTime.now(),
    );
  }

  static FolderInfo empty() {
    return FolderInfo(
      name: "",
      creationDate: DateTime.now(),
      lastModifiedDate: DateTime.now(),
    );
  }

  // Metodo per clonare una cartella
  static FolderInfo clone(FolderInfo folder) {
    FolderInfo clonedFolder = FolderInfo(
      name: folder.name,
      databaseId: folder.databaseId,
      folderId: folder.folderId,
      absolutePath: folder.absolutePath,
      creationDate: folder.creationDate,
      lastModifiedDate: folder.lastModifiedDate,
      parent: folder._parent, // Preserva il riferimento al genitore
    );
    clonedFolder.documents.addAll(folder.documents.map((doc) => DocumentInfo.clone(doc)).toList());
    clonedFolder.subFolders.addAll(folder.subFolders.map((subFolder) => FolderInfo.clone(subFolder)).toList());
    clonedFolder.subFolders.forEach((subFolder) {
      subFolder._parent = clonedFolder; // Aggiorna il riferimento al genitore nelle sottocartelle
    });
    return clonedFolder;
  }

  bool get isEmpty => name.isEmpty;

  void addDocuments(List<DocumentInfo> newDocuments) {
    documents.addAll(newDocuments);
    _updateLastModified();
  }

  void addFolder(FolderInfo newFolder) {
    // Imposta il genitore della nuova cartella con controllo
    if (newFolder != this && !_isDescendantOf(newFolder)) {
      newFolder._parent = this; 
      subFolders.add(newFolder);
      _updateLastModified();
    } else {
      throw ArgumentError("Cannot add folder to itself or to a descendant");
    }
  }

  bool _isDescendantOf(FolderInfo folder) {
    FolderInfo? current = this;
    while (current != null) {
      if (current == folder) {
        return true;
      }
      current = current._parent;
    }
    return false;
  }

  void removeFolderAt(int index) {
    subFolders.removeAt(index);
    _updateLastModified();
  }

  void removeDocumentAt(int index) {
    documents.removeAt(index);
    _updateLastModified();
  }

  void _updateLastModified() {
    lastModifiedDate = DateTime.now();
  }

  int get totalSize {
    int totalSize = documents.fold(0, (sum, doc) => sum + doc.size);
    for (var folder in subFolders) {
      totalSize += folder.totalSize;
    }
    return totalSize;
  }

  int get totalItems => subFolders.length + documents.length;

  // Salva una cartella nel database
Future<Map<String, dynamic>> saveFolder(String token) async {
  return await FileManagerService("sans7-database_0").saveFolder(this, token);
}

// Aggiorna una cartella esistente nel database
Future<void> updateFolder(String token) async {
  if (databaseId != null) {
    await FileManagerService("sans7-database_0").updateFolder(databaseId!, this, token);
  } else {
    throw Exception("Folder ID non può essere nullo");
  }
}

// Elimina una cartella dal database
Future<void> deleteFolder(String token) async {
  if (databaseId != null) {
    await FileManagerService("sans7-database_0").deleteFolder(databaseId!, token);
  } else {
    throw Exception("Folder ID non può essere nullo");
  }
}
}
