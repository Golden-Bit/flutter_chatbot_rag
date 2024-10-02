import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html; // Import per gestire download su web

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Editor',
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
  Uint8List? _textBytes;
  String? _textSource;
  TextEditingController _textEditingController = TextEditingController();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.first.bytes != null) {
      final fileBytes = result.files.first.bytes;
      final textSource = utf8.decode(fileBytes!);

      setState(() {
        _textBytes = fileBytes;
        _textSource = textSource;
        _textEditingController.text = _textSource!;
      });
    }
  }

  void _downloadTextSource() {
    if (_textSource != null) {
      final bytes = utf8.encode(_textEditingController.text);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "downloaded_text.txt")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Text Editor"),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _downloadTextSource,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: _buildEditor(),
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
}

