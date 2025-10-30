// lib/apps/enac_app/ui_components/contract_claims_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';
import 'claim_summary_panel.dart'; // per ClaimSummaryPanel.claimFromViewRow

class ContractClaimsPage extends StatefulWidget {
  final String userId;
  final String entityId;
  final String contractId;
  final Omnia8Sdk sdk;

  /// callback: (sinistro, viewRow)
  final void Function(dynamic sinistro, Map<String, dynamic> viewRow) onOpenClaim;

  const ContractClaimsPage({
    super.key,
    required this.userId,
    required this.entityId,
    required this.contractId,
    required this.sdk,
    required this.onOpenClaim,
  });

  @override
  State<ContractClaimsPage> createState() => _ContractClaimsPageState();
}

class _ContractClaimsPageState extends State<ContractClaimsPage> {
  // -------------------- Paging --------------------
  static const int _pageSize = 12;
  final List<Map<String, dynamic>> _allViews = [];
  final List<Map<String, dynamic>> _rows = [];
  int _next = 0;

  // -------------------- UI State ------------------
  bool _initialLoading = true;
  bool _loadingMore = false;
  String? _error;
  int? _hoverRowIndex;

  // -------------------- Formatters ----------------
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  // -------------------- Scrollbars ----------------
  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  // -------------------- Design (allineamento perfetto) ----------
  static const double SEPARATOR_W = 8.0;       // handle visibile tra colonne
  static const double SEPARATOR_LINE_W = 1.0;  // linea centrale
  static const double ROW_H = 44.0;
  static const double HEADER_H = 44.0;

  /// Ordine colonne:
  /// 0: TIPO (icona)
  /// 1: ESERCIZIO
  /// 2: NUM. SINISTRO
  /// 3: AVVENIMENTO
  /// 4: IMPORTO LIQUID.
  /// 5: TARGA
  /// 6: DANNO
  /// 7: STATO
  /// 8: (AZIONE)
  late List<double> _colW;

  @override
  void initState() {
    super.initState();
    _colW = <double>[56, 100, 160, 140, 140, 120, 320, 160, 56];
    _load();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  // ===================== Data Loading ======================
  Future<void> _load() async {
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _error = null;
      _rows.clear();
      _allViews.clear();
      _next = 0;
    });

