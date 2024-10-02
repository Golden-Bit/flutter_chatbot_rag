import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter_app/databases_manager/json_viewer.dart';
import 'package:flutter_app/document_manager/html_utils.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:html/parser.dart' as parser;  // Import corretto per il parser HTML
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_app/document_manager/file_manager_service.dart';


class DocumentManagerHomePage extends StatefulWidget {
  final FolderInfo currentFolder;
  final String path;
  final String token; // Aggiunto per ricevere il token

  DocumentManagerHomePage({
    required this.currentFolder,
    required this.path,
    required this.token, // Aggiunto per ricevere il token
  });

  @override
  _DocumentManagerHomePageState createState() => _DocumentManagerHomePageState();
}

class _DocumentManagerHomePageState extends State<DocumentManagerHomePage> {

 //late Future<FolderInfo> folderTreeFuture;  // Variabile per mantenere il Future del caricamento

  @override
  void initState() {
    super.initState();
    _loadFolderTree();  // Carica la struttura delle cartelle al lancio dell'app

  }

  // Metodo per caricare l'albero delle cartelle
// Metodo per caricare l'albero delle cartelle
void _loadFolderTree() async {
  try {
    FolderInfo rootFolder = await FileManagerService("sans7-database_0").fetchFolderTree(widget.token);
    
    if (widget.path == "Root") {
      // Se siamo in root, assegna direttamente la root folder
      setState(() {
        widget.currentFolder.documents = rootFolder.documents;
        widget.currentFolder.subFolders = rootFolder.subFolders;
      });
    } else {
      // Cerca la cartella corrente basata sul path
      FolderInfo? currentFolder = _findFolderByPath(rootFolder, widget.path);
      if (currentFolder != null) {
        setState(() {
          widget.currentFolder.documents = currentFolder.documents;
          widget.currentFolder.subFolders = currentFolder.subFolders;
        });
      } else {
        print("Cartella corrente non trovata: ${widget.path}");
      }
    }
  } catch (e) {
    print("Errore nel caricamento della struttura delle cartelle: $e");
  }
}

// Funzione di ricerca per trovare la cartella corrente in base al percorso assoluto
FolderInfo? _findFolderByPath(FolderInfo root, String path) {
  if (root.absolutePath == path) {
    return root;
  }

  for (var subFolder in root.subFolders) {
    FolderInfo? result = _findFolderByPath(subFolder, path);
    if (result != null) {
      return result;
    }
  }

  return null;
}


void _pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [
      'txt', 'csv', 'xls', 'xlsx', 'pdf', 'md', 'html', 'json', 'docx', 'odt'
    ],
    allowMultiple: true,
  );

  if (result != null) {
    List<DocumentInfo> newDocuments = [];

    for (var file in result.files) {
      String absolutePath = '${widget.path}/${file.name}'; // Genera il percorso assoluto del documento

      var existingDocument = widget.currentFolder.documents.firstWhere(
        (doc) => doc.absolutePath == absolutePath,
        orElse: () => DocumentInfo(
          name: '', type: '', size: 0, bytes: Uint8List(0),
          uploadDate: DateTime.now(), lastModifiedDate: DateTime.now(),
        ),
      );

      if (existingDocument.name.isEmpty) {
        // File non esistente, aggiungi direttamente
        var newDocument = DocumentInfo(
          name: file.name,
          type: file.extension ?? 'Unknown',
          size: file.size,
          bytes: file.bytes!,
          uploadDate: DateTime.now(),
          lastModifiedDate: DateTime.now(),
          documentId: DateTime.now().millisecondsSinceEpoch.toString(), // Genera un ID univoco
          absolutePath: absolutePath, // Salva il percorso assoluto
        );
        
        final saveDocuemntResponse = await newDocument.saveDocument(widget.token); // Salva nel database
        newDocument.databaseId = saveDocuemntResponse["id"];
        newDocuments.add(newDocument);

      } else {
        // File esistente, chiedi cosa fare
        String? action = await _askOverwriteOrRename(file.name);

        if (action == 'Sovrascrivi') {
          existingDocument.bytes = file.bytes!;
          existingDocument.size = file.size;
          existingDocument.lastModifiedDate = DateTime.now();
          await existingDocument.updateDocument(widget.token); // Aggiorna nel database
        } else if (action != null && action.isNotEmpty) {
          var newDocument = DocumentInfo(
            name: action,
            type: file.extension ?? 'Unknown',
            size: file.size,
            bytes: file.bytes!,
            uploadDate: DateTime.now(),
            lastModifiedDate: DateTime.now(),
            documentId: DateTime.now().millisecondsSinceEpoch.toString(), // Genera un ID univoco
            absolutePath: '${widget.path}/$action', // Salva il percorso assoluto aggiornato
          );
          final saveDocuemntResponse = await newDocument.saveDocument(widget.token); // Salva nel database
          newDocument.databaseId = saveDocuemntResponse["id"];
          newDocuments.add(newDocument);
        }
      }
    }

    if (newDocuments.isNotEmpty) {
      setState(() {
        widget.currentFolder.addDocuments(newDocuments);
      });
    }
  }
}



Future<String?> _askOverwriteOrRename(String fileName) async {
  String newFileName = fileName;
  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('File "$fileName" esiste già. Cosa vuoi fare?'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'Inserisci un nuovo nome o lascia vuoto per sovrascrivere',
          ),
          onChanged: (value) {
            newFileName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('Sovrascrivi');
            },
            child: Text('Sovrascrivi'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(newFileName.isEmpty ? null : newFileName);
            },
            child: Text('Rinomina'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text('Annulla'),
          ),
        ],
      );
    },
  );
}

