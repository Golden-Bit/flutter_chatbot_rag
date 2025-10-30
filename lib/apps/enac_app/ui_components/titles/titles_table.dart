// lib/apps/enac_app/ui_components/titles_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class TitlesTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;

  /// callback: (BuildContext ctx, Map<String, dynamic> viewRow)
  final Future<void> Function(BuildContext ctx, Map<String, dynamic> viewRow)?
      onOpenTitle;

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

/* Riga vista denormalizzata (Map) */
class _TitlesTableState extends State<TitlesTable> {
  // -------------------- Paging --------------------
  static const int _pageSize = 12;
  final List<Map<String, dynamic>> _allViews = [];
  final List<Map<String, dynamic>> _rows = [];
  int _nextIndex = 0;

  // -------------------- UI State ------------------
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int? _hoverRowIndex;

  // -------------------- Formatters ----------------
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  // -------------------- Scrollbars ----------------
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // -------------------- Design & Resize -----------
  static const double SEPARATOR_W = 8.0;       // handle visibile tra colonne
  static const double SEPARATOR_LINE_W = 1.0;  // linea centrale
  static const double ROW_H = 44.0;
  static const double HEADER_H = 44.0;

  /// Ordine colonne:
  /// 0: TIPO (icona)
  /// 1: COMPAGNIA
  /// 2: NUM. CONTRATTO
  /// 3: RISCHIO
  /// 4: SCADENZA
  /// 5: STATO
  /// 6: PREMIO
  /// 7: (AZIONE)
  late List<double> _colW;

  @override
  void initState() {
    super.initState();
    _colW = <double>[56, 220, 170, 240, 140, 140, 120, 56];
    _initLoad();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  // ===================== Data Loading ======================
  Future<void> _initLoad() async {
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _error = null;
      _rows.clear();
      _allViews.clear();
      _nextIndex = 0;
    });

    try {
      final list =
          await widget.sdk.viewEntityTitles(widget.userId, widget.clientId);
      for (final e in list) {
        _allViews.add(Map<String, dynamic>.from(e));
      }
      if (_allViews.isNotEmpty) {
        _appendPage();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // nessun titolo: nessun errore
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

  void _appendPage() {
    final end = (_nextIndex + _pageSize).clamp(0, _allViews.length);
    if (end > _nextIndex) _rows.addAll(_allViews.sublist(_nextIndex, end));
    _nextIndex = end;
  }

  bool get _hasMore => _nextIndex < _allViews.length;

  // ===================== Helpers ===========================
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
    return n == null ? '—' : _currencyFmt.format(n);
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

  // ===================== Layout (colonne ridimensionabili) ============
  double get _tableWidth =>
      _colW.reduce((a, b) => a + b) + SEPARATOR_W * (_colW.length - 1);

  Widget _separatorHandle(int indexLeft) {
    // handle condiviso da header e righe per allineamento perfetto
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
          tooltip: 'Apri Summary titolo',
          onPressed: onTap,
        ),
      ),
    );
  }

  // ===================== Header ============================
  Widget _buildHeader() {
    final labels = const [
      'TIPO',
      'COMPAGNIA',
      'NUM. CONTRATTO',
      'RISCHIO',
      'SCADENZA',
      'STATO',
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

  // ===================== Row ===============================
  Widget _buildRow(Map<String, dynamic> v, int index) {
    final compagnia =
        (v['compagnia'] ?? v['Compagnia'] ?? '').toString();
    final numeroPolizza =
        (v['numero_polizza'] ?? v['NumeroPolizza'] ?? '').toString();
    final rischio = (v['rischio'] ?? v['Rischio'] ?? '').toString();
    final scadenza = v['scadenza_titolo'] ?? v['ScadenzaTitolo'];
    final stato = (v['stato'] ?? v['Stato'] ?? '').toString();
    final premio =
        (v['premio_lordo'] ?? v['PremioLordo'] ?? v['premio'] ?? '').toString();

    final bg = (index % 2 == 0) ? Colors.white : const Color(0xFFFAFCFF);
    final hover = _hoverRowIndex == index;

    final children = <Widget>[
      // 0: icona tipo
      SizedBox(
        width: _colW[0],
        height: ROW_H,
        child: const Center(
          child: Icon(Icons.receipt_long, size: 18, color: Color(0xFF3C5468)),
        ),
      ),
      _separatorHandle(0),

      _cellText(compagnia, _colW[1]),
      _separatorHandle(1),

      _cellText(numeroPolizza, _colW[2]),
      _separatorHandle(2),

      _cellText(rischio, _colW[3]),
      _separatorHandle(3),

      _cellText(_fmtDate(scadenza), _colW[4]),
      _separatorHandle(4),

      _cellText(stato, _colW[5]),
      _separatorHandle(5),

      _cellText(_fmtMoney(premio), _colW[6], align: TextAlign.right),
      _separatorHandle(6),

      _cellIcon(Icons.search, _colW[7],
          onTap: () => widget.onOpenTitle?.call(context, v)),
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
        child: Row(children: children),
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
                children:
                    List.generate(_rows.length, (i) => _buildRow(_rows[i], i)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===================== Build =============================
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

    // Card estetica con scrollbar orizzontale visibile
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
          if (_hasMore)
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _isLoadingMore
                    ? null
                    : () async {
                        setState(() => _isLoadingMore = true);
                        await Future<void>.delayed(
                            const Duration(milliseconds: 120));
                        _appendPage();
                        if (mounted) setState(() => _isLoadingMore = false);
                      },
                icon: _isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label:
                    Text(_isLoadingMore ? 'Carico…' : 'Carica altro'),
              ),
            )
          else
            const Text('Tutti i titoli sono stati caricati'),
        ],
      ),
    );

    // Struttura finale: tabella con colonne ridimensionabili (senza min/max),
    // separatori header/corpo perfettamente allineati, scrollbar verticale e orizzontale visibili.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tableCard),
        loadMoreSection,
      ],
    );
  }
}
