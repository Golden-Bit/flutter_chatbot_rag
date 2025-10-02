
// lib/apps/enac_app/ui_components/claim_summary_panel.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic_components/backend_sdk.dart';

/// ───────────────────────────────────────────────────────────────
/// Utils
/// ───────────────────────────────────────────────────────────────
final _dateFmt = DateFormat('dd/MM/yyyy');
String _fmtDate(DateTime? dt) => (dt == null) ? '—' : _dateFmt.format(dt);

/// Link-like text
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

/// Small key/value in one line (used at header right)
Widget _pairRight(String l, String v) => RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.2),
        children: [
          TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
          TextSpan(text: v.isEmpty ? '—' : v),
        ],
      ),
    );

/// ───────────────────────────────────────────────────────────────
/// Base widgets (KV + grid)
/// ───────────────────────────────────────────────────────────────
class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.3)),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.rows, super.key});
  final List<_KV> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final colW = math.max(220.0, (c.maxWidth - 24) / 2); // 2 colonne comode
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/// ───────────────────────────────────────────────────────────────
/// SUMMARY SINISTRO – pannello con barra superiore in stile mock
/// Tabs sotto la barra: Riepilogo • Documenti • Diario di andamento
/// ───────────────────────────────────────────────────────────────
class ClaimSummaryPanel extends StatelessWidget {
  const ClaimSummaryPanel({
    super.key,
    required this.sinistro,
    required this.viewRow,
  });

  /// Dato del sinistro (pieno o ricostruito).
  final Sinistro sinistro;

  /// Riga denormalizzata (da tabella) per etichette extra.
  final Map<String, dynamic> viewRow;

