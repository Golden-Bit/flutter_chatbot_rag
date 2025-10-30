// lib/apps/enac_app/ui_components/polizze/contracts_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class ContractsTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;

  /// callback (contractId, contratto)
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
  // ------------------ Paginazione ------------------
  final int _pageSize = 10;
  List<String> _allIds = [];
  int _nextIndex = 0;
  final List<_Row> _rows = [];

  // ------------------ UI state ---------------------
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int? _hoverRowIndex;

  // ------------------ Formatter -------------------
  final NumberFormat _cur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  // ------------------ Scrollbar & controllers -----
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // ------------------ Design & layout --------------
  static const double SEPARATOR_W = 8.0;        // handle visibile tra colonne
  static const double SEPARATOR_LINE_W = 1.0;   // linea centrale del separatore
  static const double ROW_H = 44.0;
  static const double HEADER_H = 44.0;

  // Ordine colonne:
  // 0: TIPO (icona)
  // 1: COMPAGNIA
  // 2: NUMERO
  // 3: RISCHIO
  // 4: FRAZIONAMENTO
  // 5: EFFETTO
  // 6: SCADENZA
  // 7: SCAD. COPERTURA
  // 8: PREMIO
  // 9: (AZIONE)
  late List<double> _colW;

  @override
  void initState() {
    super.initState();
    _colW = <double>[56, 200, 160, 200, 140, 120, 120, 160, 120, 56];
    _initLoad();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  // ================== Loading ======================
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
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  bool get _hasMore => _nextIndex < _allIds.length;

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
        if (!mounted) continue;
        setState(() => _rows.add(_Row(contractId, c)));
      } on ApiException catch (e) {
        if (e.statusCode != 404) {
          _error = 'Errore nel caricamento contratto $contractId: ${e.message}';
        }
      } catch (e) {
        _error = 'Errore inatteso su $contractId: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _nextIndex = end;
      _isLoadingMore = false;
    });
  }

  // ================== Helpers ======================
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
        return double.tryParse(s0.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
      }
    }
    if (s0.contains(',') && !s0.contains('.')) {
      return double.tryParse(s0.replaceAll(',', '.')) ?? 0.0;
    }
    return double.tryParse(s0) ?? 0.0;
  }

  // ================== Layout Calc ===================
  double get _tableWidth =>
      _colW.reduce((a, b) => a + b) + SEPARATOR_W * (_colW.length - 1);

  // ================== Widgets di cella/separatore ===
  Widget _separatorHandle(int indexLeft) {
    // indexLeft: indice colonna a sinistra del separatore
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

  Widget _headerCell(String label, double w) {
    return SizedBox(
      width: w,
      height: HEADER_H,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '', // placeholder, verrà sovrascritto sotto via Builder
          ),
        ),
      ),
    );
  }

  Widget _headerCellWithText(String label, double w) {
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
          tooltip: 'Dettaglio contratto',
          onPressed: onTap,
        ),
      ),
    );
  }

  // ================== Header ========================
  Widget _buildHeader() {
    final labels = const [
      'TIPO',
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
      children.add(_headerCellWithText(labels[i], _colW[i]));
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

  // ================== Righe ========================
  Widget _buildRow(_Row r, int index) {
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

      // 1: Compagnia
      _cellText(id.compagnia, _colW[1]),
      _separatorHandle(1),

      // 2: Numero
      _cellText(id.numeroPolizza, _colW[2]),
      _separatorHandle(2),

      // 3: Rischio
      _cellText(ram?.descrizione ?? '', _colW[3]),
      _separatorHandle(3),

      // 4: Frazionamento
      _cellText(amm?.frazionamento ?? '', _colW[4]),
      _separatorHandle(4),

      // 5: Effetto
      _cellText(_fmtDate(amm?.effetto), _colW[5]),
      _separatorHandle(5),

      // 6: Scadenza
      _cellText(_fmtDate(amm?.scadenza), _colW[6]),
      _separatorHandle(6),

      // 7: Scad. copertura
      _cellText(_fmtDate(amm?.scadenzaCopertura), _colW[7]),
      _separatorHandle(7),

      // 8: Premio
      _cellText(_cur.format(_parseMoney(prem?.premio)), _colW[8],
          align: TextAlign.right),
      _separatorHandle(8),

      // 9: Azione
      _cellIcon(
        Icons.search,
        _colW[9],
        onTap: () => widget.onOpenContract?.call(r.id, r.c),
      ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverRowIndex = index),
      onExit: (_) => setState(() => _hoverRowIndex = null),
      child: Container(
        height: ROW_H,
        decoration: BoxDecoration(
          color: hover ? const Color(0xFFEFF7FF) : bg,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: Row(children: rowChildren),
      ),
    );
  }

  Widget _buildTableBody() {
    return Column(
      children: [
        _buildHeader(),
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

  // ================== Build ========================
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
            final table = SizedBox(
              width: _tableWidth,
              child: _buildTableBody(),
            );

            // Scrollbar orizzontale in basso
            return Scrollbar(
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
          },
        ),
      ),
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
                        width: 18, height: 18,
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
        Expanded(child: tableCard),
        loadMoreSection,
      ],
    );
  }
}
