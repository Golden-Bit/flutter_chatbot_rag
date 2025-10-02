// lib/apps/enac_app/ui_components/contract_detail_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic_components/backend_sdk.dart';

/// ═══════════════════════════════════════════════════════════════
/// Utilità formattazione
/// ═══════════════════════════════════════════════════════════════
final _dateFmt = DateFormat('dd/MM/yyyy');
final _currencyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String _fmtDate(DateTime? dt) => (dt == null) ? '—' : _dateFmt.format(dt);

/// Parser denaro robusto per stringhe tipo "1234.56" o "1234,56".
/// Non elimina più i '.' indiscriminatamente (bug che portava a x100).
double? _parseMoney(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s0 = v.toString().trim();
  if (s0.isEmpty) return null;

  // Caso 1: contiene sia ',' che '.'
  if (s0.contains(',') && s0.contains('.')) {
    final lastDot = s0.lastIndexOf('.');
    final lastComma = s0.lastIndexOf(',');
    if (lastDot > lastComma) {
      // '.' è decimale, rimuovi le virgole di migliaia
      final norm = s0.replaceAll(',', '');
      return double.tryParse(norm);
    } else {
      // ',' è decimale, rimuovi i punti di migliaia e usa '.' come decimale
      final norm = s0.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(norm);
    }
  }

  // Caso 2: solo ','
  if (s0.contains(',') && !s0.contains('.')) {
    return double.tryParse(s0.replaceAll(',', '.'));
  }

  // Caso 3: solo '.' o nessun separatore -> tenta parse diretto
  return double.tryParse(s0);
}

String _fmtMoney(dynamic v) {
  final parsed = _parseMoney(v);
  if (parsed == null) return '—';
  return _currencyFmt.format(parsed);
}

String _yesNo(bool? b) => b == null ? '—' : (b ? 'Sì' : 'No');

/// ═══════════════════════════════════════════════════════════════
/// Widgets base (cella chiave/valore + griglia sezioni)
/// ═══════════════════════════════════════════════════════════════
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
      final colW = math.max(180.0, (c.maxWidth - 24) / 2); // 2 colonne responsive
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Azioni header (icone a destra) – stile coerente con ClaimSummary
/// ═══════════════════════════════════════════════════════════════
class _HeaderActionIconsContract extends StatelessWidget {
  const _HeaderActionIconsContract();

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
        ico(Icons.file_copy, tip: 'Duplica'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.cloud_upload, enabled: false, tip: 'Carica'),
      ],
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Placeholder Documenti – identico allo stile dei Documenti sinistro
/// ═══════════════════════════════════════════════════════════════
class _DocumentsPlaceholder extends StatelessWidget {
  final String title;
  const _DocumentsPlaceholder({this.title = 'Documenti del contratto'});

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
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Nessun documento disponibile. Qui vedrai l’elenco dei documenti caricati (polizza, appendici, quietanze, ecc.).',
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

/// ═══════════════════════════════════════════════════════════════
/// Pagina Dettaglio Contratto con TAB sotto scheda (Riepilogo/Documenti)
/// ═══════════════════════════════════════════════════════════════
class ContractDetailPage extends StatelessWidget {
  const ContractDetailPage({super.key, required this.contratto});
  final ContrattoOmnia8 contratto;