void _copyItem(int index, bool isFolder) async {
  String? destinationPath = await _promptForDestination();
  
  if (destinationPath != null && destinationPath.isNotEmpty) {
    FolderInfo? destinationFolder = _getFolderByPath(destinationPath);
    
    if (destinationFolder != null) {
      if (isFolder) {
        FolderInfo folder = widget.currentFolder.subFolders[index];
        
        // Aggiorna la lista delle sottocartelle
        destinationFolder.subFolders.removeWhere((f) => f.name.isEmpty);
        
        var existingFolder = destinationFolder.subFolders.firstWhere(
          (f) => f.name == folder.name,
          orElse: () => FolderInfo.empty(),
        );

        if (existingFolder.isEmpty) {
          // Crea una copia della cartella con un nuovo percorso assoluto e un nuovo ID
          FolderInfo newFolder = FolderInfo.clone(folder);
          newFolder.absolutePath = '$destinationPath/${newFolder.name}';
          newFolder.creationDate = DateTime.now();
          newFolder.lastModifiedDate = DateTime.now();
          newFolder.setParent(destinationFolder);

          // Salva la nuova cartella nel database
          final saveFolderResponse = await newFolder.saveFolder(widget.token);
          newFolder.databaseId = saveFolderResponse["id"];

          setState(() {
            destinationFolder.addFolder(newFolder);
          });
        } else {
          String? action = await _askOverwriteOrRenameFolder(folder.name);
          if (action == 'Sovrascrivi') {
            setState(() {
              existingFolder.lastModifiedDate = DateTime.now();
            });
            await existingFolder.updateFolder(widget.token);  // Aggiorna nel database
          } else if (action != null && action.isNotEmpty) {
            FolderInfo newFolder = FolderInfo(
              name: action,
              creationDate: DateTime.now(),
              lastModifiedDate: DateTime.now(),
              parent: destinationFolder,
              absolutePath: '$destinationPath/$action',
            );

            // Salva la nuova cartella nel database
            final saveFolderResponse = await newFolder.saveFolder(widget.token);
            newFolder.databaseId = saveFolderResponse["id"];

            setState(() {
              destinationFolder.addFolder(newFolder);
            });
          }
        }
      } else {
        DocumentInfo document = widget.currentFolder.documents[index];
        
        // Aggiorna la lista dei documenti
        destinationFolder.documents.removeWhere((doc) => doc.name.isEmpty);
        
        var existingDocument = destinationFolder.documents.firstWhere(
          (doc) => doc.name == document.name,
          orElse: () => DocumentInfo(name: '', type: '', size: 0, bytes: Uint8List(0), uploadDate: DateTime.now(), lastModifiedDate: DateTime.now()),
        );

        if (existingDocument.name.isEmpty) {
          // Crea una copia del documento con un nuovo percorso assoluto e un nuovo ID
          DocumentInfo newDocument = DocumentInfo.clone(document);
          newDocument.absolutePath = '$destinationPath/${newDocument.name}';
          newDocument.uploadDate = DateTime.now();
          newDocument.lastModifiedDate = DateTime.now();

          // Salva il nuovo documento nel database
          final saveDocumentResponse = await newDocument.saveDocument(widget.token);
          newDocument.databaseId = saveDocumentResponse["id"];

          setState(() {
            destinationFolder.addDocuments([newDocument]);
          });
        } else {
          String? action = await _askOverwriteOrRename(document.name);
          if (action == 'Sovrascrivi') {
            setState(() {
              existingDocument.bytes = document.bytes;
              existingDocument.size = document.size;
              existingDocument.lastModifiedDate = DateTime.now();
            });
            await existingDocument.updateDocument(widget.token);  // Aggiorna nel database
          } else if (action != null && action.isNotEmpty) {
            DocumentInfo newDocument = DocumentInfo(
              name: action,
              type: document.type,
              size: document.size,
              bytes: document.bytes,
              uploadDate: document.uploadDate,
              lastModifiedDate: DateTime.now(),
              absolutePath: '$destinationPath/$action',
            );

            // Salva il nuovo documento nel database
            final saveDocumentResponse = await newDocument.saveDocument(widget.token);
            newDocument.databaseId = saveDocumentResponse["id"];

            setState(() {
              destinationFolder.addDocuments([newDocument]);
            });
          }
        }
      }
      setState(() {}); // Forza l'aggiornamento della UI
    }
  }
}


/*Future<String?> _askOverwriteOrRenameFolder(String folderName) async {
  String newFolderName = folderName;
  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Cartella "$folderName" esiste già. Cosa vuoi fare?'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'Inserisci un nuovo nome o lascia vuoto per sovrascrivere',
          ),
          onChanged: (value) {
            newFolderName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('Sovrascrivi');
            },
            child: Text('Sovrascrivi'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(newFolderName.isEmpty ? null : newFolderName);
            },
            child: Text('Rinomina'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text('Annulla'),
          ),
        ],
      );
    },
  );
}*/

  Future<String?> _promptForFolderName() async {
    String folderName = "";
    return showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Folder'),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(labelText: 'Folder Name'),
            onChanged: (value) {
              folderName = value;
            },
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null); // Return null if canceled
              },
            ),
            TextButton(
              child: Text('Create'),
              onPressed: () {
                Navigator.of(context).pop(folderName); // Return folderName if created
              },
            ),
          ],
        );
      },
    );
  }

  void _downloadFile(DocumentInfo document) {
    final blob = html.Blob([document.bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", document.name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
void _createFolder() async {
  String? folderName = await _promptForFolderName();
  if (folderName != null && folderName.isNotEmpty) {
    String absolutePath = '${widget.path}/$folderName'; // Genera il percorso assoluto della cartella

    var existingFolder = widget.currentFolder.subFolders.firstWhere(
      (folder) => folder.absolutePath == absolutePath,
      orElse: () => FolderInfo.empty(),
    );

    if (existingFolder.isEmpty) {
      // Cartella non esistente, aggiungi direttamente
      FolderInfo newFolder = FolderInfo(
        name: folderName,
        creationDate: DateTime.now(),
        lastModifiedDate: DateTime.now(),
        folderId: DateTime.now().millisecondsSinceEpoch.toString(), // Genera un ID univoco
        absolutePath: absolutePath, // Salva il percorso assoluto
      );
      
      final saveFolderResponse = await newFolder.saveFolder(widget.token); // Salva nel database
      newFolder.databaseId = saveFolderResponse["id"];

      setState(() {
        widget.currentFolder.addFolder(newFolder);
      });
    } else {
      // Cartella esistente, chiedi cosa fare
      String? action = await _askOverwriteOrRenameFolder(folderName);

      if (action == 'Sovrascrivi') {
        setState(() {
          existingFolder.lastModifiedDate = DateTime.now();
        });
        await existingFolder.updateFolder(widget.token); // Aggiorna nel database
      } else if (action != null && action.isNotEmpty) {
        FolderInfo newFolder = FolderInfo(
          name: action,
          creationDate: DateTime.now(),
          lastModifiedDate: DateTime.now(),
          folderId: DateTime.now().millisecondsSinceEpoch.toString(), // Genera un ID univoco
          absolutePath: '${widget.path}/$action', // Salva il percorso assoluto aggiornato
        );
        await newFolder.saveFolder(widget.token); // Salva nel database

        setState(() {
          widget.currentFolder.addFolder(newFolder);
        });
      }
    }
  }
}

Future<String?> _askOverwriteOrRenameFolder(String folderName) async {
  String newFolderName = folderName;
  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Cartella "$folderName" esiste già. Cosa vuoi fare?'),
        content: TextField(
          decoration: InputDecoration(
            labelText: 'Inserisci un nuovo nome o lascia vuoto per sovrascrivere',
          ),
          onChanged: (value) {
            newFolderName = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop('Sovrascrivi');
            },
            child: Text('Sovrascrivi'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(newFolderName.isEmpty ? null : newFolderName);
            },
            child: Text('Rinomina'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text('Annulla'),
          ),
        ],
      );
    },
  );
}


