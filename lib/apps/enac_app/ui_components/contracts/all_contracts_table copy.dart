// lib/apps/enac_app/ui_components/polizze/polizze_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class PolizzePage extends StatefulWidget {
  const PolizzePage({
    super.key,
    required this.userId,
    required this.sdk,
    this.onOpenContract,
  });

  final String userId;
  final Omnia8Sdk sdk;

  /// (entityId, contractId, contratto) -> apri dettaglio
  final void Function(String entityId, String contractId, ContrattoOmnia8 c)?
      onOpenContract;

  @override
  State<PolizzePage> createState() => _PolizzePageState();
}

/* Coppie (entity, contract) da caricare */
class _Pair {
  final String entityId;
  final String contractId;
  const _Pair(this.entityId, this.contractId);
}

/* Riga tabella con tutto quello che serve (senza "scadenza titolo") */
class _RowData {
  final String entityId;
  final String entityName;
  final String contractId;
  final ContrattoOmnia8 c;

  const _RowData({
    required this.entityId,
    required this.entityName,
    required this.contractId,
    required this.c,
  });
}

class _PolizzePageState extends State<PolizzePage> {
  // Paginazione
  static const int _pageSize = 12;
  List<_Pair> _allPairs = [];
  int _nextIndex = 0;
  final List<_RowData> _rows = [];

  // Cache entità
  final Map<String, Entity> _entityCache = {};

  // UI
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _error;

  // Formatter
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _error = null;
      _allPairs = [];
      _rows.clear();
      _nextIndex = 0;
      _entityCache.clear();
    });

    try {
      // 1) tutte le entità
      final entityIds = await widget.sdk.listEntities(widget.userId);

      // 2) per ciascuna entità raccogli gli id contratto
      final pairs = <_Pair>[];
      for (final eid in entityIds) {
        try {
          final ids = await widget.sdk.listContracts(widget.userId, eid);
          for (final cid in ids) {
            pairs.add(_Pair(eid, cid));
          }
        } catch (_) {
          // ignora errori puntuali sulla singola entità
        }
      }
      _allPairs = pairs;

      // 3) primo lotto
      await _loadMore();
    } on ApiException catch (e) {
      _error = 'Errore API: ${e.statusCode} ${e.message}';
    } catch (e) {
      _error = 'Errore: $e';
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  bool get _hasMore => _nextIndex < _allPairs.length;

  Future<void> _ensureEntity(String entityId) async {
    if (_entityCache.containsKey(entityId)) return;
    try {
      _entityCache[entityId] =
          await widget.sdk.getEntity(widget.userId, entityId);
    } catch (_) {
      _entityCache[entityId] = Entity(name: entityId);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });

    final end = (_nextIndex + _pageSize).clamp(0, _allPairs.length);
    for (int i = _nextIndex; i < end; i++) {
      final pair = _allPairs[i];
      try {
        await _ensureEntity(pair.entityId);

        final c = await widget.sdk.getContract(
          widget.userId,
          pair.entityId,
          pair.contractId,
        );

        final ent = _entityCache[pair.entityId]!;
        _rows.add(_RowData(
          entityId: pair.entityId,
          entityName: ent.name,
          contractId: pair.contractId,
          c: c,
        ));
      } on ApiException catch (e) {
        _error = 'Errore ${pair.contractId}: ${e.statusCode} ${e.message}';
      } catch (e) {
        _error = 'Errore ${pair.contractId}: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _nextIndex = end;
      _loadingMore = false;
    });
  }

  String _fmtDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);

  double _parseMoney(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s0 = v.toString().trim();
    if (s0.contains(',') && s0.contains('.')) {
      final lastDot = s0.lastIndexOf('.');
      final lastComma = s0.lastIndexOf(',');
      if (lastDot > lastComma) {
        return double.tryParse(s0.replaceAll(',', '')) ?? 0.0;
      } else {
        return double.tryParse(
                s0.replaceAll('.', '').replaceAll(',', '.')) ??
            0.0;
      }
    }
    if (s0.contains(',') && !s0.contains('.')) {
      return double.tryParse(s0.replaceAll(',', '.')) ?? 0.0;
    }
    return double.tryParse(s0) ?? 0.0;
  }

  DataRow _row(_RowData r) {
    final id = r.c.identificativi;
    final amm = r.c.amministrativi;
    final ram = r.c.ramiEl;
    final prem = r.c.premi;

    return DataRow(cells: [
      const DataCell(Icon(Icons.description_outlined, size: 18)),      // TIPO
      DataCell(Text(r.entityName, maxLines: 2)),                       // CONTRAENTE
      DataCell(Text(id.compagnia, maxLines: 2)),                       // COMPAGNIA
      DataCell(Text(id.numeroPolizza)),                                // NUMERO
      DataCell(Text(ram?.descrizione ?? '', maxLines: 2)),             // RISCHIO
      DataCell(Text(amm?.frazionamento ?? '')),                        // FRAZIONAMENTO
      DataCell(Text(_fmtDate(amm?.effetto))),                          // EFFETTO
      DataCell(Text(_fmtDate(amm?.scadenza))),                         // SCADENZA
      DataCell(Text(_fmtDate(amm?.scadenzaCopertura))),                // SCAD. COPERTURA
      DataCell(Text(_currencyFmt.format(_parseMoney(prem?.premio)))),  // PREMIO
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Apri dettaglio contratto',
          onPressed: () => widget.onOpenContract
              ?.call(r.entityId, r.contractId, r.c),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty && _error != null) {
      return Center(child: Text(_error!));
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Nessuna polizza trovata'));
    }

    final table = LayoutBuilder(
      builder: (context, constraints) {
        // Si adatta sempre alla pagina: riempie la larghezza e abilita lo scroll se serve.
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
                DataColumn(label: Text('CONTRAENTE')),
                DataColumn(label: Text('COMPAGNIA')),
                DataColumn(label: Text('NUMERO')),
                DataColumn(label: Text('RISCHIO')),
                DataColumn(label: Text('FRAZIONAMENTO')),
                DataColumn(label: Text('EFFETTO')),
                DataColumn(label: Text('SCADENZA')),
                DataColumn(label: Text('SCAD. COPERTURA')),
                DataColumn(label: Text('PREMIO')),
                DataColumn(label: SizedBox()), // lente
              ],
              rows: _rows.map(_row).toList(),
            ),
          ),
        );
      },
    );

    final loadMore = Padding(
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
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Carico…' : 'Carica altro'),
              ),
            )
          else
            const Text('Tutte le polizze sono state caricate'),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: table),
        loadMore,
      ],
    );
  }
}
