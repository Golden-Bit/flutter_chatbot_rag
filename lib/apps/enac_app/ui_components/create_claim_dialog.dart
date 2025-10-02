/* ──────────────────────────────────────────────────────────────────────────
 *  DIALOG “DENUNCIA SINISTRO” — versione Dual-Pane (form + ChatBot)
 *  ▸ Colonna sinistra: form completo del sinistro
 *  ▸ Colonna destra  : ChatBot (pre-caricato, di default nascosto)
 *  ▸ Selettore contratto OBBLIGATORIO e DENTRO IL FORM (primo campo)
 *  ▸ Il selettore contratto NON è autocompilabile dai Tool
 * ────────────────────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:boxed_ai/dual_pane_wrapper.dart';

import '../logic_components/backend_sdk.dart';
import 'claim_form_widget.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

class CreateClaimDialog extends StatefulWidget {
  const CreateClaimDialog({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.entityId,
  });

  final User user;   // username = userId
  final Token token; // auth token
  final Omnia8Sdk sdk;
  final String entityId; // id cliente

  static Future<bool?> show(
    BuildContext context, {
    required User user,
    required Token token,
    required Omnia8Sdk sdk,
    required String entityId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateClaimDialog(
        user: user,
        token: token,
        sdk: sdk,
        entityId: entityId,
      ),
    );
  }

  @override
  State<CreateClaimDialog> createState() => _CreateClaimDialogState();
}

class _CreateClaimDialogState extends State<CreateClaimDialog> {
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;

  final _claimPaneKey = GlobalKey<ClaimFormPaneState>();

  /*─────────────────────────────────────────────────────────
   *  Helpers parsing & normalizzazione
   *────────────────────────────────────────────────────────*/
  final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  DateTime? _parseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    try {
      return _fmt.parseStrict(t);
    } catch (_) {
      return null;
    }
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  /*─────────────────────────────────────────────────────────
   *  Salvataggio
   *────────────────────────────────────────────────────────*/
  Future<void> _onCreatePressed() async {
    final pane = _claimPaneKey.currentState;
    if (pane == null) return;

    final selectedContractId = pane.selectedContractId;
    if (selectedContractId == null || selectedContractId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un contratto.')),
      );
      return;
    }

    final m = pane.model; // Map<String,String>
    final requiredFields = {
      'esercizio': m['esercizio'] ?? '',
      'numero_sinistro': m['numero_sinistro'] ?? '',
      'data_avvenimento': m['data_avvenimento'] ?? '',
    };
    final missing = requiredFields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Compila i campi obbligatori: ${missing.join(', ')}')),
      );
      return;
    }

    final esercizio = _parseInt(m['esercizio'] ?? '');
    final dataAvv = _parseDate(m['data_avvenimento'] ?? '');
    final dataApertura = _parseDate(m['data_apertura'] ?? '');
    final dataChiusura = _parseDate(m['data_chiusura'] ?? '');

    if (esercizio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esercizio non valido. Usa cifre intere.')),
      );
      return;
    }
    if (dataAvv == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Data avvenimento non valida. Usa il formato gg/mm/aaaa.')));
      return;
    }

    String? nn(String k) {
      final v = (m[k] ?? '').trim();
      return v.isEmpty ? null : v;
    }

    try {
      final sinistro = Sinistro(
        esercizio: esercizio,
        numeroSinistro: (m['numero_sinistro'] ?? '').trim(),
        numeroSinistroCompagnia: nn('numero_sinistro_compagnia'),
        numeroPolizza: nn('numero_polizza'),
        compagnia: nn('compagnia'),
        rischio: nn('rischio'),
        intermediario: nn('intermediario'),
        descrizioneAssicurato: nn('descrizione_assicurato'),
        dataAvvenimento: dataAvv,
        citta: nn('citta'),
        indirizzo: nn('indirizzo'),
        cap: nn('cap'),
        provincia: nn('provincia'),
        codiceStato: nn('codice_stato'),
        targa: nn('targa'),
        dinamica: nn('dinamica'),
        statoCompagnia: nn('stato_compagnia'),
        dataApertura: dataApertura,
        dataChiusura: dataChiusura,
      );

      final userId = widget.user.username;
      final resp = await widget.sdk.createClaim(
        userId,
        widget.entityId,
        selectedContractId, // ← scelto dall’utente nel form
        sinistro,
      );
      debugPrint('[CreateClaimDialog] creato claimId=${resp.claimId}');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione sinistro: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // chat pre-caricata ma chiusa
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          Text('Denuncia sinistro',
              style:
                  GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip: _chatOpen ? 'Chiudi chat' : 'Apri chat',
            icon: Icon(
                _chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () {
              setState(() {
                _chatOpen ? _paneCtrl.closeChat() : _paneCtrl.openChat();
                _chatOpen = !_chatOpen;
              });
            },
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 1000,
        height: 640,
        child: DualPaneWrapper(
          controller: _paneCtrl,
          user: widget.user,
          token: widget.token,
          // ⬇️ Il form contiene il selettore contratto come PRIMO campo
          leftChild: ClaimFormPane(
            key: _claimPaneKey,
            user: widget.user,
            token: widget.token,
            sdk: widget.sdk,
            entityId: widget.entityId,
          ),
          autoStartMessage:
              "Da ora in poi dovrai aiutarmi con la compilazione della DENUNCIA SINISTRO usando l'apposito Tool UI; rispondi solo 'OK' a questo messaggio iniziale.",
          autoStartInvisible: false,
          openChatOnMount: false,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla')),
        TextButton(onPressed: _onCreatePressed, child: const Text('Crea')),
      ],
    );
  }
}