void _moveItem(int index, bool isFolder) async {
  String? destinationPath = await _promptForDestination();
  
  if (destinationPath != null && destinationPath.isNotEmpty) {
    FolderInfo? destinationFolder = _getFolderByPath(destinationPath);
    
    if (destinationFolder != null) {
      if (isFolder) {
        FolderInfo folder = widget.currentFolder.subFolders[index];
        
        var existingFolder = destinationFolder.subFolders.firstWhere(
          (f) => f.name == folder.name,
          orElse: () => FolderInfo.empty(),
        );

        if (existingFolder.isEmpty) {
          // Aggiorna il percorso assoluto e il genitore della cartella
          folder.absolutePath = '$destinationPath/${folder.name}';
          folder.setParent(destinationFolder);  // Usa il metodo pubblico setParent
          folder.lastModifiedDate = DateTime.now();

          // Rimuove la cartella dalla posizione originale e aggiungila alla destinazione
          widget.currentFolder.subFolders.removeAt(index);
          destinationFolder.addFolder(folder);

          // Aggiorna il database
          await folder.updateFolder(widget.token);
        } else {
          String? action = await _askOverwriteOrRenameFolder(folder.name);
          if (action == 'Sovrascrivi') {
            setState(() {
              widget.currentFolder.subFolders.removeAt(index);
              existingFolder.lastModifiedDate = DateTime.now();
            });
            await existingFolder.updateFolder(widget.token);  // Aggiorna il database
          } else if (action != null && action.isNotEmpty) {
            FolderInfo newFolder = FolderInfo(
              name: action,
              creationDate: DateTime.now(),
              lastModifiedDate: DateTime.now(),
              parent: destinationFolder,
              absolutePath: '$destinationPath/$action',
            );

            setState(() {
              widget.currentFolder.subFolders.removeAt(index);
              destinationFolder.addFolder(newFolder);
            });
            await newFolder.saveFolder(widget.token);  // Salva nel database
          }
        }
      } else {
        DocumentInfo document = widget.currentFolder.documents[index];
        
        var existingDocument = destinationFolder.documents.firstWhere(
          (doc) => doc.name == document.name,
          orElse: () => DocumentInfo(name: '', type: '', size: 0, bytes: Uint8List(0), uploadDate: DateTime.now(), lastModifiedDate: DateTime.now()),
        );

        if (existingDocument.name.isEmpty) {
          // Aggiorna il percorso assoluto del documento
          document.absolutePath = '$destinationPath/${document.name}';
          document.lastModifiedDate = DateTime.now();

          // Rimuove il documento dalla posizione originale e aggiungilo alla destinazione
          widget.currentFolder.documents.removeAt(index);
          destinationFolder.addDocuments([document]);

          // Aggiorna il database
          await document.updateDocument(widget.token);
        } else {
          String? action = await _askOverwriteOrRename(document.name);
          if (action == 'Sovrascrivi') {
            setState(() {
              widget.currentFolder.documents.removeAt(index);
              existingDocument.bytes = document.bytes;
              existingDocument.size = document.size;
              existingDocument.lastModifiedDate = DateTime.now();
            });
            await existingDocument.updateDocument(widget.token);  // Aggiorna nel database
          } else if (action != null && action.isNotEmpty) {
            DocumentInfo newDocument = DocumentInfo(
              name: action,
              type: document.type,
              size: document.size,
              bytes: document.bytes,
              uploadDate: document.uploadDate,
              lastModifiedDate: DateTime.now(),
              absolutePath: '$destinationPath/$action',
            );

            setState(() {
              widget.currentFolder.documents.removeAt(index);
              destinationFolder.addDocuments([newDocument]);
            });
            await newDocument.saveDocument(widget.token);  // Salva nel database
          }
        }
      }
      setState(() {}); // Forza l'aggiornamento della UI
    }
  }
}

  Future<String?> _promptForDestination() async {
  // Risali alla cartella root usando i campi parent
  FolderInfo rootFolder = widget.currentFolder;
  while (rootFolder.parent != null) {
    rootFolder = rootFolder.parent!;
  }

  // Ottieni tutti i percorsi partendo dalla root
  List<String> paths = _getAllPaths(rootFolder, 'Root');
  
  String? selectedPath;
  if (paths.isNotEmpty) {
    selectedPath = paths.first;
  }

  return showDialog<String?>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Select Destination'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return DropdownButton<String>(
              isExpanded: true,
              value: selectedPath,
              items: paths.map<DropdownMenuItem<String>>((String path) {
                return DropdownMenuItem<String>(
                  value: path,
                  child: Text(path), // Mostra il percorso assoluto
                );
              }).toList(),
              onChanged: (String? newPath) {
                setState(() {
                  selectedPath = newPath;
                });
              },
            );
          },
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(null); // Return null if canceled
            },
          ),
          TextButton(
            child: Text('Move/Copy'),
            onPressed: () {
              Navigator.of(context).pop(selectedPath); // Return selectedPath
            },
          ),
        ],
      );
    },
  );
}

List<String> _getAllPaths(FolderInfo folder, [String currentPath = 'Root']) {
  // Lista per mantenere traccia delle cartelle visitate
  List<String> visitedPaths = [];

  // Lista per memorizzare tutti i percorsi
  List<String> paths = [];

  // Funzione interna ricorsiva
  void _collectPaths(FolderInfo folder, String currentPath) {
    // Evita cicli verificando se la cartella corrente è già stata visitata
    if (visitedPaths.contains(currentPath)) return;
    visitedPaths.add(currentPath);

    // Aggiunge il percorso corrente alla lista dei percorsi
    paths.add(currentPath);

    for (var subFolder in folder.subFolders) {
      // Chiamata ricorsiva per ogni sottocartella
      _collectPaths(subFolder, '$currentPath/${subFolder.name}');
    }
  }

  // Avvia la raccolta dei percorsi
  _collectPaths(folder, currentPath);
  return paths;
}


  FolderInfo? _getFolderByPath(String path) {
  List<String> folders = path.split('/');
  FolderInfo? currentFolder = widget.currentFolder;

  // Partiamo dalla radice se il percorso inizia con "Root"
  if (folders.first == "Root") {
    currentFolder = widget.currentFolder;
    while (currentFolder!.parent != null) {
      currentFolder = currentFolder.parent;
    }
  }

  for (String folderName in folders.skip(1)) {
    if (folderName.isNotEmpty) {
      FolderInfo? foundFolder = currentFolder?.subFolders.firstWhere(
        (folder) => folder.name == folderName,
        orElse: () => FolderInfo.empty(),
      );
      if (foundFolder!.isEmpty) {
        return null; // Se una cartella nel percorso non viene trovata, restituisce null
      }
      currentFolder = foundFolder;
    }
  }

  return currentFolder;
}