    try {
      List<dynamic> raw;
      try {
        // Preferito: view per contratto se disponibile
        raw = await widget.sdk.viewContractClaims(
          widget.userId,
          widget.entityId,
          widget.contractId,
        );
      } catch (_) {
        // Fallback: view per entità filtrando sul contratto
        final list =
            await widget.sdk.viewEntityClaims(widget.userId, widget.entityId);
        raw = list.where((m) {
          final v = Map<String, dynamic>.from(m);
          final cid = (v['contract_id'] ??
                  v['ContrattoId'] ??
                  v['contractId'] ??
                  '')
              .toString();
          return cid == widget.contractId;
        }).toList();
      }

      for (final r in raw) {
        _allViews.add(Map<String, dynamic>.from(r));
      }
      _appendPage();
    } catch (e) {
      _error = 'Errore nel caricamento sinistri: $e';
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  void _appendPage() {
    final end = (_next + _pageSize).clamp(0, _allViews.length);
    if (end > _next) _rows.addAll(_allViews.sublist(_next, end));
    _next = end;
  }

  bool get _hasMore => _next < _allViews.length;

  // ===================== Helpers ===========================
  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    if (v is DateTime) return _dateFmt.format(v);
    try {
      return _dateFmt.format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  double? _parseMoney(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      return lastDot > lastComma
          ? double.tryParse(s.replaceAll(',', ''))
          : double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    }
    if (s.contains(',')) return double.tryParse(s.replaceAll(',', '.'));
    return double.tryParse(s);
  }

  String _fmtMoney(dynamic v) {
    final n = _parseMoney(v);
    return n == null ? '—' : _currencyFmt.format(n);
  }

  Future<void> _openClaim(Map<String, dynamic> row) async {
    final String claimId =
        (row['claim_id'] ?? row['id'] ?? row['Id'] ?? row['SinistroId'] ?? '')
            .toString();

    dynamic sinistro;
    try {
      sinistro = await widget.sdk.getClaim(
        widget.userId,
        widget.entityId,
        widget.contractId,
        claimId,
      );
    } catch (_) {
      // Fallback sintetico da view
      sinistro = ClaimSummaryPanel.claimFromViewRow(row);
    }

    widget.onOpenClaim(sinistro, {
      ...row,
      'contract_id': widget.contractId,
      'claim_id': claimId,
    });
  }

  // ===================== Layout helpers (colonne ridimensionabili) ============
  double get _tableWidth =>
      _colW.reduce((a, b) => a + b) + SEPARATOR_W * (_colW.length - 1);

  Widget _separatorHandle(int indexLeft) {
    // handle condiviso da header e corpo: garantisce allineamento perfetto
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
            '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // Header con testo (uso funzione separata per mantenere stile coerente)
  Widget _headerCellLabeled(String label, double w) {
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

  // ===================== Header ============================
  Widget _buildHeader() {
    final labels = const [
      'TIPO',
      'ESERCIZIO',
      'NUM. SINISTRO',
      'AVVENIMENTO',
      'IMPORTO LIQUID.',
      'TARGA',
      'DANNO',
      'STATO',
      '',
    ];

    final children = <Widget>[];
    for (var i = 0; i < _colW.length; i++) {
      children.add(_headerCellLabeled(labels[i], _colW[i]));
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
    final esercizio =
        (v['esercizio'] ?? v['Esercizio'] ?? '').toString();
    final numSinistro = (v['numero_sinistro'] ??
            v['NumeroSinistro'] ??
            v['num_sinistro'] ??
            '')
        .toString();
    final avvenimento = v['data_accadimento'] ??
        v['data_avvenimento'] ??
        v['DataAvvenimento'];
    final importo =
        (v['importo_liquidato'] ?? v['ImportoLiquidato'] ?? v['importo'])
            ?.toString();
    final targa = (v['targa'] ?? v['Targa'] ?? '').toString();
    final danno = (v['descrizione_evento'] ??
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
      // 0: TIPO
      SizedBox(
        width: _colW[0],
        height: ROW_H,
        child: const Center(
          child: Icon(Icons.report_gmailerrorred, size: 18, color: Color(0xFF3C5468)),
        ),
      ),
      _separatorHandle(0),

      _cellText(esercizio, _colW[1]),
      _separatorHandle(1),

      _cellText(numSinistro, _colW[2]),
      _separatorHandle(2),

      _cellText(_fmtDate(avvenimento), _colW[3]),
      _separatorHandle(3),

      _cellText(_fmtMoney(importo), _colW[4], align: TextAlign.right),
      _separatorHandle(4),

      _cellText(targa, _colW[5]),
      _separatorHandle(5),

      _cellText(danno, _colW[6]),
      _separatorHandle(6),

      _cellText(stato, _colW[7]),
      _separatorHandle(7),

      _cellIcon(Icons.search, _colW[8], onTap: () => _openClaim(v)),
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
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return Center(child: Text(_error!));
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Nessun sinistro per questo contratto'));
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

            // Scrollbar orizzontale visibile in basso + drag nativo
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

    final loadMore = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (_hasMore)
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _loadingMore
                    ? null
                    : () async {
                        setState(() => _loadingMore = true);
                        await Future<void>.delayed(
                            const Duration(milliseconds: 120));
                        _appendPage();
                        if (mounted) setState(() => _loadingMore = false);
                      },
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Carico…' : 'Carica altro'),
              ),
            )
          else
            const Text('Tutti i sinistri sono stati caricati'),
        ],
      ),
    );

    // Struttura finale: tabella espandibile, scroll verticale con scrollbar,
    // scroll orizzontale con scrollbar visibile, colonne ridimensionabili,
    // separatori header/corpo perfettamente allineati.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tableCard),
        loadMore,
      ],
    );
  }
}
