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
    this.onOpenContract
  });

  @override
  State<ContractsTable> createState() => _ContractsTableState();
}

class _ContractsTableState extends State<ContractsTable> {
  late Future<List<ContrattoOmnia8>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /* ------------------------------------------------------------------
   *  CARICAMENTO CONTRATTI (tollerante ai 404)
   * ----------------------------------------------------------------*/
  Future<List<ContrattoOmnia8>> _load() async {
    try {
      final ids =
          await widget.sdk.listContracts(widget.userId, widget.clientId);

      final list = <ContrattoOmnia8>[];
      for (final it in ids) {
        try {
          final c = await widget.sdk.getContract(
            widget.userId,
            widget.clientId,
            it.contractId,
          );
          list.add(c);
        } on ApiException catch (e) {
          if (e.statusCode == 404) continue; // salta contratti orfani
          rethrow;
        }
      }
      return list;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return []; // nessun contratto
      rethrow;
    }
  }

  /* ------------------------------------------------------------------
   *  RIGA TABELLA
   * ----------------------------------------------------------------*/
  DataRow _row(BuildContext context, ContrattoOmnia8 c) {
    final id  = c.identificativi;
    final amm = c.amministrativi;
    final cur = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    return DataRow(cells: [
      const DataCell(Icon(Icons.edit_document, size: 18)),
      DataCell(Text(id.tpCar ?? '')),
      DataCell(Text(id.ramo)),
      DataCell(Text(id.compagnia, maxLines: 2)),
      DataCell(Text(id.numeroPolizza)),
      DataCell(Text(c.ramiEl.descrizione, maxLines: 2)),
      DataCell(Text(amm.frazionamento)),
      DataCell(Text(DateFormat('dd/MM/yyyy').format(amm.effetto))),
      DataCell(Text(DateFormat('dd/MM/yyyy').format(amm.scadenza))),
      DataCell(Text(amm.scadenzaCopertura != null
          ? DateFormat('dd/MM/yyyy').format(amm.scadenzaCopertura!)
          : '')),
      DataCell(Text(cur.format(c.premi.premio))),
      /* ---- pulsante dettaglio ---- */
      DataCell(
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Dettaglio contratto',
          onPressed: () => widget.onOpenContract?.call(c), // callback ↑
        ),
      ),
    ]);
  }

  /* ------------------------------------------------------------------
   *  BUILD
   * ----------------------------------------------------------------*/
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContrattoOmnia8>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text('Errore: ${snap.error}'));
        }

        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('Nessun contratto'));
        }

        return LayoutBuilder(
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
                    DataColumn(label: Text('TP CAR.')),
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
                  rows: list.map((c) => _row(context, c)).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
