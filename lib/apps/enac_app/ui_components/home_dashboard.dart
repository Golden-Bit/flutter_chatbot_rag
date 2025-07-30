import 'package:flutter/material.dart';

/// Dashboard “Attività” (Home) – solo presentazione, nessuna logica.
///
/// Struttura:
///   • Colonna sx:  Link ▸ Agenda ▸ Insoluti
///   • Colonna dx:  Task ▸ Richieste
///
/// Ogni riquadro usa la stessa intestazione: titolo + azioni (↻ help ⚙ ecc.).
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  /* ---------- header generico dei box ---------- */
  Widget _boxHeader(String title,
      {bool addBtn = false, VoidCallback? onAdd}) {
    Widget iconBtn(IconData ic, VoidCallback? cb) => IconButton(
          icon: Icon(ic, size: 18, color: Colors.grey.shade700),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          onPressed: cb ?? () {},
        );

    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600)),
        const Spacer(),
        iconBtn(Icons.refresh, null),
        iconBtn(Icons.help_outline, null),
        iconBtn(Icons.settings_outlined, null),
        if (addBtn)
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(68, 28),
              backgroundColor: Colors.grey.shade200,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Task'),
            onPressed: onAdd ?? () {},
          ),
      ],
    );
  }

  /* ---------- mini‑pillola categoria ---------- */
  Widget _tag(String txt, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
        child: Text(txt,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );

  /* ---------- box “Agenda” ---------- */
  Widget _agendaBox() => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag('APPUNTAMENTI', Colors.blue.shade700),
            const SizedBox(height: 8),
            const Text('Non sono presenti elementi da visualizzare',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  /* ---------- box “Task” ---------- */
  Widget _taskBox() => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag('IMPEGNI', Colors.brown.shade600),
            const SizedBox(height: 8),
            const Text('Non sono presenti elementi da visualizzare',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );

  /* ---------- box “Insoluti” ---------- */
  Widget _insolutiBox() => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag('TITOLI', Colors.red.shade400),
            const SizedBox(height: 8),
            _insolutiRow('In scadenza oggi', '5'),
            _insolutiRow('Arretrati degli ultimi 30 giorni', '94'),
            _insolutiRow('In scadenza nei prossimi 60 giorni', '233'),
          ],
        ),
      );
  Widget _insolutiRow(String label, String n) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(n, style: const TextStyle(color: Colors.blue)),
          ],
        ),
      );

  /* ---------- box “Richieste” ---------- */
  Widget _richiesteBox() => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tag('ATTIVITÀ', Colors.orange.shade700),
            const SizedBox(height: 8),
            for (final l in [
              'In lavorazione',
              'Da trattare',
              'Non assegnate',
              'Inoltrate',
              'In carico al p.v.'
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(l)),
                    const Text('‑', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
          ],
        ),
      );

  /* ---------- box “Link” ---------- */
  Widget _linksBox() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Link',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // riquadro link (es. TeamViewer)
          SizedBox(
            width: 70,
            height: 70,
            child: Material(
              color: const Color(0xFF0090ff),
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: () {},
                child: const Center(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: Icon(Icons.link, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  /* ---------- build principale ---------- */
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attività',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          /* ---------------- GRID 2 col ---------------- */
          LayoutBuilder(builder: (ctx, c) {
            final double w = c.maxWidth;
            final double colW = (w - 16) / 2; // gap 16
            return Wrap(
              spacing: 16,
              runSpacing: 24,
              children: [
                // colonna SX
                SizedBox(
                  width: colW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linksBox(),
                      const SizedBox(height: 28),
                      _boxHeader('Agenda'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: _cardDecoration,
                        child: _agendaBox(),
                      ),
                      const SizedBox(height: 28),
                      _boxHeader('Insoluti'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: _cardDecoration,
                        child: _insolutiBox(),
                      ),
                    ],
                  ),
                ),

                // colonna DX
                SizedBox(
                  width: colW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _boxHeader('Task', addBtn: true),
                      const SizedBox(height: 8),
                      Container(
                        decoration: _cardDecoration,
                        child: _taskBox(),
                      ),
                      const SizedBox(height: 28),
                      _boxHeader('Richieste'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: _cardDecoration,
                        child: _richiesteBox(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /* ---------- stile card ---------- */
  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(2),
      );
}