void _deleteFolder(int index) async {
  FolderInfo folder = widget.currentFolder.subFolders[index];

  try {
    // Elimina la cartella dal database
    await folder.deleteFolder(widget.token);

    // Aggiorna la UI rimuovendo la cartella
    setState(() {
      widget.currentFolder.removeFolderAt(index);
    });
  } catch (e) {
    // Gestisci eventuali errori nell'eliminazione
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore durante l\'eliminazione della cartella: $e')),
    );
  }
}

void _editFolder(int index) async {
  FolderInfo folder = widget.currentFolder.subFolders[index];

  String? newFolderName = await _promptForFolderName(); // Metodo per chiedere all'utente il nuovo nome
  if (newFolderName != null && newFolderName.isNotEmpty) {
    folder.name = newFolderName;
    folder.lastModifiedDate = DateTime.now();

    try {
      // Aggiorna la cartella nel database
      await folder.updateFolder(widget.token);

      // Aggiorna la UI
      setState(() {});
    } catch (e) {
      // Gestisci eventuali errori nell'aggiornamento
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la modifica della cartella: $e')),
      );
    }
  }
}

void _deleteFile(int index) async {
  DocumentInfo document = widget.currentFolder.documents[index];

  try {
    // Elimina il documento dal database
    await document.deleteDocument(widget.token);

    // Aggiorna la UI rimuovendo il documento
    setState(() {
      widget.currentFolder.removeDocumentAt(index);
    });
  } catch (e) {
    // Gestisci eventuali errori nell'eliminazione
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore durante l\'eliminazione del file: $e')),
    );
  }
}

void _editFile(int index) async {
  final document = widget.currentFolder.documents[index];
  final fileType = document.type.toLowerCase();

  Future<void> _updateDocument(Uint8List updatedBytes) async {
    document.bytes = updatedBytes;
    document.lastModifiedDate = DateTime.now();
  try {
      // Aggiorna il documento nel database
      await document.updateDocument(widget.token);

      // Aggiorna la UI
      setState(() {});
    } catch (e) {
      // Gestisci eventuali errori nell'aggiornamento
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio del file: $e')),
      );
    }
  }

  if (fileType == 'txt') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  } else if (fileType == 'json') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JsonEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  } else if (fileType == 'pdf') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  } else if (fileType == 'md' || fileType == 'markdown') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  } else if (fileType == 'html') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HtmlEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  }  else if (fileType == 'csv' || fileType == 'xlsx') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableEditor(
          document: document,
          onSave: (updatedBytes) async => await _updateDocument(updatedBytes),
        ),
      ),
    );
  } else {
    // Gestione di altri tipi di file
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Formato di file non supportato')),
    );
  }
}


