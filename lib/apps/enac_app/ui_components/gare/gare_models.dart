import 'package:flutter/material.dart';

class Gara {
  final String id;
  final String titolo;          // es. "GARA POLIZZE 2024"
  final int anno;               // es. 2024
  final String stato;           // es. "ARCHIVIO", "APERTO", "AGGIUDICATA"
  final String enteAppaltante;  // es. "Comune di Roma"
  final DateTime? scadenzaPresentazione; // termine presentazione offerte
  final DateTime? dataAggiudicazione;
  final String? cig;            // codice CIG (se presente)
  final String? rup;            // RUP / referente
  final String? note;

  // conteggi/documenti tipici della sezione
  final int nBando;
  final int nDisciplinare;
  final int nCapitolati;
  final int nStatisticheSinistri;
  final int nModelliPartecipazione;

  Gara({
    required this.id,
    required this.titolo,
    required this.anno,
    required this.stato,
    required this.enteAppaltante,
    this.scadenzaPresentazione,
    this.dataAggiudicazione,
    this.cig,
    this.rup,
    this.note,
    this.nBando = 0,
    this.nDisciplinare = 0,
    this.nCapitolati = 0,
    this.nStatisticheSinistri = 0,
    this.nModelliPartecipazione = 0,
  });

  // in futuro userai questo per collegarti al BE
  factory Gara.fromJson(Map<String, dynamic> j) => Gara(
    id: j['id'] ?? '',
    titolo: j['titolo'] ?? '',
    anno: (j['anno'] ?? 0) is int ? j['anno'] : int.tryParse('${j['anno']}') ?? 0,
    stato: j['stato'] ?? 'ARCHIVIO',
    enteAppaltante: j['ente_appaltante'] ?? '',
    scadenzaPresentazione: _parseDateOpt(j['scadenza_presentazione']),
    dataAggiudicazione: _parseDateOpt(j['data_aggiudicazione']),
    cig: j['cig'],
    rup: j['rup'],
    note: j['note'],
    nBando: j['n_bando'] ?? 0,
    nDisciplinare: j['n_disciplinare'] ?? 0,
    nCapitolati: j['n_capitolati'] ?? 0,
    nStatisticheSinistri: j['n_statistiche_sinistri'] ?? 0,
    nModelliPartecipazione: j['n_modelli_partecipazione'] ?? 0,
  );
}

DateTime? _parseDateOpt(dynamic v) {
  if (v == null) return null;
  try { return v is DateTime ? v : DateTime.parse(v.toString()); } catch (_) { return null; }
}

String fmtDate(DateTime? d) {
  if (d == null) return '—';
  String two(int x) => x < 10 ? '0$x' : '$x';
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

@immutable
class GaraDocBadge extends StatelessWidget {
  final String label;
  final int count;
  const GaraDocBadge({super.key, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(2),
          ),
          child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
      ]),
    );
  }
}
