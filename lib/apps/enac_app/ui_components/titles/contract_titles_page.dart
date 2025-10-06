import 'package:boxed_ai/apps/enac_app/ui_components/titles/title_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class ContractTitlesPage extends StatefulWidget {
  final String userId;
  final String entityId;
  final String contractId;
  final Omnia8Sdk sdk;

  /// Quando l’utente clicca la lente:
  /// ti passo (Titolo titolo, Map viewRow)
  final void Function(dynamic titolo, Map<String, dynamic> viewRow) onOpenTitle;

  const ContractTitlesPage({
    super.key,
    required this.userId,
    required this.entityId,
    required this.contractId,
    required this.sdk,
    required this.onOpenTitle,
  });

  @override
  State<ContractTitlesPage> createState() => _ContractTitlesPageState();
}

class _ContractTitlesPageState extends State<ContractTitlesPage> {
  // paging
  static const int _pageSize = 12;
  final List<Map<String, dynamic>> _allViews = [];
  final List<Map<String, dynamic>> _rows = [];
  int _next = 0;

  // ui
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _error;

  final _d = DateFormat('dd/MM/yyyy');
  final _c = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _rows.clear();
      _allViews.clear();
      _next = 0;
    });

    try {
      List<dynamic> raw;
      try {
        // ✨ preferito (se disponibile nello SDK)
        raw = await widget.sdk.viewContractTitles(
          widget.userId, widget.entityId, widget.contractId,
        );
      } catch (_) {
        // fallback: prendo tutti i titoli dell’entità e filtro per contratto
        final list = await widget.sdk.viewEntityTitles(widget.userId, widget.entityId);
        raw = list.where((m) {
          final v = Map<String, dynamic>.from(m);
          final cid = (v['contract_id'] ?? v['ContrattoId'] ?? v['contractId'] ?? '').toString();
          return cid == widget.contractId;
        }).toList();
      }
      for (final r in raw) {
        _allViews.add(Map<String, dynamic>.from(r));
      }
      _appendPage();
    } catch (e) {
      _error = 'Errore nel caricamento titoli: $e';
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  void _appendPage() {
    final end = (_next + _pageSize).clamp(0, _allViews.length);
    _rows.addAll(_allViews.sublist(_next, end));
    _next = end;
  }

  bool get _hasMore => _next < _allViews.length;

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    if (v is DateTime) return _d.format(v);
    try { return _d.format(DateTime.parse(v.toString())); } catch (_) { return v.toString(); }
  }

  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      return lastDot > lastComma
          ? double.tryParse(s.replaceAll(',', ''))
          : double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    }
    if (s.contains(',')) return double.tryParse(s.replaceAll(',', '.'));
    return double.tryParse(s);
  }

  String _fmtMoney(dynamic v) {
    final n = _parseMoney(v);
    return n == null ? '—' : _c.format(n);
  }

  Future<void> _openTitle(Map<String, dynamic> row) async {
    // recupero id titolo robusto
    final String titleId = (row['title_id'] ?? row['titolo_id'] ?? row['TitleId'] ?? row['id'] ?? row['Id'] ?? '')
        .toString();
    dynamic titolo;
    try {
      titolo = await widget.sdk.getTitle(widget.userId, widget.entityId, widget.contractId, titleId);
    } catch (_) {
      // fallback: se non hai l’endpoint, usa un helper sul panel (vedi nota più giù)
      titolo = TitleSummaryPanel.titleFromViewRow(row);
    }
    widget.onOpenTitle(titolo, row);
  }

  DataRow _row(Map<String, dynamic> v) {
    // con contratto noto, evito colonne ridondanti
    final rischio   = (v['rischio'] ?? v['Rischio'] ?? '').toString();
    final scad      = v['scadenza_titolo'] ?? v['ScadenzaTitolo'];
    final stato     = (v['stato'] ?? v['Stato'] ?? '').toString();
    final pv        = (v['pv'] ?? v['PV'] ?? '').toString();
    final pv2       = (v['pv2'] ?? v['PV2'] ?? '').toString();
    final premio    = (v['premio_lordo'] ?? v['PremioLordo'] ?? v['premio'] ?? '').toString();

    return DataRow(cells: [
      const DataCell(Icon(Icons.receipt_long, size: 18)),
      DataCell(Text(rischio, maxLines: 2)),
      DataCell(Text(_fmtDate(scad))),
      DataCell(Text(stato)),
      DataCell(Text(pv)),
      DataCell(Text(pv2)),
      DataCell(Text(_fmtMoney(premio))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Apri Summary titolo',
          onPressed: () => _openTitle(v),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) return Center(child: Text(_error!));
    if (_rows.isEmpty) return const Center(child: Text('Nessun titolo per questo contratto'));

    final table = LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 48,
            columns: const [
              DataColumn(label: Text('TIPO')),
              DataColumn(label: Text('RISCHIO')),
              DataColumn(label: Text('SCADENZA TITOLO')),
              DataColumn(label: Text('STATO')),
              DataColumn(label: Text('P.V')),
              DataColumn(label: Text('P.V 2')),
              DataColumn(label: Text('PREMIO')),
              DataColumn(label: SizedBox()),
            ],
            rows: _rows.map(_row).toList(),
          ),
        ),
      );
    });

    final loadMore = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (_hasMore)
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _loadingMore ? null : () async {
                  setState(() => _loadingMore = true);
                  await Future<void>.delayed(const Duration(milliseconds: 120));
                  _appendPage();
                  if (mounted) setState(() => _loadingMore = false);
                },
                icon: _loadingMore
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Carico…' : 'Carica altro'),
              ),
            )
          else
            const Text('Tutti i titoli sono stati caricati'),
        ],
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: table),
      loadMore,
    ]);
  }
}
