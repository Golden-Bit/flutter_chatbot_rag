import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'context_api_sdk.dart';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context API Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ContextApiSdk _apiSdk = ContextApiSdk();
  List<ContextMetadata> _contexts = [];
  FilePickerResult? _selectedFile;
  bool _isLoading = false; // Variabile di stato per indicare il caricamento generale
  String? _loadingContext; // Contesto corrente per l'upload
  String? _loadingFileName; // Nome del file in fase di caricamento

  Map<String, bool> _isLoadingMap = {}; // Stato di caricamento per ciascun contesto
  Map<String, String?> _loadingFileNamesMap = {}; // Nome del file in caricamento per ciascun contesto

  @override
  void initState() {
    super.initState();
    _loadContexts();
  }

  // Funzione per caricare i contesti
  Future<void> _loadContexts() async {
    try {
      final contexts = await _apiSdk.listContexts();
      if (mounted) {
        setState(() {
          _contexts = contexts;
        });
      }
    } catch (e) {
      print('Errore nel recupero dei contesti: $e');
    }
  }

  // Funzione per caricare i file di un contesto specifico
  Future<List<Map<String, dynamic>>> _loadFilesForContext(String contextPath) async {
    try {
      final files = await _apiSdk.listFiles(contexts: [contextPath]);
      return files;
    } catch (e) {
      print('Errore nel recupero dei file per il contesto $contextPath: $e');
      return [];
    }
  }

  // Funzione per caricare un file in più contesti
  Future<void> _uploadFile(Uint8List fileBytes, List<String> contexts,
      {String? description, required String fileName}) async {
    try {
      await _apiSdk.uploadFileToContexts(
          fileBytes, contexts, description: description, fileName: fileName);
    } catch (e) {
      print('Errore caricamento file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingContext = null;
          _loadingFileName = null;
        });
      }
    }
  }

  // Funzione per eliminare un contesto
  Future<void> _deleteContext(String contextName) async {
    try {
      await _apiSdk.deleteContext(contextName);
      _loadContexts();
    } catch (e) {
      print('Errore eliminazione contesto: $e');
    }
  }

  // Funzione per eliminare un file
  Future<void> _deleteFile(String fileId) async {
    try {
      await _apiSdk.deleteFile(fileId: fileId);
    } catch (e) {
      print('Errore eliminazione file: $e');
    }
  }

  // Funzione per gestire l'upload del file per un contesto specifico
  void _uploadFileForContext(String contextPath) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.first.bytes != null) {
      // Aggiorna lo stato di caricamento del contesto
      setState(() {
        _isLoadingMap[contextPath] = true;
        _loadingFileNamesMap[contextPath] = result.files.first.name;
      });

      // Esegui il caricamento del file
      try {
        await _uploadFile(
          result.files.first.bytes!,
          [contextPath],
          fileName: result.files.first.name,
        );
      } catch (e) {
        print('Errore durante il caricamento: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingMap.remove(contextPath);
            _loadingFileNamesMap.remove(contextPath);
          });
        }
      }
    } else {
      print("Nessun file selezionato");
    }
  }

  // Mostra il dialog per caricare file in contesti multipli
  void _showUploadFileToMultipleContextsDialog() {
    TextEditingController descriptionController = TextEditingController();
    List<String> selectedContexts = [];
    FilePickerResult? fileResult;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Carica File in Contesti Multipli'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      fileResult = await FilePicker.platform.pickFiles();
                      if (fileResult != null) {
                        setState(() {
                          selectedFileName = fileResult!.files.first.name;
                        });
                      }
                    },
                    child: Text(selectedFileName != null
                        ? 'File Selezionato: $selectedFileName'
                        : 'Seleziona File'),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Seleziona Contesti'),
                    items: _contexts.map((context) {
                      return DropdownMenuItem<String>(
                        value: context.path,
                        child: Text(context.path),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && !selectedContexts.contains(value)) {
                        setState(() {
                          selectedContexts.add(value);
                        });
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 6.0,
                    children: selectedContexts.map((context) {
                      return Chip(
                        label: Text(context),
                        onDeleted: () {
                          setState(() {
                            selectedContexts.remove(context);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'Descrizione del File'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (fileResult != null && selectedContexts.isNotEmpty) {
                      // Chiudi il dialog prima di iniziare il caricamento
                      Navigator.of(context).pop();
                      setState(() {
                        _isLoading = true;
                        _loadingContext = selectedContexts.join(", ");
                        _loadingFileName = fileResult!.files.first.name;
                      });

                      // Caricamento file
                      _uploadFile(
                        fileResult!.files.first.bytes!,
                        selectedContexts,
                        description: descriptionController.text,
                        fileName: fileResult!.files.first.name,
                      ).then((_) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                            _loadingContext = null;
                            _loadingFileName = null;
                          });
                        }
                      });
                    } else {
                      print('Errore: seleziona almeno un contesto e un file.');
                    }
                  },
                  child: Text('Carica File'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Funzione per creare un nuovo contesto e caricare il file obbligatorio
  Future<void> _createContextAndUploadFile(String name, String description) async {
    if (_selectedFile == null || _selectedFile!.files.first.bytes == null) {
      print("Errore: nessun file selezionato.");
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _loadingContext = name;
        _loadingFileName = _selectedFile!.files.first.name;
      });

      // Creazione del contesto
      await _apiSdk.createContext(name, description: description);

      // Caricamento del file nel contesto creato
      String fileName = _selectedFile!.files.first.name;
      await _uploadFile(
        _selectedFile!.files.first.bytes!,
        [name],
        description: description,
        fileName: fileName,
      );

      _loadContexts(); // Ricarica i contesti dopo aver creato uno nuovo
    } catch (e) {
      print('Errore creazione contesto o caricamento file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingContext = null;
          _loadingFileName = null;
        });
      }
    }
  }
// Funzione per creare un nuovo contesto senza caricare subito un file
  Future<void> _createContext(String name, String description) async {
    try {
      // Creazione del contesto nell'API
      await _apiSdk.createContext(name, description: description);

      // Aggiunge il nuovo contesto manualmente alla lista dei contesti
      setState(() {
        _contexts.add(ContextMetadata(path: name, customMetadata: {'description': description}));
      });
    } catch (e) {
      print('Errore creazione contesto: $e');
    }
  }
  // Funzione per mostrare il dialog per creare un contesto con caricamento obbligatorio di un file
  // Funzione per mostrare il dialog per creare un contesto senza obbligo di caricare un file subito
  void _showCreateContextDialog() {
    TextEditingController contextNameController = TextEditingController();
    TextEditingController contextDescriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Crea Nuovo Contesto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contextNameController,
                decoration: InputDecoration(labelText: 'Nome del Contesto'),
              ),
              TextField(
                controller: contextDescriptionController,
                decoration: InputDecoration(labelText: 'Descrizione del Contesto'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (contextNameController.text.isNotEmpty) {
                  // Chiude il dialog prima di creare il contesto
                  Navigator.of(context).pop();
                  _createContext(
                    contextNameController.text,
                    contextDescriptionController.text,
                  );
                } else {
                  print('Errore: nome del contesto obbligatorio.');
                }
              },
              child: Text('Crea Contesto'),
            ),
          ],
        );
      },
    );
  }


  // Funzione per mostrare il dialog con la lista dei file di un contesto specifico
  void _showFilesForContextDialog(String contextPath) async {
    List<Map<String, dynamic>> filesForContext = await _loadFilesForContext(contextPath);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('File per il contesto: $contextPath'),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.upload_file),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _uploadFileForContext(contextPath);
                    },
                  ),
                  //IconButton(
                  //  icon: Icon(Icons.delete),
                  //  onPressed: () async {
                  //    Navigator.of(context).pop();
                   //   await _deleteContext(contextPath);
                    //},
                 // ),
                ],
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: filesForContext.isEmpty
                ? Text('Nessun file trovato per questo contesto.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filesForContext.length,
                    itemBuilder: (context, index) {
                      String filePath = filesForContext[index]['path'];
                      List<String> pathSegments = filePath.split('/');
                      String fileName = pathSegments.isNotEmpty ? pathSegments.last : 'Sconosciuto';
                      String contextName = pathSegments.length > 1
                          ? pathSegments[pathSegments.length - 2]
                          : 'Sconosciuto';
                      String fileSize =
                          filesForContext[index]['custom_metadata']['size'] ?? 'Sconosciuto';
                      String fileType =
                          filesForContext[index]['custom_metadata']['type'] ?? 'Sconosciuto';
                      String uploadDate =
                          filesForContext[index]['custom_metadata']['upload_date'] ??
                              'Sconosciuto';
                      String fileUUID =
                          filesForContext[index]['custom_metadata']['file_uuid'] ?? 'Sconosciuto';

                      return Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 5),
                              Text('Contesto di appartenenza: $contextName'),
                              //Text('Peso del file: $fileSize'),
                              //Text('Tipologia: $fileType'),
                              //Text('Data di caricamento: $uploadDate'),
                              Text('ID del file: $fileUUID'),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () async {
                                    await _deleteFile(fileUUID);
                                    setState(() {
                                      filesForContext.removeAt(index);
                                    });
                                    Navigator.of(context).pop();
                                    _showFilesForContextDialog(contextPath);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: //AppBar(
        //title: Text('Context API Dashboard'),
      //),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Text('Gestione dei Contesti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            //SizedBox(height: 10),
           Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Cambia l'allineamento per separare il testo e il pulsante
  children: [
    Text('Gestione dei Contesti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    ElevatedButton(
      onPressed: _showCreateContextDialog,
      child: Text('+ Crea Nuovo Contesto'),
    ),
  ],
),
            SizedBox(height: 10),
            Expanded(
              flex: 1,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 300,  // Dimensione massima per ciascuna scheda
  crossAxisSpacing: 10,     // Spaziatura tra le colonne
  mainAxisSpacing: 10,      // Spaziatura tra le righe
  childAspectRatio: 2,      // Proporzione larghezza/altezza delle schede
),
                itemCount: _contexts.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic>? metadata = _contexts[index].customMetadata;
                  List<Widget> metadataWidgets = [];

                  if (metadata != null) {
                    metadata.forEach((key, value) {
                      metadataWidgets.add(
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            '$key: ${value.toString().length > 20 ? value.toString().substring(0, 20) + '...' : value.toString()}',
                            style: TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    });
                  }

                  return GestureDetector(
                    onTap: () {
                      _showFilesForContextDialog(_contexts[index].path);
                    },
                    child: Card(
                      elevation: 2,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _contexts[index].path,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 5),
                                ...metadataWidgets,
                                // Mostra l'indicatore di caricamento solo se questo contesto sta caricando
                                if (_isLoadingMap[_contexts[index].path] == true) ...[
                                  SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        _loadingFileNamesMap[_contexts[index].path] ?? '',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteContext(_contexts[index].path);
                                } else if (value == 'upload') {
                                  _uploadFileForContext(_contexts[index].path);
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'upload',
                                  child: Text('Carica File'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Elimina'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
