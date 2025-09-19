// lib/apps/enac_app/ui_components/dialogs/create_client_dialog.dart
import 'package:flutter/material.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:boxed_ai/apps/enac_app/llogic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

/*═══════════════════════════════════════════════════════════════════════════
 *  DIALOG  “CREA CLIENTE” + DUAL‑PANE CON CHAT
 *═════════════════════════════════════════════════════════════════════════*/
class CreateClientDialog extends StatefulWidget {
  const CreateClientDialog({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
  });

  final User  user;
  final Token token;
  final Omnia8Sdk sdk;

  /// Helper per aprire la dialog e restituire `true`
  /// se la creazione è andata a buon fine.
  static Future<bool?> show(
    BuildContext context, {
    required User  user,
    required Token token,
    required Omnia8Sdk sdk,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CreateClientDialog(user: user, token: token, sdk: sdk),
    );
  }

  @override
  State<CreateClientDialog> createState() => _CreateClientDialogState();
}

/*───────────────────────────────────────────────────────────────────────────*/
class _CreateClientDialogState extends State<CreateClientDialog> {
  /*──────── form & dati ───────*/
  final _formKey = GlobalKey<FormState>();
  final _data = <String, String?>{
    'name'              : null,
    'address'           : null,
    'tax_code'          : null,
    'vat'               : null,
    'phone'             : null,
    'email'             : null,
    'sector'            : null,
    'legal_rep'         : null,
    'legal_rep_tax_code': null,
  };

  /*──────── dual‑pane ─────────*/
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;           // stato locale del toggle

  @override
  void initState() {
    super.initState();
    // Chat pre‑caricata ma nascosta
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  /*──────── helper input ───────*/
  TextFormField _field(
    String label,
    FormFieldSetter<String?> onSaved, {
    FormFieldValidator<String>? validator,
  }) =>
      TextFormField(
        decoration: InputDecoration(
          labelText : label,
          isDense   : true,
          border    : const OutlineInputBorder(),
        ),
        onSaved   : onSaved,
        validator : validator,
      );

  /*──────── dialog ─────────────*/
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
      title: Row(
        children: [
          Text('Crea nuovo cliente',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip : _chatOpen ? 'Chiudi chat' : 'Apri chat',
            icon    : Icon(_chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () {
              setState(() {
                _chatOpen = !_chatOpen;
                _chatOpen ? _paneCtrl.openChat()
                          : _paneCtrl.closeChat();
              });
            },
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,       // gestito dal DualPane
      content: SizedBox(
        width : 860,                          // larghezza complessiva dialog
        height: 520,                          // altezza fissa per scroll interno
        child: DualPaneWrapper(
          controller : _paneCtrl,
          user       : widget.user,
          token      : widget.token,
          // KEY opzionale se vuoi accedere al chatbot
          leftChild  : _buildForm(),          // definito sotto
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _onCreatePressed,
          child: const Text('Crea'),
        ),
      ],
    );
  }

  /*──────── form “sinistro” ────*/
  Widget _buildForm() => Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _field('Ragione sociale *', (v) => _data['name'] = v,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Obbligatorio' : null),
                const SizedBox(height: 12),
                _field('Indirizzo', (v) => _data['address'] = v),
                const SizedBox(height: 12),
                _field('Telefono', (v) => _data['phone'] = v),
                const SizedBox(height: 12),
                _field('Email', (v) => _data['email'] = v,
                    validator: (v) =>
                        (v != null && v.isNotEmpty && !v.contains('@'))
                            ? 'Email non valida'
                            : null),
                const SizedBox(height: 12),
                _field('Partita IVA', (v) => _data['vat'] = v),
                const SizedBox(height: 12),
                _field('Codice fiscale', (v) => _data['tax_code'] = v),
                const SizedBox(height: 12),
                _field('Settore / ATECO', (v) => _data['sector'] = v),
                const SizedBox(height: 12),
                _field('Legale rappresentante', (v) => _data['legal_rep'] = v),
                const SizedBox(height: 12),
                _field('CF legale rappresentante',
                    (v) => _data['legal_rep_tax_code'] = v),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );

  /*──────── salvataggio ────────*/
  Future<void> _onCreatePressed() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final client = Client(
      name            : _data['name']?.trim() ?? '',
      address         : _data['address'],
      taxCode         : _data['tax_code'],
      vat             : _data['vat'],
      phone           : _data['phone'],
      email           : _data['email'],
      sector          : _data['sector'],
      legalRep        : _data['legal_rep'],
      legalRepTaxCode : _data['legal_rep_tax_code'],
    );

    final clientId =
        const Uuid().v4().replaceAll('-', '').substring(0, 12);

    try {
      await widget.sdk.createClient(widget.user.username, clientId, client);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione cliente: $e')),
      );
    }
  }
}
