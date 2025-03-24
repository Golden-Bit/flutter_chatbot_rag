import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_app/ui_components/icons/cube.dart';
import 'context_api_sdk.dart';
import 'dart:typed_data';

/*void main() {
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
}*/

class DashboardScreen extends StatefulWidget {
  final String username;
  final String token;

  const DashboardScreen({
    Key? key,
    required this.username,
    required this.token,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ContextApiSdk _apiSdk = ContextApiSdk();
  List<ContextMetadata> _contexts = [];
  FilePickerResult? _selectedFile;
  bool _isLoading =
      false; // Variabile di stato per indicare il caricamento generale
  String? _loadingContext; // Contesto corrente per l'upload
  String? _loadingFileName; // Nome del file in fase di caricamento

  Map<String, bool> _isLoadingMap =
      {}; // Stato di caricamento per ciascun contesto
  Map<String, String?> _loadingFileNamesMap =
      {}; // Nome del file in caricamento per ciascun contesto
// Controller per le due barre di ricerca
  TextEditingController _nameSearchController =
      TextEditingController(); // Per la ricerca per nome
  TextEditingController _descriptionSearchController =
      TextEditingController(); // Per la ricerca per descrizione

// Lista dei contesti filtrati
  List<ContextMetadata> _filteredContexts = [];

  @override
  void initState() {
    super.initState();
    _loadContexts();
  }

  /// Restituisce un'icona basata sull'estensione del file.
  Map<String, dynamic> _getIconForFileType(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return {'icon': Icons.picture_as_pdf, 'color': Colors.red};
      case 'docx':
      case 'doc':
        return {'icon': Icons.article, 'color': Colors.blue};
      case 'xlsx':
      case 'xls':
        return {'icon': Icons.table_chart, 'color': Colors.green};
      case 'pptx':
      case 'ppt':
        return {'icon': Icons.slideshow, 'color': Colors.orange};
      case 'txt':
        return {'icon': Icons.text_snippet, 'color': Colors.grey};
      case 'jpg':
      case 'jpeg':
      case 'png':
        return {'icon': Icons.image, 'color': Colors.purple};
      case 'zip':
      case 'rar':
        return {'icon': Icons.folder_zip, 'color': Colors.brown};
      default:
        return {'icon': Icons.insert_drive_file, 'color': Colors.grey};
    }
  }

  // Funzione per caricare i contesti
  Future<void> _loadContexts() async {
    try {
      final contexts =
          await _apiSdk.listContexts(widget.username, widget.token);
      if (mounted) {
        setState(() {
          _contexts = contexts;
          _filteredContexts =
              List.from(_contexts); // Inizializza la lista filtrata
        });
      }
    } catch (e) {
      print('Errore nel recupero dei contesti: $e');
    }
  }

  void _filterContexts() {
    final query = _nameSearchController.text.toLowerCase(); // Unica query

    setState(() {
      _filteredContexts = _contexts.where((context) {
        final name = context.path.toLowerCase();
        final description =
            (context.customMetadata?['description'] ?? '').toLowerCase();
        return name.contains(query) ||
            description.contains(query); // Controllo su entrambi
      }).toList();
    });
  }

  // Funzione per caricare i file di un contesto specifico
  Future<List<Map<String, dynamic>>> _loadFilesForContext(
      String contextPath) async {
    try {
      final files = await _apiSdk
          .listFiles(widget.username, widget.token, contexts: [contextPath]);
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
          fileBytes, contexts, widget.username, widget.token,
          description: description, fileName: fileName);
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
      await _apiSdk.deleteContext(contextName, widget.username, widget.token);
      _loadContexts();
    } catch (e) {
      print('Errore eliminazione contesto: $e');
    }
  }

  // Funzione per eliminare un file
  Future<void> _deleteFile(String fileId) async {
    try {
      await _apiSdk.deleteFile(widget.username, widget.token, fileId: fileId);
    } catch (e) {
      print('Errore eliminazione file: $e');
    }
  }

