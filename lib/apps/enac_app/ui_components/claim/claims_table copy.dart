// lib/apps/enac_app/ui_components/claims_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class ClaimsTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;
  final Future<void> Function(BuildContext ctx, Map<String, dynamic> viewRow)? onOpenClaim;

  const ClaimsTable({
    super.key,
    required this.userId,
    required this.clientId,
    required this.sdk,
    this.onOpenClaim,
  });

  @override
  State<ClaimsTable> createState() => _ClaimsTableState();
}

class _ClaimsTableState extends State<ClaimsTable> {
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

  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  // ------- Money parser robusto -------
  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s0 = v.toString().trim();
    if (s0.isEmpty) return null;

    if (s0.contains(',') && s0.contains('.')) {
      final lastDot = s0.lastIndexOf('.');
      final lastComma = s0.lastIndexOf(',');
      if (lastDot > lastComma) {
        return double.tryParse(s0.replaceAll(',', ''));
      } else {
        return double.tryParse(s0.replaceAll('.', '').replaceAll(',', '.'));
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
      // View denormalizzata con tutti i sinistri dell’entità
      final list = await widget.sdk.viewEntityClaims(
        widget.userId,
        widget.clientId,
      );
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
    // Colonne finali: COMPAGNIA, NUM. CONTRATTO, ESERCIZIO, NUM. SINISTRO,
    // AVVENIMENTO, IMPORTO LIQUID., DESCRIZIONE, STATO SINISTRO, lente
    final compagnia   = (v['compagnia'] ?? v['Compagnia'] ?? '').toString();
    final numPolizza  = (v['numero_polizza'] ?? v['NumeroPolizza'] ?? '').toString();
    final esercizio   = (v['esercizio'] ?? v['Esercizio'] ?? '').toString();
    final numSinistro = (v['numero_sinistro'] ?? v['NumeroSinistro'] ?? v['num_sinistro'] ?? '').toString();
    final avvenimento = v['data_avvenimento'] ?? v['DataAvvenimento'];
    final importo     = (v['importo_liquidato'] ?? v['ImportoLiquidato'] ?? v['importo'] ?? '').toString();

    // DESCRIZIONE: usa descrizione/dinamica/danneggiamento come fallback
    final descrizione = (v['descrizione'] ??
                         v['Descrizione'] ??
                         v['dinamica'] ??
                         v['Dinamica'] ??
                         v['danneggiamento'] ??
                         '').toString();

    final stato       = (v['stato_compagnia'] ?? v['StatoCompagnia'] ?? v['codice_stato'] ?? v['CodiceStato'] ?? '').toString();

    return DataRow(cells: [
      // (TIPO eliminato)
      DataCell(Text(compagnia, maxLines: 2)),        // COMPAGNIA
      DataCell(Text(numPolizza)),                    // NUM. CONTRATTO
      DataCell(Text(esercizio)),                     // ESERCIZIO
      DataCell(Text(numSinistro)),                   // NUM. SINISTRO
      DataCell(Text(_fmtDate(avvenimento))),         // AVVENIMENTO
      DataCell(Text(_fmtMoney(importo))),            // IMPORTO LIQUID.
      DataCell(Text(descrizione, maxLines: 2)),      // DESCRIZIONE (ex DANNEGGIAMENTO)
      DataCell(Text(stato)),                         // STATO SINISTRO
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Apri Summary sinistro',
          onPressed: () => widget.onOpenClaim?.call(context, v),
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
      return const Center(child: Text('Nessun sinistro'));
    }

    final table = LayoutBuilder(
      builder: (context, constraints) {
        // Adattiva: riempie la pagina; se lo spazio non basta, è disponibile lo scroll orizzontale
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 12,
              headingRowHeight: 36,
              dataRowMinHeight: 48,
              columns: const [
                // (TIPO rimosso)
                DataColumn(label: Text('COMPAGNIA')),
                DataColumn(label: Text('NUM. CONTRATTO')),
                DataColumn(label: Text('ESERCIZIO')),
                DataColumn(label: Text('NUM. SINISTRO')),
                DataColumn(label: Text('AVVENIMENTO')),
                DataColumn(label: Text('IMPORTO LIQUID.')),
                DataColumn(label: Text('DESCRIZIONE')),       // ex DANNEGGIAMENTO
                DataColumn(label: Text('STATO SINISTRO')),
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
            const Text('Tutti i sinistri sono stati caricati'),
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
