import 'dart:convert';            // jsonEncode / jsonDecode
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_app/context_api_sdk.dart';

final ContextApiSdk _apiSdk = ContextApiSdk();

// NEW – cache locale per evitare round‑trip ripetuti
Map<String, List<String>>? _extToLoaders;
Map<String, dynamic>?      _kwargsSchema;

// Converte qualunque numero in testo intero senza simboli/decimali
String _fmtIntNoCurrency(num? v) => ((v ?? 0).round()).toString();


Future<void> _ensureLoaderCatalog() async {
  if (_extToLoaders != null && _kwargsSchema != null) return;
  _extToLoaders = await _apiSdk.getLoadersCatalog();
  _kwargsSchema = await _apiSdk.getLoaderKwargsSchema();
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

/// Box riassuntivo della stima costo (pre‑processing)
Widget _buildCostBox(FileCost fc) {
  List<TableRow> _rows2cols(List<List<String?>> kv) {
    final rows = <TableRow>[];
    for (var i = 0; i < kv.length; i += 2) {
      final left  = kv[i];
      final right = (i + 1 < kv.length) ? kv[i + 1] : ['', null];
      rows.add(TableRow(children: [
        _kvCell(left[0]!,  left[1]),
        _kvCell(right[0]!, right[1]),
      ]));
    }
    return rows;
  }

  final primaryKv = <List<String?>>[
    ['Filename',    fc.filename],
    ['Kind',        fc.kind],
    ['Pages',       fc.pages?.toString()],
    ['Minutes',     fc.minutes?.toStringAsFixed(2)],
    ['Strategy',    fc.strategy],
    ['Size (B)',    fc.sizeBytes.toString()],
    ['Tokens est.', fc.tokensEst?.toString()],
  ]..removeWhere((e) => e[1] == null);

  final paramKv = (fc.params ?? {})
      .entries
      .map((e) => [e.key, e.value.toString()])
      .toList();

  final List<Widget> formulaSection = [];
  if (fc.formula != null || (fc.paramsConditions?.isNotEmpty ?? false)) {
    formulaSection
      ..add(const SizedBox(height: 12))
      ..add(const Divider(height: 1))
      ..add(const SizedBox(height: 6));
    if (fc.formula != null) {
      formulaSection.add(_kvCell('Cost', fc.formula!.split('=').last));
    }
    fc.paramsConditions?.forEach((k, v) {
      formulaSection.add(_kvCell(k, v));
    });
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
        },
        children: _rows2cols(primaryKv),
      ),
      if (paramKv.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 6),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          children: _rows2cols(paramKv),
        ),
      ],
      ...formulaSection,
      const SizedBox(height: 8),
      const Divider(height: 1),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          _fmtIntNoCurrency(fc.costUsd),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    ],
  );
}

