// lib/apps/enac_app/ui_components/home_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart'; // Omnia8Sdk + Entity
import 'package:boxed_ai/apps/enac_app/ui_components/clients/create_client_dialog.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

/// Dashboard “Home” con:
///   • 2 riquadri superiori AFFIANCATI: Titoli in Scadenza / Scadenze Contrattuali (da BE)
///   • Lista delle Entità Assicurate (10 per pagina + “Carica altri”)
///   • Pulsante verde “+ Nuova Entità” come nei risultati di ricerca
///
/// NOTE:
/// - L’errore del servizio dashboardDue viene gestito SILENZIOSAMENTE:
///   se fallisce, i contatori restano a 0 ma l’elenco entità viene comunque mostrato.
class HomeDashboard extends StatefulWidget {
  final User user; // username = userId
  final Token token;
  final Omnia8Sdk sdk;
  final void Function(String clientId)? onOpenClient;

  const HomeDashboard({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    this.onOpenClient,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  /* --------------------- stato “due” + entità --------------------- */
  Future<void>? _boot; // inizializzazione
  Map<String, dynamic> _due = {};
  List<String> _allEntityIds = [];
  final List<MapEntry<String, Entity>> _loaded = []; // (id, entity)
  static const int _pageSize = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _boot = _init();
  }

  /// Inizializza: prova a leggere i contatori; comunque carica le entità.
  Future<void> _init() async {
    final userId = widget.user.username;

    // 1) Prova a prendere i contatori. Qualsiasi errore -> ignora (contatori a 0).
    Map<String, dynamic> due = {};
    try {
      due = await widget.sdk.dashboardDue(userId, days: 120);
    } catch (_) {
      // silenzioso: lasciamo "due" = {} così i contatori renderanno 0
    }

    // 2) Entità: se fallisce mostriamo un piccolo snackbar ma NON blocchiamo la vista.
    List<String> ids = const [];
    try {
      ids = await widget.sdk.listEntities(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile caricare le entità: $e')),
        );
      }
    }

    // 3) Carica il primo lotto (se abbiamo id)
    final first = ids.isEmpty ? <MapEntry<String, Entity>>[] : await _fetchEntitiesChunk(ids, 0, _pageSize);

    if (!mounted) return;
    setState(() {
      _due = due;
      _allEntityIds = ids;
      _loaded
        ..clear()
        ..addAll(first);
    });
  }

  Future<List<MapEntry<String, Entity>>> _fetchEntitiesChunk(
      List<String> ids, int start, int count) async {
    final userId = widget.user.username;
    final int end = (start + count) > ids.length ? ids.length : (start + count);
    if (start >= end) return <MapEntry<String, Entity>>[];
    final slice = ids.sublist(start, end);

    final pairs = await Future.wait(slice.map((id) async {
      try {
        final ent = await widget.sdk.getEntity(userId, id);
        return MapEntry(id, ent);
      } catch (_) {
        return MapEntry(id, Entity(name: id)); // fallback minimale
      }
    }));
    return pairs;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_loaded.length >= _allEntityIds.length) return;

    setState(() => _isLoadingMore = true);
    try {
      final next = await _fetchEntitiesChunk(
        _allEntityIds,
        _loaded.length,
        _pageSize,
      );
      if (!mounted) return;
      setState(() => _loaded.addAll(next));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /* --------------------- helpers UI / dati “due” --------------------- */

  // Estrazione robusta dei contatori dal payload dashboardDue
int _dueCount(String scope, int days) {
  // 1) Prova prima a calcolare dai LISTATI (payload attuale del BE)
  final String listKey = scope == 'titles' ? 'titles_due' : 'contracts_due';
  final dynamic rawList =
      _due[listKey] ?? _due[listKey.toLowerCase()] ?? _due[listKey.toUpperCase()];
  if (rawList is List) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(Duration(days: days));
    final dateKey = scope == 'titles' ? 'scadenza_titolo' : 'scadenza';

    int count = 0;
    for (final item in rawList) {
      if (item is Map) {
        final dynamic ds =
            item[dateKey] ?? item[dateKey.toLowerCase()] ?? item[dateKey.toUpperCase()];
        if (ds is String && ds.isNotEmpty) {
          try {
            final d = DateTime.parse(ds);
            final dd = DateTime(d.year, d.month, d.day);
            if (!dd.isBefore(today) && !dd.isAfter(limit)) {
              count++;
            }
          } catch (_) {
            // data non parsabile -> ignora
          }
        }
      }
    }
    return count;
  }

  // 2) Fallback: vecchia logica su mappe con contatori già aggregati (se in futuro il BE li esponesse)
  final Map<String, dynamic> root = {
    for (final e in _due.entries) e.key.toString().toLowerCase(): e.value
  };
  dynamic sec = root[scope] ??
      root[scope == 'titles' ? 'titoli' : 'contratti'] ??
      root['${scope}_due'] ??
      root['${scope}_counts'];

  int? parse(dynamic x) {
    if (x == null) return null;
    if (x is num) return x.toInt();
    return int.tryParse(x.toString());
  }

  if (sec is Map) {
    final m = {for (final e in sec.entries) e.key.toString().toLowerCase(): e.value};
    for (final k in <String>['$days', 'in_$days', 'in$days', '${days}_giorni']) {
      final v = parse(m[k]);
      if (v != null) return v;
    }
  }

  for (final k in <String>[
    '${scope}_$days',
    '${scope}in$days',
    '${scope}_in_$days',
    '${scope}$days',
    '${scope}_${days}_giorni',
  ]) {
    final v = parse(root[k]);
    if (v != null) return v;
  }

  return 0;
}


