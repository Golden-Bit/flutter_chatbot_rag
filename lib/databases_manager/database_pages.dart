import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Importa foundation.dart per kIsWeb
import 'database_model.dart';
import 'database_service.dart';
import 'expandable_card.dart';
//import 'json_viewer.dart';
import '../user_manager/user_model.dart';
import 'dart:convert';  // Importa dart:convert per jsonDecode e JsonEncoder
import 'dart:html' as html; // Aggiungi questa importazione per la gestione dei file su web
import 'package:path_provider/path_provider.dart'; // Importa per le piattaforme non web

class DatabasePage extends StatefulWidget {
  final List<Database> databases;
  final String token;
  final User user;

  DatabasePage({required this.databases, required this.token, required this.user});

  @override
  _DatabasePageState createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final TextEditingController _dbNameController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();


  void _createDatabase() async {
    if (_dbNameController.text.isNotEmpty) {
      final String inputDbName = _dbNameController.text;
      final String fullDbName = "${widget.user.username}-$inputDbName";

      try {
        await _databaseService.createDatabase(inputDbName, widget.token);
        setState(() {
          widget.databases.add(Database(
            dbName: fullDbName,
            host: "localhost",
            port: 27017,
          ));
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Database creato con successo!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante la creazione del database: $e'),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Inserisci il nome del database!'),
      ));
    }
  }

