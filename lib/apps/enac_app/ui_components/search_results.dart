// lib/apps/enac_app/ui_components/search_results.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart'; // Omnia8Sdk, Entity, ContrattoOmnia8, Sinistro
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

/// Pannello risultati ricerca globale:
///   • Entità (clienti)
///   • Contratti (polizze)
///   • Sinistri
///
/// NOTE: prevede 3 callback opzionali per aprire i dettagli.
/// Se non vengono passati, il click mostra uno SnackBar.
class SearchResultsPanel extends StatefulWidget {
  final String query;
  final User user; // username = userId
  final Token token;
  final Omnia8Sdk sdk;

  final void Function(String clientId)? onOpenClient;
  final void Function(String entityId, String contractId, ContrattoOmnia8? contratto)? onOpenContract;
  final void Function(String entityId, String contractId, String claimId, Map<String, dynamic> viewRow, Sinistro? sinistro)? onOpenClaim;

  const SearchResultsPanel({
    super.key,
    required this.query,
    required this.user,
    required this.token,
    required this.sdk,
    this.onOpenClient,
    this.onOpenContract,
    this.onOpenClaim,
  });

  @override
  State<SearchResultsPanel> createState() => _SearchResultsPanelState();
}

/* ───────────────────────────── Helpers comuni ───────────────────────────── */

