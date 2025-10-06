// lib/apps/enac_app/ui_components/client_titles_page.dart
/* *****************************************************************
 *  ClientTitlesPage
 *  – dettaglio cliente + lista titoli (creazione con dialog)
 *  – onOpenTitle: apre il Summary nel contenuto della pagina (no Navigator)
 * *****************************************************************/
import 'package:boxed_ai/apps/enac_app/ui_components/titles/title_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

import '../../logic_components/backend_sdk.dart';
import 'titles_table.dart';
import 'create_title_dialog.dart';


class ClientTitlesPage extends StatefulWidget {
  final User user;        // username = userId
  final Token token;
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;

  /// Come per i contratti: il parent (HomeScaffold) decide cosa mostrare.
  final void Function(Titolo titolo, Map<String, dynamic> viewRow) onOpenTitle;

  const ClientTitlesPage({
    super.key,
    required this.user,
    required this.token,
    required this.userId,
    required this.clientId,
    required this.sdk,
    required this.onOpenTitle,
  });

  @override
  State<ClientTitlesPage> createState() => _ClientTitlesPageState();
}

class _ClientTitlesPageState extends State<ClientTitlesPage> {
  int _refresh = 0;

  Widget _sectionTitle(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  RichText _kv(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            const TextSpan(text: '', style: TextStyle(fontSize: 1)),
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ---------- intestazione cliente ---------- */
        FutureBuilder<Entity>(
          future: widget.sdk.getEntity(widget.userId, widget.clientId),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              final msg = (snap.error is ApiException &&
                      (snap.error as ApiException).statusCode == 404)
                  ? 'Il cliente non esiste più (404)'
                  : 'Errore: ${snap.error}';
              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(msg)),
                  ],
                ),
              );
            }

            final c = snap.data!;
            return Container(
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
                        /* tag + ragione sociale */
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
                            Text(c.name,
                                style: const TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF0082C8),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        /* griglia 3 colonne × 2 righe */
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
                                _kv('PARTITA IVA', c.vat ?? 'n.d.'),
                                _kv('COD. FISCALE', c.taxCode ?? 'n.d.'),
                                _kv('LEG. RAPP.', c.legalRep ?? 'n.d.'),
                                _kv('CF LEG. RAPP.', c.legalRepTaxCode ?? 'n.d.'),
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
          },
        ),
        const SizedBox(height: 24),

        /* ---------- titolo pagina ---------- */
        Row(
          children: [
            const Text('Titoli',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF00A651),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuovo titolo'),
              onPressed: () async {
                final created = await CreateTitleDialog.show(
                  context,
                  user: widget.user,
                  token: widget.token,
                  sdk: widget.sdk,
                  entityId: widget.clientId,
                );
                if (created == true && mounted) {
                  setState(() => _refresh++); // ricarica tabella
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _sectionTitle('Elenco'),

        /* ---------- tabella titoli ---------- */
        Expanded(
          child: TitlesTable(
            key: ValueKey(_refresh),
            userId: widget.userId,
            clientId: widget.clientId,
            sdk: widget.sdk,
            onOpenTitle: (ctx, viewRow) async {
              // Ricava eventuali id per recuperare il Titolo completo
              final titleId = (viewRow['title_id'] ?? viewRow['TitoloId'] ?? viewRow['id'] ?? viewRow['titleId'])?.toString();
              final contractId = (viewRow['contract_id'] ?? viewRow['contractId'])?.toString();

              Titolo? titolo;
              if (titleId != null && contractId != null) {
                try {
                  titolo = await widget.sdk.getTitle(
                    widget.userId,
                    widget.clientId,
                    contractId,
                    titleId,
                  );
                } catch (_) {
                  // fallback al sintetico
                }
              }

              titolo ??= TitleSummaryPanel.titleFromViewRow(viewRow);

              // NIENTE Navigator: delega al parent (HomeScaffold)
              widget.onOpenTitle(titolo!, viewRow);
            },
          ),
        ),
      ],
    );
  }
}
