import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html; // Import per gestire download su web

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTML Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _htmlBytes;
  String? _htmlSource;
  bool _isHtmlLoaded = false;
  TextEditingController _textEditingController = TextEditingController();
  double _splitRatio = 0.5;

  ViewMode _viewMode = ViewMode.editAndView;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html'],
    );

    if (result != null && result.files.first.bytes != null) {
      final fileBytes = result.files.first.bytes;
      final htmlSource = utf8.decode(fileBytes!);

      setState(() {
        _htmlBytes = fileBytes;
        _htmlSource = htmlSource;
        _isHtmlLoaded = true;
        _textEditingController.text = _htmlSource!;
      });
    }
  }

  void _formatHtml() {
    if (_textEditingController.text.isNotEmpty) {
      final document = parser.parse(_textEditingController.text);
      final formattedHtml = _formatDocument(document);
      setState(() {
        _textEditingController.text = formattedHtml;
      });
    }
  }

  String _formatDocument(dom.Document document) {
    final buffer = StringBuffer();
    _writeNode(buffer, document.documentElement!, 0);
    return buffer.toString();
  }

  void _writeNode(StringBuffer buffer, dom.Node node, int indentLevel) {
    final indent = '  ' * indentLevel;
    if (node is dom.Element) {
      if (node.localName == 'pre' || node.localName == 'code') {
        buffer.write(node.outerHtml);
      } else {
        buffer.writeln('$indent<${node.localName}>');
        node.nodes.forEach((child) {
          _writeNode(buffer, child, indentLevel + 1);
        });
        buffer.writeln('$indent</${node.localName}>');
      }
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.writeln('$indent$text');
      }
    }
  }

  void _downloadHtmlSource() {
    if (_htmlSource != null) {
      final bytes = utf8.encode(_htmlSource!);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "downloaded_html.html")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _downloadRenderedPdf() async {
    try {
      final pdf = pw.Document();
      if (_htmlSource != null) {
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text(_textEditingController.text),
              );
            },
          ),
        );

        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "rendered_pdf.pdf")
          ..click();
        html.Url.revokeObjectUrl(url);
      }
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
        title: Text("HTML Viewer"),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _pickFile,
          ),
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
      body: _htmlBytes == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickFile,
                child: Text("Load HTML File"),
              ),
            )
          : Padding(
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
                  'HTML content will be displayed here',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}

enum ViewMode { editOnly, viewOnly, editAndView }

class HtmlUtils {
  /// Formatta un documento HTML in una stringa leggibile.
  static String formatDocument(dom.Document document) {
    final buffer = StringBuffer();
    _writeNode(buffer, document.documentElement!, 0);
    return buffer.toString();
  }

  /// Scrive un nodo HTML e i suoi figli nel buffer con l'indentazione appropriata.
  static void _writeNode(StringBuffer buffer, dom.Node node, int indentLevel) {
    final indent = '  ' * indentLevel;
    if (node is dom.Element) {
      if (node.localName == 'pre' || node.localName == 'code') {
        buffer.write(node.outerHtml);
      } else {
        buffer.writeln('$indent<${node.localName}>');
        node.nodes.forEach((child) {
          _writeNode(buffer, child, indentLevel + 1);
        });
        buffer.writeln('$indent</${node.localName}>');
      }
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.writeln('$indent$text');
      }
    }
  }

  /// Genera un PDF dal contenuto HTML e lo consente di scaricare.
  static Future<void> downloadRenderedPdf(String htmlContent) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Text(htmlContent),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "rendered_pdf.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}