import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:html' as html; // Import per gestire download su web

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Viewer',
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
  Uint8List? _markdownBytes;
  String? _markdownSource;
  bool _isMarkdownLoaded = false;
  TextEditingController _textEditingController = TextEditingController();
  double _splitRatio = 0.5;

  ViewMode _viewMode = ViewMode.editAndView;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );

    if (result != null && result.files.first.bytes != null) {
      final fileBytes = result.files.first.bytes;
      final markdownSource = utf8.decode(fileBytes!);

      setState(() {
        _markdownBytes = fileBytes;
        _markdownSource = markdownSource;
        _isMarkdownLoaded = true;
        _textEditingController.text = _markdownSource!;
      });
    }
  }

  void _downloadMarkdownSource() {
    if (_markdownSource != null) {
      final bytes = utf8.encode(_markdownSource!);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "downloaded_markdown.md")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _downloadHtmlSource() {
    if (_markdownSource != null) {
      final htmlContent = md.markdownToHtml(_markdownSource!);
      final bytes = utf8.encode(htmlContent);
      final blob = html.Blob([bytes], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "downloaded_markdown.html")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Markdown Viewer"),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: _isMarkdownLoaded ? () => setState(() {}) : null,
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
      body: _markdownBytes == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickFile,
                child: Text("Load Markdown File"),
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

enum ViewMode { editOnly, viewOnly, editAndView }
