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

  // Scrollbar & scroll controller
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // Costanti per allineamento perfetto
  static const double SEPARATOR_W = 8.0; // handle visibile tra colonne
  static const double SEPARATOR_LINE_W = 1.0; // linea centrale
  static const double ROW_H = 44.0;
  static const double HEADER_H = 44.0;

  // Colonne e larghezze (px). Nessun min/max imposto; clamp interno solo per evitare <= 1px.
  // Ordine colonne:
  // 0: TIPO (icona) | 1: CONTRAENTE | 2: COMPAGNIA | 3: NUMERO | 4: RISCHIO |
  // 5: FRAZIONAMENTO | 6: EFFETTO | 7: SCADENZA | 8: SCAD. COPERTURA | 9: PREMIO | 10: (azione)
  late List<double> _colW;

  // Hover row index (migliora estetica)
  int? _hoverRowIndex;

  @override
  void initState() {
    super.initState();
    _colW = <double>[56, 220, 200, 160, 200, 140, 120, 120, 160, 120, 56];
    _boot();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
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
          s0.replaceAll('.', '').replaceAll(',', '.'),
        ) ?? 0.0;
      }
    }
    if (s0.contains(',') && !s0.contains('.')) {
      return double.tryParse(s0.replaceAll(',', '.')) ?? 0.0;
    }
    return double.tryParse(s0) ?? 0.0;
  }

  // -------------------- UI Helpers (colonne ridimensionabili) ----------------

  double get _tableWidth {
    // somma delle colonne + spessori dei separatori (tra le colonne: n-1)
    return _colW.reduce((a, b) => a + b) + SEPARATOR_W * (_colW.length - 1);
  }

  // Separatore/handle comune (header + righe) con linea centrale
  Widget _separatorHandle(int indexLeft) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final dx = d.delta.dx;
          setState(() {
            final i = indexLeft;
            final j = indexLeft + 1;
            final newLeft = _colW[i] + dx;
            final newRight = _colW[j] - dx;
            _colW[i] = newLeft <= 1 ? 1 : newLeft;
            _colW[j] = newRight <= 1 ? 1 : newRight;
          });
        },
        child: SizedBox(
          width: SEPARATOR_W,
          height: double.infinity,
          child: Center(
            child: Container(
              width: SEPARATOR_LINE_W,
              height: double.infinity,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  // Celle (stessa spaziatura per header e corpo)
  Widget _headerCell(String label, double w) {
    return SizedBox(
      width: w,
      height: HEADER_H,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
              color: Color(0xFF0A2B4E),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellText(String text, double w, {TextAlign align = TextAlign.left}) {
    return SizedBox(
      width: w,
      height: ROW_H,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment:
              align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _cellIcon(IconData icon, double w, {VoidCallback? onTap}) {
    final ico = Icon(icon, size: 18, color: const Color(0xFF3C5468));
    return SizedBox(
      width: w,
      height: ROW_H,
      child: Center(
        child: IconButton(
          icon: ico,
          splashRadius: 18,
          tooltip: 'Apri dettaglio contratto',
          onPressed: onTap,
        ),
      ),
    );
  }

  // Riga header (nessun padding extra: allineamento perfetto)
  Widget _buildHeader() {
    final labels = const [
      'TIPO',
      'CONTRAENTE',
      'COMPAGNIA',
      'NUMERO',
      'RISCHIO',
      'FRAZIONAMENTO',
      'EFFETTO',
      'SCADENZA',
      'SCAD. COPERTURA',
      'PREMIO',
      '',
    ];

    final children = <Widget>[];
    for (var i = 0; i < _colW.length; i++) {
      children.add(_headerCell(labels[i], _colW[i]));
      if (i < _colW.length - 1) children.add(_separatorHandle(i));
    }

    return Container(
      height: HEADER_H,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(children: children),
    );
  }

  // Riga dati (stessa struttura/ordine del header)
  Widget _buildRow(_RowData r, int index) {
    final id = r.c.identificativi;
    final amm = r.c.amministrativi;
    final ram = r.c.ramiEl;
    final prem = r.c.premi;

    final bg = (index % 2 == 0) ? Colors.white : const Color(0xFFFAFCFF);
    final hover = _hoverRowIndex == index;

    final rowChildren = <Widget>[
      // 0: icona
      SizedBox(
        width: _colW[0],
        height: ROW_H,
        child: const Center(
          child: Icon(Icons.description_outlined, size: 18, color: Color(0xFF3C5468)),
        ),
      ),
      _separatorHandle(0),

      // 1: Contraente
      _cellText(r.entityName, _colW[1]),
      _separatorHandle(1),

      // 2: Compagnia
      _cellText(id.compagnia, _colW[2]),
      _separatorHandle(2),

      // 3: Numero
      _cellText(id.numeroPolizza, _colW[3]),
      _separatorHandle(3),

      // 4: Rischio
      _cellText(ram?.descrizione ?? '', _colW[4]),
      _separatorHandle(4),

      // 5: Frazionamento
      _cellText(amm?.frazionamento ?? '', _colW[5]),
      _separatorHandle(5),

      // 6: Effetto
      _cellText(_fmtDate(amm?.effetto), _colW[6]),
      _separatorHandle(6),

      // 7: Scadenza
      _cellText(_fmtDate(amm?.scadenza), _colW[7]),
      _separatorHandle(7),

      // 8: Scad. copertura
      _cellText(_fmtDate(amm?.scadenzaCopertura), _colW[8]),
      _separatorHandle(8),

      // 9: Premio
      _cellText(
        _currencyFmt.format(_parseMoney(prem?.premio)),
        _colW[9],
        align: TextAlign.right,
      ),
      _separatorHandle(9),

      // 10: azione
      _cellIcon(
        Icons.search,
        _colW[10],
        onTap: () => widget.onOpenContract?.call(r.entityId, r.contractId, r.c),
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverRowIndex = index),
      onExit: (_) => setState(() => _hoverRowIndex = null),
      child: Container(
        height: ROW_H,
        decoration: BoxDecoration(
          color: hover ? const Color(0xFFEFF7FF) : bg,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(children: rowChildren),
      ),
    );
  }

  Widget _buildTableBody() {
    return Column(
      children: [
        _buildHeader(),
        // Blocca altezza al contenitore verticale disponibile grazie a Expanded più sotto.
        // Il contenuto (righe) potrà scorrere verticalmente con scrollbar visibile.
        Expanded(
          child: Scrollbar(
            controller: _vCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _vCtrl,
              scrollDirection: Axis.vertical,
              child: Column(
                children: List.generate(_rows.length, (i) => _buildRow(_rows[i], i)),
              ),
            ),
          ),
        ),
      ],
    );
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

    // Contenitore estetico
    final tableCard = Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Orizzontale: scrollbar in basso + drag
            final table = SizedBox(
              width: _tableWidth,
              child: _buildTableBody(),
            );

            final horizontalScrollable = Scrollbar(
              controller: _hCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _hCtrl,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: table,
                ),
              ),
            );

            return horizontalScrollable;
          },
        ),
      ),
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

    // Struttura finale: la tabella riempie lo spazio, con scrollbar verticale a destra
    // e scrollbar orizzontale in basso. Separatori header/corpo perfettamente allineati.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tableCard),
        loadMore,
      ],
    );
  }
}