  void _createCollection(String dbName) async {
    final TextEditingController _collectionNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Crea nuova Collection'),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: TextField(
            controller: _collectionNameController,
            decoration: InputDecoration(labelText: 'Nome Collection'),
          ),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Crea'),
              onPressed: () async {
                if (_collectionNameController.text.isNotEmpty) {
                  try {
                    await _databaseService.createCollection(dbName, _collectionNameController.text, widget.token);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Collection creata con successo!'),
                    ));
                    Navigator.of(context).pop(); // Chiude il dialog
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante la creazione della collection: $e'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Inserisci il nome della collection!'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteDatabase(String dbName) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Conferma Eliminazione Database'),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: Text('Sei sicuro di voler eliminare il database $dbName?'),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Elimina',                    
              style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
              onPressed: () async {
                try {
                  await _databaseService.deleteDatabase(dbName, widget.token);
                  setState(() {
                    widget.databases.removeWhere((db) => db.dbName == dbName);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Database eliminato con successo!'),
                  ));
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante l\'eliminazione del database: $e'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

 void _showCollections(String dbName) async {
  try {
    List<Collection> collections = await _databaseService.fetchCollections(dbName, widget.token);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Collections in $dbName'),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                bool _isHovering = false;

                return StatefulBuilder(
                  builder: (context, setState) {
                    return MouseRegion(
                      onEnter: (_) {
                        setState(() {
                          _isHovering = true;
                        });
                      },
                      onExit: (_) {
                        setState(() {
                          _isHovering = false;
                        });
                      },
                      child: ListTile(
                        title: Text(collection.name),
                        trailing: _isHovering
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: Colors.green),
                                    onPressed: () => _addDataToCollection(dbName, collection.name),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteCollection(dbName, collection.name),
                                  ),
                                ],
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _showCollectionData(dbName, collection.name);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Errore durante il caricamento delle collection: $e'),
    ));
  }
}


  void _addDataToCollection(String dbName, String collectionName) async {
    final TextEditingController _jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aggiungi Dato a $collectionName'),
            ],
          ),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      final jsonData = jsonDecode(_jsonController.text);
                      _jsonController.text = JsonEncoder.withIndent('  ').convert(jsonData);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Errore durante la formattazione del JSON: $e'),
                      ));
                    }
                  },
                  child: Text('Formatta JSON'),
                ),
              ),
              TextField(
                controller: _jsonController,
                decoration: InputDecoration(
                  labelText: 'Inserisci il dato in formato JSON',
                ),
                maxLines: 8,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Aggiungi'),
              onPressed: () async {
                if (_jsonController.text.isNotEmpty) {
                  try {
                    final jsonData = jsonDecode(_jsonController.text);
                    await _databaseService.addDataToCollection(dbName, collectionName, jsonData, widget.token);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Dato aggiunto con successo a $collectionName!'),
                    ));
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante l\'aggiunta del dato: $e'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Inserisci un dato valido in formato JSON!'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteCollection(String dbName, String collectionName) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Conferma Eliminazione Collection'),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: Text('Sei sicuro di voler eliminare la collection $collectionName?'),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Elimina',                   
               style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
              onPressed: () async {
                try {
                  await _databaseService.deleteCollection(dbName, collectionName, widget.token);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Collection $collectionName eliminata con successo!'),
                  ));
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante l\'eliminazione della collection: $e'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

void _showCollectionData(String dbName, String collectionName) async {
    try {
      List<Map<String, dynamic>> data = await _databaseService.fetchCollectionData(dbName, collectionName, widget.token);
      List<Map<String, dynamic>> filteredData = List.from(data);

      List<Map<String, String>> filters = [];
      List<String> jsonKeys = data.isNotEmpty ? data.first.keys.toList() : [];

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              void applyFilters() {
                setState(() {
                  filteredData = data.where((item) {
                    return filters.every((filter) {
                      final field = filter['field']!;
                      final value = filter['value']!;
                      return item[field]?.toString().contains(value) ?? false;
                    });
                  }).toList();
                });
              }

              Future<void> importData() async {
                try {
                  if (kIsWeb) {
                    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
                    uploadInput.accept = '.json';
                    uploadInput.click();

                    uploadInput.onChange.listen((event) async {
                      final files = uploadInput.files;
                      if (files != null && files.isNotEmpty) {
                        final file = files.first;
                        final reader = html.FileReader();

                        reader.onLoadEnd.listen((event) async {
                          final content = reader.result as String;
                          List<dynamic> jsonData = jsonDecode(content);

                          for (var item in jsonData) {
                            if (item is Map<String, dynamic>) {
                              await _databaseService.addDataToCollection(dbName, collectionName, item, widget.token);
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Dati importati con successo!'),
                          ));
                        });

                        reader.readAsText(file);
                      }
                    });
                  } else {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (result != null) {
                      File file = File(result.files.single.path!);
                      String content = await file.readAsString();
                      List<dynamic> jsonData = jsonDecode(content);

                      for (var item in jsonData) {
                        if (item is Map<String, dynamic>) {
                          await _databaseService.addDataToCollection(dbName, collectionName, item, widget.token);
                        }
                      }

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Dati importati con successo!'),
                      ));
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante l\'importazione dei dati: $e'),
                  ));
                }
              }

            Future<void> exportData() async {
    try {
        // Utilizza i dati filtrati per creare il contenuto JSON
        String jsonContent = JsonEncoder.withIndent('  ').convert(filteredData);

        if (kIsWeb) {
            final bytes = utf8.encode(jsonContent);
            final blob = html.Blob([bytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute("download", "$collectionName.json")
              ..click();
            html.Url.revokeObjectUrl(url);
        } else {
            final directory = await getApplicationDocumentsDirectory(); // Per piattaforme non web
            final path = '${directory.path}/$collectionName.json';
            final file = File(path);
            await file.writeAsString(jsonContent);

            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Dati esportati con successo in $path!'),
            ));
        }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante l\'esportazione dei dati: $e'),
        ));
    }
}

              return AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Dati in $collectionName'),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showCollections(dbName); // Riapre il dialog delle collections
                      },
                    ),
                  ],
                ),
                           backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Riquadro principale che contiene i filtri e i pulsanti
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0), // Padding interno
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      constraints: BoxConstraints(
                        maxHeight: 150.0, // Altezza massima del riquadro
                      ),
                      child: Row(
                        children: [
                          // Lista scorrevole dei filtri
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  ...filters.map((filter) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              value: filter['field'],
                                              onChanged: (newValue) {
                                                setState(() {
                                                  filter['field'] = newValue!;
                                                });
                                              },
                                              items: jsonKeys.map<DropdownMenuItem<String>>((String key) {
                                                return DropdownMenuItem<String>(
                                                  value: key,
                                                  child: Text(key),
                                                );
                                              }).toList(),
                                              decoration: InputDecoration(
                                                labelText: 'Campo',
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              onChanged: (newValue) {
                                                setState(() {
                                                  filter['value'] = newValue;
                                                });
                                              },
                                              decoration: InputDecoration(
                                                labelText: 'Valore',
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                filters.remove(filter);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ),
                          // Riquadro laterale per i pulsanti
                          Container(
                            padding: EdgeInsets.all(8.0), // Padding interno del riquadro dei pulsanti
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: [
                                // Colonna sinistra con i pulsanti "Aggiungi Filtro" e "Applica Filtri"
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribuisce uniformemente i pulsanti
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          filters.add({'field': jsonKeys.first, 'value': ''});
                                        });
                                      },
                                      icon: Icon(Icons.add),
                                      label: Text('Aggiungi Filtro'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(180, 60), // Imposta la larghezza minima per il pulsante
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0), // Stesso angolo dei riquadri
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8.0), // Spaziatura verticale tra i pulsanti
                                    ElevatedButton.icon(
                                      onPressed: applyFilters, // Chiamata a applyFilters che aggiorna immediatamente lo stato
                                      icon: Icon(Icons.search), // Icona della lente di ricerca
                                      label: Text('Applica Filtri'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(180, 60), // Imposta la larghezza minima per il pulsante
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0), // Stesso angolo dei riquadri
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 8.0), // Spaziatura orizzontale tra le due colonne di pulsanti
                                // Colonna destra con i pulsanti "Importa Dati" e "Esporta Dati"
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribuisce uniformemente i pulsanti
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: importData, // Chiama la logica di importazione
                                      icon: Icon(Icons.file_upload), // Icona per l'importazione
                                      label: Text('Importa Dati'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(180, 60), // Imposta la larghezza minima per il pulsante
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0), // Stesso angolo dei riquadri
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 8.0), // Spaziatura verticale tra i pulsanti
                                    ElevatedButton.icon(
                                      onPressed: exportData, // Chiama la logica di esportazione
                                      icon: Icon(Icons.file_download), // Icona per l'esportazione
                                      label: Text('Esporta Dati'),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: Size(180, 60), // Imposta la larghezza minima per il pulsante
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0), // Stesso angolo dei riquadri
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.0),
                    // Sezione dei dati filtrati
                    Expanded(
                      child: Container(
                        width: double.maxFinite,
                        height: 400,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final item = filteredData[index];
                            return ExpandableCard(
                              item: item,
                              dbName: dbName,
                              collectionName: collectionName,
                              onEdit: (item) => _editCollectionData(dbName, collectionName, item),
                              onDelete: (itemId) => _deleteCollectionData(dbName, collectionName, itemId),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Chiudi'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Errore durante il caricamento dei dati della collection: $e'),
      ));
    }
  }


  void _editCollectionData(String dbName, String collectionName, Map<String, dynamic> item) async {
    Map<String, dynamic> itemCopy = Map.from(item);
    itemCopy.remove('_id');

    final TextEditingController _jsonController = TextEditingController(
      text: JsonEncoder.withIndent('  ').convert(itemCopy),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifica Dato in $collectionName'),
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      final jsonData = jsonDecode(_jsonController.text);
                      _jsonController.text = JsonEncoder.withIndent('  ').convert(jsonData);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Errore durante la formattazione del JSON: $e'),
                      ));
                    }
                  },
                  child: Text('Formatta JSON'),
                ),
              ),
              TextField(
                controller: _jsonController,
                decoration: InputDecoration(
                  labelText: 'Modifica il dato in formato JSON',
                ),
                maxLines: 8,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Salva'),
              onPressed: () async {
                if (_jsonController.text.isNotEmpty) {
                  try {
                    final jsonData = jsonDecode(_jsonController.text);

                    await _databaseService.updateCollectionData(
                      dbName,
                      collectionName,
                      item['_id'],
                      jsonData,
                      widget.token,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Dato aggiornato con successo in $collectionName!'),
                    ));
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante l\'aggiornamento del dato: $e'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Inserisci un dato valido in formato JSON!'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteCollectionData(String dbName, String collectionName, String itemId) async {
  Navigator.of(context).pop(); // Chiude il dialogo prima di eseguire l'eliminazione
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Conferma Eliminazione Dato'),
                   backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
        content: Text('Sei sicuro di voler eliminare questo dato?'),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Elimina',                    
            style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
            onPressed: () async {
              try {
                await _databaseService.deleteCollectionData(dbName, collectionName, itemId, widget.token);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Dato eliminato con successo!'),
                ));
                Navigator.of(context).pop(); // Chiude il dialogo di conferma eliminazione
                _showCollectionData(dbName, collectionName); // Ricarica i dati della collection
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Errore durante l\'eliminazione del dato: $e'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Databases'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calcola il numero di colonne in base alla larghezza disponibile
                int columns = (constraints.maxWidth ~/ 250).toInt(); // Adatta 250 alla larghezza desiderata per ogni scheda
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  children: widget.databases.map((db) {
                    return InkWell(
                      onTap: () => _showCollections(db.dbName), // Apre la lista delle collections al clic
                      child: Card(
                                      color: Colors.white, // Imposta lo sfondo bianco
                                                          elevation: 6, // Intensità dell'ombra (0 = nessuna ombra)
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4), // Angoli arrotondati
    //side: BorderSide(
    //  color: Colors.grey, // Colore dei bordi
    //  width: 0, // Spessore dei bordi
    //),
  ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // Allinea i testi a sinistra
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    db.dbName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.left, // Assicura l'allineamento a sinistra
                                  ),
                                  PopupMenuButton<String>(
                                                                                            color: Colors.white,
                                    onSelected: (value) {
                                      if (value == 'create') {
                                        _createCollection(db.dbName);
                                      } else if (value == 'delete') {
                                        _deleteDatabase(db.dbName);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) {
                                      return [
                                        PopupMenuItem(
                                          value: 'create',
                                          child: Text('Crea Collection'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Elimina Database'),
                                        ),
                                      ];
                                    },
                                    icon: Icon(Icons.more_vert),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0),
                              Container(
                                width: double.infinity, // Occupa tutta la larghezza disponibile
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0), // Bordi smussati
                                  child: Image.asset(
                                    '/mongodb_icon.png', // Sostituisci con il percorso corretto dell'immagine
                                    height: 80.0, // Altezza dell'immagine
                                    fit: BoxFit.cover, // Assicura che l'immagine copra l'intero container
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.0),
                              Text(
                                'Host: ${db.host}',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.left,
                              ),
                              Text(
                                'Port: ${db.port}',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.left,
                              ),
                              Text(
                                'Tipologia: Database Mongo',
                                style: TextStyle(fontSize: 14),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Crea Database'),
                         backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _dbNameController,
                    decoration: InputDecoration(labelText: 'Nome Database'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Annulla'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('Crea'),
                  onPressed: () {
                    _createDatabase();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Icon(Icons.add),
    ),
  );
 }
}