  /// Build da viewRow (fallback quando non abbiamo l’oggetto pieno)
  static Sinistro claimFromViewRow(Map<String, dynamic> v) {
    DateTime d(String k) {
      final raw = v[k]?.toString();
      if (raw == null || raw.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return DateTime.now();
      }
    }

    String? s(String k) => v[k]?.toString();

    return Sinistro(
      esercizio: int.tryParse((s('esercizio') ?? s('Esercizio') ?? '0')) ?? 0,
      numeroSinistro: (s('numero_sinistro') ?? s('NumeroSinistro') ?? s('num_sinistro') ?? ''),
      numeroSinistroCompagnia: s('numero_sinistro_compagnia') ?? s('NumeroSinistroCompagnia'),
      numeroPolizza: s('numero_polizza') ?? s('NumeroPolizza'),
      compagnia: s('compagnia') ?? s('Compagnia'),
      rischio: s('rischio') ?? s('Rischio'),
      intermediario: s('intermediario') ?? s('Intermediario'),
      descrizioneAssicurato: s('descrizione_assicurato') ?? s('DescrizioneAssicurato'),
      dataAvvenimento: d('data_avvenimento'),
      citta: s('città') ?? s('citta') ?? s('Citta'),
      indirizzo: s('indirizzo') ?? s('Indirizzo'),
      cap: s('cap') ?? s('CAP'),
      provincia: s('provincia') ?? s('Provincia'),
      codiceStato: s('codice_stato') ?? s('CodiceStato'),
      targa: s('targa') ?? s('Targa'),
      dinamica: s('dinamica') ?? s('Dinamica'),
      statoCompagnia: s('stato_compagnia') ?? s('StatoCompagnia'),
      dataApertura: d('data_apertura'),
      dataChiusura: (s('data_chiusura')?.isNotEmpty ?? false) ? d('data_chiusura') : null,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Header (barra superiore)
  // ────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    String _s(String a, [String? b]) =>
        (viewRow[a] ?? (b != null ? viewRow[b] : null) ?? '').toString();

    // Identificativi in alto a sinistra
    final esercizio = _s('esercizio', 'Esercizio').isEmpty
        ? sinistro.esercizio.toString()
        : _s('esercizio', 'Esercizio');
    final nSinistro = _s('numero_sinistro', 'NumeroSinistro').isEmpty
        ? sinistro.numeroSinistro
        : _s('numero_sinistro', 'NumeroSinistro');

    // Polizza / Cliente
    final compagnia = _s('compagnia', 'Compagnia').isEmpty ? (sinistro.compagnia ?? '') : _s('compagnia', 'Compagnia');
    final numeroPolizza = _s('numero_polizza', 'NumeroPolizza').isEmpty ? (sinistro.numeroPolizza ?? '') : _s('numero_polizza', 'NumeroPolizza');
    final clientName = _s('entity_name', 'cliente').isEmpty ? (_s('Cliente', 'CLIENTE')) : _s('entity_name', 'cliente');

    // Rischio / Intermediario
    final rischio = _s('rischio', 'Rischio').isEmpty ? (sinistro.rischio ?? '') : _s('rischio', 'Rischio');
    final intermediario = _s('intermediario', 'Intermediario').isEmpty ? (sinistro.intermediario ?? '') : _s('intermediario', 'Intermediario');

    // Date a destra
    final dataAvvRaw = viewRow['data_avvenimento'] ?? viewRow['DataAvvenimento'] ?? sinistro.dataAvvenimento;
    final dataChiusRaw = viewRow['data_chiusura'] ?? viewRow['DataChiusura'] ?? sinistro.dataChiusura;
    final dataAvv = _fmtScadenza(dataAvvRaw);
    final dataChius = _fmtScadenza(dataChiusRaw);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        border: Border.all(color: Colors.grey.shade300),
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

          // Testo principale a sinistra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Riga tag + titolo "YYYY - nnnn"
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('SINISTRO', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${esercizio.isEmpty ? '-' : esercizio} - ${nSinistro.isEmpty ? '-' : nSinistro}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0082C8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sezione: CONTRATTO / CLIENTE
                Wrap(
                  spacing: 18,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('CONTRATTO  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: _linkText('${compagnia.isEmpty ? '—' : compagnia} - ${numeroPolizza.isEmpty ? '—' : numeroPolizza}'),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('CLIENTE  ', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const Icon(Icons.open_in_new, size: 14, color: Color(0xFF0082C8)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: _linkText(clientName.isEmpty ? '—' : clientName),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Sezione: RISCHIO / INTERMEDIARIO
                Wrap(
                  spacing: 24,
                  runSpacing: 2,
                  children: [
                    _kvInline('RISCHIO', rischio),
                    _kvInline('INTERMEDIARIO', intermediario),
                  ],
                ),
              ],
            ),
          ),

          // Colonna destra: icone azioni + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _HeaderActionIcons(),
              const SizedBox(height: 6),
              _pairRight('DATA AVVENIMENTO', dataAvv),
              const SizedBox(height: 4),
              _pairRight('DATA CHIUSURA', dataChius),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _kvInline(String k, String v) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(text: '$k  ', style: const TextStyle(color: Colors.blueGrey)),
            TextSpan(text: v.isEmpty ? '—' : v),
          ],
        ),
      );

  String _fmtScadenza(dynamic v) {
    if (v == null) return '—';
    if (v is DateTime) return _fmtDate(v);
    final s = v.toString();
    if (s.isEmpty) return '—';
    try {
      return _fmtDate(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  // ────────────────────────────────────────────────────────────
  // Tabs
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    String _s(String a, [String? b]) =>
        (viewRow[a] ?? (b != null ? viewRow[b] : null) ?? '').toString();

    // Polizza
    final compagnia =
        _s('compagnia', 'Compagnia').isEmpty ? (sinistro.compagnia ?? '') : _s('compagnia', 'Compagnia');
    final numeroPolizza =
        _s('numero_polizza', 'NumeroPolizza').isEmpty ? (sinistro.numeroPolizza ?? '') : _s('numero_polizza', 'NumeroPolizza');
    final rischio = _s('rischio', 'Rischio').isEmpty ? (sinistro.rischio ?? '') : _s('rischio', 'Rischio');
    final descAssic = _s('descrizione_assicurato', 'DescrizioneAssicurato');

    // Numerazione
    final esercizio =
        _s('esercizio', 'Esercizio').isEmpty ? sinistro.esercizio.toString() : _s('esercizio', 'Esercizio');
    final numSinistro = _s('numero_sinistro', 'NumeroSinistro').isEmpty ? sinistro.numeroSinistro : _s('numero_sinistro', 'NumeroSinistro');
    final numSinComp = _s('numero_sinistro_compagnia', 'NumeroSinistroCompagnia');
    final statoComp = _s('stato_compagnia', 'StatoCompagnia');

    // Avvenimento
    final dataAvvRaw = viewRow['data_avvenimento'] ?? viewRow['DataAvvenimento'] ?? sinistro.dataAvvenimento;
    final citta = _s('città', 'citta').isEmpty ? (sinistro.citta ?? '') : _s('città', 'citta');
    final indirizzo = _s('indirizzo', 'Indirizzo').isEmpty ? (sinistro.indirizzo ?? '') : _s('indirizzo', 'Indirizzo');
    final cap = _s('cap', 'CAP').isEmpty ? (sinistro.cap ?? '') : _s('cap', 'CAP');
    final provincia = _s('provincia', 'Provincia').isEmpty ? (sinistro.provincia ?? '') : _s('provincia', 'Provincia');
    final codiceStato = _s('codice_stato', 'CodiceStato').isEmpty ? (sinistro.codiceStato ?? '') : _s('codice_stato', 'CodiceStato');
    final targa = _s('targa', 'Targa').isEmpty ? (sinistro.targa ?? '') : _s('targa', 'Targa');
    final dinamica = _s('dinamica', 'Dinamica').isEmpty ? (sinistro.dinamica ?? '') : _s('dinamica', 'Dinamica');

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),

          // Barra tab in stile "sotto la scheda"
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const TabBar(
              labelPadding: EdgeInsets.symmetric(horizontal: 16),
              isScrollable: true,
              indicatorColor: Color(0xFF0082C8),
              labelColor: Color(0xFF0A2B4E),
              unselectedLabelColor: Colors.black54,
              tabs: [
                Tab(text: 'Riepilogo'),
                Tab(text: 'Documenti'),
                Tab(text: 'Diario di Andamento'),
              ],
            ),
          ),

          // Contenuto tab
          Expanded(
            child: TabBarView(
              children: [
                // ─────────────── RIEPILOGO ───────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Polizza
                      const Text('Polizza', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Compagnia', compagnia),
                        _KV('Numero Contratto', numeroPolizza),
                        _KV('Rischio', rischio),
                        _KV('Descrizione Assicurato', descAssic),
                        _KV('Targa', targa),
                      ]),

                      // Numerazione
                      const SizedBox(height: 28),
                      const Text('Numerazione', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Esercizio', esercizio),
                        _KV('Numero Sinistro', numSinistro),
                        _KV('Num. Sin. Compagnia', numSinComp ?? ''),
                        _KV('Stato Sin. Compagnia', statoComp ?? ''),
                      ]),

                      // Avvenimento
                      const SizedBox(height: 28),
                      const Text('Avvenimento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _SectionGrid(rows: [
                        _KV('Data Avvenimento', _fmtScadenza(dataAvvRaw)),
                        _KV('Città Avvenimento', citta),
                        _KV('Indirizzo Avvenimento', indirizzo),
                        _KV('CAP Avvenimento', cap),
                        _KV('Provincia', provincia),
                        _KV('Codice Stato', codiceStato),
                        _KV('Dinamica del Sinistro', dinamica),
                      ]),
                    ],
                  ),
                ),

                // ─────────────── DOCUMENTI (placeholder) ───────────────
                _DocumentsPlaceholder(),

                // ─────────────── DIARIO (placeholder) ───────────────
                _DiaryPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Azioni header a destra – replica della striscia icone nello screenshot
