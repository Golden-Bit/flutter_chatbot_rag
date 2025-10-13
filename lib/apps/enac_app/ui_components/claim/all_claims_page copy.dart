// lib/apps/enac_app/ui_components/claims/all_claims_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../logic_components/backend_sdk.dart';

/// Pagina che mostra TUTTI i sinistri di tutte le entità
/// con UI uguale allo screenshot fornito.
class AllClaimsPage extends StatefulWidget {
  const AllClaimsPage({
    super.key,
    required this.userId,
    required this.sdk,
    this.onOpenClaim,
  });

  final String userId;
  final Omnia8Sdk sdk;

  /// Callback quando l'utente clicca una card.
  /// Vengono passati: entityId, contractId, claimId, viewRow (dalla view),
  /// e l'oggetto [Sinistro] se è stato possibile recuperarlo via API.
  final void Function(
    String entityId,
    String contractId,
    String claimId,
    Map<String, dynamic> viewRow,
    Sinistro? sinistro,
  )? onOpenClaim;

  @override
  State<AllClaimsPage> createState() => _AllClaimsPageState();
}

/* -------------------------- Helpers locali -------------------------- */
String _takeS(Map<String, dynamic> v, List<String> keys) {
  for (final k in keys) {
    final val = v[k];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString();
    }
  }
  return '';
}

String? _takeSOpt(Map<String, dynamic> v, List<String> keys) {
  for (final k in keys) {
    final val = v[k];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString();
    }
  }
  return null;
}

DateTime? _parseDateOpt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

/* --------------------------- Modello riga --------------------------- */
class _ClaimRow {
  final String entityId;
  final String entityName;
  final Map<String, dynamic> view; // riga view denormalizzata
  final DateTime? dataAvvenimento;
  final String? contractId;
  final String? claimId;

  _ClaimRow({
    required this.entityId,
    required this.entityName,
    required this.view,
    required this.dataAvvenimento,
    required this.contractId,
    required this.claimId,
  });
}

/* =============================== STATE ============================== */
class _AllClaimsPageState extends State<AllClaimsPage> {
  static const int _pageSize = 12;