  /// Header sintetico con badge, titolo, info e azioni
  Widget _header(BuildContext ctx) {
    final id = contratto.identificativi;

    RichText pair(String l, String v) => RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            children: [
              TextSpan(text: '$l ', style: const TextStyle(color: Colors.blueGrey)),
              TextSpan(text: v.isEmpty ? '—' : v),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7E6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // logo/placeholder
          Container(
            width: 56,
            height: 56,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          // testo a sinistra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A651),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('CONTRATTO',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Text('${id.compagnia} – ${id.numeroPolizza}',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0082C8),
                        fontWeight: FontWeight.w600,
                      )),
                ]),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 18,
                  runSpacing: 2,
                  children: [
                    pair('RAMO', id.ramo),
                    pair('RISCHIO', id.tipo),
                    pair('PRODOTTO', contratto.ramiEl?.descrizione ?? '—'),
                    pair('INTERMEDIARIO', contratto.unitaVendita?.intermediario ?? '—'),
                  ],
                ),
              ],
            ),
          ),

          // premio + azioni
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('PREMIO ANNUO',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              Text(_fmtMoney(contratto.premi?.premio),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const _HeaderActionIconsContract(),
            ],
          ),
        ],
      ),
    );
  }

  /// Sezione helper
  Widget _section(String t, List<_KV> rows) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _SectionGrid(rows: rows),
          ],
        ),
      );

  /// Contenuto del tab RIEPILOGO (quello “attuale” esistente)
  Widget _buildRiepilogo() {
    final id   = contratto.identificativi;
    final uv   = contratto.unitaVendita;          // opzionale
    final amm  = contratto.amministrativi;        // opzionale
    final prem = contratto.premi;                 // opzionale
    final rinn = contratto.rinnovo;               // opzionale
    final op   = contratto.operativita;           // opzionale
    final pr   = op?.parametriRegolazione;        // opzionale
    final ram  = contratto.ramiEl;                // opzionale

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* ─────────── Identificativi ─────────── */
          _section('Identificativi', [
            _KV('Tipo', id.tipo),
            _KV('TpCar', id.tpCar ?? ''),
            _KV('Ramo', id.ramo),
            _KV('Compagnia', id.compagnia),
            _KV('Numero Polizza', id.numeroPolizza),
          ]),

          /* ─────────── Rischio / Prodotto (RamiEl) ─────────── */
          _section('Rischio / Prodotto', [
            _KV('Descrizione', ram?.descrizione ?? ''),
          ]),

          /* ─────────── Unità Vendita ─────────── */
          _section('Unità Vendita', [
            _KV('Punto Vendita', uv?.puntoVendita ?? ''),
            _KV('Punto Vendita 2', uv?.puntoVendita2 ?? ''),
            _KV('Account', uv?.account ?? ''),
            _KV('Intermediario', uv?.intermediario ?? ''),
          ]),

          /* ─────────── Amministrativi (completo) ─────────── */
          _section('Amministrativi', [
            _KV('Effetto', _fmtDate(amm?.effetto)),
            _KV('Scadenza', _fmtDate(amm?.scadenza)),
            _KV('Data Emissione', _fmtDate(amm?.dataEmissione)),
            _KV('Ultima Rata Pagata', _fmtDate(amm?.ultimaRataPagata)),
            _KV('Scadenza Originaria', _fmtDate(amm?.scadenzaOriginaria)),
            _KV('Scadenza Mora', _fmtDate(amm?.scadenzaMora)),
            _KV('Scadenza Vincolo', _fmtDate(amm?.scadenzaVincolo)),
            _KV('Scadenza Copertura', _fmtDate(amm?.scadenzaCopertura)),
            _KV('Fine Copertura Proroga', _fmtDate(amm?.fineCoperturaProroga)),
            _KV('Numero Proposta', amm?.numeroProposta ?? ''),
            _KV('Codice Convenzione', amm?.codConvenzione ?? ''),
            _KV('Frazionamento', amm?.frazionamento ?? ''),
            _KV('Modalità Incasso', amm?.modalitaIncasso ?? ''),
            _KV('Compreso Firma', _yesNo(amm?.compresoFirma)),
          ]),

          /* ─────────── Premi (completo) ─────────── */
          _section('Premi', [
            _KV('Premio', _fmtMoney(prem?.premio)),
            _KV('Netto', _fmtMoney(prem?.netto)),
            _KV('Accessori', _fmtMoney(prem?.accessori)),
            _KV('Diritti', _fmtMoney(prem?.diritti)),
            _KV('Imposte', _fmtMoney(prem?.imposte)),
            _KV('Spese', _fmtMoney(prem?.spese)),
            _KV('Fondo', _fmtMoney(prem?.fondo)),
            _KV('Sconto', prem?.sconto == null ? '—' : _fmtMoney(prem?.sconto)),
          ]),

          /* ─────────── Rinnovo (completo) ─────────── */
          _section('Rinnovo', [
            _KV('Rinnovo', rinn?.rinnovo ?? ''),
            _KV('Disdetta', rinn?.disdetta ?? ''),
            _KV('Giorni Mora', rinn?.giorniMora ?? ''),
            _KV('Proroga', rinn?.proroga ?? ''),
          ]),

          /* ─────────── Operatività / Regolazione ─────────── */
          _section('Operatività', [
            _KV('Regolazione', _yesNo(op?.regolazione)),
            _KV('Inizio', _fmtDate(pr?.inizio)),
            _KV('Fine', _fmtDate(pr?.fine)),
            _KV('Ultima Reg. Emessa', _fmtDate(pr?.ultimaRegEmessa)),
            _KV('Giorni Invio Dati', pr?.giorniInvioDati?.toString() ?? ''),
            _KV('Giorni Pagamento Reg.', pr?.giorniPagReg?.toString() ?? ''),
            _KV('Giorni Mora Regolazione', pr?.giorniMoraRegolazione?.toString() ?? ''),
            _KV('Cadenza Regolazione', pr?.cadenzaRegolazione ?? ''),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header “scheda”
            _header(context),

            // Barra tab sotto scheda
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
                ],
              ),
            ),

            // Contenuto tab
            Expanded(
              child: TabBarView(
                children: [
                  _buildRiepilogo(),
                  const _DocumentsPlaceholder(title: 'Documenti del contratto'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
