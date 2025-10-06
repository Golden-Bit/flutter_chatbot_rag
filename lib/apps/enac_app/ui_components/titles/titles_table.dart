import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class TitlesTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;
  final Future<void> Function(BuildContext ctx, Map<String, dynamic> viewRow)? onOpenTitle;

  const TitlesTable({
    super.key,
    required this.userId,
    required this.clientId,
    required this.sdk,
    this.onOpenTitle,
  });

  @override
  State<TitlesTable> createState() => _TitlesTableState();
}

class _TitlesTableState extends State<TitlesTable> {
  // Paginazione
  final int _pageSize = 12;
  List<Map<String, dynamic>> _allViews = [];
  int _nextIndex = 0;

  // Dati visualizzati
  final List<Map<String, dynamic>> _rows = [];

  // UI
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  // ------- Money parser robusto (fix ×100) -------
  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s0 = v.toString().trim();
    if (s0.isEmpty) return null;

    if (s0.contains(',') && s0.contains('.')) {
      final lastDot = s0.lastIndexOf('.');
      final lastComma = s0.lastIndexOf(',');
      if (lastDot > lastComma) {
        final norm = s0.replaceAll(',', '');
        return double.tryParse(norm);
      } else {
        final norm = s0.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(norm);
      }
    }
    if (s0.contains(',') && !s0.contains('.')) {
      return double.tryParse(s0.replaceAll(',', '.'));
    }
    return double.tryParse(s0);
  }

  String _fmtMoney(dynamic v) {
    final n = _parseMoney(v);
    if (n == null) return '—';
    return _currencyFmt.format(n);
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return _dateFmt.format(v);
    final s = v.toString();
    try {
      // prova ISO (YYYY-MM-DD...)
      return _dateFmt.format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _error = null;
      _allViews = [];
      _rows.clear();
      _nextIndex = 0;
    });

    try {
      // View denormalizzata con tutti i titoli dell’entità
      final list = await widget.sdk.viewEntityTitles(widget.userId, widget.clientId);
      _allViews = list.map((e) => Map<String, dynamic>.from(e)).toList();
      if (_allViews.isNotEmpty) {
        await _loadMore();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _allViews = [];
        _error = null;
      } else {
        _error = 'Errore: ${e.statusCode} ${e.message}';
      }
    } catch (e) {
      _error = 'Errore inatteso: $e';
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  bool get _hasMore => _nextIndex < _allViews.length;

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    final end = (_nextIndex + _pageSize).clamp(0, _allViews.length);
    for (int i = _nextIndex; i < end; i++) {
      _rows.add(_allViews[i]);
    }

    if (mounted) {
      setState(() {
        _nextIndex = end;
        _isLoadingMore = false;
      });
    }
  }

  DataRow _row(BuildContext context, Map<String, dynamic> v) {
    // campi attesi dalla view (fallback a stringa vuota)
    final compagnia = (v['compagnia'] ?? v['Compagnia'] ?? '').toString();
    final numeroPolizza =
        (v['numero_polizza'] ?? v['NumeroPolizza'] ?? '').toString();
    final rischio = (v['rischio'] ?? v['Rischio'] ?? '').toString();
    final scadenza = v['scadenza_titolo'] ?? v['ScadenzaTitolo'];
    final stato = (v['stato'] ?? v['Stato'] ?? '').toString();
    final pv = (v['pv'] ?? v['PV'] ?? '').toString();
    final pv2 = (v['pv2'] ?? v['PV2'] ?? '').toString();
    final premio = (v['premio_lordo'] ?? v['PremioLordo'] ?? v['premio'] ?? '').toString();

    return DataRow(cells: [
      const DataCell(Icon(Icons.receipt_long, size: 18)),
      DataCell(Text(compagnia, maxLines: 2)),
      DataCell(Text(numeroPolizza)),
      DataCell(Text(rischio, maxLines: 2)),
      DataCell(Text(_fmtDate(scadenza))),
      DataCell(Text(stato)),
      DataCell(Text(pv)),
      DataCell(Text(pv2)),
      DataCell(Text(_fmtMoney(premio))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Apri Summary titolo',
          onPressed: () => widget.onOpenTitle?.call(context, v),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _rows.isEmpty) {
      return Center(child: Text(_error!));
    }

    if (_rows.isEmpty) {
      return const Center(child: Text('Nessun titolo'));
    }

    final table = LayoutBuilder(
      builder: (context, constraints) {
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
                DataColumn(label: Text('COMPAGNIA')),
                DataColumn(label: Text('NUM. CONTRATTO')),
                DataColumn(label: Text('RISCHIO')),
                DataColumn(label: Text('SCADENZA TITOLO')),
                DataColumn(label: Text('STATO')),
                DataColumn(label: Text('P.V')),
                DataColumn(label: Text('P.V 2')),
                DataColumn(label: Text('PREMIO')),
                DataColumn(label: SizedBox()), // lente
              ],
              rows: _rows.map((v) => _row(context, v)).toList(),
            ),
          ),
        );
      },
    );

    final loadMoreSection = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_hasMore)
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _isLoadingMore ? null : _loadMore,
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_isLoadingMore ? 'Carico…' : 'Carica altro'),
              ),
            )
          else
            const Text('Tutti i titoli sono stati caricati'),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: table),
        loadMoreSection,
      ],
    );
  }
}