  // Funzione per gestire l'upload del file per un contesto specifico
  void _uploadFileForContext(String contextPath) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.first.bytes != null) {
      setState(() {
        // Stato di caricamento del contesto specifico
        _isLoadingMap[contextPath] = true;
        _loadingFileNamesMap[contextPath] =
            result.files.first.name; // Nome del file in caricamento
      });

      try {
        await _uploadFile(
          result.files.first.bytes!,
          [contextPath],
          fileName: result.files.first.name,
        );
      } catch (e) {
        print('Errore durante il caricamento: $e');
      } finally {
        setState(() {
          // Rimuovi lo stato di caricamento una volta completato
          _isLoadingMap.remove(contextPath);
          _loadingFileNamesMap.remove(contextPath);
        });
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
              backgroundColor: Colors.white, // Sfondo del popup
              elevation: 6, // Intensità dell'ombra
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(4), // Arrotondamento degli angoli
                //side: BorderSide(
                //  color: Colors.blue, // Colore del bordo
                //  width: 2, // Spessore del bordo
                //),
              ),
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
                    decoration:
                        InputDecoration(labelText: 'Seleziona le Knowledge Boxes'),
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
                    decoration:
                        InputDecoration(labelText: 'Descrizione del File'),
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
Widget _buildSearchAreaWithTitle() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth > 900) {
        // Se la larghezza disponibile è maggiore di 900,
        // mostra titolo e campo di ricerca in riga, con spazio tra di loro
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Titolo allineato a sinistra
            Text(
              'Knowledge Boxes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            // Campo di ricerca con larghezza massima fissata (ad es. 600)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600),
              child: TextField(
                controller: _nameSearchController,
                onChanged: (value) {
                  _filterContexts();
                },
                decoration: InputDecoration(
                  hintText: 'Cerca per nome o descrizione...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        // Se la larghezza disponibile è inferiore a 900,
        // mostra il titolo sopra il campo di ricerca
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titolo allineato a sinistra
            Text(
              'Knowledge Boxes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            // Campo di ricerca centrato e che occupa tutta la larghezza disponibile
            Center(
              child: TextField(
                controller: _nameSearchController,
                onChanged: (value) {
                  _filterContexts();
                },
                decoration: InputDecoration(
                  hintText: 'Cerca per nome o descrizione...',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black), // Bordi neri
                  ),
    enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
                ),
              ),
            ),
          ],
        );
      }
    },
  );
}

  // Funzione per creare un nuovo contesto e caricare il file obbligatorio
  Future<void> _createContextAndUploadFile(
      String name, String description) async {
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

      await _apiSdk.createContext(
          name, description, widget.username, widget.token);

      String fileName = _selectedFile!.files.first.name;
      await _uploadFile(
        _selectedFile!.files.first.bytes!,
        [name],
        description: description,
        fileName: fileName,
      );

      setState(() {
        _contexts.add(ContextMetadata(
            path: name, customMetadata: {'description': description}));
        _filteredContexts = List.from(_contexts); // Sincronizza con _contexts
        _filterContexts(); // Applica i filtri
      });
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

  Future<void> _createContext(String name, String description) async {
    try {
      await _apiSdk.createContext(
          name, description, widget.username, widget.token);

      setState(() {
        _contexts.add(ContextMetadata(
            path: name, customMetadata: {'description': description}));
        _filteredContexts = List.from(_contexts); // Sincronizza con _contexts
        _filterContexts(); // Applica i filtri
      });
    } catch (e) {
      print('Errore creazione contesto: $e');
    }
  }

  // Funzione per mostrare il dialog per creare un contesto con caricamento obbligatorio di un file
  // Funzione per mostrare il dialog per creare un contesto senza obbligo di caricare un file subito
  void _showCreateContextDialog() {
    TextEditingController contextNameController = TextEditingController();
    TextEditingController contextDescriptionController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Crea Nuovo Contesto'),
          backgroundColor: Colors.white, // Sfondo del popup
          elevation: 6, // Intensità dell'ombra
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16), // Arrotondamento degli angoli
            //side: BorderSide(
            //  color: Colors.blue, // Colore del bordo
            //  width: 2, // Spessore del bordo
            //),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contextNameController,
                decoration: InputDecoration(labelText: 'Nome del Contesto'),
              ),
              TextField(
                controller: contextDescriptionController,
                decoration:
                    InputDecoration(labelText: 'Descrizione del Contesto'),
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

  void _showFilesForContextDialog(String contextPath) async {
    // Carica i file per il contesto selezionato
    List<Map<String, dynamic>> filesForContext =
        await _loadFilesForContext(contextPath);

    // Trova la descrizione associata al contesto corrente
    final selectedContext = _contexts.firstWhere(
      (context) => context.path == contextPath,
      orElse: () => ContextMetadata(path: '', customMetadata: {}),
    );
    final description = selectedContext.customMetadata?['description'] ?? null;

    // Controller per la barra di ricerca
    TextEditingController searchController = TextEditingController();

    // Lista dei file filtrati
    List<Map<String, dynamic>> filteredFiles = List.from(filesForContext);

    // Funzione per filtrare i file
    void _filterFiles(String query) {
      filteredFiles = filesForContext.where((file) {
        final fileName = (file['path'] ?? '').toLowerCase();
        return fileName.contains(query.toLowerCase());
      }).toList();
    }

    // Mostra il dialog
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
                        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16), // Arrotondamento degli angoli
            //side: BorderSide(
            //  color: Colors.blue, // Colore del bordo
            //  width: 2, // Spessore del bordo
            //),
          ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    WireframeCubeIcon(
  size: 36.0,
  color: Colors.blue,
),
    SizedBox(width: 8.0),
                  Text(
                    contextPath,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )]),
                  SizedBox(height: 8.0),
                  if (description != null)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 16.0),
                  // Barra di ricerca
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      // Aggiorna i risultati del filtro
                      setState(() {
                        _filterFiles(value);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cerca file...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black), // Bordi neri
                  ),
    enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 6,
              //shape: RoundedRectangleBorder(
              //  borderRadius: BorderRadius.circular(8),
              //),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400, maxHeight: 800),
                child: Container(
                  width: double.maxFinite,
                  child: filteredFiles.isEmpty
                      ? Text('Nessun file trovato per questo contesto.')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredFiles.length,
                          itemBuilder: (context, index) {
                            String filePath = filteredFiles[index]['path'];
                            List<String> pathSegments = filePath.split('/');
                            String fileName = pathSegments.isNotEmpty
                                ? pathSegments.last
                                : 'Sconosciuto';
                            String fileUUID = filteredFiles[index]
                                    ['custom_metadata']['file_uuid'] ??
                                'Sconosciuto';
                            String fileType = filteredFiles[index]
                                    ['custom_metadata']['type'] ??
                                'Sconosciuto';
                            String uploadDate = filteredFiles[index]
                                    ['custom_metadata']['upload_date'] ??
                                'Sconosciuto';
                            String fileSize = filteredFiles[index]
                                    ['custom_metadata']['size'] ??
                                'Sconosciuto';

                            return Card(
                              color: Colors.white,
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Riga superiore: Nome file e icona rappresentativa
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Nome del file
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Icona del file
                                        Icon(
                                          _getIconForFileType(fileName)[
                                              'icon'], // Ottieni l'icona
                                          size: 32,
                                          color: _getIconForFileType(fileName)[
                                              'color'], // Ottieni il colore
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    // Dettagli aggiuntivi del file
                                    Text('Tipo: $fileType'),
                                    Text('Dimensione: $fileSize'),
                                    Text('Data di caricamento: $uploadDate'),
                                    // Spazio per spostare il cestino in basso
                                    Spacer(),
                                    // Cestino in basso a destra
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: IconButton(
                                        icon: Icon(Icons.delete,
                                            color:
                                                Colors.black), // Cestino nero
                                        onPressed: () async {
                                          await _deleteFile(
                                              fileUUID); // Funzione per eliminare il file
                                          setState(() {
                                            filesForContext.removeWhere(
                                                (file) =>
                                                    file['custom_metadata']
                                                        ['file_uuid'] ==
                                                    fileUUID);
                                            _filterFiles(searchController
                                                .text); // Aggiorna la lista filtrata
                                          });
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: //AppBar(
      //title: Text('Context API Dashboard'),
      //),
      backgroundColor: Colors.transparent, // Imposta lo sfondo bianco
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
            //Text('Gestione dei Contesti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            //SizedBox(height: 10),
// Titolo e pulsante "Nuovo Contesto"
            Text('Knowledge Boxes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
// Barre di ricerca
const SizedBox(width: 16),
    ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 250), // Limite di larghezza
      child: TextField(
        controller: _nameSearchController,
        onChanged: (value) {
          _filterContexts(); // Aggiorna i risultati del filtro
        },
        decoration: InputDecoration(
          hintText: 'Cerca per nome o descrizione...',
          prefixIcon: Icon(Icons.search),
          contentPadding: EdgeInsets.symmetric(vertical: 8.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    ),
  ],
),*/
_buildSearchAreaWithTitle(),
            SizedBox(height: 10),

            SizedBox(height: 10),
            Expanded(
              flex: 1,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent:
                      300, // Dimensione massima per ciascuna scheda
                  crossAxisSpacing: 10, // Spaziatura tra le colonne
                  mainAxisSpacing: 10, // Spaziatura tra le righe
                  childAspectRatio:
                      1.5, // Proporzione larghezza/altezza delle schede
                ),
                itemCount:
                    _filteredContexts.length + 1, // Aggiungiamo una card in più
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap:
                          _showCreateContextDialog, // Apre il dialog per creare il contesto
                      child: Card(
                        color: Colors.blue, // Sfondo grigio
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Crea Knowledge Box',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Testo bianco
                            ),
                          ),
                        ),
                      ),
                    );
                  }

// Dopo questa parte, lascia il resto invariato
                  final contextMetadata = _filteredContexts[
                      index - 1]; // Offset perché il primo è la scheda grigia

                  Map<String, dynamic>? metadata =
                      contextMetadata.customMetadata;
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
                      _showFilesForContextDialog(contextMetadata.path);
                    },
                    child: Card(
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
                                          // 1) ICONA CUBO
WireframeCubeIcon(
  size: 36.0,
  color: Colors.blue,
),
    SizedBox(width: 8.0),
                                      // Nome del contesto
                                      Text(
                                        contextMetadata.path,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )]),
                                      // Rotella di caricamento e nome del file (se in caricamento)
                                    ],
                                  ),
                                ),
                                // Menu popup per azioni (Carica File ed Elimina Contesto)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteContext(contextMetadata.path);
                                    } else if (value == 'upload') {
                                      _uploadFileForContext(
                                          contextMetadata.path);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
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
                              ],
                            ),
                            SizedBox(height: 5),
                            // Metadati del contesto
                            ...metadataWidgets,
                            SizedBox(height: 5),
                            if (_isLoadingMap[contextMetadata.path] == true &&
                                _loadingFileNamesMap[contextMetadata.path] !=
                                    null)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16.0,
                                    height: 16.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0, // Rotella più sottile
                                      color:
                                          Colors.blue, // Colore della rotella
                                    ),
                                  ),
                                  SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      _loadingFileNamesMap[
                                              contextMetadata.path] ??
                                          '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
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

