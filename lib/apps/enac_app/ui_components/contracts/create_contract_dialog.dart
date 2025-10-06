/* ──────────────────────────────────────────────────────────────────────────
 *  DIALOG “NUOVO CONTRATTO” — versione Dual-Pane (form + ChatBot)
 *  ▸ Colonna sinistra: form completo del contratto
 *  ▸ Colonna destra  : ChatBot (pre-caricato, di default nascosto)
 *  ▸ Icona chat in alto a destra per aprire / chiudere il pane destro
 *  ▸ Nessuna logica di business modificata
 * ───────────────────────────────────────────────────────────────────────── */
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/chatbot.dart';                       // ChatBot
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // (può restare, anche se non più usato per l'id contratto)

/*══════════════════════════════════════════════════════════════════════════
 *  W I D G E T
 *════════════════════════════════════════════════════════════════════════*/
class CreateContractDialog extends StatefulWidget {
  const CreateContractDialog({
    super.key,
    required this.user,
    required this.token,
    required this.sdk,
    required this.clientId,
  });

  final User  user;               // username = userId
  final Token token;              // token corrente
  final Omnia8Sdk sdk;            // backend SDK
  final String clientId;          // id cliente

  /* Helper statico -------------------------------------------------------- */
  static Future<bool?> show(
    BuildContext context, {
    required User  user,
    required Token token,
    required Omnia8Sdk sdk,
    required String clientId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateContractDialog(
        user     : user,
        token    : token,
        sdk      : sdk,
        clientId : clientId,
      ),
    );
  }

  @override
  State<CreateContractDialog> createState() => _CreateContractDialogState();
}

/*══════════════════════════════════════════════════════════════════════════
 *  S T A T E
 *════════════════════════════════════════════════════════════════════════*/
class _CreateContractDialogState extends State<CreateContractDialog> {
  final _contractPaneKey = GlobalKey<ContractFormPaneState>(); // NEW

  /*──── form: controller testo obbligatori / principali ──────────────────*/
  final _ctrl = <String, TextEditingController>{
    'tipo'         : TextEditingController(),
    'tpCar'        : TextEditingController(),
    'ramo'         : TextEditingController(),
    'compagnia'    : TextEditingController(),
    'numero'       : TextEditingController(),
    'pv1'          : TextEditingController(),
    'pv2'          : TextEditingController(),
    'account'      : TextEditingController(),
    'intermediario': TextEditingController(),
    'fraz'         : TextEditingController(text: 'Annuale'),
    'modIncasso'   : TextEditingController(text: 'Bonifico'),
    'numeroProposta': TextEditingController(),
    'codConvenzione': TextEditingController(),
    'premio'       : TextEditingController(text: '0'),
    'netto'        : TextEditingController(text: '0'),
    'accessori'    : TextEditingController(text: '0'),
    'diritti'      : TextEditingController(text: '0'),
    'imposte'      : TextEditingController(text: '0'),
    'spese'        : TextEditingController(text: '0'),
    'fondo'        : TextEditingController(text: '0'),
    'sconto'       : TextEditingController(text: '0'),
  };

  /*──── controller Rinnovo ───────────────────────────────────────────────*/
  final _rinCtrl = <String, TextEditingController>{
    'rinnovo' : TextEditingController(),
    'disdetta': TextEditingController(),
    'gMora'   : TextEditingController(),
    'proroga' : TextEditingController(),
  };

  /*──── controller Operatività / Regolazione ─────────────────────────────*/
  final _opCtrl = <String, TextEditingController>{
    'cadReg'   : TextEditingController(),
    'gInvio'   : TextEditingController(),
    'gPag'     : TextEditingController(),
    'gMoraReg' : TextEditingController(),
  };

  /*──── date controller ──────────────────────────────────────────────────*/
  final DateFormat _fmt = DateFormat('dd/MM/yyyy');
  late final TextEditingController _effCtrl   =
      TextEditingController(text: _fmt.format(DateTime.now()));
  late final TextEditingController _scadCtrl  =
      TextEditingController(text: _fmt.format(DateTime.now().add(const Duration(days: 365))));
  late final TextEditingController _emisCtrl  =
      TextEditingController(text: _fmt.format(DateTime.now()));

  final _scMoraCtrl  = TextEditingController();
  final _scVinCtrl   = TextEditingController();
  final _scCopCtrl   = TextEditingController();
  final _finePrCtrl  = TextEditingController();

  /*──── Regolazione date ────────────────────────────────────────────────*/
  late final TextEditingController _inizioRegCtrl =
      TextEditingController(text: _fmt.format(DateTime.now()));
  late final TextEditingController _fineRegCtrl   =
      TextEditingController(text: _fmt.format(DateTime.now().add(const Duration(days: 365))));
  final _ultRegCtrl = TextEditingController();

