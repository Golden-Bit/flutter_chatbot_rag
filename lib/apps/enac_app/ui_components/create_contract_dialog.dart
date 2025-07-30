/* ──────────────────────────────────────────────────────────────────────────
 *  DIALOG “NUOVO CONTRATTO” — versione Dual‑Pane (form + ChatBot)
 *  ▸ Colonna sinistra: form completo del contratto
 *  ▸ Colonna destra  : ChatBot (pre‑caricato, di default nascosto)
 *  ▸ Icona chat in alto a destra per aprire / chiudere il pane destro
 *  ▸ Nessuna logica di business modificata
 * ───────────────────────────────────────────────────────────────────────── */
import 'package:flutter/material.dart';
import 'package:flutter_app/dual_pane_wrapper.dart';
import 'package:flutter_app/chatbot.dart';                       // ChatBot
import 'package:flutter_app/apps/enac_app/llogic_components/backend_sdk.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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

  /*──── Dual‑Pane (chat) ────────────────────────────────────────────────*/
  final DualPaneController _paneCtrl = DualPaneController();
  bool _chatOpen = false;          // toggle icona

  @override
  void initState() {
    super.initState();
    /// chat pre‑caricata ma chiusa
    WidgetsBinding.instance.addPostFrameCallback((_) => _paneCtrl.closeChat());
  }

  /*======================================================================
   *  INPUT HELPER
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
      /*──────── contenuto Dual‑Pane ───────────────────────────────────*/
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width : 1000,   // spazio sufficiente per form + chat
        height: 620,
        child: DualPaneWrapper(
          controller : _paneCtrl,
          user       : widget.user,
          token      : widget.token,
          leftChild  : _buildForm(),       // definito sotto
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
    if (!_formKey.currentState!.validate()) return;

    DateTime _parse(String s) => _fmt.parseStrict(s.trim());

    final contratto = ContrattoOmnia8(
      /*---- Identificativi ----*/
      identificativi: Identificativi(
        tipo          : _ctrl['tipo']!.text.trim(),
        tpCar         : _ctrl['tpCar']!.text.trim().isEmpty ? null : _ctrl['tpCar']!.text.trim(),
        ramo          : _ctrl['ramo']!.text.trim(),
        compagnia     : _ctrl['compagnia']!.text.trim(),
        numeroPolizza : _ctrl['numero']!.text.trim(),
      ),
      /*---- Unità vendita ----*/
      unitaVendita: UnitaVendita(
        puntoVendita : _ctrl['pv1']!.text.trim(),
        puntoVendita2: _ctrl['pv2']!.text.trim(),
        account      : _ctrl['account']!.text.trim(),
        intermediario: _ctrl['intermediario']!.text.trim(),
      ),
      /*---- Amministrativi ----*/
      amministrativi: Amministrativi(
        effetto           : _parse(_effCtrl.text),
        scadenza          : _parse(_scadCtrl.text),
        dataEmissione     : _parse(_emisCtrl.text),
        ultimaRataPagata  : _parse(_emisCtrl.text),
        frazionamento     : _ctrl['fraz']!.text.trim(),
        modalitaIncasso   : _ctrl['modIncasso']!.text.trim(),
        compresoFirma     : false,
        scadenzaOriginaria: _parse(_scadCtrl.text),
        scadenzaMora      : _scMoraCtrl.text.isEmpty ? null : _parse(_scMoraCtrl.text),
        numeroProposta    : _ctrl['numeroProposta']!.text.trim().isEmpty ? null : _ctrl['numeroProposta']!.text.trim(),
        codConvenzione    : _ctrl['codConvenzione']!.text.trim().isEmpty ? null : _ctrl['codConvenzione']!.text.trim(),
        scadenzaVincolo   : _scVinCtrl.text.isEmpty ? null : _parse(_scVinCtrl.text),
        scadenzaCopertura : _scCopCtrl.text.isEmpty ? null : _parse(_scCopCtrl.text),
        fineCoperturaProroga: _finePrCtrl.text.isEmpty ? null : _parse(_finePrCtrl.text),
      ),
      /*---- Premi ----*/
      premi: Premi(
        premio    : double.parse(_ctrl['premio']!.text.replaceAll(',', '.')),
        netto     : double.parse(_ctrl['netto']!.text.replaceAll(',', '.')),
        accessori : double.parse(_ctrl['accessori']!.text.replaceAll(',', '.')),
        diritti   : double.parse(_ctrl['diritti']!.text.replaceAll(',', '.')),
        imposte   : double.parse(_ctrl['imposte']!.text.replaceAll(',', '.')),
        spese     : double.parse(_ctrl['spese']!.text.replaceAll(',', '.')),
        fondo     : double.parse(_ctrl['fondo']!.text.replaceAll(',', '.')),
        sconto    : double.tryParse(_ctrl['sconto']!.text.replaceAll(',', '.')),
      ),
      /*---- Rinnovo ----*/
      rinnovo: Rinnovo(
        rinnovo   : _rinCtrl['rinnovo']!.text.trim(),
        disdetta  : _rinCtrl['disdetta']!.text.trim(),
        giorniMora: _rinCtrl['gMora']!.text.trim(),
        proroga   : _rinCtrl['proroga']!.text.trim(),
      ),
      /*---- Operatività ----*/
      operativita: Operativita(
        regolazione: _regolazione,
        parametriRegolazione: ParametriRegolazione(
          inizio  : _parse(_inizioRegCtrl.text),
          fine    : _parse(_fineRegCtrl.text),
          ultimaRegEmessa      : _ultRegCtrl.text.isEmpty ? null : _parse(_ultRegCtrl.text),
          giorniInvioDati      : int.tryParse(_opCtrl['gInvio']!.text),
          giorniPagReg         : int.tryParse(_opCtrl['gPag']!.text),
          giorniMoraRegolazione: int.tryParse(_opCtrl['gMoraReg']!.text),
          cadenzaRegolazione   : _opCtrl['cadReg']!.text.trim(),
        ),
      ),
      /*---- RamiEl ----*/
      ramiEl: RamiEl(descrizione: _ramiDescCtrl.text.trim()),
    );

    final contractId =
        const Uuid().v4().replaceAll('-', '').substring(0, 12);

    try {
      await widget.sdk.createContract(
        widget.user.username,
        widget.clientId,
        contratto,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore creazione contratto: $e')));
    }
  }
}
