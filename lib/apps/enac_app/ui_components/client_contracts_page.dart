/* *****************************************************************
 *  ClientContractsPage
 *  – dettaglio cliente + lista contratti + “Nuovo contratto”
 * *****************************************************************/
import 'package:flutter/material.dart';
import 'package:flutter_app/apps/enac_app/ui_components/create_contract_dialog.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../llogic_components/backend_sdk.dart';
import 'contracts_table.dart';

class ClientContractsPage extends StatefulWidget {
  final User user; // username = userId
  final Token token; 
  final String userId;
  final String clientId;
  final Omnia8Sdk sdk;
  final void Function(ContrattoOmnia8) onOpenContract;

  const ClientContractsPage({
    super.key,
    required this.user,
    required this.token,
    required this.userId,
    required this.clientId,
    required this.sdk,
    required this.onOpenContract,
  });

  @override
  State<ClientContractsPage> createState() => _ClientContractsPageState();
}


/* =================================================================
 *  STATE
 * =================================================================*/
class _ClientContractsPageState extends State<ClientContractsPage> {

  int _refresh = 0;
  /* ===============================================================
   *  DIALOG “NUOVO CONTRATTO” (copertura totale dei campi)
   * ===============================================================*/
/* ===============================================================
 *  DIALOG “NUOVO CONTRATTO” – copertura completa di tutti i campi
 * ===============================================================*/

/* ===============================================================
 *  Sezione (titoletti) helper
 * ===============================================================*/
Widget _sectionTitle(String t) => Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );

/* piccolo “chiave : valore” compatto */
RichText _kv(String label, String value) => RichText(
  text: TextSpan(
    style: const TextStyle(fontSize: 13, color: Colors.black87),
    children: [
      TextSpan(
        text: '$label\n',
        style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
      ),
      TextSpan(text: value),
    ],
  ),
);

/* colonna di campi, distanziati di 6 px */
Widget _infoColumn(List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (int i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(height: 6),
      children[i],
    ]
  ],
);

  /* ===============================================================
   *  BUILD
   * ===============================================================*/
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ---------- intestazione cliente ---------- */
        FutureBuilder(
          future: widget.sdk.getClient(widget.userId, widget.clientId),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snap.hasError) {
              // banner errore
              final msg =
                  (snap.error is ApiException &&
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
                  /* ── icona ── */
                  Container(
                    width: 90,
                    height: 90,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const Icon(Icons.person,
                        size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),

                  /* ── testo ── */
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF00A651),
                                  borderRadius: BorderRadius.circular(2)),
                              child: const Text('CLIENTE',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
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
                            /* colonna 1 */
                            Expanded(
                              child: _infoColumn([
                                _kv('INDIRIZZO', c.address ?? 'n.d.'),
                                _kv('TELEFONO',  c.phone   ?? 'n.d.'),
                              ]),
                            ),
                            const SizedBox(width: 12),

                            /* colonna 2 */
                            Expanded(
                              child: _infoColumn([
                                _kv('EMAIL',      c.email    ?? 'n.d.'),
                                _kv('SETTORE',    c.sector   ?? 'n.d.'),
                              ]),
                            ),
                            const SizedBox(width: 12),

                            /* colonna 3 */
                            Expanded(
                              child: _infoColumn([
                                _kv('PARTITA IVA',     c.vat     ?? 'n.d.'),
                                _kv('COD. FISCALE',    c.taxCode ?? 'n.d.'),
                                _kv('LEG. RAPP.',      c.legalRep ?? 'n.d.'),
                                _kv('CF LEG. RAPP.',   c.legalRepTaxCode ?? 'n.d.'),
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

        /* ---------- titolo + pulsante ---------- */
        Row(
          children: [
            const Text('Contratti',
                style:
                    TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF00A651), // blu come resto UI
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3)),
            ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuovo contratto'),
             onPressed: () async {
   final created = await CreateContractDialog.show(
     context,
     user     : widget.user,
     token    : widget.token,
     sdk      : widget.sdk,
     clientId : widget.clientId,
   );
   if (created == true && mounted) {
     setState(() => _refresh++);
   }
 },
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Elenco',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        /* ---------- tabella contratti ---------- */
        Expanded(
          child: ContractsTable(
                key      : ValueKey(_refresh),
            userId: widget.userId,
            clientId: widget.clientId,
            sdk: widget.sdk,
            onOpenContract: widget.onOpenContract,
          ),
        ),
      ],
    );
  }
}