String _takeS(Map<String, dynamic> v, List<String> keys) {
  for (final k in keys) {
    final val = v[k];
    if (val != null) {
      final s = val.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return '';
}


String? _takeSOpt(Map<String, dynamic> v, List<String> keys) {
  for (final k in keys) {
    final val = v[k];
    if (val != null) {
      final s = val.toString().trim();
      if (s.isNotEmpty) return s;
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

bool _mapContainsQuery(Map<String, dynamic> v, String q) {
  if (q.isEmpty) return true;
  final qq = q.toLowerCase();
  for (final entry in v.entries) {
    final s = entry.value?.toString().toLowerCase();
    if (s != null && s.contains(qq)) return true;
  }
  return false;
}

/* ────────────────────────────── Modelli riga ────────────────────────────── */

class _ContractRow {
  final String entityId;
  final String entityName;
  final Map<String, dynamic> view;
  final String? contractId;
  final DateTime? decorrenza;
  final DateTime? scadenza;

  _ContractRow({
    required this.entityId,
    required this.entityName,
    required this.view,
    required this.contractId,
    required this.decorrenza,
    required this.scadenza,
  });
}

class _ClaimRow {
  final String entityId;
  final String entityName;
  final Map<String, dynamic> view;
  final String? contractId;
  final String? claimId;
  final DateTime? dataAvvenimento;

  _ClaimRow({
    required this.entityId,
    required this.entityName,
    required this.view,
    required this.contractId,
    required this.claimId,
    required this.dataAvvenimento,
  });
}

/* ───────────────────────────────── STATE ───────────────────────────────── */

class _SearchResultsPanelState extends State<SearchResultsPanel> {
  late Future<void> _future;

  // ENTITÀ
  final List<MapEntry<String, Entity>> _entityResults = []; // (id, entity)

  // CONTRATTI
  final List<_ContractRow> _contractsAll = [];
  final List<_ContractRow> _contractsShown = [];
  static const int _contractsPage = 10;
  int _contractsNext = 0;
  bool _contractsLoadingMore = false;

  // SINISTRI
  final List<_ClaimRow> _claimsAll = [];
  final List<_ClaimRow> _claimsShown = [];
  static const int _claimsPage = 10;
  int _claimsNext = 0;
  bool _claimsLoadingMore = false;

  // error/signal
  String? _errContracts;
  String? _errClaims;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  @override
  void didUpdateWidget(covariant SearchResultsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _future = _loadAll();
      setState(() {});
    }
  }

  /* ───────────────────────────── Networking ───────────────────────────── */

  Future<void> _loadAll() async {
    _entityResults.clear();
    _contractsAll.clear();
    _contractsShown.clear();
    _contractsNext = 0;
    _errContracts = null;

    _claimsAll.clear();
    _claimsShown.clear();
    _claimsNext = 0;
    _errClaims = null;

    // 1) ENTITÀ (come prima)
    final userId = widget.user.username;
    try {
      final ids = await widget.sdk.listEntities(userId);
      final pairs = await Future.wait(
        ids.map((id) async {
          try {
            final e = await widget.sdk.getEntity(userId, id);
            return MapEntry(id, e);
          } catch (_) {
            return MapEntry(id, Entity(name: id));
          }
        }),
      );

      final q = widget.query.trim().toLowerCase();
      final filtered = q.isEmpty
          ? pairs
          : pairs.where((p) => p.value.name.toLowerCase().contains(q)).toList();
      filtered.sort((a, b) => a.value.name.compareTo(b.value.name));
      _entityResults.addAll(filtered);

      // 2) CONTRATTI (view globale oppure per-entità fallback)
      await _loadContracts(userId, ids);

      // 3) SINISTRI (per-entità, come AllClaimsPage)
      await _loadClaims(userId, ids);

      // paginazione iniziale
      _appendContractsPage();
      _appendClaimsPage();
    } catch (e) {
      // se fallisse qui, mostriamo semplicemente liste vuote + snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore ricerca: $e')),
        );
      }
    }
  }

  Future<void> _loadContracts(String userId, List<String> entityIds) async {
    try {
      // Primo tentativo: vista globale (se esiste nel tuo SDK)
      final List<Map<String, dynamic>> global = await widget.sdk.viewAllContracts(userId);
      final Map<String, String> entityNames = await _ensureEntityNames(userId, entityIds);

      _collectContractsFromView(global, entityNames, fallbackEntityId: null);
    } catch (_) {
      // Fallback: vista per entità
      try {
        final Map<String, String> entityNames = await _ensureEntityNames(userId, entityIds);
        for (final eid in entityIds) {
          try {
            // Se nel tuo SDK il nome differisce, adegua (es. viewEntityPolicies / viewEntityContracts)
            final list = await widget.sdk.viewEntityContracts(userId, eid);
            _collectContractsFromView(list, entityNames, fallbackEntityId: eid);
          } catch (_) {
            // ignoro l'errore di una singola entità
          }
        }
      } catch (e) {
        _errContracts = 'Impossibile caricare le polizze: $e';
      }
    }

    // Ordina per scadenza desc (null in fondo)
    _contractsAll.sort((a, b) {
      final da = a.scadenza;
      final db = b.scadenza;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    // Filtra per query full-text sulle view
    final q = widget.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      _contractsAll.retainWhere((r) => _mapContainsQuery(r.view, q));
    }
  }

  void _collectContractsFromView(
    List<dynamic> rawList,
    Map<String, String> entityNames, {
    String? fallbackEntityId,
  }) {
    for (final raw in rawList) {
      final v = Map<String, dynamic>.from(raw as Map);
      final contractId = _takeSOpt(v, ['contract_id', 'id_contratto', 'id_contract', 'contractId', 'ContrattoId']);
      final eId = _takeSOpt(v, ['entity_id', 'cliente_id', 'id_entita', 'entityId']) ?? fallbackEntityId ?? '';
      if (eId.isEmpty) continue;

      final row = _ContractRow(
        entityId: eId,
        entityName: entityNames[eId] ?? eId,
        view: v,
        contractId: contractId,
        decorrenza: _parseDateOpt(v['decorrenza'] ?? v['DataDecorrenza']),
        scadenza: _parseDateOpt(v['scadenza'] ?? v['DataScadenza']),
      );
      _contractsAll.add(row);
    }
  }

  Future<void> _loadClaims(String userId, List<String> entityIds) async {
    try {
      final Map<String, String> entityNames = await _ensureEntityNames(userId, entityIds);
      for (final eid in entityIds) {
        try {
          final list = await widget.sdk.viewEntityClaims(userId, eid);
          for (final raw in list) {
            final v = Map<String, dynamic>.from(raw);
            final contractId = _takeSOpt(v, [
              'contract_id',
              'id_contratto',
              'id_contract',
              'contractId',
              'ContrattoId',
            ]);
            final claimId = _takeSOpt(v, [
              'claim_id',
              'id',
              'Id',
              'ID',
              'sinistro_id',
              'SinistroId',
              'id_sinistro',
            ]);

            final row = _ClaimRow(
              entityId: eid,
              entityName: entityNames[eid] ?? eid,
              view: v,
              contractId: contractId,
              claimId: claimId,
              dataAvvenimento: _parseDateOpt(v['data_avvenimento'] ?? v['DataAvvenimento']),
            );
            _claimsAll.add(row);
          }
        } catch (_) {
          // ignoro singola entità
        }
      }
    } catch (e) {
      _errClaims = 'Impossibile caricare i sinistri: $e';
    }

    // Ordine per data avvenimento desc, null in fondo
    _claimsAll.sort((a, b) {
      final da = a.dataAvvenimento;
      final db = b.dataAvvenimento;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    // Filtra per query
    final q = widget.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      _claimsAll.retainWhere((r) => _mapContainsQuery(r.view, q));
    }
  }

  Future<Map<String, String>> _ensureEntityNames(String userId, List<String> ids) async {
    final Map<String, String> names = {};
    for (final id in ids) {
      try {
        final e = await widget.sdk.getEntity(userId, id);
        names[id] = e.name;
      } catch (_) {
        names[id] = id;
      }
    }
    return names;
  }

  /* ──────────────────────────── Paginazione ──────────────────────────── */

  void _appendContractsPage() {
    final end = (_contractsNext + _contractsPage).clamp(0, _contractsAll.length);
    _contractsShown.addAll(_contractsAll.sublist(_contractsNext, end));
    _contractsNext = end;
  }

  void _appendClaimsPage() {
    final end = (_claimsNext + _claimsPage).clamp(0, _claimsAll.length);
    _claimsShown.addAll(_claimsAll.sublist(_claimsNext, end));
    _claimsNext = end;
  }

  /* ─────────────────────────── UI Helpers base ────────────────────────── */

  InlineSpan _highlight(String src) {
    final q = widget.query.trim();
    if (q.isEmpty) return TextSpan(text: src);
    final reg = RegExp(RegExp.escape(q), caseSensitive: false);
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in reg.allMatches(src)) {
      if (m.start > last) spans.add(TextSpan(text: src.substring(last, m.start)));
      spans.add(TextSpan(
        text: src.substring(m.start, m.end),
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0082C8)),
      ));
      last = m.end;
    }
    if (last < src.length) spans.add(TextSpan(text: src.substring(last)));
    return TextSpan(children: spans);
  }

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

  Widget _kv(String l, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.25),
          children: [
            TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
            TextSpan(text: v.isEmpty ? '—' : v),
          ],
        ),
      );

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    // dd/MM/yyyy (senza import di intl qui per stare snello)
    final two = (int x) => x < 10 ? '0$x' : '$x';
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ───────────────────────────── ENTITÀ UI ───────────────────────────── */

  Widget _entityCard(MapEntry<String, Entity> pair) {
    final id = pair.key;
    final c = pair.value;

    Widget info(String label, String v) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.openSans(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(text: '$label\n', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                TextSpan(text: v.isEmpty ? 'n.d.' : v),
              ],
            ),
          ),
        );

    return InkWell(
      onTap: () {
        if (widget.onOpenClient != null) return widget.onOpenClient!(id);
        _snack('Apertura cliente non configurata');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7E6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF00A651), borderRadius: BorderRadius.circular(2)),
                              child: const Text("ENTITA'", style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: _highlight(c.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              info('INDIRIZZO', c.address ?? ''),
                              info('TELEFONO / EMAIL', (c.phone ?? 'n.d.') + (c.email != null ? '  /  ${c.email}' : '')),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              info('IDENTIFICATIVO', 'Id. ${c.vat ?? '---'}'),
                              info('COD. FISCALE', c.taxCode ?? ''),
                            ])),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              info('SETTORE / ATECO', c.sector ?? ''),
                              info('LEGALE RAPPRESENTANTE', c.legalRep ?? ''),
                            ])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(top: 4, right: 6, child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final i in const [Icons.mail, Icons.phone, Icons.chat_bubble_outline, Icons.print])
                Padding(padding: const EdgeInsets.only(left: 6), child: Icon(i, size: 16, color: Colors.grey.shade700)),
            ])),
          ],
        ),
      ),
    );
  }

  /* ─────────────────────────── CONTRATTI UI ─────────────────────────── */

  Future<void> _openContract(_ContractRow r) async {
    final contractId = r.contractId ?? _takeS(r.view, ['contract_id', 'id_contratto', 'id_contract', 'contractId', 'ContrattoId']);
    if (contractId.isEmpty) {
      _snack('Impossibile aprire il contratto: id mancante');
      return;
    }

    ContrattoOmnia8? c;
    try {
      // Se disponibile nel tuo SDK:
      c = await widget.sdk.getContract(widget.user.username, r.entityId, contractId);
    } catch (_) {
      // ok, passo null: il chiamante può ricostruire da view
      c = null;
    }

    if (widget.onOpenContract != null) {
      widget.onOpenContract!(r.entityId, contractId, c);
    } else {
      _snack('Apertura contratto non configurata');
    }
  }

  Widget _contractCard(_ContractRow r) {
    final v = r.view;

    final compagnia = _takeS(v, ['compagnia', 'Compagnia', 'company', 'Company']);
    final numPol    = _takeS(v, ['numero_polizza', 'NumeroPolizza', 'policy_number', 'PolicyNumber']);
    final rischio   = _takeS(v, ['rischio','Rischio','prodotto','Prodotto','ramo','Ramo','linea','product','Product']);
    final contraente= _takeS(v, ['contraente', 'Contraente', 'intestatario', 'Intestatario', 'cliente', 'Cliente']);
    final stato     = _takeS(v, ['stato', 'Stato', 'status', 'Status']);
    final premio    = _takeS(v, ['premio', 'Premio', 'premio_annuo', 'PremioAnnuo', 'premium']);
    final decor = _fmtDate(r.decorrenza);
    final scad  = _fmtDate(r.scadenza);

    return InkWell(
      onTap: () => _openContract(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // icona
            Container(
              width: 48,
              height: 48,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Icon(Icons.policy, size: 28, color: Colors.grey),
            ),
            const SizedBox(width: 10),

            // colonna sinistra
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(2)),
                    child: const Text('CONTRATTO', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${(compagnia.isEmpty ? '-' : compagnia)} - ${(numPol.isEmpty ? '-' : numPol)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, color: Color(0xFF0082C8), fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('DECORRENZA  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  Text(decor, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 18),
                  const Text('SCADENZA  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  Text(scad, style: const TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Text("ENTITA'  ", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                  const SizedBox(width: 4),
                  Expanded(child: _linkText(r.entityName)),
                ]),
              ]),
            ),

            // colonna centrale
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('RISCHIO', rischio),
                  const SizedBox(height: 6),
                  _kv('STATO', stato),
                  const SizedBox(height: 6),
                  _kv('PREMIO ANN.', premio),
                ]),
              ),
            ),

            // colonna destra
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('ID CONTRATTO', r.contractId ?? '—'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────────────── SINISTRI UI ─────────────────────────── */

  Future<void> _openClaim(_ClaimRow r) async {
    final contractId = r.contractId ?? _takeS(r.view, [
      'contract_id',
      'id_contratto',
      'id_contract',
      'contractId',
      'ContrattoId',
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
      _snack('Impossibile aprire il sinistro: id mancanti');
      return;
    }

    Sinistro? sin;
    try {
      sin = await widget.sdk.getClaim(widget.user.username, r.entityId, contractId, claimId);
    } catch (_) {
      sin = null; // il chiamante potrà ricostruire dal viewRow
    }

    if (widget.onOpenClaim != null) {
      widget.onOpenClaim!(r.entityId, contractId, claimId, r.view, sin);
    } else {
      _snack('Apertura sinistro non configurata');
    }
  }

  Widget _claimCard(_ClaimRow r) {
    final v = r.view;

    final esercizio   = _takeS(v, ['esercizio', 'Esercizio']);
    final numSinistro = _takeS(v, ['numero_sinistro', 'NumeroSinistro', 'num_sinistro']);
    final dataAvv     = _fmtDate(_parseDateOpt(v['data_avvenimento']) ?? _parseDateOpt(v['DataAvvenimento']));
    final compagnia   = _takeS(v, ['compagnia', 'Compagnia']);
    final numeroPol   = _takeS(v, ['numero_polizza', 'NumeroPolizza']);
    final clienteName = _takeS(v, ['entity_name', 'cliente', 'Cliente', 'CLIENTE']);
    final identificativo = _takeS(v, [
      'identificativo',
      'Identificativo',
      'numero_sinistro_compagnia',
      'NumeroSinistroCompagnia'
    ]);
    final targa     = _takeS(v, ['targa', 'Targa']);
    final indirizzo = _takeS(v, ['indirizzo', 'Indirizzo', 'address', 'Address']);
    final dataPresc = _fmtDate(_parseDateOpt(v['data_prescrizione']) ?? _parseDateOpt(v['DataPrescrizione']));

    return InkWell(
      onTap: () => _openClaim(r),
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
            // icona sinistro
            Container(
              width: 48,
              height: 48,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Icon(Icons.local_fire_department, size: 28, color: Colors.grey),
            ),
            const SizedBox(width: 10),

            // colonna sinistra
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(2)),
                    child: const Text('SINISTRO', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${esercizio.isEmpty ? '-' : esercizio} - ${numSinistro.isEmpty ? '-' : numSinistro}',
                    style: const TextStyle(fontSize: 22, color: Color(0xFF0082C8), fontWeight: FontWeight.w600),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('DATA AVVENIMENTO  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  Text(dataAvv, style: const TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Text('CONTRATTO  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                  const SizedBox(width: 4),
                  Expanded(child: _linkText('${(compagnia.isEmpty ? '—' : compagnia)} - ${(numeroPol.isEmpty ? '—' : numeroPol)}')),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Text("ENTITA'  ", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                  const SizedBox(width: 4),
                  Expanded(child: _linkText(clienteName.isEmpty ? r.entityName : clienteName)),
                ]),
              ]),
            ),

            // colonna centrale
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('IDENTIFICATIVO', identificativo),
                  const SizedBox(height: 6),
                  _kv('TARGA', targa),
                  const SizedBox(height: 6),
                  _kv('INDIRIZZO', indirizzo),
                ]),
              ),
            ),

            // colonna destra
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kv('DATA PRESCRIZIONE', dataPresc),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────────────────── BUILD ───────────────────────────────── */

  Widget _sectionHeader(String title, int count) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('($count)', style: const TextStyle(color: Colors.blueGrey)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // banner informativo
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF6CC),
                padding: const EdgeInsets.all(12),
                child: const Text(
                  'Alcuni risultati potrebbero essere stati limitati per performance. '
                  'Affina la ricerca per ottenere elenchi più precisi.',
                  style: TextStyle(fontSize: 13),
                ),
              ),

              // ───────────────────────── ENTITÀ ─────────────────────────
              _sectionHeader('Entità', _entityResults.length),
              if (_entityResults.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Nessuna entità trovata'))
              else
                ..._entityResults.map(_entityCard),

              // ───────────────────────── CONTRATTI ─────────────────────
              _sectionHeader('Contratti', _contractsAll.length),
              if (_errContracts != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_errContracts!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_contractsAll.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Nessuna polizza trovata'))
              else ...[
                for (final r in _contractsShown) _contractCard(r),
                if (_contractsNext < _contractsAll.length)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: _contractsLoadingMore
                            ? null
                            : () async {
                                setState(() => _contractsLoadingMore = true);
                                await Future<void>.delayed(const Duration(milliseconds: 150));
                                _appendContractsPage();
                                if (mounted) setState(() => _contractsLoadingMore = false);
                              },
                        icon: _contractsLoadingMore
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.unfold_more),
                        label: Text(_contractsLoadingMore ? 'Caricamento…' : 'Carica altri'),
                      ),
                    ),
                  )
                else
                  const Center(child: Padding(padding: EdgeInsets.only(top: 6), child: Text('Tutte le polizze sono state caricate'))),
              ],

              // ───────────────────────── SINISTRI ──────────────────────
              _sectionHeader('Sinistri', _claimsAll.length),
              if (_errClaims != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_errClaims!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_claimsAll.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Nessun sinistro trovato'))
              else ...[
                for (final r in _claimsShown) _claimCard(r),
                if (_claimsNext < _claimsAll.length)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: _claimsLoadingMore
                            ? null
                            : () async {
                                setState(() => _claimsLoadingMore = true);
                                await Future<void>.delayed(const Duration(milliseconds: 150));
                                _appendClaimsPage();
                                if (mounted) setState(() => _claimsLoadingMore = false);
                              },
                        icon: _claimsLoadingMore
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.unfold_more),
                        label: Text(_claimsLoadingMore ? 'Caricamento…' : 'Carica altri'),
                      ),
                    ),
                  )
                else
                  const Center(child: Padding(padding: EdgeInsets.only(top: 6), child: Text('Tutti i sinistri sono stati caricati'))),
              ],
            ],
          ),
        );
      },
    );
  }
}
