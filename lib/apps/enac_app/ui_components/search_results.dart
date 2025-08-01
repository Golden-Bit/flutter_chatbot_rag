import 'package:flutter/material.dart';
import 'package:flutter_app/apps/enac_app/ui_components/create_client_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_app/apps/enac_app/llogic_components/backend_sdk.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';

class _ClientSearchResult {
  final String id; // ← clientId vero
  final Client data; // ← oggetto Client già esistente
  _ClientSearchResult(this.id, this.data);
}

/// Pannello risultati di ricerca (solo entità CLIENTE)
class SearchResultsPanel extends StatefulWidget {
  final String query;
  final User user; // username = userId
  final Token token; 
  final Omnia8Sdk sdk;
  final void Function(String clientId)? onOpenClient;

  const SearchResultsPanel({
    super.key,
    required this.query,
    required this.user,
    required this.token,
    required this.sdk,
    this.onOpenClient,
  });

  @override
  State<SearchResultsPanel> createState() => _SearchResultsPanelState();
}

class _SearchResultsPanelState extends State<SearchResultsPanel> {
  late Future<List<Client>> _future;
  late List<String> _clientIds; // lista parallela di id

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// ricarica se l’utente cambia la query senza ricreare il widget
  @override
  void didUpdateWidget(covariant SearchResultsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      setState(() => _future = _load());
    }
  }

  /* ------------------------------------------------------------------
   *  CHIAMATE DI RETE
   * ----------------------------------------------------------------*/
  Future<List<Client>> _load() async {
    try {
      /* ------------------------------------------------------------------
     * 1. Scarica la lista degli id (solo metadati)
     * ----------------------------------------------------------------*/
      final items = await widget.sdk.listClients(widget.user.username);

      /* ------------------------------------------------------------------
     * 2. Per ogni id scarica il Client completo e tieni l’id vero
     * ----------------------------------------------------------------*/
      final clients = <Client>[];
      _clientIds = []; // ← reset

      for (final it in items) {
        final c = await widget.sdk.getClient(
          widget.user.username,
          it.clientId,
        );
        clients.add(c);
        _clientIds.add(it.clientId); // id autentico
      }

      /* ------------------------------------------------------------------
     * 3. Filtra sui nomi (query) mantenendo id e dati allineati
     * ----------------------------------------------------------------*/
      final q = widget.query.toLowerCase();
      final kept = <Client>[];
      final keptIds = <String>[];

      for (var i = 0; i < clients.length; i++) {
        if (clients[i].name.toLowerCase().contains(q)) {
          kept.add(clients[i]);
          keptIds.add(_clientIds[i]);
        }
      }

      /* ------------------------------------------------------------------
     * 4. Ordina per nome e riallinea la lista di id
     * ----------------------------------------------------------------*/
/* 4. Ordina tenendo allineato id ↔ cliente --------------------- */
final pairs = List.generate(
  kept.length,
  (i) => MapEntry(kept[i], keptIds[i]),          // (Client , id)
)..sort((a, b) => a.key.name.compareTo(b.key.name));

_clientIds = [for (final p in pairs) p.value];   // id nella posizione giusta
return       [for (final p in pairs) p.key];     // lista Client ordinata
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore di rete: $e')),
        );
      }
      _clientIds = []; // evita disallineamenti
      return [];
    }
  }

  /* ------------------------------------------------------------------
   *  UI — HEADER con pulsante “Nuovo cliente”
   * ----------------------------------------------------------------*/
  Widget _header(int total) => Row(
        children: [
          Text('Risultati ricerca ($total)',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
            label: const Text('Nuovo cliente',
                style: TextStyle(fontWeight: FontWeight.w500)),
             onPressed: () async {
   final created = await CreateClientDialog.show(
     context,
     user : widget.user,
     token: widget.token,
     sdk  : widget.sdk,
   );
   if (created == true && mounted) {
     setState(() => _future = _load());
   }
 },
          ),
        ],
      );

  /* ------------------------------------------------------------------
   *  Evidenziazione query nella stringa
   * ----------------------------------------------------------------*/
  InlineSpan _highlight(String src) {
    if (widget.query.isEmpty) return TextSpan(text: src);

    final q = widget.query;
    final reg = RegExp(RegExp.escape(q), caseSensitive: false);

    final spans = <TextSpan>[];
    int last = 0;

    for (final m in reg.allMatches(src)) {
      if (m.start > last) {
        spans.add(TextSpan(text: src.substring(last, m.start)));
      }
      spans.add(TextSpan(
          text: src.substring(m.start, m.end),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.blue)));
      last = m.end;
    }
    if (last < src.length) spans.add(TextSpan(text: src.substring(last)));
    return TextSpan(children: spans);
  }

  /* ------------------------------------------------------------------
   *  Card cliente
   * ----------------------------------------------------------------*/
  /* ------------------------------------------------------------------
 *  Card cliente (3 colonne × 2 righe)
 * ----------------------------------------------------------------*/
Widget _card(Client c, String id) => InkWell(
  onTap: () => widget.onOpenClient?.call(id), // id reale
  child: Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFE6F7E6),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* --- icona segnaposto --- */
        Container(
          width: 90,
          height: 90,
          color: Colors.white,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 40, color: Colors.grey),
        ),

        /* --- contenuto testuale --- */
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /* etichetta + ragione sociale */
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFF00A651),
                      borderRadius: BorderRadius.circular(2)),
                  child: const Text('CLIENTE',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: _highlight(c.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                /* griglia 3 × 2 */
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /* colonna 1 */
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('INDIRIZZO', c.address ?? 'n.d.'),
                          _info(
                            'TELEFONO / EMAIL',
                            (c.phone ?? 'n.d.') +
                                (c.email != null ? '  /  ${c.email}' : ''),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    /* colonna 2 */
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('IDENTIFICATIVO', 'Id. ${c.vat ?? '---'}'),
                          _info('COD. FISCALE', c.taxCode ?? 'n.d.'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    /* colonna 3 */
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _info('SETTORE / ATECO', c.sector ?? 'n.d.'),
                          _info('LEGALE RAPPRESENTANTE', c.legalRep ?? 'n.d.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);


  Widget _info(String label, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.openSans(fontSize: 13, color: Colors.black87),
            children: [
              TextSpan(
                  text: '$label\n',
                  style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              TextSpan(text: v),
            ],
          ),
        ),
      );

  /* ------------------------------------------------------------------
   *  BUILD
   * ----------------------------------------------------------------*/
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Client>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snap.data ?? [];
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(results.length),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF6CC),
                padding: const EdgeInsets.all(12),
                child: const Text(
                  'Alcune entità sono state escluse per limitare i risultati. '
                  'Se non hai trovato quello che cerchi, puoi provare ad affinare la ricerca',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Elenco',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text('Nessun risultato')),
              for (var i = 0; i < results.length; i++)
                _card(results[i], _clientIds[i]),
            ],
          ),
        );
      },
    );
  }
}
