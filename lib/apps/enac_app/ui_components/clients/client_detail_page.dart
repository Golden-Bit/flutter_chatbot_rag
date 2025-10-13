// lib/apps/enac_app/ui_components/client_detail_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../logic_components/backend_sdk.dart'; // Entity, Omnia8Sdk

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
      final colW = math.max(220.0, (c.maxWidth - 24) / 2);
      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [for (final kv in rows) SizedBox(width: colW, child: kv)],
      );
    });
  }
}

/* ────────────────────────────────────────────────────────────────
 *  Azioni header – ora con tasto Elimina
 * ────────────────────────────────────────────────────────────── */
class _HeaderActionIconsClient extends StatelessWidget {
  const _HeaderActionIconsClient({this.onEdit, this.onDelete});
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
        ico(Icons.edit, tip: 'Modifica', onTap: onEdit),
        ico(Icons.delete_outline, tip: 'Elimina', onTap: onDelete), // ⬅️ NEW
        ico(Icons.file_copy, tip: 'Duplica'),
        ico(Icons.mail, tip: 'Email'),
        ico(Icons.phone, tip: 'Chiama'),
        ico(Icons.cloud_upload, enabled: false, tip: 'Carica'),
      ],
    );
  }
}

/* ────────────────────────────────────────────────────────────────
 *  ClientDetailPage (SUMMARY) – con azione Elimina
 * ────────────────────────────────────────────────────────────── */
class ClientDetailPage extends StatefulWidget {
  final Entity client;
  final Omnia8Sdk sdk;
  final String userId;
  final String entityId;
  final VoidCallback? onEditRequested;
  final VoidCallback? onDeleted;

  const ClientDetailPage({
    super.key,
    required this.client,
    required this.sdk,
    required this.userId,
    required this.entityId,
    this.onEditRequested,
    this.onDeleted,
  });

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  // KV compatto per la card header
  RichText _kvMini(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: '$label\n', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            TextSpan(text: value.isEmpty ? 'n.d.' : value),
          ],
        ),
      );

  Future<void> _confirmAndDelete() async {
    // 1) Alert di conferma
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_outlined),
            SizedBox(width: 8),
            Text('Eliminare l’entità?'),
          ],
        ),
        content: Text(
          'Questa operazione rimuoverà definitivamente l’entità '
          '"${widget.client.name}". L’azione è irreversibile. Confermi?',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2) Chiamata SDK
    try {
      await widget.sdk.deleteEntity(widget.userId, widget.entityId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entità eliminata.')),
      );

      // 3) Notifica al parent per tornare alla vista precedente
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      // errore: mostro dialog di errore coerente
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('Errore eliminazione'),
          content: Text('Impossibile eliminare l’entità.\nDettagli: $e'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    }
  }

  /// Header: badge CLIENTE + nome + 3 colonne info + azioni in alto
  Widget _header(BuildContext context) {
    final c = widget.client;

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
                      child: const Text("ENTITA'", style: TextStyle(color: Colors.white, fontSize: 11)),
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

                // griglia compatta
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

          // azioni in alto a destra
          _HeaderActionIconsClient(
            onEdit: widget.onEditRequested,
            onDelete: _confirmAndDelete, // ⬅️ NEW
          ),
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
    final c = widget.client;

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