  final _rows = <_ClaimRow>[];
  final _all = <_ClaimRow>[];
  int _next = 0;

  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  final _date = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _rows.clear();
      _all.clear();
      _next = 0;
      _error = null;
    });

    try {
      // Prendo tutte le entità, e per ognuna la view dei sinistri
      final entityIds = await widget.sdk.listEntities(widget.userId);

      // Recupero anche il nome entità (per CLIENTE)
      final Map<String, String> entityNames = {};
      for (final eid in entityIds) {
        try {
          final e = await widget.sdk.getEntity(widget.userId, eid);
          entityNames[eid] = e.name;
        } catch (_) {
          entityNames[eid] = eid;
        }
      }

      // View per ogni entità
      for (final eid in entityIds) {
        try {
          final list = await widget.sdk.viewEntityClaims(widget.userId, eid);
          for (final raw in list) {
            final v = Map<String, dynamic>.from(raw);

            // data avvenimento robusta
            final d = _parseDateOpt(v['data_avvenimento']) ??
                _parseDateOpt(v['DataAvvenimento']);

            // id (robusto su più alias)
            final cid = _takeSOpt(v, [
              'contract_id',
              'id_contratto',
              'ContrattoId',
              'id_contract',
              'contractId',
            ]);
            final clid = _takeSOpt(v, [
              'claim_id',
              'id',
              'Id',
              'ID',
              'sinistro_id',
              'SinistroId',
              'id_sinistro',
            ]);

            _all.add(_ClaimRow(
              entityId: eid,
              entityName: entityNames[eid] ?? eid,
              view: v,
              dataAvvenimento: d,
              contractId: cid,
              claimId: clid,
            ));
          }
        } catch (e) {
          // ignoro fallimenti puntuali su una singola entità
        }
      }

      // Ordino per data avvenimento desc (null in fondo)
      _all.sort((a, b) {
        final da = a.dataAvvenimento;
        final db = b.dataAvvenimento;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      await _loadMore();
    } on ApiException catch (e) {
      _error = 'Errore API: ${e.statusCode} ${e.message}';
    } catch (e) {
      _error = 'Errore: $e';
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  bool get _hasMore => _next < _all.length;

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    final end = (_next + _pageSize).clamp(0, _all.length);
    _rows.addAll(_all.sublist(_next, end));
    if (mounted) {
      setState(() {
        _next = end;
        _loadingMore = false;
      });
    }
  }

  /* ------------------------- UI helpers ------------------------- */
  Text _linkText(String s) => Text(
        s,
        style: const TextStyle(
          color: Color(0xFF0082C8),
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF0082C8),
        ),
        overflow: TextOverflow.ellipsis,
      );

  String _fmt(DateTime? d) => d == null ? '—' : _date.format(d);

  Widget _kvRight(String l, String v) => RichText(
        textAlign: TextAlign.left,
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.25),
          children: [
            TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
            TextSpan(text: v.isEmpty ? '—' : v),
          ],
        ),
      );

  Future<void> _onOpen(_ClaimRow r) async {
    // Provo a recuperare l'oggetto Sinistro completo, se ho gli ID
    Sinistro? sin;
    if (r.contractId != null && r.claimId != null) {
      try {
        sin = await widget.sdk.getClaim(
          widget.userId,
          r.entityId,
          r.contractId!,
          r.claimId!,
        );
      } catch (_) {
        // fallback: verrà creato dal chiamante via viewRow
      }
    }
    final contractId = r.contractId ?? _takeS(r.view, [
      'contract_id',
      'id_contratto',
      'ContrattoId',
      'id_contract',
      'contractId',
    ]);
    final claimId = r.claimId ?? _takeS(r.view, [
      'claim_id',
      'id',
      'Id',
      'ID',
      'sinistro_id',
      'SinistroId',
      'id_sinistro',
    ]);

    if (contractId.isEmpty || claimId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il sinistro: id mancanti')),
      );
      return;
    }

    widget.onOpenClaim?.call(r.entityId, contractId, claimId, r.view, sin);
  }

  /* ----------------------------- CARD ---------------------------- */
  Widget _claimCard(_ClaimRow r) {
    final v = r.view;

    // Titolo (Esercizio - Numero)
    final esercizio   = _takeS(v, ['esercizio', 'Esercizio']);
    final numSinistro = _takeS(v, ['numero_sinistro', 'NumeroSinistro', 'num_sinistro']);

    // Blocchi sinistra (come screenshot)
    final dataAvv =
        _fmt(_parseDateOpt(v['data_avvenimento']) ?? _parseDateOpt(v['DataAvvenimento']));
    final compagnia   = _takeS(v, ['compagnia', 'Compagnia']);
    final numeroPol   = _takeS(v, ['numero_polizza', 'NumeroPolizza']);
    final clienteName =
        _takeS(v, ['entity_name', 'cliente', 'Cliente', 'CLIENTE']);
    // Colonna centrale destra
    final identificativo = _takeS(v, [
      'identificativo',
      'Identificativo',
      'numero_sinistro_compagnia',
      'NumeroSinistroCompagnia'
    ]);
    final targa     = _takeS(v, ['targa', 'Targa']);
    final indirizzo = _takeS(v, ['indirizzo', 'Indirizzo', 'address', 'Address']);
    // Colonna estrema destra
    final dataPresc =
        _fmt(_parseDateOpt(v['data_prescrizione']) ?? _parseDateOpt(v['DataPrescrizione']));

    // Larghezze simili allo screenshot
    return InkWell(
      onTap: () => _onOpen(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icona sinistro (fiamma grigia)
            Container(
              width: 48,
              height: 48,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Icon(Icons.local_fire_department,
                  size: 28, color: Colors.grey),
            ),
            const SizedBox(width: 10),

            // COLONNA SINISTRA (badge + titolo + 3 righe)
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Riga badge + titolo blu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'SINISTRO',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${esercizio.isEmpty ? '-' : esercizio} - ${numSinistro.isEmpty ? '-' : numSinistro}',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF0082C8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // DATA AVVENIMENTO
                  Row(
                    children: [
                      const Text('DATA AVVENIMENTO  ',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      Text(dataAvv, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // CONTRATTO (link)
                  Row(
                    children: [
                      const Text('CONTRATTO  ',
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _linkText(
                          '${(compagnia.isEmpty ? '—' : compagnia)} - ${(numeroPol.isEmpty ? '—' : numeroPol)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // CLIENTE (link)
                  Row(
                    children: [
                      const Text("ENTITA'  ",
                          style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                      const SizedBox(width: 4),
                      Expanded(child: _linkText(clienteName.isEmpty ? r.entityName : clienteName)),
                    ],
                  ),
                ],
              ),
            ),

            // COLONNA CENTRALE DESTRA (identificativo / targa / indirizzo)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRight('IDENTIFICATIVO', identificativo),
                    const SizedBox(height: 6),
                    _kvRight('TARGA', targa),
                    const SizedBox(height: 6),
                    _kvRight('INDIRIZZO', indirizzo),
                  ],
                ),
              ),
            ),

            // COLONNA DESTRA ESTREMA (data prescrizione)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRight('DATA PRESCRIZIONE', dataPresc),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ------------------------------ BUILD ------------------------------ */
  @override
  Widget build(BuildContext context) {
    if (_loadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty && _error != null) {
      return Center(child: Text(_error!));
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Nessun sinistro trovato'));
    }

    final list = ListView.separated(
      padding: const EdgeInsets.only(top: 0, bottom: 8),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (_, i) => _claimCard(_rows[i]),
    );

    final loadMore = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Carico…' : 'Carica altro'),
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
        Expanded(child: list),
        loadMore,
      ],
    );
  }
}
