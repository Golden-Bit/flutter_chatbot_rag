import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../llogic_components/backend_sdk.dart';   // contiene la classe Client

/* ════════════════════════════════════════════════════════════════
 *  P A G I N A   D E T T A G L I O   C L I E N T E
 * ═════════════════════════════════════════════════════════════ */
class ClientDetailPage extends StatefulWidget {
  final Client client;
  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // formattatore euro (riusato in tutta la classe)
  final _cf = NumberFormat.currency(locale: 'it_IT', symbol: '€');

  /* ---------- helper celle & righe TAB “Potenzialità” ---------- */
  Widget _cell(String v) => Container(
        height: 32,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration:
            BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
        child: Text(v),
      );

  TableRow _row(String label, String num, String val) => TableRow(
        children: [
          Padding(
              padding: const EdgeInsets.only(right: 8, top: 6),
              child: Text(label)),
          _cell(num),
          _cell(val),
        ],
      );

  @override
  void initState() {
    _tab = TabController(length: 8, vsync: this); // 8 tab totali
    super.initState();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /* ────────────────────────────────────────────────────────────
   *  UTILITIES GRAFICHE
   * ────────────────────────────────────────────────────────── */
  RichText _kv(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(
                text: '$label\n',
                style:
                    const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            TextSpan(text: value),
          ],
        ),
      );

  Widget _infoColumn(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            children[i],
          ]
        ],
      );

  /* ────────────────────────────────────────────────────────────
   *  1️⃣  CARD ANAGRAFICA (stessa di ClientContractsPage)
   * ────────────────────────────────────────────────────────── */
  Widget _topInfo(Client c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7E6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* icona */
            Container(
              width: 90,
              height: 90,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
            const SizedBox(width: 12),

            /* testo */
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF00A651),
                            borderRadius: BorderRadius.circular(2)),
                        child: const Text('CLIENTE',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 22,
                              color: Color(0xFF0082C8),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  /* griglia 3×2 */
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _infoColumn([
                          _kv('INDIRIZZO', c.address ?? 'n.d.'),
                          _kv('TELEFONO', c.phone ?? 'n.d.'),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoColumn([
                          _kv('EMAIL', c.email ?? 'n.d.'),
                          _kv('SETTORE', c.sector ?? 'n.d.'),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoColumn([
                          _kv('PARTITA IVA', c.vat ?? 'n.d.'),
                          _kv('COD. FISCALE', c.taxCode ?? 'n.d.'),
                          _kv('LEG. RAPP.', c.legalRep ?? 'n.d.'),
                          _kv('CF LEG. RAPP.', c.legalRepTaxCode ?? 'n.d.'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /* ────────────────────────────────────────────────────────────
   *  2️⃣  TAB “POTENZIALITÀ” (dati fittizi)
   * ────────────────────────────────────────────────────────── */
  Widget _potenzialita() {
    final rows = <TableRow>[
      _row('Progetti Aperti', '0', _cf.format(0)),
      _row('Portafoglio Auto', '2', _cf.format(60424.75)),
      _row('Portafoglio Rami El.', '6', _cf.format(1148114.02)),
      _row('Portafoglio Vita', '0', _cf.format(0)),
      _row('Vita premio unico', '0', _cf.format(0)),
      _row('Contabilità Insoluti', '6', _cf.format(566199.92)),
      _row('… di cui arretrati', '6', _cf.format(566199.92)),
      _row('Sospesi/Acconti', '0', _cf.format(0)),
      _row('Sinistri Aperti', '15', _cf.format(0)),
      _row('Sinistri Riservati', '1', _cf.format(1000000)),
      _row('Sinistri Liquidati', '14', _cf.format(17523.07)),
      _row('Frequenza 2024', '', '225,00 %'),
      _row('Frequenza 2025', '', '120,00 %'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* rating + mesi inattività */
          Row(
            children: [
              const Text('Rating',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF00A651),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('AA+',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 32),
              const Text('Mesi inattività',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFF00A651),
                    borderRadius: BorderRadius.circular(4)),
                child: const Text('0',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          /* tabella valori */
          Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FixedColumnWidth(60),
              2: FixedColumnWidth(120),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: rows,
          ),
        ],
      ),
    );
  }

  /* ────────────────────────────────────────────────────────────
   *  Placeholder per gli altri tab
   * ────────────────────────────────────────────────────────── */
  Widget _placeholder(String label) =>
      Center(child: Text('$label – in sviluppo'));

  /* ────────────────────────────────────────────────────────────
   *  BUILD
   * ────────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final c = widget.client;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Dettaglio cliente')),
      body: Column(
        children: [
          _topInfo(c),
          const SizedBox(height: 12),

          /* TAB BAR */
          TabBar(
            controller: _tab,
            isScrollable: true,
            labelColor: Colors.black,
            tabs: const [
              Tab(text: 'Potenzialità'),
              Tab(text: 'Amministrativi ✓'),
              Tab(text: 'Autorizzazioni ✓'),
              Tab(text: 'Contatto ✓'),
              Tab(text: 'Marketing ✓'),
              Tab(text: 'Bancari'),
              Tab(text: 'Appalti / Cauzioni'),
              Tab(text: 'Relazioni ✓'),
            ],
          ),

          /* CONTENUTO TAB */
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _potenzialita(),
                _placeholder('Amministrativi'),
                _placeholder('Autorizzazioni'),
                _placeholder('Contatto'),
                _placeholder('Marketing'),
                _placeholder('Bancari'),
                _placeholder('Appalti / Cauzioni'),
                _placeholder('Relazioni'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
