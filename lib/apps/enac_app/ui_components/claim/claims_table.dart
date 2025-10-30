// lib/apps/enac_app/ui_components/claims_table.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

class ClaimsTable extends StatefulWidget {
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;

  /// callback: (ctx, viewRow)
  final Future<void> Function(BuildContext ctx, Map<String, dynamic> viewRow)?
      onOpenClaim;

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
  // ---------------- Paginazione ----------------
  final int _pageSize = 12;
  List<Map<String, dynamic>> _allViews = [];
  int _nextIndex = 0;
  final List<Map<String, dynamic>> _rows = [];

  // ---------------- UI ------------------------
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int? _hoverRowIndex;

  // ---------------- Formatter -----------------
  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'it_IT', symbol: '€');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  // ---------------- Scrollbar -----------------
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // ---------------- Design & Layout -----------
  static const double SEPARATOR_W = 8.0;       // handle visibile tra colonne
  static const double SEPARATOR_LINE_W = 1.0;  // linea del separatore
  static const double ROW_H = 44.0;
  static const double HEADER_H = 44.0;

  /// Ordine colonne:
  /// 0: COMPAGNIA
  /// 1: NUM. CONTRATTO
  /// 2: ESERCIZIO
  /// 3: NUM. SINISTRO
  /// 4: AVVENIMENTO
  /// 5: IMPORTO LIQUID.
  /// 6: DESCRIZIONE
  /// 7: STATO
  /// 8: (AZIONE)
  late List<double> _colW;

  @override
  void initState() {
    super.initState();
    _colW = <double>[200, 160, 100, 160, 140, 140, 320, 160, 56];
    _initLoad();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  // ================= Loading ==================
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
      if (mounted) setState(() => _isInitialLoading = false);
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

    if (!mounted) return;
    setState(() {
      _nextIndex = end;
      _isLoadingMore = false;
    });
  }

  // ================= Helpers ==================
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

  String _fmtDateDyn(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return _dateFmt.format(v);
    final s = v.toString().trim();
    try {
      return _dateFmt.format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  double get _tableWidth =>
      _colW.reduce((a, b) => a + b) + SEPARATOR_W * (_colW.length - 1);

  // =========== Celle e separatori (allineati) ===========
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
          tooltip: 'Apri Summary sinistro',
          onPressed: onTap,
        ),
      ),
    );
  }

  // ================= Header =====================
  Widget _buildHeader() {
    final labels = const [
      'COMPAGNIA',
      'NUM. CONTRATTO',
      'ESERCIZIO',
      'NUM. SINISTRO',
      'AVVENIMENTO',
      'IMPORTO LIQUID.',
      'DESCRIZIONE',
      'STATO',
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

  // ================= Row ========================
  Widget _buildRow(Map<String, dynamic> v, int index) {
    // Preferisce chiavi nuovo schema; fallback legacy
    final compagnia =
        (v['compagnia'] ?? v['Compagnia'] ?? '').toString();
    final numeroContratto =
        (v['numero_contratto'] ?? v['numero_polizza'] ?? v['NumeroPolizza'] ?? '')
            .toString();
    final esercizio =
        (v['esercizio'] ?? v['Esercizio'] ?? '').toString();
    final numeroSinistro =
        (v['numero_sinistro'] ?? v['NumeroSinistro'] ?? v['num_sinistro'] ?? '')
            .toString();

    final dataEvento =
        v['data_accadimento'] ?? v['data_avvenimento'] ?? v['DataAvvenimento'];

    final importoLiquidato =
        v['importo_liquidato'] ?? v['ImportoLiquidato'] ?? v['importo'];

    // Descrizione: ricava da nuove e vecchie chiavi
    final descrizione = (v['descrizione_evento'] ??
            v['descrizione'] ??
            v['Descrizione'] ??
            v['dinamica'] ??
            v['Dinamica'] ??
            v['danneggiamento'] ??
            '')
        .toString();

    final stato = (v['stato'] ??
            v['stato_compagnia'] ??
            v['StatoCompagnia'] ??
            v['codice_stato'] ??
            v['CodiceStato'] ??
            '')
        .toString();

    final bg = (index % 2 == 0) ? Colors.white : const Color(0xFFFAFCFF);
    final hover = _hoverRowIndex == index;

    final children = <Widget>[
      _cellText(compagnia, _colW[0]),
      _separatorHandle(0),

      _cellText(numeroContratto, _colW[1]),
      _separatorHandle(1),

      _cellText(esercizio, _colW[2]),
      _separatorHandle(2),

      _cellText(numeroSinistro, _colW[3]),
      _separatorHandle(3),

      _cellText(_fmtDateDyn(dataEvento), _colW[4]),
      _separatorHandle(4),

      _cellText(_fmtMoney(importoLiquidato), _colW[5], align: TextAlign.right),
      _separatorHandle(5),

      _cellText(descrizione, _colW[6]),
      _separatorHandle(6),

      _cellText(stato, _colW[7]),
      _separatorHandle(7),

      _cellIcon(
        Icons.search,
        _colW[8],
        onTap: () => widget.onOpenClaim?.call(context, v),
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
                children: List.generate(_rows.length, (i) => _buildRow(_rows[i], i)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= Build ======================
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

            // Scrollbar orizzontale in basso + drag
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
            const Text('Tutti i sinistri sono stati caricati'),
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