  Widget _dueBox({
    required String title,
    required List<({String label, int days})> rows,
    EdgeInsets padding = const EdgeInsets.all(12),
  }) {
    Widget row(String label, int count) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              InkWell(
                onTap: () {}, // hook per futura navigazione filtro
                child: Text(
                  '$count',
                  style: const TextStyle(color: Color(0xFF0082C8)),
                ),
              ),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final r in rows)
            row(
              r.label,
              _dueCount(
                title.toLowerCase().contains('titoli') ? 'titles' : 'contracts',
                r.days,
              ),
            ),
        ],
      ),
    );
  }

  /* ------------------------------ UI: ENTITÀ ------------------------------ */

  Widget _entitiesHeader() => Row(
        children: [
          const Text('Elenco delle Entità Assicurate',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF00A651),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuova Entità',
                style: TextStyle(fontWeight: FontWeight.w500)),
            onPressed: () async {
              final created = await CreateClientDialog.show(
                context,
                user: widget.user,
                token: widget.token,
                sdk: widget.sdk,
              );
              if (created == true && mounted) {
                // ricarica tutto per mostrare la nuova entità in cima
                setState(() => _boot = _init());
              }
            },
          ),
        ],
      );

  Widget _entityCard(MapEntry<String, Entity> pair) {
    final id = pair.key;
    final c = pair.value;

    Widget headerIcons() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in const [
              Icons.mail,
              Icons.phone,
              Icons.chat_bubble_outline,
              Icons.print,
            ])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(i, size: 16, color: Colors.grey.shade700),
              ),
          ],
        );

    Widget info(String label, String v) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.openSans(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                    text: '$label\n',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                TextSpan(text: v.isEmpty ? 'n.d.' : v),
              ],
            ),
          ),
        );

    return InkWell(
      onTap: () => widget.onOpenClient?.call(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7E6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            // contenuto
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // icona
                Container(
                  width: 90,
                  height: 90,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),

                // testo
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // riga titolo (badge + ragione sociale)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A651),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text("ENTITA'",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Color(0xFF0082C8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // griglia 3x2
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  info('INDIRIZZO', c.address ?? ''),
                                  info(
                                    'TELEFONO / EMAIL',
                                    (c.phone ?? 'n.d.') +
                                        (c.email != null
                                            ? '  /  ${c.email}'
                                            : ''),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  info('IDENTIFICATIVO',
                                      'Id. ${c.vat ?? '---'}'),
                                  info('COD. FISCALE', c.taxCode ?? ''),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  info('SETTORE / ATECO', c.sector ?? ''),
                                  info('LEGALE RAPPRESENTANTE',
                                      c.legalRep ?? ''),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // azioni in alto a destra
            Positioned(
              top: 4,
              right: 6,
              child: headerIcons(),
            ),
          ],
        ),
      ),
    );
  }

  /* ------------------------------- BUILD ------------------------------- */

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── RIGA RIQUADRI IN TESTA (AFFIANCATI) ───────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _dueBox(
                      title: 'Titoli in Scadenza',
                      rows: const [
                        (label: 'In Scadenza tra 60 giorni', days: 60),
                        (label: 'In Scadenza tra 90 giorni', days: 90),
                        (label: 'In Scadenza tra 120 giorni', days: 120),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _dueBox(
                      title: 'Scadenze Contrattuali',
                      rows: const [
                        (label: 'Polizze in Scadenza tra 60 giorni', days: 60),
                        (label: 'Polizze in scadenza tra 90 giorni', days: 90),
                        (label: 'Polizze in scadenza tra 120 giorni', days: 120),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── ELENCO ENTITÀ + PULSANTE CREAZIONE ─────────────────────
              _entitiesHeader(),
              const SizedBox(height: 8),

              // elenco
              for (final p in _loaded) _entityCard(p),

              // “Carica altri”
              if (_loaded.length < _allEntityIds.length)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingMore ? null : _loadMore,
                      icon: _isLoadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.unfold_more),
                      label: Text(
                        _isLoadingMore ? 'Caricamento…' : 'Carica altri',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