void _openFolder(FolderInfo folder) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DocumentManagerHomePage(
        currentFolder: folder,
        path: '${folder.absolutePath}', // Usa il percorso assoluto della cartella
        token: widget.token,
      ),
    ),
  ).then((_) {
    _loadFolderTree(); // Ricarica l'albero per riflettere il nuovo percorso
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path),
        actions: [
          IconButton(
            icon: Icon(Icons.create_new_folder),
            onPressed: _createFolder,
            tooltip: 'Create New Folder',
          ),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _pickFile,
            tooltip: 'Upload Files',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: _buildResponsiveGrid(),
      ),
    );
  }

  Widget _buildResponsiveGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = (constraints.maxWidth ~/ 270).toInt();
        crossAxisCount = crossAxisCount > 0 ? crossAxisCount : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
            childAspectRatio: 1.05,
          ),
          itemCount: widget.currentFolder.totalItems,
          itemBuilder: (context, index) {
            if (index < widget.currentFolder.subFolders.length) {
              return _buildFolderCard(widget.currentFolder.subFolders[index], index);
            } else {
              int fileIndex = index - widget.currentFolder.subFolders.length;
              return _buildDocumentCard(widget.currentFolder.documents[fileIndex], fileIndex);
            }
          },
        );
      },
    );
  }

  Widget _buildFolderCard(FolderInfo folder, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openFolder(folder),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 5.0,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.folder, color: Colors.amber, size: 48.0),
                    Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (String choice) {
                        if (choice == 'Elimina') {
                          _deleteFolder(index);
                        } else if (choice == 'Modifica') {
                          _editFolder(index);
                        } else if (choice == 'Sposta in') {
                          _moveItem(index, true);
                        } else if (choice == 'Copia in') {
                          _copyItem(index, true);
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return {'Modifica', 'Elimina', 'Sposta in', 'Copia in'}.map((String choice) {
                          return PopupMenuItem<String>(
                            value: choice,
                            child: Text(choice),
                          );
                        }).toList();
                      },
                      tooltip: 'Opzioni',
                    ),
                  ],
                ),
                SizedBox(height: 8.0),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(8.0),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.black, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          folder.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.0, // Font leggermente ingrandito
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.0),
                        Row(
                          children: [
                            Text(
                              "Documenti:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              "${folder.documents.length}",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "Sottocartelle:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              "${folder.subFolders.length}",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "Dimensione Totale:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              "${_formatSize(folder.totalSize)}",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Row(
                          children: [
                            Text(
                              "Creato il:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              _formatDate(folder.creationDate),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "Modificato il:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 4.0),
                            Text(
                              _formatDate(folder.lastModifiedDate),
                              style: TextStyle(color: Colors.grey[700]),
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
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentInfo document, int index) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 5.0,
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileIcon(document.type),
                Spacer(),
                PopupMenuButton<String>(
                  onSelected: (String choice) {
                    if (choice == 'Scarica') {
                      _downloadFile(document);
                    } else if (choice == 'Elimina') {
                      _deleteFile(index);
                    } else if (choice == 'Modifica') {
                      _editFile(index);
                    } else if (choice == 'Sposta in') {
                      _moveItem(index, false);
                    } else if (choice == 'Copia in') {
                      _copyItem(index, false);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return {'Modifica', 'Scarica', 'Elimina', 'Sposta in', 'Copia in'}.map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      );
                    }).toList();
                  },
                  tooltip: 'Opzioni',
                ),
              ],
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.black, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      document.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0, // Font leggermente ingrandito
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.0),
                    Row(
                      children: [
                        Text(
                          "Tipo:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          document.type.toUpperCase(),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Dimensione:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          _formatSize(document.size),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    Row(
                      children: [
                        Text(
                          "Creato il:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          _formatDate(document.uploadDate),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Modificato il:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          _formatDate(document.lastModifiedDate),
                          style: TextStyle(color: Colors.grey[700]),
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

  Widget _buildFileIcon(String fileType) {
    IconData iconData;
    Color iconColor;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        iconData = Icons.grid_on;
        iconColor = Colors.green;
        break;
      case 'docx':
      case 'odt':
        iconData = Icons.article;
        iconColor = Colors.blue;
        break;
      case 'md':
      case 'txt':
        iconData = Icons.text_snippet;
        iconColor = Colors.grey;
        break;
      case 'html':
        iconData = Icons.code;
        iconColor = Colors.purple;
        break;
      case 'json':
        iconData = Icons.data_object;
        iconColor = Colors.brown;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
        break;
    }

    return Icon(iconData, color: iconColor, size: 48.0);
  }

  String _formatSize(int sizeInBytes) {
    const int kb = 1024;
    const int mb = 1024 * kb;
    const int gb = 1024 * mb;

    if (sizeInBytes >= gb) {
      return "${(sizeInBytes / gb).toStringAsFixed(2)} GB";
    } else if (sizeInBytes >= mb) {
      return "${(sizeInBytes / mb).toStringAsFixed(2)} MB";
    } else if (sizeInBytes >= kb) {
      return "${(sizeInBytes / kb).toStringAsFixed(2)} KB";
    } else {
      return "$sizeInBytes B";
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


class TextEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  TextEditor({required this.document, required this.onSave});

  @override
  _TextEditorState createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late TextEditingController _textEditingController;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(
      text: utf8.decode(widget.document.bytes),
    );
  }

  void _save() {
    final updatedBytes = utf8.encode(_textEditingController.text);
    widget.onSave(Uint8List.fromList(updatedBytes));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifica: ${widget.document.name}"),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: TextField(
          controller: _textEditingController,
          maxLines: null,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.all(16.0),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }
}

class JsonEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  JsonEditor({required this.document, required this.onSave});

  @override
  _JsonEditorState createState() => _JsonEditorState();
}

class _JsonEditorState extends State<JsonEditor> {
  late TextEditingController _textEditingController;
  dynamic _jsonDecoded;
  bool _isJsonValid = true;
  bool _isJsonLoaded = false;
  double _splitRatio = 0.5;

  ViewMode _viewMode = ViewMode.editAndView;

  @override
  void initState() {
    super.initState();
    final jsonSource = utf8.decode(widget.document.bytes);
    try {
      _jsonDecoded = json.decode(jsonSource);
      _isJsonValid = true;
      _isJsonLoaded = true;
    } catch (e) {
      _isJsonValid = false;
    }
    _textEditingController = TextEditingController(text: jsonSource);
  }

  void _save() {
    try {
      final updatedBytes = utf8.encode(_textEditingController.text);
      widget.onSave(Uint8List.fromList(updatedBytes));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isJsonValid = false;
      });
    }
  }

  void _formatJson() {
    try {
      final jsonDecoded = json.decode(_textEditingController.text);
      final formattedJson = JsonEncoder.withIndent('  ').convert(jsonDecoded);
      setState(() {
        _textEditingController.text = formattedJson;
        _isJsonValid = true;
      });
    } catch (e) {
      setState(() {
        _isJsonValid = false;
      });
    }
  }

  void _runJson() {
    try {
      final jsonString = _textEditingController.text;
      final jsonDecoded = json.decode(jsonString);
      setState(() {
        _jsonDecoded = jsonDecoded;
        _isJsonValid = true;
      });
    } catch (e) {
      setState(() {
        _isJsonValid = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Formato JSON non valido')),
      );
    }
  }

  void _downloadJsonSource() {
    final jsonString = _textEditingController.text;
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "${widget.document.name}")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifica: ${widget.document.name}"),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: _isJsonLoaded ? _runJson : null,
          ),
          IconButton(
            icon: Icon(Icons.format_indent_increase),
            onPressed: _formatJson,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined),
            onPressed: () => setState(() {
              _viewMode = ViewMode.viewOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.view_sidebar),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editAndView;
            }),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _save,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Download JSON') {
                _downloadJsonSource();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Download JSON'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;

            if (_viewMode == ViewMode.editOnly) {
              return _buildEditor();
            } else if (_viewMode == ViewMode.viewOnly) {
              return _buildViewer();
            } else {
              return Row(
                children: [
                  Expanded(
                    flex: (_splitRatio * 100).toInt(),
                    child: _buildEditor(),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitRatio += details.primaryDelta! / maxWidth;
                        if (_splitRatio < 0.1) _splitRatio = 0.1;
                        if (_splitRatio > 0.9) _splitRatio = 0.9;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(
                        width: 16,
                        color: Colors.transparent,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.arrow_left, color: Colors.grey),
                              Icon(Icons.arrow_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - _splitRatio) * 100).toInt(),
                    child: _buildViewer(),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: TextField(
        controller: _textEditingController,
        maxLines: null,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(16.0),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: _jsonDecoded != null
              ? JsonViewer(json: _jsonDecoded)
              : Text(
                  'Il contenuto JSON verrà visualizzato qui',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}

class PdfEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  PdfEditor({required this.document, required this.onSave});

  @override
  _PdfEditorState createState() => _PdfEditorState();
}

class _PdfEditorState extends State<PdfEditor> {
  Uint8List? _pdfBytes;
  String? _pdfName;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pdfBytes = widget.document.bytes;
    _pdfName = widget.document.name;
  }

  void _savePdf() {
    if (_pdfBytes != null) {
      PdfDocument document = PdfDocument(inputBytes: _pdfBytes!);

      // Apply any desired changes to the PDF document here

      List<int> bytes = document.saveSync();
      document.dispose();

      setState(() {
        widget.onSave(Uint8List.fromList(bytes));
      });

      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", _pdfName ?? "document.pdf")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _zoomIn() {
    if (_pdfViewerController.zoomLevel < 3) {
      _pdfViewerController.zoomLevel += 0.25;
    }
  }

  void _zoomOut() {
    if (_pdfViewerController.zoomLevel > 1) {
      _pdfViewerController.zoomLevel -= 0.25;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfName ?? "Modifica PDF"),
        actions: _pdfBytes != null
            ? [
                IconButton(
                  icon: Icon(Icons.zoom_in),
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out),
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: Icon(Icons.download),
                  onPressed: _savePdf,
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.upload_file),
                  onPressed: () {
                    // No file picker here because we already have a PDF loaded
                  },
                ),
              ],
      ),
      body: Center(
        child: _pdfBytes == null
            ? Text("Nessun file PDF caricato")
            : SfPdfViewer.memory(
                _pdfBytes!,
                controller: _pdfViewerController,
                key: _pdfViewerKey,
              ),
      ),
    );
  }
}

class HtmlEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  HtmlEditor({required this.document, required this.onSave});

  @override
  _HtmlEditorState createState() => _HtmlEditorState();
}

class _HtmlEditorState extends State<HtmlEditor> {
  Uint8List? _htmlBytes;
  String? _htmlSource;
  bool _isHtmlLoaded = false;
  TextEditingController _textEditingController = TextEditingController();
  double _splitRatio = 0.5;

