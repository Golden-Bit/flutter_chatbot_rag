import 'package:flutter/material.dart';
import 'gare_models.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

typedef OnOpenGara = void Function(Gara gara);

class GarePage extends StatefulWidget {
  final User user;
  final Token token;
  final Omnia8Sdk sdk;
  final OnOpenGara onOpenGara;

  const GarePage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.onOpenGara,
  });

  @override
  State<GarePage> createState() => _GarePageState();
}

class _GarePageState extends State<GarePage> {
  late Future<void> _future;

  // dataset completo (placeholder finché non arriva il BE)
  final List<Gara> _all = [];
  // elementi mostrati
  final List<Gara> _shown = [];

  static const int _pageSize = 10;
  int _nextIndex = 0;
  bool _loadingMore = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  /* -------------------- DATA LOADING -------------------- */
  Future<void> _loadAll() async {
    _all.clear();
    _shown.clear();
    _nextIndex = 0;
    _err = null;

    try {
      // TODO BACKEND:
      // final raw = await widget.sdk.listGare(widget.user.username, offset: 0, limit: 200);
      // _all.addAll(raw.map((m) => Gara.fromJson(m)));

      // PLACEHOLDER + riempitivo per provare la paginazione
      _all.addAll([
        Gara(
          id: 'g-2023-broker',
          titolo: 'GARA BROKER 2023',
          anno: 2023,
          stato: 'ARCHIVIO',
          enteAppaltante: 'Comune di Milano',
          nBando: 1, nDisciplinare: 1, nCapitolati: 2, nStatisticheSinistri: 1, nModelliPartecipazione: 3,
          dataAggiudicazione: DateTime(2023, 7, 18),
        ),
        Gara(
          id: 'g-2024-polizze',
          titolo: 'GARA POLIZZE 2024',
          anno: 2024,
          stato: 'APERTO',
          enteAppaltante: 'Città Metropolitana di Torino',
          scadenzaPresentazione: DateTime.now().add(const Duration(days: 35)),
          nBando: 1, nDisciplinare: 1, nCapitolati: 3, nStatisticheSinistri: 2, nModelliPartecipazione: 4,
        ),
        Gara(
          id: 'g-2027-polizze',
          titolo: 'GARA POLIZZE 2027',
          anno: 2027,
          stato: 'PROGRAMMATA',
          enteAppaltante: 'Regione Lazio',
          nBando: 0, nDisciplinare: 0, nCapitolati: 0, nStatisticheSinistri: 0, nModelliPartecipazione: 0,
        ),
      ]);

      for (int i = 0; i < 24; i++) {
        final y = 2025 + (i % 4);
        _all.add(Gara(
          id: 'g-$y-${i + 1}',
          titolo: 'GARA POLIZZE $y – Lotto ${i + 1}',
          anno: y,
          stato: (i % 3 == 0) ? 'APERTO' : (i % 3 == 1) ? 'PROGRAMMATA' : 'ARCHIVIO',
          enteAppaltante: (i % 2 == 0) ? 'Provincia di Parma' : 'Comune di Bologna',
          nBando: 1, nDisciplinare: 1, nCapitolati: 2, nStatisticheSinistri: 1, nModelliPartecipazione: 2,
        ));
      }

      _appendPage(); // primo batch
    } catch (e) {
      _err = 'Impossibile caricare l’elenco gare: $e';
    }
    if (mounted) setState(() {});
  }

  void _appendPage() {
    final end = (_nextIndex + _pageSize).clamp(0, _all.length);
    _shown.addAll(_all.sublist(_nextIndex, end));
    _nextIndex = end;
  }

  /* -------------------- UI -------------------- */

  Widget _row(Gara g) {
    return InkWell(
      onTap: () => widget.onOpenGara(g),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          color: Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 40,
              child: const Center(child: Icon(Icons.mail_outline, size: 28, color: Colors.black87)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.titolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_err != null) {
          return Center(child: Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
        }

        // ⚓️ Top-anchoring anti-centering:
        // riempiamo l’altezza disponibile così, anche se il parent centra,
        // il contenuto rimane agganciato in alto.
        return LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Nessuna gara trovata'),
                        )
                      else ...[
                        for (final g in _shown) _row(g),
                        if (_nextIndex < _all.length)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton.icon(
                                onPressed: _loadingMore
                                    ? null
                                    : () async {
                                        setState(() => _loadingMore = true);
                                        await Future<void>.delayed(const Duration(milliseconds: 150));
                                        _appendPage();
                                        if (mounted) setState(() => _loadingMore = false);
                                      },
                                icon: _loadingMore
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.unfold_more),
                                label: Text(_loadingMore ? 'Caricamento…' : 'Carica altri'),
                              ),
                            ),
                          )
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Tutte le gare sono state caricate'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
