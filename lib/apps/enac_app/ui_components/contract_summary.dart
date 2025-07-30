// lib/apps/enac_app/ui_components/contract_detail_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../llogic_components/backend_sdk.dart';

/* ════════════════════════════════════════════════════════════════
   UTILITÀ
   ══════════════════════════════════════════════════════════════ */
final _df = DateFormat('dd/MM/yyyy');
final _cf = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String _d(DateTime? dt) => dt == null ? '' : _df.format(dt);

class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: const TextStyle(
                fontSize: 11, color: Colors.blueGrey, height: 1.3)),
        const SizedBox(height: 2),
        Container(
         width: double.infinity,          // ⬅️ occupa l’intera cella
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(v.isEmpty ? '—' : v,
              style: const TextStyle(fontSize: 14)),
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
      final colW = math.max(100.0, (c.maxWidth - 24) / 2); // larghezza ≥100
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (final kv in rows) SizedBox(width: colW, child: kv),
        ],
      );
    });
  }
}

/* ════════════════════════════════════════════════════════════════
   P A G I N A   D E T T A G L I O
   ══════════════════════════════════════════════════════════════ */
class ContractDetailPage extends StatelessWidget {
  const ContractDetailPage({super.key, required this.contratto});
  final ContrattoOmnia8 contratto;

  /* ────────────────────── header ─────────────────────────────── */
  Widget _header(BuildContext ctx) {
    final id = contratto.identificativi;

    RichText pair(String l, String v) => RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            children: [
              TextSpan(
                  text: '$l ',
                  style: const TextStyle(color: Colors.blueGrey)),
              TextSpan(text: v),
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
          /* logo/placeholder */
          Container(
            width: 56,
            height: 56,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported,
                size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          /* testo */
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF00A651),
                        borderRadius: BorderRadius.circular(2)),
                    child: const Text('CONTRATTO',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  Text('${id.compagnia} – ${id.numeroPolizza}',
                      style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFF0082C8),
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                pair('RAMO', id.ramo),
                pair('RISCHIO', id.tipo),
                pair('PRODOTTO', contratto.ramiEl.descrizione),
                pair('INTERMEDIARIO',
                    contratto.unitaVendita.intermediario),
              ],
            ),
          ),

          /* premio + icone */
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('PREMIO ANNUO',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              Text(_cf.format(contratto.premi.premio),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final ic in [
                    Icons.edit,
                    Icons.file_copy,
                    Icons.mail_outline,
                    Icons.phone_in_talk,
                    Icons.cloud_upload
                  ])
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(ic, size: 18),
                      onPressed: () {},
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ────────────────────── sezione helper ─────────────────────── */
  Widget _section(String t, List<_KV> rows) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _SectionGrid(rows: rows),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final id = contratto.identificativi;
    final uv = contratto.unitaVendita;
    final amm = contratto.amministrativi;
    final prem = contratto.premi;
    final rinn = contratto.rinnovo;
    final op = contratto.operativita;
    final pr = op.parametriRegolazione;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),

            /* ── Identificativi ── */
            _section('Identificativi', [
              _KV('Tipo', id.tipo),
              _KV('TpCar', id.tpCar ?? ''),
              _KV('Ramo', id.ramo),
              _KV('Compagnia', id.compagnia),
              _KV('Numero Polizza', id.numeroPolizza),
            ]),

            /* ── Unità vendita ── */
            _section('Unità Vendita', [
              _KV('Punto Vendita', uv.puntoVendita),
              _KV('Punto Vendita 2', uv.puntoVendita2),
              _KV('Account', uv.account),
              _KV('Intermediario', uv.intermediario),
            ]),

            /* ── Amministrativi ── */
            _section('Amministrativi', [
              _KV('Effetto', _d(amm.effetto)),
              _KV('Scadenza', _d(amm.scadenza)),
              _KV('Data Emissione', _d(amm.dataEmissione)),
              _KV('Ultima Rata Pagata', _d(amm.ultimaRataPagata)),
              _KV('Scadenza Originaria', _d(amm.scadenzaOriginaria)),
              _KV('Scadenza Mora', _d(amm.scadenzaMora)),
              _KV('Scadenza Vincolo', _d(amm.scadenzaVincolo)),
              _KV('Scadenza Copertura', _d(amm.scadenzaCopertura)),
              _KV('Fine Copertura Proroga', _d(amm.fineCoperturaProroga)),
              _KV('Numero Proposta', amm.numeroProposta ?? ''),
              _KV('Codice Convenzione', amm.codConvenzione ?? ''),
              _KV('Frazionamento', amm.frazionamento),
              _KV('Modalità Incasso', amm.modalitaIncasso),
              _KV('Compreso Firma', amm.compresoFirma ? 'Sì' : 'No'),
            ]),

            /* ── Premi ── */
            _section('Premi', [
              _KV('Premio', _cf.format(prem.premio)),
              _KV('Netto', _cf.format(prem.netto)),
              _KV('Accessori', _cf.format(prem.accessori)),
              _KV('Diritti', _cf.format(prem.diritti)),
              _KV('Imposte', _cf.format(prem.imposte)),
              _KV('Spese', _cf.format(prem.spese)),
              _KV('Fondo', _cf.format(prem.fondo)),
              _KV('Sconto',
                  prem.sconto == null ? '—' : _cf.format(prem.sconto)),
            ]),

            /* ── Rinnovo ── */
            _section('Rinnovo', [
              _KV('Rinnovo', rinn.rinnovo),
              _KV('Disdetta', rinn.disdetta),
              _KV('Giorni Mora', rinn.giorniMora),
              _KV('Proroga', rinn.proroga),
            ]),

            /* ── Operatività / Regolazione ── */
            _section('Operatività', [
              _KV('Regolazione', op.regolazione ? 'Sì' : 'No'),
              _KV('Inizio', _d(pr.inizio)),
              _KV('Fine', _d(pr.fine)),
              _KV('Ultima Reg. Emessa', _d(pr.ultimaRegEmessa)),
              _KV('Giorni Invio Dati',
                  pr.giorniInvioDati?.toString() ?? ''),
              _KV('Giorni Pagamento Reg.',
                  pr.giorniPagReg?.toString() ?? ''),
              _KV('Giorni Mora Regolazione',
                  pr.giorniMoraRegolazione?.toString() ?? ''),
              _KV('Cadenza Regolazione', pr.cadenzaRegolazione),
            ]),
          ],
        ),
      ),
    );
  }
}