  ViewMode _viewMode = ViewMode.editAndView;

  @override
  void initState() {
    super.initState();
    _htmlBytes = widget.document.bytes;
    _htmlSource = utf8.decode(_htmlBytes!);
    _isHtmlLoaded = true;
    _textEditingController.text = _htmlSource!;
  }

  void _save() {
    final updatedBytes = utf8.encode(_textEditingController.text);
    widget.onSave(Uint8List.fromList(updatedBytes));
    Navigator.pop(context);
  }

  void _formatHtml() {
    if (_textEditingController.text.isNotEmpty) {
      final document = parser.parse(_textEditingController.text);
      final formattedHtml = HtmlUtils.formatDocument(document);  // Utilizzo della funzione di utilità
      setState(() {
        _textEditingController.text = formattedHtml;
      });
    }
  }

  void _downloadHtmlSource() {
    final htmlSource = _textEditingController.text;
    final bytes = utf8.encode(htmlSource);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", widget.document.name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _downloadRenderedPdf() async {
    try {
      await HtmlUtils.downloadRenderedPdf(_textEditingController.text);  // Utilizzo della funzione di utilità
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifica: ${widget.document.name}"),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: _isHtmlLoaded ? () => setState(() {}) : null,
          ),
          IconButton(
            icon: Icon(Icons.format_indent_increase),
            onPressed: _formatHtml,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined),
            onPressed: () => setState(() {
              _viewMode = ViewMode.viewOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.view_sidebar),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editAndView;
            }),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _save,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Download HTML') {
                _downloadHtmlSource();
              } else if (value == 'Download PDF') {
                _downloadRenderedPdf();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Download HTML', 'Download PDF'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;

            if (_viewMode == ViewMode.editOnly) {
              return _buildEditor();
            } else if (_viewMode == ViewMode.viewOnly) {
              return _buildViewer();
            } else {
              return Row(
                children: [
                  Expanded(
                    flex: (_splitRatio * 100).toInt(),
                    child: _buildEditor(),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitRatio += details.primaryDelta! / maxWidth;
                        if (_splitRatio < 0.1) _splitRatio = 0.1;
                        if (_splitRatio > 0.9) _splitRatio = 0.9;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(
                        width: 16,
                        color: Colors.transparent,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.arrow_left, color: Colors.grey),
                              Icon(Icons.arrow_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - _splitRatio) * 100).toInt(),
                    child: _buildViewer(),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: TextField(
        controller: _textEditingController,
        maxLines: null,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(16.0),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: _htmlSource != null
              ? HtmlWidget(_textEditingController.text)
              : Text(
                  'Il contenuto HTML verrà visualizzato qui',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}
class MarkdownEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  MarkdownEditor({required this.document, required this.onSave});

  @override
  _MarkdownEditorState createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _textEditingController;
  bool _isMarkdownLoaded = false;
  double _splitRatio = 0.5;
  ViewMode _viewMode = ViewMode.editAndView;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(
      text: utf8.decode(widget.document.bytes),
    );
    _isMarkdownLoaded = true;
  }

  void _save() {
    final updatedBytes = utf8.encode(_textEditingController.text);
    widget.onSave(Uint8List.fromList(updatedBytes));
    Navigator.pop(context);
  }

  void _runMarkdown() {
    setState(() {
      // This triggers a rebuild to reflect the latest Markdown content
    });
  }

  void _downloadMarkdownSource() {
    final markdownSource = _textEditingController.text;
    final bytes = utf8.encode(markdownSource);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", widget.document.name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _downloadHtmlSource() {
    final markdownSource = _textEditingController.text;
    final htmlContent = md.markdownToHtml(markdownSource);
    final bytes = utf8.encode(htmlContent);
    final blob = html.Blob([bytes], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "${widget.document.name}.html")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifica: ${widget.document.name}"),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: _isMarkdownLoaded ? _runMarkdown : null,
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.visibility_outlined),
            onPressed: () => setState(() {
              _viewMode = ViewMode.viewOnly;
            }),
          ),
          IconButton(
            icon: Icon(Icons.view_sidebar),
            onPressed: () => setState(() {
              _viewMode = ViewMode.editAndView;
            }),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _save,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Download Markdown') {
                _downloadMarkdownSource();
              } else if (value == 'Download HTML') {
                _downloadHtmlSource();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Download Markdown', 'Download HTML'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;

            if (_viewMode == ViewMode.editOnly) {
              return _buildEditor();
            } else if (_viewMode == ViewMode.viewOnly) {
              return _buildViewer(constraints.maxHeight);
            } else {
              return Row(
                children: [
                  Expanded(
                    flex: (_splitRatio * 100).toInt(),
                    child: _buildEditor(),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitRatio += details.primaryDelta! / maxWidth;
                        if (_splitRatio < 0.1) _splitRatio = 0.1;
                        if (_splitRatio > 0.9) _splitRatio = 0.9;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeColumn,
                      child: Container(
                        width: 16,
                        color: Colors.transparent,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.arrow_left, color: Colors.grey),
                              Icon(Icons.arrow_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - _splitRatio) * 100).toInt(),
                    child: _buildViewer(constraints.maxHeight),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: TextField(
        controller: _textEditingController,
        maxLines: null,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(16.0),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildViewer(double maxHeight) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Markdown(
          data: _textEditingController.text,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
        ),
      ),
    );
  }
}

class TableEditor extends StatefulWidget {
  final DocumentInfo document;
  final Function(Uint8List) onSave;

  TableEditor({required this.document, required this.onSave});

  @override
  _TableEditorState createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditor> {
  List<List<String>> data = [];
  List<String> filters = [];
  List<bool> selectedRows = [];
  bool isSelectAllChecked = false;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  void _loadTableData() {
    final csvSource = utf8.decode(widget.document.bytes);
    setState(() {
      data = CsvToListConverter().convert(csvSource).map((row) {
        return List<String>.from(row.map((cell) => cell.toString()));
      }).toList();
      filters = List<String>.filled(data[0].length, "");
      selectedRows = List<bool>.filled(data.length, false);
    });
  }

  void _save() {
    final csvData = ListToCsvConverter().convert(data);
    final updatedBytes = utf8.encode(csvData);
    widget.onSave(Uint8List.fromList(updatedBytes));
    Navigator.pop(context);
  }

  void _updateCell(int rowIndex, int columnIndex, String value) {
    setState(() {
      data = List.from(data);  // Crea una nuova lista mutabile
      data[rowIndex] = List.from(data[rowIndex]);  // Crea una nuova lista per la riga
      data[rowIndex][columnIndex] = value;
    });
  }

  void _updateFilter(int columnIndex, String value) {
    setState(() {
      filters = List.from(filters);  // Crea una nuova lista mutabile
      filters[columnIndex] = value.toLowerCase();
    });
  }

  bool _filterRow(List<String> row) {
    for (int i = 0; i < filters.length; i++) {
      if (filters[i].isNotEmpty && !row[i].toLowerCase().contains(filters[i])) {
        return false;
      }
    }
    return true;
  }

  void _toggleSelection(int rowIndex) {
    setState(() {
      selectedRows = List.from(selectedRows);  // Crea una nuova lista mutabile
      selectedRows[rowIndex] = !selectedRows[rowIndex];
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      isSelectAllChecked = value ?? false;
      selectedRows = List<bool>.filled(data.length, isSelectAllChecked);
    });
  }

  void _deleteSelectedRows() {
    setState(() {
      List<List<String>> newData = [];
      List<bool> newSelectedRows = [];
      
      for (int i = 0; i < data.length; i++) {
        if (!selectedRows[i]) {
          newData.add(data[i]);
          newSelectedRows.add(false);
        }
      }
      
      data = newData;
      selectedRows = newSelectedRows;
      isSelectAllChecked = false;
    });
  }

  void _addRow() {
    setState(() {
      data = List.from(data)..add(List<String>.filled(data[0].length, ""));
      selectedRows = List.from(selectedRows)..add(false);
    });
  }

  void _addColumn() {
    setState(() {
      data = data.map((row) {
        return List<String>.from(row)..add("");
      }).toList();
      filters = List.from(filters)..add("");
    });
  }

  void _deleteColumn(int columnIndex) {
    setState(() {
      data = data.map((row) {
        return List<String>.from(row)..removeAt(columnIndex);
      }).toList();
      filters = List.from(filters)..removeAt(columnIndex);
    });
  }

  void _moveColumnLeft(int columnIndex) {
    if (columnIndex > 0) {
      setState(() {
        data = data.map((row) {
          final newRow = List<String>.from(row);
          final cell = newRow.removeAt(columnIndex);
          newRow.insert(columnIndex - 1, cell);
          return newRow;
        }).toList();
        filters = List.from(filters);
        final filter = filters.removeAt(columnIndex);
        filters.insert(columnIndex - 1, filter);
      });
    }
  }

  void _moveColumnRight(int columnIndex) {
    if (columnIndex < data[0].length - 1) {
      setState(() {
        data = data.map((row) {
          final newRow = List<String>.from(row);
          final cell = newRow.removeAt(columnIndex);
          newRow.insert(columnIndex + 1, cell);
          return newRow;
        }).toList();
        filters = List.from(filters);
        final filter = filters.removeAt(columnIndex);
        filters.insert(columnIndex + 1, filter);
      });
    }
  }

  void _deleteRow(int rowIndex) {
    setState(() {
      data = List.from(data)..removeAt(rowIndex);
      selectedRows = List.from(selectedRows)..removeAt(rowIndex);
    });
  }

  void _moveRowUp(int rowIndex) {
    if (rowIndex > 1) {
      setState(() {
        data = List.from(data);
        final row = data.removeAt(rowIndex);
        data.insert(rowIndex - 1, row);
        
        selectedRows = List.from(selectedRows);
        final selected = selectedRows.removeAt(rowIndex);
        selectedRows.insert(rowIndex - 1, selected);
      });
    }
  }

  void _moveRowDown(int rowIndex) {
    if (rowIndex < data.length - 1) {
      setState(() {
        data = List.from(data);
        final row = data.removeAt(rowIndex);
        data.insert(rowIndex + 1, row);
        
        selectedRows = List.from(selectedRows);
        final selected = selectedRows.removeAt(rowIndex);
        selectedRows.insert(rowIndex + 1, selected);
      });
    }
  }

  void _exportCSV() async {
    final params = await _showCSVExportDialog();
    if (params != null) {
      String csvData = const ListToCsvConverter().convert(
        data,
        fieldDelimiter: params['separator'],
      );
      final bytes = Utf8Encoder().convert(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "my_table.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<Map<String, dynamic>?> _showCSVExportDialog() async {
    String selectedSeparator = ',';
    TextEditingController customSeparatorController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('CSV Export Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Select or Enter Field Separator:'),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text("Comma (,)"),
                            value: ',',
                            groupValue: selectedSeparator,
                            onChanged: (value) {
                              setState(() {
                                selectedSeparator = value!;
                                customSeparatorController.clear();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text("Semicolon (;)"),
                            value: ';',
                            groupValue: selectedSeparator,
                            onChanged: (value) {
                              setState(() {
                                selectedSeparator = value!;
                                customSeparatorController.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: customSeparatorController,
                      decoration: InputDecoration(
                        labelText: "Custom Separator",
                        hintText: "Enter custom separator",
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectedSeparator = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'separator': selectedSeparator,
                    });
                  },
                  child: Text('Export'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportJSON() async {
    final format = await _showFormatSelectionDialog();
    if (format != null) {
      String jsonData;
      if (format == 'List of Lists') {
        jsonData = jsonEncode(data);
      } else {
        Map<String, List<String>> jsonMap = {};
        for (int i = 0; i < data[0].length; i++) {
          String key = data[0][i];
          jsonMap[key] = data.sublist(1).map((row) => row[i]).toList();
        }
        jsonData = jsonEncode(jsonMap);
      }

      final bytes = Utf8Encoder().convert(jsonData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "my_table.json")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<String?> _showFormatSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String selectedFormat = 'List of Lists';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select JSON Export Format'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text('List of Lists'),
                            selected: selectedFormat == 'List of Lists',
                            onSelected: (bool selected) {
                              setState(() {
                                selectedFormat = 'List of Lists';
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: Text('Pandas DataFrame'),
                            selected: selectedFormat == 'Pandas DataFrame',
                            onSelected: (bool selected) {
                              setState(() {
                                selectedFormat = 'Pandas DataFrame';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text('Example Output:'),
                    SizedBox(height: 10),
                    if (selectedFormat == 'List of Lists')
                      _buildJsonExample(
                        '''
[
  ["Name", "Age", "Profession"],
  ["John Doe", "28", "Engineer"],
  ["Jane Smith", "34", "Doctor"],
  ["Alex Johnson", "40", "Teacher"]
]
                        ''',
                      ),
                    if (selectedFormat == 'Pandas DataFrame')
                      _buildJsonExample(
                        '''
{
  "Name": ["John Doe", "Jane Smith", "Alex Johnson"],
  "Age": ["28", "34", "40"],
  "Profession": ["Engineer", "Doctor", "Teacher"]
}
                        ''',
                      ),
                  ],
                )),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedFormat);
                  },
                  child: Text('Export'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildJsonExample(String json) {
    return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          json,
          style: TextStyle(fontFamily: 'Courier', fontSize: 12),
        ),
      ),
    );
  }

  void _importCSV() async {
    final fileUpload = html.FileUploadInputElement();
    fileUpload.accept = '.csv';
    fileUpload.click();

    fileUpload.onChange.listen((event) {
      final reader = html.FileReader();
      reader.readAsText(fileUpload.files!.first);
      reader.onLoadEnd.listen((event) {
        final csvData = reader.result as String;
        final csvList = const CsvToListConverter().convert(csvData).map((row) {
          return List<String>.from(row.map((cell) => cell.toString()));
        }).toList();
        setState(() {
          data = csvList;
          selectedRows = List<bool>.filled(data.length, false);
        });
      });
    });
  }

  void _importJSON() async {
    final fileUpload = html.FileUploadInputElement();
    fileUpload.accept = '.json';
    fileUpload.click();

    fileUpload.onChange.listen((event) {
      final reader = html.FileReader();
      reader.readAsText(fileUpload.files!.first);
      reader.onLoadEnd.listen((event) {
        final jsonData = reader.result as String;
        final dynamic jsonObject = jsonDecode(jsonData);

        if (jsonObject is List) {
          final List<dynamic> jsonList = jsonObject;
          final convertedData = jsonList.map((row) {
            return List<String>.from((row as List<dynamic>).map((cell) => cell.toString()));
          }).toList();
          setState(() {
            data = convertedData;
            selectedRows = List<bool>.filled(data.length, false);
          });
        } else if (jsonObject is Map) {
          final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(jsonObject);
          final headers = jsonMap.keys.toList();
          final int numRows = (jsonMap.values.first as List).length;

          List<List<String>> convertedData = [];
          convertedData.add(headers);

          for (int i = 0; i < numRows; i++) {
            List<String> row = [];
            for (var key in headers) {
              row.add(jsonMap[key]?[i]?.toString() ?? "");
            }
            convertedData.add(row);
          }

          setState(() {
            data = convertedData;
            selectedRows = List<bool>.filled(data.length, false);
          });
        }
      });
    });
  }

  Widget _buildFilterBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: SizedBox(
        height: 150, // Altezza massima del riquadro dei filtri
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(data[0].length, (columnIndex) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Filtra ${data[0][columnIndex]}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  ),
                  onChanged: (value) {
                    _updateFilter(columnIndex, value);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(int rowIndex, int columnIndex) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(
              text: data[rowIndex][columnIndex],
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            onSubmitted: (value) {
              _updateCell(rowIndex, columnIndex, value);
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
          ),
        ),
        PopupMenuButton<int>(
          icon: Icon(Icons.more_vert),
          onSelected: (int index) {
            switch (index) {
              case 0:
                _moveColumnLeft(columnIndex);
                break;
              case 1:
                _moveColumnRight(columnIndex);
                break;
              case 2:
                _deleteColumn(columnIndex);
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            if (columnIndex > 0)
              PopupMenuItem<int>(
                value: 0,
                child: Text('Sposta a sinistra'),
              ),
            if (columnIndex < data[rowIndex].length - 1)
              PopupMenuItem<int>(
                value: 1,
                child: Text('Sposta a destra'),
              ),
            PopupMenuItem<int>(
              value: 2,
              child: Text('Elimina colonna'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataCell(int rowIndex, int columnIndex) {
    return TextField(
      controller: TextEditingController(
        text: data[rowIndex][columnIndex],
      ),
      onSubmitted: (value) {
        _updateCell(rowIndex, columnIndex, value);
      },
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Modifica: ${widget.document.name}"),
        actions: [
IconButton(
  icon: Icon(Icons.save),
  onPressed: _save,
  tooltip: "Salva modifiche",
),
IconButton(
  icon: Icon(Icons.add),
  onPressed: _addRow,
  tooltip: "Aggiungi riga",
),
IconButton(
  icon: Icon(Icons.add_box),
  onPressed: _addColumn,
  tooltip: "Aggiungi colonna",
),
          PopupMenuButton<String>(
  icon: Icon(Icons.upload_file),
  tooltip: 'Importa tabella',
  onSelected: (value) {
    if (value == 'Importa CSV') {
      _importCSV();
    } else if (value == 'Importa JSON') {
      _importJSON();
    }
  },
  itemBuilder: (BuildContext context) {
    return {'Importa CSV', 'Importa JSON'}
        .map((String choice) {
      return PopupMenuItem<String>(
        value: choice,
        child: Text(choice),
      );
    }).toList();
  },
),
          PopupMenuButton<String>(
            icon: Icon(Icons.download),
            tooltip: 'Esporta tabella',
            onSelected: (value) {
              if (value == 'Esporta CSV') {
                _exportCSV();
              } else if (value == 'Esporta JSON') {
                _exportJSON();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Esporta CSV', 'Esporta JSON'}
                  .map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterBox(),
            SizedBox(height: 10),
            Expanded(
              child: Scrollbar(
                controller: _horizontalScrollController,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: List.generate(data.length, (rowIndex) {
                          if (rowIndex > 0 && !_filterRow(data[rowIndex])) {
                            return SizedBox.shrink();
                          }
                          return Row(
                            children: [
                              if (rowIndex == 0) SizedBox(width: 40),
                              if (rowIndex > 0)
                                PopupMenuButton<int>(
                                  icon: Icon(Icons.more_vert),
                                  onSelected: (int index) {
                                    switch (index) {
                                      case 0:
                                        _moveRowUp(rowIndex);
                                        break;
                                      case 1:
                                        _moveRowDown(rowIndex);
                                        break;
                                      case 2:
                                        _deleteRow(rowIndex);
                                        break;
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    PopupMenuItem<int>(
                                      value: 0,
                                      child: Text('Sposta in alto'),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 1,
                                      child: Text('Sposta in basso'),
                                    ),
                                    PopupMenuItem<int>(
                                      value: 2,
                                      child: Text('Elimina riga'),
                                    ),
                                  ],
                                ),
                              if (rowIndex == 0)
                                Checkbox(
                                  value: isSelectAllChecked,
                                  onChanged: _toggleSelectAll,
                                ),
                              if (rowIndex > 0)
                                Checkbox(
                                  value: selectedRows[rowIndex],
                                  onChanged: (bool? value) {
                                    _toggleSelection(rowIndex);
                                  },
                                ),
                              if (rowIndex == 0) SizedBox(width: 0),
                              ...List.generate(data[rowIndex].length, (columnIndex) {
                                return Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black),
                                      borderRadius: BorderRadius.circular(8.0),
                                      color: rowIndex == 0
                                          ? const Color.fromARGB(255, 114, 240, 105).withOpacity(0.8)
                                          : Colors.white,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: rowIndex == 0
                                          ? _buildHeaderCell(rowIndex, columnIndex)
                                          : _buildDataCell(rowIndex, columnIndex),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}


enum ViewMode { editOnly, viewOnly, editAndView }
