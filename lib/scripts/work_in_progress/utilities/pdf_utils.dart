import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _pdfBytes;
  String? _pdfName;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 0;
  int _totalPages = 0;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      setState(() {
        _pdfBytes = fileBytes;
        _pdfName = fileName;
      });
    }
  }

  void _zoomIn() {
    if (_pdfViewerController.zoomLevel < 3) { // Livello massimo di zoom per la dimostrazione
      _pdfViewerController.zoomLevel += 0.25;
    }
  }

  void _zoomOut() {
    if (_pdfViewerController.zoomLevel > 1) { // Livello minimo di zoom per prevenire uno zoom eccessivo all'indietro
      _pdfViewerController.zoomLevel -= 0.25;
    }
  }

  void _jumpToPage(int pageNumber) {
    _pdfViewerController.jumpToPage(pageNumber);
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _pdfViewerController.previousPage();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      _pdfViewerController.nextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfName ?? "Carica e Visualizza PDF"),
        actions: _pdfBytes != null
            ? [
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: PdfSearchDelegate(_pdfViewerController),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.zoom_in),
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out),
                  onPressed: _zoomOut,
                ),
                IconButton(
                  icon: Icon(Icons.navigate_before),
                  onPressed: _previousPage,
                ),
                Center(
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.navigate_next),
                  onPressed: _nextPage,
                ),
              ]
            : null,
      ),
      body: Center(
        child: _pdfBytes == null
            ? ElevatedButton(
                onPressed: _pickFile,
                child: Text("Carica PDF"),
              )
            : SfPdfViewer.memory(
                _pdfBytes!,
                controller: _pdfViewerController,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  if (_totalPages != details.document.pages.count) {
                    setState(() {
                      _totalPages = details.document.pages.count;
                      _currentPage = _pdfViewerController.pageNumber;
                    });
                  }
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  if (_currentPage != details.newPageNumber) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                  }
                },
                key: GlobalKey(),
              ),
      ),
      floatingActionButton: _pdfBytes != null
          ? FloatingActionButton(
              child: Icon(Icons.list),
              onPressed: () {
                _showJumpToPageDialog(context);
              },
            )
          : null,
    );
  }

  void _showJumpToPageDialog(BuildContext context) {
    TextEditingController pageNumberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Jump to Page'),
          content: TextField(
            controller: pageNumberController,
            decoration: InputDecoration(labelText: 'Page Number'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                int pageNumber = int.tryParse(pageNumberController.text) ?? 1;
                _jumpToPage(pageNumber);
                Navigator.of(context).pop();
              },
              child: Text('Go'),
            ),
          ],
        );
      },
    );
  }
}

class PdfSearchDelegate extends SearchDelegate {
  final PdfViewerController pdfViewerController;

  PdfSearchDelegate(this.pdfViewerController);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pdfViewerController.searchText(query);
    });
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
