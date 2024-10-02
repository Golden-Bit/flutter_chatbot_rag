import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';
import 'dart:html' as html;

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
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

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

  void _savePdf() {
    if (_pdfBytes != null) {
      // Load the PDF document
      PdfDocument document = PdfDocument(inputBytes: _pdfBytes!);

      // Apply the web link annotation
      PdfTextWebLink webLink = PdfTextWebLink(
        url: 'https://www.example.com',
        text: 'Example',
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
      );

      // Draw the web link on the first page
      webLink.draw(
        document.pages[0],
        Offset(100, 100),
      );

      // Flatten the annotations so they are embedded in the PDF as static content
      for (int i = 0; i < document.pages.count; i++) {
        document.pages[i].annotations.flattenAllAnnotations();
      }

      // Save the document as bytes
      List<int> bytes = document.saveSync();
      document.dispose();

      // Convert the bytes to a blob and create an anchor element
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
                  icon: Icon(Icons.download),
                  onPressed: _savePdf,
                ),
              ]
            : [
                IconButton(
                  icon: Icon(Icons.upload_file),
                  onPressed: _pickFile,
                ),
              ],
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
                key: _pdfViewerKey,
              ),
      ),
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