  /*──── RamiEl ───────────────────────────────────────────────────────────*/
  final _ramiDescCtrl = TextEditingController();

  bool _regolazione = false;
  final _formKey    = GlobalKey<FormState>();

  /*──── Dual-Pane (chat) ────────────────────────────────────────────────*/
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;          // toggle icona

  @override
  void initState() {
    super.initState();
    /// chat pre-caricata ma chiusa
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  /*======================================================================
   *  INPUT HELPER
   *====================================================================*/
  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());

  TextFormField _txt(TextEditingController c, String l,
      {FormFieldValidator<String>? v}) =>
          TextFormField(controller: c, validator: v, decoration: _dec(l));

  SizedBox _num(TextEditingController c, String l) =>
      SizedBox(width: 110, child: _txt(c, l));

  Future<DateTime?> _pickDate(TextEditingController c) async {
    final parts = c.text.split('/');
    final init = parts.length == 3
        ? DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]))
        : DateTime.now();

    return showDatePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate : DateTime(2100),
      initialDate: init,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary  : Colors.black,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        child: child!,
      ),
    ).then((res) {
      if (res != null) c.text = _fmt.format(res);
      return res;
    });
  }

  InkWell _date(TextEditingController c, String l) => InkWell(
        onTap: () => _pickDate(c),
        child: IgnorePointer(child: _txt(c, l)),
      );

  Widget _sectionTitle(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  /*======================================================================
   *  BUILD
   *====================================================================*/
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding : const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      backgroundColor: Colors.white,
      shape         : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      titlePadding  : const EdgeInsets.fromLTRB(24, 20, 8, 0),
      /*──────── title + toggle chat ───────────────────────────────────*/
      title: Row(
        children: [
          Text('Nuovo contratto',
              style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip : _chatOpen ? 'Chiudi chat' : 'Apri chat',
            icon    : Icon(_chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () {
              setState(() {
                _chatOpen ? _paneCtrl.closeChat() : _paneCtrl.openChat();
                _chatOpen = !_chatOpen;
              });
            },
          ),
        ],
      ),
      /*──────── contenuto Dual-Pane ───────────────────────────────────*/
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width : 1000,   // spazio sufficiente per form + chat
        height: 620,

        child: DualPaneWrapper(
          controller : _paneCtrl,
          user       : widget.user,
          token      : widget.token,
          leftChild  : ContractFormPane(key: _contractPaneKey),       // definito sotto
          // ➜ AUTO-MSG alla chat al mount:
          autoStartMessage  : "Da ora in poi dovrai aiutarmi con la compilazione di form utilizzando l'apposito Tool UI fornito, non appena te lo chiederò. Rispondi solo affermativamente a questo messaggio, grazie!",
          autoStartInvisible: false,
          openChatOnMount   : false,
        ),
      ),
      /*──────── bottoni azione ───────────────────────────────────────*/
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

  /*──── FORM (colonna sinistra) ─────────────────────────────────────────*/
  // (Manteniamo il builder legacy, anche se il form reale è nel ContractFormPane)
  Widget _buildForm() => Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(children: [
              /* Identificativi ------------------------------------------------*/
              _sectionTitle('Identificativi'),
              Row(children: [
                Expanded(child: _txt(_ctrl['tipo']!, 'Tipo *')),
                const SizedBox(width: 8),
                Expanded(child: _txt(_ctrl['tpCar']!, 'TpCar')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _txt(_ctrl['ramo']!, 'Ramo *')),
                const SizedBox(width: 8),
                Expanded(child: _txt(_ctrl['compagnia']!, 'Compagnia *')),
              ]),
              const SizedBox(height: 8),
              _txt(_ctrl['numero']!, 'Numero polizza *'),

              /* Amministrativi base ------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Amministrativi'),
              Row(children: [
                Expanded(child: _date(_effCtrl, 'Effetto *')),
                const SizedBox(width: 8),
                Expanded(child: _date(_scadCtrl, 'Scadenza *')),
              ]),
              const SizedBox(height: 8),
              _date(_emisCtrl, 'Data emissione *'),
              const SizedBox(height: 8),
              _txt(_ctrl['fraz']!, 'Frazionamento *'),
              const SizedBox(height: 8),
              _txt(_ctrl['modIncasso']!, 'Modalità incasso *'),

              /* Amministrativi opz. ------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Altri dati Amministrativi (facoltativi)'),
              _date(_scMoraCtrl, 'Scadenza Mora'),
              const SizedBox(height: 8),
              _txt(_ctrl['numeroProposta']!, 'Numero proposta'),
              const SizedBox(height: 8),
              _txt(_ctrl['codConvenzione']!, 'Codice convenzione'),
              const SizedBox(height: 8),
              _date(_scVinCtrl, 'Scadenza Vincolo'),
              const SizedBox(height: 8),
              _date(_scCopCtrl, 'Scadenza Copertura'),
              const SizedBox(height: 8),
              _date(_finePrCtrl, 'Fine copertura proroga'),

              /* Premi ---------------------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Premi'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _num(_ctrl['premio']!,    'Premio *'),
                  _num(_ctrl['netto']!,     'Netto *'),
                  _num(_ctrl['accessori']!, 'Accessori'),
                  _num(_ctrl['diritti']!,   'Diritti'),
                  _num(_ctrl['imposte']!,   'Imposte'),
                  _num(_ctrl['spese']!,     'Spese'),
                  _num(_ctrl['fondo']!,     'Fondo'),
                  _num(_ctrl['sconto']!,    'Sconto'),
                ],
              ),

              /* Unità vendita -------------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Unità vendita'),
              _txt(_ctrl['pv1']!, 'Punto vendita *'),
              const SizedBox(height: 8),
              _txt(_ctrl['pv2']!, 'Punto vendita 2'),
              const SizedBox(height: 8),
              _txt(_ctrl['account']!, 'Account *'),
              const SizedBox(height: 8),
              _txt(_ctrl['intermediario']!, 'Intermediario *'),

              /* Rinnovo -------------------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Rinnovo'),
              _txt(_rinCtrl['rinnovo']!, 'Rinnovo'),
              const SizedBox(height: 8),
              _txt(_rinCtrl['disdetta']!, 'Disdetta'),
              const SizedBox(height: 8),
              _txt(_rinCtrl['gMora']!, 'Giorni Mora'),
              const SizedBox(height: 8),
              _txt(_rinCtrl['proroga']!, 'Proroga'),

              /* Operatività / Regolazione ------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Operatività'),
              Row(children: [
                Checkbox(
                  value: _regolazione,
                  onChanged: (v) => setState(() => _regolazione = v ?? false),
                ),
                const Text('Regolazione'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _date(_inizioRegCtrl, 'Inizio *')),
                const SizedBox(width: 8),
                Expanded(child: _date(_fineRegCtrl,   'Fine *')),
              ]),
              const SizedBox(height: 8),
              _date(_ultRegCtrl, 'Ultima reg. emessa'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _num(_opCtrl['gInvio']!, 'Giorni invio dati')),
                const SizedBox(width: 8),
                Expanded(child: _num(_opCtrl['gPag']!,  'Giorni pag. reg.')),
              ]),
              const SizedBox(height: 8),
              _num(_opCtrl['gMoraReg']!, 'Giorni mora regolaz.'),
              const SizedBox(height: 8),
              _txt(_opCtrl['cadReg']!, 'Cadenza regolazione'),

              /* RamiEl --------------------------------------------------------*/
              const Divider(height: 24),
              _sectionTitle('Rischio / Prodotto'),
              _txt(_ramiDescCtrl, 'Descrizione *'),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      );

  /*======================================================================
   *  SALVATAGGIO CONTRATTO
   *====================================================================*/
  Future<void> _onCreatePressed() async {
    final pane = _contractPaneKey.currentState;
    if (pane == null) {
      debugPrint('[CreateContractDialog] ERRORE: ContractFormPane non montato');
      return;
    }

    final m = pane.model;            // Map<String,String> (esposto dal pane)
    final reg = pane.regolazione;    // bool (esposto dal pane)
    debugPrint('[CreateContractDialog] model keys=${m.keys} regolazione=$reg');

    // helper locali
    String t(String k) => (m[k] ?? '').trim();
    String? nn(String k) => t(k).isEmpty ? null : t(k);
    DateTime? pd(String k) {
      final s = t(k);
      if (s.isEmpty) return null;
      try {
        return DateFormat('dd/MM/yyyy').parseStrict(s);
      } catch (_) {
        return null;
      }
    }
    int? pint(String k) => (t(k).isEmpty) ? null : int.tryParse(t(k));
    String pstr(String k) {
      final s = t(k);
      if (s.isEmpty) return '0.00';
      final d = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
      return d.toStringAsFixed(2);
    }

    // Validazioni minime su presenza
    final requiredFields = {
      'tipo'        : t('tipo'),
      'ramo'        : t('ramo'),
      'compagnia'   : t('compagnia'),
      'numero'      : t('numero'),
      'effetto'     : t('effetto'),
      'scadenza'    : t('scadenza'),
      'fraz'        : t('fraz'),
      'modIncasso'  : t('modIncasso'),
      'pv1'         : t('pv1'),
      'account'     : t('account'),
      'intermediario': t('intermediario'),
      'premio'      : t('premio'),
      'netto'       : t('netto'),
      'rami_desc'   : t('rami_desc'), // chiave che il pane deve esporre
    };
    final missing = requiredFields.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compila i campi obbligatori: ${missing.join(', ')}')),
      );
      return;
    }

    // Validazioni di FORMATO (date obbligatorie) per evitare il crash del "!"
    final effetto = pd('effetto');
    if (effetto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato data Effetto non valido (usa gg/mm/aaaa).')),
      );
      return;
    }
    final scadenza = pd('scadenza');
    if (scadenza == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato data Scadenza non valido (usa gg/mm/aaaa).')),
      );
      return;
    }

    final emissione = pd('emissione') ?? effetto;
    final ultimaRata = pd('emissione') ?? effetto;

    // Build del payload secondo il NUOVO SDK
    final contratto = ContrattoOmnia8(
      /*---- Identificativi ----*/
      identificativi: Identificativi(
        tipo          : t('tipo'),
        tpCar         : nn('tpCar'),
        ramo          : t('ramo'),
        compagnia     : t('compagnia'),
        numeroPolizza : t('numero'),
      ),

      /*---- Unità vendita ----*/
      unitaVendita: UnitaVendita(
        puntoVendita  : t('pv1'),
        puntoVendita2 : t('pv2'),
        account       : t('account'),
        intermediario : t('intermediario'),
      ),

      /*---- Amministrativi ----*/
amministrativi: Amministrativi(
  effetto            : pd('effetto')!,
  scadenza           : pd('scadenza')!,
  dataEmissione      : pd('emissione') ?? pd('effetto') ?? DateTime.now(),
  ultimaRataPagata   : pd('ultima_rata_pagata') ?? pd('emissione') ?? DateTime.now(), // ⬅️ nuovo
  frazionamento      : t('fraz').toLowerCase(),
  modalitaIncasso    : t('modIncasso'),
  compresoFirma      : t('compresoFirma').toLowerCase() == 'true',                    // ⬅️ nuovo
  scadenzaOriginaria : pd('scadenza_originaria') ?? pd('scadenza')!,                  // ⬅️ nuovo
  scadenzaMora       : pd('sc_mora'),
  numeroProposta     : nn('numeroProposta'),
  codConvenzione     : nn('codConvenzione'),
  scadenzaVincolo    : pd('sc_vincolo'),
  scadenzaCopertura  : pd('sc_copertura'),
  fineCoperturaProroga: pd('fine_proroga'),
),

      /*---- Premi ----*/
      premi: Premi(
        premio    : pstr('premio'),
        netto     : pstr('netto'),
        accessori : pstr('accessori'),
        diritti   : pstr('diritti'),
        imposte   : pstr('imposte'),
        spese     : pstr('spese'),
        fondo     : pstr('fondo'),
        sconto    : t('sconto').isEmpty ? null : pstr('sconto'),
      ),

      /*---- Rinnovo ----*/
      rinnovo: Rinnovo(
        rinnovo    : t('rinnovo'),
        disdetta   : t('disdetta'),
        giorniMora : t('gMora'),
        proroga    : t('proroga'),
      ),

      /*---- Operatività ----*/
      operativita: Operativita(
        regolazione: reg,
        parametriRegolazione: ParametriRegolazione(
          inizio                : pd('inizioReg') ?? effetto,
          fine                  : pd('fineReg')   ?? scadenza,
          ultimaRegEmessa       : pd('ultReg'),
          giorniInvioDati       : pint('gInvio'),
          giorniPagReg          : pint('gPag'),
          giorniMoraRegolazione : pint('gMoraReg'),
          cadenzaRegolazione    : (nn('cadReg')?.toLowerCase() ?? 'annuale'),
        ),
      ),

      /*---- RamiEl ----*/
      ramiEl: RamiEl(descrizione: t('rami_desc')),
    );

    try {
      debugPrint('[CreateContractDialog] Creo contratto per client ${widget.clientId}');
      final resp = await widget.sdk.createContract(
        widget.user.username,  // userId
        widget.clientId,       // entityId
        contratto,             // payload
      );
      // Se vuoi usare i dettagli restituiti:
      debugPrint('[CreateContractDialog] creato contractId=${resp.contractId}');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore creazione contratto: $e')),
      );
    }
  }
}
