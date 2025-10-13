// lib/apps/enac_app/ui_components/client_detail_page.dart
// ═══════════════════════════════════════════════════════════════
// ClientDetailPage (SUMMARY) – Header con azioni in alto a destra
// + Riepilogo dati (niente Tab)
// ═══════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../logic_components/backend_sdk.dart'; // Entity

/* ────────────────────────────────────────────────────────────────
 *  Widgets base (KV + griglia) – coerenti con altri summary
 * ────────────────────────────────────────────────────────────── */
class _KV extends StatelessWidget {
  const _KV(this.k, this.v, {super.key});
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.3)),
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

/* ────────────────────────────────────────────────────────────────
 *  Azioni header (stile coerente con contratti/sinistri)
 * ────────────────────────────────────────────────────────────── */
class _HeaderActionIconsClient extends StatelessWidget {
  const _HeaderActionIconsClient({this.onEdit});
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final active = Colors.grey.shade700;
    final disabled = Colors.grey.shade400;

    Widget ico(IconData i, {bool enabled = true, String? tip, VoidCallback? onTap}) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: tip ?? '',
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Icon(i, size: 18, color: enabled ? active : disabled),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ico(Icons.edit, tip: 'Modifica', onTap: onEdit), // ⬅️ CLICK!
        ico(Icons.file_copy, tip: 'Duplica'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.cloud_upload, enabled: false, tip: 'Carica'),
      ],
    );
  }
}

/* ────────────────────────────────────────────────────────────────
 *  ClientDetailPage (solo SUMMARY, senza Tab)
 * ────────────────────────────────────────────────────────────── */
class ClientDetailPage extends StatelessWidget {
  final Entity client;
  final VoidCallback? onEditRequested;
  const ClientDetailPage({super.key, required this.client, this.onEditRequested});

  // KV compatto per la card header
  RichText _kvMini(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            TextSpan(text: value.isEmpty ? 'n.d.' : value),
          ],
        ),
      );

  /// Header: badge CLIENTE + nome + 3 colonne info
  /// Pulsanti **in alto a destra** (come richiesto).
  Widget _header(BuildContext context) {
    final c = client;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7E6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // icona/silhouette
          Container(
            width: 90,
            height: 90,
            color: Colors.white,
            alignment: Alignment.center,
            child: const Icon(Icons.person, size: 40, color: Colors.grey),
          ),
          const SizedBox(width: 12),

          // contenuto testuale
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // badge + ragione sociale
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A651),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text("ENTITA'",
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF0082C8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // griglia 3x? compatta nella card
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvMini('INDIRIZZO', c.address ?? 'n.d.'),
                          const SizedBox(height: 6),
                          _kvMini('TELEFONO', c.phone ?? 'n.d.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvMini('EMAIL', c.email ?? 'n.d.'),
                          const SizedBox(height: 6),
                          _kvMini('SETTORE', c.sector ?? 'n.d.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvMini('PARTITA IVA', c.vat ?? 'n.d.'),
                          const SizedBox(height: 6),
                          _kvMini('COD. FISCALE', c.taxCode ?? 'n.d.'),
                          const SizedBox(height: 6),
                          _kvMini('LEG. RAPP.', c.legalRep ?? 'n.d.'),
                          const SizedBox(height: 6),
                          _kvMini('CF LEG. RAPP.', c.legalRepTaxCode ?? 'n.d.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // colonna destra con azioni IN ALTO
          _HeaderActionIconsClient(onEdit: onEditRequested),
        ],
      ),
    );
  }

  Widget _section(String title, List<_KV> rows) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _SectionGrid(rows: rows),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = client;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),

        // RIEPILOGO (no tab)
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Anagrafica', [
                _KV('Ragione Sociale', c.name),
                _KV('Indirizzo', c.address ?? ''),
                _KV('Settore / ATECO', c.sector ?? ''),
              ]),
              _section('Contatti', [
                _KV('Telefono', c.phone ?? ''),
                _KV('Email', c.email ?? ''),
              ]),
              _section('Dati Fiscali', [
                _KV('Partita IVA', c.vat ?? ''),
                _KV('Codice Fiscale', c.taxCode ?? ''),
              ]),
              _section('Rappresentanza', [
                _KV('Legale Rappresentante', c.legalRep ?? ''),
                _KV('CF Legale Rappresentante', c.legalRepTaxCode ?? ''),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
