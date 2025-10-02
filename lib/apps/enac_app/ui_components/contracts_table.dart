import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic_components/backend_sdk.dart';

class ContractsTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;
  final void Function(ContrattoOmnia8)? onOpenContract;

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

class _ContractsTableState extends State<ContractsTable> {
  // Stato paginazione
  final int _pageSize = 10;
  List<String> _allIds = [];
  int _nextIndex = 0;

  // Stato dati caricati
  final List<ContrattoOmnia8> _contracts = [];

  // Stato UI
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
   *  CARICAMENTO INIZIALE: prende tutti gli ID (tollerante ai 404)
   *  poi carica la prima pagina di 10 contratti
   * ----------------------------------------------------------------*/
  Future<void> _initLoad() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _allIds = [];
      _contracts.clear();
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
      // 404 = nessun contratto
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
   *  CARICA ALTRI 10 CONTRATTI (tollerante ai 404)
   * ----------------------------------------------------------------*/
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _error = null;
    });

    final end = (_nextIndex + _pageSize).clamp(0, _allIds.length);
    for (int i = _nextIndex; i < end; i++) {
      final contractId = _allIds[i]; // <— è una stringa, non un oggetto
      try {
        final c = await widget.sdk.getContract(
          widget.userId,
          widget.clientId,
          contractId,
        );
        if (mounted) {
          setState(() {
            _contracts.add(c);
          });
        }
      } on ApiException catch (e) {
        // 404 = contratto orfano → lo saltiamo
        if (e.statusCode != 404) {
          // non blocchiamo la pagina, ma segnaliamo l'ultimo errore
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
  String _fmtDate(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

  num _money(String? s) {
    if (s == null) return 0.0;
    // Le API usano stringhe tipo "1234.56"
    return double.tryParse(s) ?? 0.0;
  }

  /* ------------------------------------------------------------------
   *  RIGA TABELLA (null-safe)
   * ----------------------------------------------------------------*/
  DataRow _row(BuildContext context, ContrattoOmnia8 c) {
    final id = c.identificativi; // non-null (required nel modello)
    final amm = c.amministrativi; // può essere null
    final premi = c.premi; // può essere null
    final ramiEl = c.ramiEl; // può essere null

    return DataRow(cells: [
      const DataCell(Icon(Icons.description_outlined, size: 18)),
      DataCell(Text(id.tpCar ?? '')),
      DataCell(Text(id.ramo)),
      DataCell(Text(id.compagnia, maxLines: 2)),
      DataCell(Text(id.numeroPolizza)),
      DataCell(Text(ramiEl?.descrizione ?? '', maxLines: 2)),
      DataCell(Text(amm?.frazionamento ?? '')),
      DataCell(Text(_fmtDate(amm?.effetto))),
      DataCell(Text(_fmtDate(amm?.scadenza))),
      DataCell(Text(_fmtDate(amm?.scadenzaCopertura))),
      DataCell(Text(_cur.format(_money(premi?.premio)))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Dettaglio contratto',
          onPressed: () => widget.onOpenContract?.call(c),
        ),
      ),
    ]);
  }

  /* ------------------------------------------------------------------
   *  BUILD
   * ----------------------------------------------------------------*/
  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _contracts.isEmpty) {
      return Center(child: Text(_error!));
    }

    if (_contracts.isEmpty) {
      return const Center(child: Text('Nessun contratto'));
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
                DataColumn(label: Text('TP CAR.')),
                DataColumn(label: Text('RAMO')),
                DataColumn(label: Text('COMPAGNIA')),
                DataColumn(label: Text('NUMERO')),
                DataColumn(label: Text('RISCHIO / PRODOTTO')),
                DataColumn(label: Text('FRAZIONAMENTO')),
                DataColumn(label: Text('EFFETTO')),
                DataColumn(label: Text('SCADENZA')),
                DataColumn(label: Text('SCAD. COPERTURA')),
                DataColumn(label: Text('PREMIO')),
                DataColumn(label: SizedBox()), // lente
              ],
              rows: _contracts.map((c) => _row(context, c)).toList(),
            ),
          ),
        );
      },
    );

    final loadMoreSection = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (_error != null) // mostra eventuali errori non-bloccanti dell’ultimo batch
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
            const Text('Tutti i contratti sono stati caricati'),
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
