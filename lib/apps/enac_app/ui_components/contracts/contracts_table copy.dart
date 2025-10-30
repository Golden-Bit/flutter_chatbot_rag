
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class ContractsTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;

  // Passa anche contractId
  final void Function(String contractId, ContrattoOmnia8 c)? onOpenContract;

  const ContractsTable({
    super.key,
    required this.userId,
    required this.clientId,
    required this.sdk,
    this.onOpenContract,
  });

  @override
  State<ContractsTable> createState() => _ContractsTableState();
}

/* Riga tabellare con ID + oggetto contratto */
class _Row {
  final String id;
  final ContrattoOmnia8 c;
  _Row(this.id, this.c);
}

class _ContractsTableState extends State<ContractsTable> {
  // Paginazione
  final int _pageSize = 10;
  List<String> _allIds = [];
  int _nextIndex = 0;

  // elenco righe (id + contratto)
  final List<_Row> _rows = [];

  // UI state
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  final NumberFormat _cur = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  /* ------------------------------------------------------------------
   *  CARICAMENTO INIZIALE
   * ----------------------------------------------------------------*/
  Future<void> _initLoad() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _allIds = [];
      _rows.clear();
      _nextIndex = 0;
    });

    try {
      final ids = await widget.sdk.listContracts(widget.userId, widget.clientId);
      _allIds = ids;
      _error = null;
      if (_allIds.isNotEmpty) {
        await _loadMore();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _allIds = [];
        _error = null;
      } else {
        _error = 'Errore: ${e.statusCode} ${e.message}';
      }
    } catch (e) {
      _error = 'Errore inatteso: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  bool get _hasMore => _nextIndex < _allIds.length;

  /* ------------------------------------------------------------------
   *  CARICA ALTRI _pageSize CONTRATTI
   * ----------------------------------------------------------------*/
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    final end = (_nextIndex + _pageSize).clamp(0, _allIds.length);
    for (int i = _nextIndex; i < end; i++) {
      final contractId = _allIds[i];
      try {
        final c = await widget.sdk.getContract(
          widget.userId,
          widget.clientId,
          contractId,
        );
        if (mounted) {
          setState(() {
            _rows.add(_Row(contractId, c));
          });
        }
      } on ApiException catch (e) {
        if (e.statusCode != 404) {
          _error = 'Errore nel caricamento contratto $contractId: ${e.message}';
        }
      } catch (e) {
        _error = 'Errore inatteso su $contractId: $e';
      }
    }

    if (mounted) {
      setState(() {
        _nextIndex = end;
        _isLoadingMore = false;
      });
    }
  }

  /* ------------------------------------------------------------------
   *  HELPERS
   * ----------------------------------------------------------------*/
  String _fmtDate(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

  num _money(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /* ------------------------------------------------------------------
   *  RIGA TABELLA (versione aggiornata senza TP CAR. e RAMO)
   * ----------------------------------------------------------------*/
  DataRow _row(BuildContext context, _Row r) {
    final c = r.c;
    final id = c.identificativi; // non-null (required nel modello)
    final amm = c.amministrativi; // nullable
    final premi = c.premi;        // nullable
    final ramiEl = c.ramiEl;      // nullable

    return DataRow(cells: [
      const DataCell(Icon(Icons.description_outlined, size: 18)),
      DataCell(Text(id.compagnia, maxLines: 2)),
      DataCell(Text(id.numeroPolizza)),
      DataCell(Text(ramiEl?.descrizione ?? '', maxLines: 2)), // Rischio
      DataCell(Text(amm?.frazionamento ?? '')),
      DataCell(Text(_fmtDate(amm?.effetto))),
      DataCell(Text(_fmtDate(amm?.scadenza))),
      DataCell(Text(_fmtDate(amm?.scadenzaCopertura))),
      DataCell(Text(_cur.format(_money(premi?.premio)))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Dettaglio contratto',
          onPressed: () => widget.onOpenContract?.call(r.id, r.c),
        ),
      ),
    ]);
  }

  /* ------------------------------------------------------------------
   *  BUILD: tabella adattiva alla larghezza della pagina
   * ----------------------------------------------------------------*/
  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _rows.isEmpty) {
      return Center(child: Text(_error!));
    }

    if (_rows.isEmpty) {
      return const Center(child: Text('Nessun contratto'));
    }

    final table = LayoutBuilder(
      builder: (context, constraints) {
        // Larghezza tabella:
        // - se le colonne “stanno”, la tabella si espande fino a riempire la pagina
        // - se non stanno, resta lo scroll orizzontale senza tagli
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
                DataColumn(label: Text('NUMERO')),
                DataColumn(label: Text('RISCHIO')),
                DataColumn(label: Text('FRAZIONAMENTO')),
                DataColumn(label: Text('EFFETTO')),
                DataColumn(label: Text('SCADENZA')),
                DataColumn(label: Text('SCAD. COPERTURA')),
                DataColumn(label: Text('PREMIO')),
                DataColumn(label: SizedBox()), // lente
              ],
              rows: _rows.map((r) => _row(context, r)).toList(),
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
            const Text('Tutte le polizze sono state caricate'),
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