/// Dialog «Configura loader» con stima costo live e recalcolo immediato
Future<Map<String, dynamic>?> showLoaderConfigDialog(
  BuildContext ctx,
  String       fileName,
  Uint8List    fileBytes,
) async {
  // 1️⃣ Cataloghi & schema
  await _ensureLoaderCatalog();
  final ext     = fileName.split('.').last.toLowerCase();
  final loaders = _extToLoaders![ext] ?? _extToLoaders!['default']!;
  String selectedLoader = loaders.first;

  // 2️⃣ Controller per i kwargs
  final ctrls = <String, TextEditingController>{};
  Map<String, dynamic> _editableSchema() {
    final raw = _kwargsSchema![selectedLoader] as Map<String, dynamic>;
    return Map.fromEntries(raw.entries.where(
      (e) => (e.value['editable'] ?? true) == true,
    ));
  }
  void _initCtrls() {
    ctrls.clear();
    for (final e in _editableSchema().entries) {
      ctrls[e.key] = TextEditingController(
        text: jsonEncode(e.value['default']),
      );
    }
  }
  _initCtrls();

  // 3️⃣ Stima iniziale da backend
  late FileCost _baseCost;
  Future<void> _fetchInitial() async {
    final kwargsMap = {
      ext: ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
    };
    final est = await _apiSdk.estimateFileProcessingCost(
      [fileBytes],
      [fileName],
      loaderKwargs: kwargsMap,
    );
    _baseCost = est.files.first;
  }
  await _fetchInitial();

  // 4️⃣ ShowDialog con StatefulBuilder e stato locale per il costo
  return showDialog<Map<String, dynamic>>(
    context: ctx,
    barrierDismissible: false,
    builder: (dialogCtx) {
      FileCost? _currentCost;

      // applica sempre ricomputazione + rebuild
      void _apply(StateSetter setSt) {
        final override = {
          ext: selectedLoader,
          ...ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
        };
        _currentCost = _apiSdk.recomputeFileCost(
          _baseCost,
          configOverride: override,
        );
        setSt(() {});
      }

      // trigger iniziale dopo primo frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // bisogna chiamare setSt solo dentro StatefulBuilder:
        // quindi usiamo un micro-delay per invocare il rebuild iniziale
        // sulla prima build (setSt valido)
      });

      return StatefulBuilder(
        builder: (c, setSt) {
          // primo apply (ora che setSt è disponibile)
          if (_currentCost == null) {
            _apply(setSt);
          }

          Future<void> _onLoaderChanged(String? v) async {
            if (v == null) return;
            selectedLoader = v;
            _initCtrls();
            _apply(setSt);
          }

          List<Widget> _buildFields() {
            return _editableSchema().entries.map((e) {
              final fld   = e.value as Map<String, dynamic>;
              final typ   = fld['type'] as String;
              final items = fld['items'];
              final label = fld['name'];
              Widget _label() => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (fld['description'] != null)
                        Tooltip(
                          message: fld['description'],
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.help_outline, size: 16),
                          ),
                        ),
                    ],
                  );
              if (items is List && items.isNotEmpty) {
                final curr = jsonDecode(ctrls[e.key]!.text) ?? items.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _label(),
                    _styledDropdown(
                      value: curr.toString(),
                      items: items.map((v) => v.toString()).toList(),
                      onChanged: (v) {
                        ctrls[e.key]!.text = jsonEncode(v);
                        _apply(setSt);
                      },
                    ),
                  ],
                );
              }
              if (typ == 'boolean' || typ == 'bool') {
                final curr = jsonDecode(ctrls[e.key]!.text) as bool;
                return CheckboxListTile(
                  title: _label(),
                  value: curr,
                  onChanged: (v) {
                    ctrls[e.key]!.text = jsonEncode(v);
                    _apply(setSt);
                  },
                );
              }
              return TextField(
                controller: ctrls[e.key],
                decoration: InputDecoration(label: _label()),
                onChanged: (_) => _apply(setSt),
              );
            }).toList();
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Configura loader – $fileName'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Loader', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    _styledDropdown(
                      value: selectedLoader,
                      items: loaders,
                      onChanged: _onLoaderChanged,
                    ),
                    const SizedBox(height: 16),
                    _kwargsPanel(_buildFields()),
                    const SizedBox(height: 20),
                    const Text(
                      'Stima costo preprocessing',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (_currentCost == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _buildCostBox(_currentCost!),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Annulla'),
                onPressed: () => Navigator.of(c).pop(null),
              ),
              ElevatedButton(
                child: const Text('Procedi'),
                onPressed: () {
                  final loadersMap = {ext: selectedLoader};
                  final kwargsMap  = {
                    ext: ctrls.map((k, v) => MapEntry(k, jsonDecode(v.text))),
                  };
                  Navigator.of(c).pop({
                    'loaders'      : loadersMap,
                    'loader_kwargs': kwargsMap,
                  });
                },
              ),
            ],
          );
        },
      );
    },
  );
}
