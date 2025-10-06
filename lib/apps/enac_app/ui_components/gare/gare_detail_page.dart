import 'package:flutter/material.dart';
import 'gare_models.dart';

class GaraDetailPage extends StatelessWidget {
  final Gara gara;
  const GaraDetailPage({super.key, required this.gara});

  // -- helpers ---------------------------------------------------------------

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    String two(int x) => x < 10 ? '0$x' : '$x';
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Widget _chip(String text, {Color color = const Color(0xFFDDEBF7)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      child: Text(text, style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.25),
            children: [
              TextSpan(text: '$k\n', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              TextSpan(text: v.isEmpty ? '—' : v),
            ],
          ),
        ),
      );

  // pill badge per i conteggi documentali
  Widget _docBadge(String label, int count) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ]),
    );
  }

  // -- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Top-anchored scroll: nessun Center e nessuna altezza forzata
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(right: 8, bottom: 24),
          child: ConstrainedBox(
            // si estende in larghezza ma NON in altezza → resta in alto
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // evita centrature verticali
              children: [
                // intestazione
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _chip('GARA', color: const Color(0xFF0A60FF).withOpacity(.12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gara.titolo,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0082C8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // griglia 2 colonne
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _kv('ANNO', '${gara.anno}'),
                        _kv('STATO', gara.stato),
                        _kv('ENTE APPALTANTE', gara.enteAppaltante),
                        _kv('SCADENZA PRESENTAZIONE', _fmtDate(gara.scadenzaPresentazione)),
                        _kv('DATA AGGIUDICAZIONE', _fmtDate(gara.dataAggiudicazione)),
                      ]),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _kv('CIG', gara.cig ?? '—'),
                        _kv('RUP', gara.rup ?? '—'),
                        _kv('NOTE', gara.note ?? '—'),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Text('Documentazione', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                Wrap(
                  runSpacing: 8,
                  children: [
                    _docBadge('Bandi', gara.nBando),
                    _docBadge('Disciplinari', gara.nDisciplinare),
                    _docBadge('Capitolati', gara.nCapitolati),
                    _docBadge('Statistiche Sinistri', gara.nStatisticheSinistri),
                    _docBadge('Modelli di Partecipazione', gara.nModelliPartecipazione),
                  ],
                ),

                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    color: const Color(0xFFFFF6CC),
                  ),
                  child: const Text(
                    'Sezione di archivio: qui verranno caricati i documenti relativi alla gara '
                    '(Bando, Disciplinare, Capitolati, Statistiche, Modelli, ecc.).',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
