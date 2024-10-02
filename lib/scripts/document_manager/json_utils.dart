import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_app/databases_manager/json_viewer.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSON Viewer',
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
  Uint8List? _jsonBytes;
  String? _jsonSource;
  dynamic _jsonDecoded;
  bool _isJsonLoaded = false;
  TextEditingController _textEditingController = TextEditingController();
  double _splitRatio = 0.5;

  ViewMode _viewMode = ViewMode.editAndView;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.first.bytes != null) {
      final fileBytes = result.files.first.bytes;
      final jsonSource = utf8.decode(fileBytes!);
      final jsonDecoded = json.decode(jsonSource);

      setState(() {
        _jsonBytes = fileBytes;
        _jsonSource = jsonSource;
        _jsonDecoded = jsonDecoded;
        _isJsonLoaded = true;
        _textEditingController.text = _jsonSource!;
      });
    }
  }

  void _formatJson() {
    if (_textEditingController.text.isNotEmpty) {
      final jsonString = _textEditingController.text;
      try {
        final jsonDecoded = json.decode(jsonString);
        final formattedJson = JsonEncoder.withIndent('  ').convert(jsonDecoded);
        setState(() {
          _textEditingController.text = formattedJson;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid JSON format')),
        );
      }
    }
  }

  void _runJson() {
    try {
      final jsonString = _textEditingController.text;
      final jsonDecoded = json.decode(jsonString);
      setState(() {
        _jsonDecoded = jsonDecoded;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON format')),
      );
    }
  }

  void _downloadJsonSource() {
    if (_jsonSource != null) {
      final bytes = utf8.encode(_jsonSource!);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "downloaded_json.json")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("JSON Viewer"),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _pickFile,
          ),
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
      body: _jsonBytes == null
          ? Center(
              child: ElevatedButton(
                onPressed: _pickFile,
                child: Text("Load JSON File"),
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
          child: _jsonDecoded != null
              ? JsonViewer(json: _jsonDecoded)
              : Text(
                  'JSON content will be displayed here',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}

enum ViewMode { editOnly, viewOnly, editAndView }