class _HeaderActionIcons extends StatelessWidget {
  const _HeaderActionIcons();

  @override
  Widget build(BuildContext context) {
    Color active = Colors.grey.shade700;
    Color disabled = Colors.grey.shade400;

    Widget ico(IconData i, {bool enabled = true, String? tip}) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: tip ?? '',
            child: Icon(i, size: 18, color: enabled ? active : disabled),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ico(Icons.edit, tip: 'Modifica'),
        ico(Icons.sell, tip: 'Tag'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.chat_bubble, enabled: false, tip: 'Chat'),
        ico(Icons.chat_bubble_outline, enabled: false, tip: 'Note'),
        ico(Icons.print, enabled: false, tip: 'Stampa'),
      ],
    );
  }
}

/// Placeholder Documenti
class _DocumentsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 64),
              const SizedBox(height: 12),
              const Text('Documenti del sinistro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Nessun documento disponibile. Qui vedrai l’elenco dei documenti caricati (quietanze, foto, perizie, ecc.).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: null, // da agganciare al flusso upload
                icon: const Icon(Icons.upload_file),
                label: const Text('Carica documento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder Diario di Andamento
class _DiaryPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.note_alt),
            title: const Text('Diario di andamento'),
            subtitle: const Text(
              'Qui verranno mostrate le note cronologiche del sinistro (inserite dall’operatore o dalla compagnia).',
            ),
            trailing: TextButton.icon(
              onPressed: null, // da agganciare alla creazione nota
              icon: const Icon(Icons.add),
              label: const Text('Nuova nota'),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade50,
          ),
          child: const Text(
            'Nessuna nota presente.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}