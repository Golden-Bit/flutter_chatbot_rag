import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

void main() {
  runApp(TableExportApp());
}

class TableExportApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Custom Table Import/Export',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TableExportScreen(),
    );
  }
}

class TableExportScreen extends StatefulWidget {
  @override
  _TableExportScreenState createState() => _TableExportScreenState();
}

class _TableExportScreenState extends State<TableExportScreen> {
  List<List<String>> data = [
    ["Name", "Age", "Profession"],
    ["John Doe", "28", "Engineer"],
    ["Jane Smith", "34", "Doctor"],
    ["Alex Johnson", "40", "Teacher"]
  ];

  List<String> filters = ["", "", ""];
  List<bool> selectedRows = [false, false, false, false];
  bool isSelectAllChecked = false;

  void _updateCell(int rowIndex, int columnIndex, String value) {
    setState(() {
      data[rowIndex][columnIndex] = value;
    });
  }

  void _updateFilter(int columnIndex, String value) {
    setState(() {
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
      selectedRows[rowIndex] = !selectedRows[rowIndex];
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      isSelectAllChecked = value ?? false;
      for (int i = 1; i < selectedRows.length; i++) {
        if (_filterRow(data[i])) {
          selectedRows[i] = isSelectAllChecked;
        }
      }
    });
  }

  void _deleteSelectedRows() {
    setState(() {
      List<int> rowsToDelete = [];
      for (int i = 1; i < selectedRows.length; i++) {
        if (selectedRows[i] && _filterRow(data[i])) {
          rowsToDelete.add(i);
        }
      }
      for (int i = rowsToDelete.length - 1; i >= 0; i--) {
        data.removeAt(rowsToDelete[i]);
        selectedRows.removeAt(rowsToDelete[i]);
      }
      isSelectAllChecked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Web Custom Table Import/Export Example'),
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
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
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 180,
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: List.generate(data[0].length, (columnIndex) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double width = constraints.maxWidth.clamp(200.0, 600.0);
                          return Container(
                            width: width,
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                labelText: 'Filtra ${data[0][columnIndex]}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                              ),
                              onChanged: (value) {
                                _updateFilter(columnIndex, value);
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              height: 180,
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addRow,
                            child: Text("+ Aggiungi riga"),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _addColumn,
                            child: Text("+ Aggiungi colonna"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _deleteSelectedRows,
                            child: Text("Elimina selezionati"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _exportCSV,
                            child: Text("Esporta CSV"),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _exportJSON,
                            child: Text("Esporta JSON"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _importCSV,
                            child: Text("Importa CSV"),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _importJSON,
                            child: Text("Importa JSON"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  void _addRow() {
    setState(() {
      data.add(List<String>.filled(data[0].length, "", growable: true));
      selectedRows.add(false);
    });
  }

  void _addColumn() {
    setState(() {
      for (var i = 0; i < data.length; i++) {
        data[i].add("");
      }
      filters.add("");
    });
  }

  void _deleteColumn(int columnIndex) {
    setState(() {
      for (var i = 0; i < data.length; i++) {
        data[i].removeAt(columnIndex);
      }
      filters.removeAt(columnIndex);
    });
  }

  void _moveColumnLeft(int columnIndex) {
    if (columnIndex > 0) {
      setState(() {
        for (var row in data) {
          final cell = row.removeAt(columnIndex);
          row.insert(columnIndex - 1, cell);
        }
        final filter = filters.removeAt(columnIndex);
        filters.insert(columnIndex - 1, filter);
      });
    }
  }

  void _moveColumnRight(int columnIndex) {
    if (columnIndex < data[0].length - 1) {
      setState(() {
        for (var row in data) {
          final cell = row.removeAt(columnIndex);
          row.insert(columnIndex + 1, cell);
        }
        final filter = filters.removeAt(columnIndex);
        filters.insert(columnIndex + 1, filter);
      });
    }
  }

  void _deleteRow(int rowIndex) {
    setState(() {
      data.removeAt(rowIndex);
      selectedRows.removeAt(rowIndex);
    });
  }

  void _moveRowUp(int rowIndex) {
    if (rowIndex > 1) {
      setState(() {
        final row = data.removeAt(rowIndex);
        data.insert(rowIndex - 1, row);
        final selected = selectedRows.removeAt(rowIndex);
        selectedRows.insert(rowIndex - 1, selected);
      });
    }
  }

  void _moveRowDown(int rowIndex) {
    if (rowIndex < data.length - 1) {
      setState(() {
        final row = data.removeAt(rowIndex);
        data.insert(rowIndex + 1, row);
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
}
