import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/clients/client_form_widget.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';

class CreateOrEditClientPage extends StatefulWidget {
  const CreateOrEditClientPage({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.onCancel,
    required this.onSaved, // callback dopo salvataggio (create/update)
    this.entityId,         // null => create, valorizzato => edit
    this.initialEntity,    // dati pre-esistenti in edit
    this.headerTitle,      // opz., default automatico
  });

  final User user;
  final Token token;
  final Omnia8Sdk sdk;

  final VoidCallback onCancel;
  final FutureOr<void> Function(String entityId) onSaved;

  final String? entityId;
  final Entity? initialEntity;
  final String? headerTitle;

  bool get isEdit => entityId != null;

  @override
  State<CreateOrEditClientPage> createState() => _CreateOrEditClientPageState();
}

class _CreateOrEditClientPageState extends State<CreateOrEditClientPage> {
  final DualPaneController _paneCtrl = DualPaneController();
  final _clientPaneKey = GlobalKey<ClientFormPaneState>();
  bool _saving = false;

  static const _kBrandGreen = Color(0xFF00A651);

  ButtonStyle get _cancelStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade800,
        side: BorderSide(color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );

  ButtonStyle get _saveStyle => ElevatedButton.styleFrom(
        backgroundColor: _kBrandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  @override
  void initState() {
    super.initState();
    // Chat pre-caricata ma chiusa; la apri/chiudi dalla AppBar globale.
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());

    // Prefill in EDIT (digitazione istantanea)
    if (widget.initialEntity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final s = _clientPaneKey.currentState;
        if (s == null) return;
        final e = widget.initialEntity!;
        final m = <String, dynamic>{
          'name'              : e.name,
          if (e.address != null)            'address'           : e.address,
          if (e.taxCode != null)            'tax_code'          : e.taxCode,
          if (e.vat != null)                'vat'               : e.vat,
          if (e.phone != null)              'phone'             : e.phone,
          if (e.email != null)              'email'             : e.email,
          if (e.sector != null)             'sector'            : e.sector,
          if (e.legalRep != null)           'legal_rep'         : e.legalRep,
          if (e.legalRepTaxCode != null)    'legal_rep_tax_code': e.legalRepTaxCode,
        };
        await s.fill(m, typingMs: 0); // niente animazione in prefill
      });
    }
  }

  Future<void> _onSavePressed() async {
    final pane = _clientPaneKey.currentState;
    if (pane == null) return;

    final m = pane.model; // Map<String, String>
    String? nn(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

    if ((m['name'] ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la ragione sociale')),
      );
      return;
    }
    if ((m['email'] ?? '').isNotEmpty && !m['email']!.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email non valida')),
      );
      return;
    }

    final client = Entity(
      name            : (m['name'] ?? '').trim(),
      address         : nn(m['address']),
      taxCode         : nn(m['tax_code']),
      vat             : nn(m['vat']),
      phone           : nn(m['phone']),
      email           : nn(m['email']),
      sector          : nn(m['sector']),
      legalRep        : nn(m['legal_rep']),
      legalRepTaxCode : nn(m['legal_rep_tax_code']),
    );

    setState(() => _saving = true);
    try {
      final userId = widget.user.username;
      late final String id;
      if (widget.isEdit) {
        id = widget.entityId!;
        await widget.sdk.updateEntity(userId, id, client);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente aggiornato')),
          );
        }
      } else {
        id = const Uuid().v4().replaceAll('-', '').substring(0, 12);
        await widget.sdk.createEntity(userId, id, client);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente creato')),
          );
        }
      }
      await widget.onSaved(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.headerTitle ??
        (widget.isEdit ? 'Modifica cliente' : 'Crea nuovo cliente');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER INLINE (senza icona chat: c’è già in AppBar)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _saving ? null : widget.onCancel,
                style: _cancelStyle,
                child: const Text('Annulla'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _onSavePressed,
                style: _saveStyle,
                child: Text(widget.isEdit ? 'Salva' : 'Crea'),
              ),
            ],
          ),
        ),

        // CONTENUTO INLINE a piena altezza
        // Expanded evita l'altezza fissa 520 e riempie tutto lo spazio disponibile.
        Expanded(
          child: DualPaneWrapper(
            controller       : _paneCtrl,
            user             : widget.user,
            token            : widget.token,

            // ⬇️ Form centrato, larghezza max 600 px
            leftChild: ClientFormPane(key: _clientPaneKey),

            // Se il tuo DualPaneWrapper supporta la larghezza massima della chat,
            // puoi aggiungere (lasciato commentato per non rompere la build):
            // chatMaxWidth: 400,

            autoStartMessage  : "Da ora in poi dovrai aiutarmi con la compilazione di form utilizzando l'apposito Tool UI fornito, non appena te lo chiederò. rispondi solo affermativamente a tale messaggio, grazie !",
            autoStartInvisible: false,
            openChatOnMount   : false,
          ),
        ),
      ],
    );
  }
}
