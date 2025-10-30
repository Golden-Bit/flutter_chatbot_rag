import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';
import 'claim_summary_panel.dart'; // per ClaimSummaryPanel.claimFromViewRow

class ContractClaimsPage extends StatefulWidget {
  final String userId;
  final String entityId;
  final String contractId;
  final Omnia8Sdk sdk;

  /// (Sinistro sinistro, Map viewRow)
  final void Function(dynamic sinistro, Map<String, dynamic> viewRow) onOpenClaim;

  const ContractClaimsPage({
    super.key,
    required this.userId,
    required this.entityId,
    required this.contractId,
    required this.sdk,
    required this.onOpenClaim,
  });

  @override
  State<ContractClaimsPage> createState() => _ContractClaimsPageState();
}

class _ContractClaimsPageState extends State<ContractClaimsPage> {
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
        raw = await widget.sdk.viewContractClaims(
          widget.userId, widget.entityId, widget.contractId,
        );
      } catch (_) {
        // fallback: prendo tutti i sinistri dell’entità e filtro per contratto
        final list = await widget.sdk.viewEntityClaims(widget.userId, widget.entityId);
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
      _error = 'Errore nel caricamento sinistri: $e';
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

  Future<void> _openClaim(Map<String, dynamic> row) async {
    final String claimId = (row['claim_id'] ?? row['id'] ?? row['Id'] ?? row['SinistroId'] ?? '')
        .toString();

    dynamic sinistro;
    try {
      sinistro = await widget.sdk.getClaim(
        widget.userId, widget.entityId, widget.contractId, claimId,
      );
    } catch (_) {
      sinistro = ClaimSummaryPanel.claimFromViewRow(row);
    }

    widget.onOpenClaim(sinistro, {
      ...row,
      'contract_id': widget.contractId,
      'claim_id': claimId,
    });
  }

  DataRow _row(Map<String, dynamic> v) {
    // con contratto noto, non mostro la colonna “num. contratto”
    final esercizio   = (v['esercizio'] ?? v['Esercizio'] ?? '').toString();
    final numSinistro = (v['numero_sinistro'] ?? v['NumeroSinistro'] ?? v['num_sinistro'] ?? '').toString();
    final avv         = v['data_avvenimento'] ?? v['DataAvvenimento'];
    final importo     = (v['importo_liquidato'] ?? v['ImportoLiquidato'] ?? v['importo'] ?? '').toString();
    final targa       = (v['targa'] ?? v['Targa'] ?? '').toString();
    final danno       = (v['dinamica'] ?? v['Dinamica'] ?? v['danneggiamento'] ?? '').toString();
    final stato       = (v['stato_compagnia'] ?? v['StatoCompagnia'] ?? v['codice_stato'] ?? v['CodiceStato'] ?? '').toString();

    return DataRow(cells: [
      const DataCell(Icon(Icons.report_gmailerrorred, size: 18)),
      DataCell(Text(esercizio)),
      DataCell(Text(numSinistro)),
      DataCell(Text(_fmtDate(avv))),
      DataCell(Text(_fmtMoney(importo))),
      DataCell(Text(targa)),
      DataCell(Text(danno, maxLines: 2)),
      DataCell(Text(stato)),
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Apri Summary sinistro',
          onPressed: () => _openClaim(v),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) return Center(child: Text(_error!));
    if (_rows.isEmpty) return const Center(child: Text('Nessun sinistro per questo contratto'));

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
              DataColumn(label: Text('ESERCIZIO')),
              DataColumn(label: Text('NUM. SINISTRO')),
              DataColumn(label: Text('AVVENIMENTO')),
              DataColumn(label: Text('IMPORTO LIQUID.')),
              DataColumn(label: Text('TARGA')),
              DataColumn(label: Text('DANNO')),
              DataColumn(label: Text('STATO')),
              DataColumn(label: SizedBox()), // lente
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
            const Text('Tutti i sinistri sono stati caricati'),
        ],
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: table),
      loadMore,
    ]);
  }
}
