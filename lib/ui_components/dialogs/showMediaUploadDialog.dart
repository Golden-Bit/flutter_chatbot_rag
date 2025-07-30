// media_upload_dialog.dart
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

enum MediaSource { file, url }

Future<({MediaSource source, Uint8List? bytes, String? url})?>
    showMediaUploadDialog(BuildContext ctx) {
  return showDialog<({MediaSource source, Uint8List? bytes, String? url})>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => const _MediaUploadDialog(),
  );
}

/// Dropdown stile Material 3 ri‑utilizzabile
Widget _styledDropdown({
  required String value,
  required List<String> items,
  required void Function(String?) onChanged,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          value: value,
          items: items
              .map((it) => DropdownMenuItem(value: it, child: Text(it)))
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.black87),
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.zero,
            height: 48,
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Riquadro grigio che contiene i parametri dinamici del loader
Widget _kwargsPanel(List<Widget> fields) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Column(children: fields),
  );
}

/// Helper per una riga “chiave: valore”
Widget _kvCell(String key, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 13),
        children: [
          TextSpan(
            text: '$key: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class _MediaUploadDialog extends StatefulWidget {
  const _MediaUploadDialog();

  @override
  State<_MediaUploadDialog> createState() => _MediaUploadDialogState();
}

class _MediaUploadDialogState extends State<_MediaUploadDialog> {
  MediaSource _src = MediaSource.file;          // drop‑down iniziale
  Uint8List?  _fileBytes;
  String?     _fileName;
  final _urlCtrl = TextEditingController();

  bool get _canProceed {
    if (_src == MediaSource.file) return _fileBytes != null;
    return _urlCtrl.text.trim().isNotEmpty;
  }

  /*──────── layout dinamico ────────*/
  Widget _buildBody() {
    switch (_src) {
      case MediaSource.file:
        return _kwargsPanel([
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName ?? 'Seleziona file…'),
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'mp4'],
                withData: true,
              );
              if (res != null && res.files.single.bytes != null) {
                setState(() {
                  _fileBytes = res.files.single.bytes;
                  _fileName  = res.files.single.name;
                });
              }
            },
          ),
        ]);

      case MediaSource.url:
        return _kwargsPanel([
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Direct URL',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (_) => setState(() {}),
          )
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Upload media'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _styledDropdown(
              value : _src.name,
              items : MediaSource.values.map((e) => e.name).toList(),
              onChanged: (v) => setState(() {
                _src = MediaSource.values
                    .firstWhere((e) => e.name == v, orElse: () => MediaSource.file);
              }),
            ),
            const SizedBox(height: 16),
            _buildBody(),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annulla'),
          onPressed: () => Navigator.pop(context, null),
        ),
        ElevatedButton(
          child: const Text('Procedi'),
          onPressed: _canProceed
              ? () => Navigator.pop(
                    context,
                    (source: _src, bytes: _fileBytes, url: _urlCtrl.text.trim()),
                  )
              : null,
        ),
      ],
    );
  }
}


