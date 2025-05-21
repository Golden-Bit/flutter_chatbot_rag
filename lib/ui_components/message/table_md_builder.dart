import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Builder che sostituisce la <table> Markdown con un DataTable
/// scrollabile + bottone CSV.
class ScrollableTableBuilder extends MarkdownElementBuilder {
  ScrollableTableBuilder({required this.onDownload});
  final void Function(List<List<String>> rows) onDownload;

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // ── 1. estrai header + righe
    final header = <String>[];
    final rows   = <List<String>>[];

    for (final md.Element row in element.children!.whereType<md.Element>()) {
      if (row.tag != 'tr') continue;

      final cells   = row.children!.whereType<md.Element>().toList();
      final values  = cells.map((c) => c.textContent.trim()).toList();

      if (cells.first.tag == 'th') {
        header.addAll(values);
      } else {
        rows.add(values);
      }
    }

    // ── 2. DataTable
    final dataTable = DataTable(
      columns: header
          .map((h) => DataColumn(
                label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)),
              ))
          .toList(),
      rows: rows
          .map((r) => DataRow(cells: r.map((v) => DataCell(Text(v))).toList()))
          .toList(),
      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
      dataRowHeight: 40,
    );

    // ── 3. contenitore scroll (vert + orizz)
    final tableBox = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: dataTable,
          ),
        ),
      ),
    );

    // ── 4. pulsante CSV
    final csvButton = Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.download),
        label: const Text('CSV'),
        onPressed: () => onDownload([header, ...rows]),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [tableBox, const SizedBox(height: 4), csvButton],
      ),
    );
  }
}
