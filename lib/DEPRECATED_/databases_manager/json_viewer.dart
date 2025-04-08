// json_viewer.dart
import 'package:flutter/material.dart';

class JsonViewer extends StatefulWidget {
  final dynamic json;
  final double indent;

  JsonViewer({required this.json, this.indent = 0});

  @override
  _JsonViewerState createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  Map<String, bool> expandedStateMap = {};

  @override
  Widget build(BuildContext context) {
    if (widget.json is Map) {
      return Padding(
        padding: EdgeInsets.only(left: widget.indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.json.entries.map<Widget>((entry) {
            return _buildKeyValue(entry.key, entry.value);
          }).toList(),
        ),
      );
    } else if (widget.json is List) {
      return Padding(
        padding: EdgeInsets.only(left: widget.indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.json.asMap().entries.map<Widget>((entry) {
            return _buildKeyValue(entry.key.toString(), entry.value);
          }).toList(),
        ),
      );
    } else {
      return _buildSimpleValue(widget.json);
    }
  }

  Widget _buildKeyValue(String key, dynamic value) {
    bool isExpanded = expandedStateMap[key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (value is Map || value is List)
              IconButton(
                icon: Icon(isExpanded
                    ? Icons.expand_less
                    : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    expandedStateMap[key] = !isExpanded;
                  });
                },
              ),
            Text(
              '$key: ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!(value is Map || value is List)) _buildSimpleValue(value),
          ],
        ),
        if (isExpanded && (value is Map || value is List))
          JsonViewer(json: value, indent: widget.indent + 16),
      ],
    );
  }

  Widget _buildSimpleValue(dynamic value) {
    TextStyle textStyle;

    if (value is int) {
      textStyle = TextStyle(color: Colors.blueAccent);
    } else if (value is double) {
      textStyle = TextStyle(color: Colors.orange);
    } else if (value is bool) {
      textStyle = TextStyle(color: value ? Colors.blue : Colors.red);
    } else if (value is String) {
      textStyle = TextStyle(color: Colors.green);
    } else {
      textStyle = TextStyle(color: Colors.black);
    }

    return Text(
      value.toString(),
      style: textStyle,
    );
  }
}
