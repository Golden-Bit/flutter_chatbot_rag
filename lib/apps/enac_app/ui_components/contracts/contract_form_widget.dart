// lib/apps/enac_app/ui_components/contract_form_pane.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';

class ContractFormPane extends StatefulWidget with ChatBotExtensions {
  const ContractFormPane({super.key, this.initialValues});

  @override
  State<ContractFormPane> createState() => ContractFormPaneState();
  final Map<String, String>? initialValues;

  /*───────────────────────────────────────────────────────────────────────*/
  /* ToolSpec: COMPILA TUTTO (ogni parametro è opzionale)                  */
  /*───────────────────────────────────────────────────────────────────────*/
  static final ToolSpec fillTool = ToolSpec(
    toolName: 'FillContractFormWidget',
    description:
        '''Compila il form contratto (solo campi richiesti). Ogni parametro è opzionale: se assente, il campo non viene toccato.
Se ti viene chiesto di compilare una polizza/contratto, o anche se non viene specificato alcun tipo di form specifico 
(ma ti viene solo cheisto di compialr eun form generico), dovrai impiegare tale tool ui per compilare form.

Di seguito ti mostro le tipologie di contratto/polizza che dovrai compilare. Nel caso in cui l'utente ti abbia fornito dei documenti, 
allora dovrai utilizzare le infromaizoni contenute al loro interno per ottenre i dati da inserire nel form. 

Tipologie contratto/polizza:

L’esempio Specifico – Polizza Kasko
Al fine di semplificare l’apprendimento e la capacità di caricamento in pia9aforma, di seguito ripor.amo le voci da
caricare e la posizione delle rela.ve nel testo:
• Tipo: la voce “.po”, in realtà, deve solo essere un elenco a cascata, ma che ai nostri fini sarà solo Polizza (da
indicare con acronimo POL).
• Rischio: si intende “Kasko”, e lo si può capire dall’ogge9o della copertura, una volta che si oJene una
conoscenza tecnica sufficiente. Per questo momento, in via sinte.ca, lo si può trovare nella primissima pagina
del PDF in alto, alla terza riga nell’intestazione del documento.
• Compagnia: il nome della Compagnia è riportato in più pun. del documento: lo si può trovare infaJ pagina 1
del PDF, corrispondente al termine “Assicuratore”, e lo si può trovare in tuJ i piè di pagina.
• Numero di Polizza: il numero della Polizza è riportato in alto al centro del documento PDF, so9o la scri9a Kasko;
inoltre, è riportato anche nella “Scheda di Polizza”, a pagina 5 del PDF
• Premio Annuo Imponibile: è la cifra espressa in euro che corrisponde alla voce Premio Ne9o, riportato nella
prima pagina del PDF nella tabella al centro; la stessa cifra, poi, può essere trovata in “Scheda di polizza” (pagina
5), alla voca Premio Imponibile Annuo.
• Imposte: è la cifra espressa in euro ed in percentuale indicata con il termine imposte nella prima pagina del
PDF e a pagina 5 in “Scheda di Polizza”.
• Premio Annuo Lordo: è la cifra espressa in euro che corrisponde al termine Premio Lordo, riportato nella prima
pagina del PDF nella tabella al centro, oltre che nella “Scheda di Polizza” a pagina 5.
• Frazionamento: In genere essa può essere semestrale o annuale, ma in questa polizza il termine è riportato
nella prima pagina del PDF e nella pagina 5, so9o la “Scheda di Polizza”.
• EffeNo: il termine esprime una data ed è indicato nella pagina 1 del PDF come Decorrenza, oltre ad essere
indicato all’Art. 9 della Sezione I – “Durata del Contra9o” e in “Scheda di Polizza” a pagina 5 del PDF.
• Scadenza: analogamente all’effe9o, il termine esprime una data ed è indicato nella pagina 1 del PDF come
Scadenza, oltre ad essere indicato all’Art. 9 della Sezione I – “Durata del Contra9o” e in “Scheda di Polizza” a
pagina 5 del PDF.
• Scadenza Copertura: il termine si esprime con una data ed è stabilito dai termini che disciplinano la mora del
pagamento per le rate successive al primo pagamento. Le garanzie di polizza, infaJ, si sospendono in mancanza
del pagamento del premio solo dopo il 60 giorno dalla data di scadenza, per cui la scadenza reale della copertura
è pos.cipata di 60 giorni rispe9o alla scadenza riportata in Polizza.
• Data di Emissione: il termine indica una data ed è indicata nella pagina 1 del PDF, in corrispondenza del termine
“Emesso con unico effe9o il”.
• Giorni di Mora: la modalità di funzionamento dei temini di mora è descri9a all’Art. 10 – “Pagamento del Premio
– decorrenza dell’assicurazione”, a pagina 10 del PDF. La dicitura “entro 60 giorni” significa che i giorni di mora
per il pagamento sono 60.
• Broker: il nome del Broker è riportato a pagina 1 del PDF alla voce Broker, oltre ad essere inserito in “Scheda di
Polizza” a pagina 5 del PDF; in più, c’è anche la descrizione del Broker e della rela.va ges.one del contra9o
all’art. 17 “Clausola Broker” della Sezione I.
• Indirizzo del Broker: è riportato so9o il nome del Broker, nella pagina 1 del PDF.
• Tacito Rinnovo: questa informazione è riportata nella pagina 1 del PDF. Per esser più precisi, dove è descri9a la
data della scadenza c’è scri9o “è escluso il tacito rinnovo”. Quindi la risposta da inserire è NO.
• DisdeNa: Qualora sia previsto il Tacito Rinnovo, sarebbe previsto anche un termine entro il quale comunicare
la Disde9a. Su questa polizza, non essendo previsto il tacito rinnovo, non è prevista nemmeno la disde9a. Si
può quindi inserire NO.
• Facoltà di Proroga: Tale informazione è contenuta nell’art. 9 Durata del Contra9o della Sezione I a pagina 9 del
PDF, dove è scri9o che il Contraente può chiedere la proroga di 1 anno.
• Regolazione al termine del periodo: Tale meccanismo è contenuto nell’art. 2 Regolazione del Premio, a pagina
6 del PDF, per cui la risposta è Sì.
L’esempio Specifico – Polizza CumulaOva contro gli Infortuni AeronauOci IspeNori di volo / ispeNori del traffico aereo
/ PiloO Collaudatori / Tecnici Collaudatori
Al fine di semplificare l’apprendimento e la capacità di caricamento in pia9aforma, di seguito ripor.amo le voci da
caricare e la posizione delle rela.ve nel testo:
• Tipo: la voce “.po”, in realtà, deve solo essere un elenco a cascata, ma che ai nostri fini sarà solo Polizza (da
indicare con acronimo POL).
• Rischio: si intende “Infortuni Aeronau.ci”, e lo si può capire dal .tolo del Documento al centro della prima
pagina del pdf. La prima pagina della Polizza si chiama frontespizio di Polizza
• Compagnia: il nome della Compagnia è riportato in più pun. del documento: lo si può trovare in tu9e le
intestazioni e i piè di pagina.
• Numero di Polizza: il numero della Polizza è riportato nella prima pagina del PDF (frontespizio), so9o la scri9a
POLIZZA nella prima tabella in alto.
• Premio Annuo Imponibile: in questa Polizza non è riportato il Premio Imponibile. Esso dovrà essere calcolato
sulla base del premio lordo di Polizza riportato nell’ul.ma riga di pagina 23 del PDF, considerando che le imposte
applicate sono il 22,25% del premio ne9o.
• Imposte: tale voce non è presente nel testo. Le imposte dovranno essere calcolate partendo dal premio lordo
riportato a pagina 23 del PDF in ul.ma riga. Le imposte sono il 22.25% del premio ne9o.
• Premio Annuo Lordo: è la cifra espressa in euro che corrisponde al termine Premio Annuo Lordo, riportato nella
pagina 23 del PDF in ul.ma riga.
• Frazionamento: In questa polizza il termine è riportato nel frontespizio di polizza, prima pagina del PDF,
nell’ul.ma riga della tabella.
• EffeNo: il termine esprime una data ed è indicato nella pagina 1 del PDF come Decorrenza, nell’ul.ma riga della
tabella.
• Scadenza: analogamente all’effe9o, il termine esprime una data ed è indicato nella pagina 1 del PDF come
Scadenza, nell’ul.ma riga della tabella.
• Scadenza Copertura: il termine si esprime con una data ed è stabilito dai termini che disciplinano la modalità
del pagamento all’ar.colo 2, pagina 6 del PDF dove c’è scri9o che il cliente potrà pagare le rate successive al
primo pagamento entro 60 giorni dalla data di scadenza. Le garanzie di polizza, infaJ, si sospendono in
mancanza del pagamento del premio solo dopo il 60 giorno dalla data di scadenza, per cui la scadenza reale
della copertura è pos.cipata di 60 giorni rispe9o alla scadenza riportata in Polizza.
• Data di Emissione: elemento non presente in Polizza e non desumibile neanche indire9amente.
• Giorni di Mora: la modalità di funzionamento dei temini di mora è descri9a all’Ar.colo 2 – “Pagamento del
Premio e decorrenza dell’assicurazione”, a pagina 6 del PDF. La dicitura “entro 60 giorni” significa che i giorni di
mora per il pagamento sono 60.
• Broker: il nome del Broker è riportato a pagina 4 del PDF tra le Definizioni alla voce Broker; in più, c’è anche la
descrizione del Broker e della rela.va ges.one del contra9o all’art. 15 a pagina 9 del PDF “Clausola Broker”.
• Indirizzo del Broker: è riportato nell’ar.colo 15 a pagina 9 del PDF.
• Tacito Rinnovo: questa informazione è riportata nell’ar.colo 1 a pagina 6 del PDF, dove è scri9o che la polizza
“scadrà alle ore 24.00 del 31/12/2027, senza tacita proroga”. Quindi la risposta da inserire è NO.
• DisdeNa: Qualora sia previsto il Tacito Rinnovo, sarebbe previsto anche un termine entro il quale comunicare
la Disde9a. Su questa polizza, non essendo previsto il tacito rinnovo, non è prevista nemmeno la disde9a. Si
può quindi inserire NO.
• Facoltà di Proroga: Tale informazione è contenuta nell’art. 1 “Durata del Contra9o” a pagina 6 del PDF, dove è
scri9o che il Contraente può chiedere la proroga di 1 anno.
• Regolazione al termine del periodo: Tale meccanismo è contenuto nell’art. 7 Regolazione Premio della Sezione
IV – Condizioni Par.colari Aggiun.ve regolazione del Premio Scomposizione del premio, a pagina 23 del PDF,
per cui la risposta è Sì.

NOTA IMPORTANTE: QUANDO DOVRAI CERCARE NEL VECTOR STORE, NEL CASO DI DOCUEMNTI FORNITI DA UTNETE, ALLORA NON DOVRAI FILTRARE IN BASE ALLE PAGINE (IN QUANTO POTREBBERO NON CORRISPONDERE)!!! DOVRAI SOLO FARE QUERY AL VECTOR STORE IN BASE AL CONTENUTO PER INDIVIDUARE I DATI CHE TI SERVONO.
''',
    params: const [
      // Identificativi
      ToolParamSpec(
        name: 'tipo',
        paramType: ParamType.string,
        description: 'Tipologia documento di polizza: COND = condizioni, APP0 = appendice a premio nullo, APP€ = appendice con premio.',
        example: 'COND',
      ),
      ToolParamSpec(
        name: 'rischio',
        paramType: ParamType.string,
        description: 'Evento futuro e incerto assicurato (es. ramo/garanzia). Usalo in modo descrittivo (es.: "Responsabilità Civile Generale", "Incendio", "Kasko").',
        example: 'Responsabilità Civile Generale',
      ),
      ToolParamSpec(
        name: 'compagnia',
        paramType: ParamType.string,
        description: 'Denominazione della compagnia assicuratrice.',
        example: 'ACME Assicurazioni S.p.A.',
      ),
      ToolParamSpec(
        name: 'numero',
        paramType: ParamType.string,
        description: 'Numero univoco di Polizza/Appendice assegnato dalla compagnia (serve per tracciabilità e corrispondenza).',
        example: 'POL-2025-001',
      ),

      // Importi
      ToolParamSpec(
        name: 'premio_imponibile',
        paramType: ParamType.number,
        description: 'Premio annuo imponibile (o “netto”), prima delle imposte. Accetta 1.234,56 o 1234.56.',
        example: 1000.00,
        minValue: 0,
      ),
      ToolParamSpec(
        name: 'imposte',
        paramType: ParamType.number,
        description: 'Imposte applicate per legge sul premio (variano per ramo; p.es. RCA ~26,5% sul lordo).',
        example: 220.00,
        minValue: 0,
      ),
      ToolParamSpec(
        name: 'premio_lordo',
        paramType: ParamType.number,
        description: 'Totale da pagare: imponibile + imposte (+ eventuali oneri).',
        example: 1220.00,
        minValue: 0,
      ),

      // Amministrativi / date
      ToolParamSpec(
        name: 'fraz',
        paramType: ParamType.string,
        description: 'Frazionamento del premio: Annuale / Semestrale / Trimestrale / Mensile.',
        example: 'Annuale',
      ),
      ToolParamSpec(
        name: 'effetto',
        paramType: ParamType.string,
        description: 'Decorrenza della copertura (inizio validità). Formato dd/MM/yyyy.',
        example: '01/01/2026',
      ),
      ToolParamSpec(
        name: 'scadenza',
        paramType: ParamType.string,
        description: 'Fine del periodo assicurativo previsto dal contratto. Formato dd/MM/yyyy.',
        example: '01/01/2027',
      ),
      ToolParamSpec(
        name: 'scadenza_copertura',
        paramType: ParamType.string,
        description: 'Giorno in cui termina l’efficacia della protezione. Può includere periodo di comporto. Formato dd/MM/yyyy.',
        example: '31/01/2027',
      ),
      ToolParamSpec(
        name: 'data_emissione',
        paramType: ParamType.string,
        description: 'Data di redazione/registrazione della polizza. Formato dd/MM/yyyy.',
        example: '01/01/2026',
      ),
      ToolParamSpec(
        name: 'giorni_mora',
        paramType: ParamType.string,
        description: 'Tolleranza post-scadenza entro cui la copertura resta valida (tipicamente 15 giorni).',
        example: '15',
      ),

      // Broker
      ToolParamSpec(
        name: 'broker',
        paramType: ParamType.string,
        description: 'Intermediario assicurativo indipendente che tutela l’interesse del cliente.',
        example: 'Broker XYZ S.r.l.',
      ),
      ToolParamSpec(
        name: 'broker_indirizzo',
        paramType: ParamType.string,
        description: 'Indirizzo del broker / punto vendita (via, civico, CAP, città, provincia).',
        example: 'Via Roma 1, 20100 Milano (MI)',
      ),

      // Rinnovo / opzionali
      ToolParamSpec(
        name: 'tacito_rinnovo',
        paramType: ParamType.string,
        description: 'Rinnovo automatico alla scadenza (Sì/No) se non viene inviata disdetta nei tempi previsti.',
        example: 'Sì',
      ),
      ToolParamSpec(
        name: 'disdetta',
        paramType: ParamType.string,
        description: 'Termini/modalità per evitare il rinnovo (es.: "30 gg prima").',
        example: '30 gg prima',
      ),
      ToolParamSpec(
        name: 'proroga',
        paramType: ParamType.string,
        description: 'Eventuale estensione temporanea oltre la scadenza alle stesse condizioni.',
        example: '15 gg',
      ),
      ToolParamSpec(
        name: 'regolazione_fine_periodo',
        paramType: ParamType.boolean,
        description: 'Se previsto conguaglio a fine periodo su dati variabili (p.es. fatturato/addetti).',
        example: true,
      ),

      // Digitazione
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata). Default 22.',
        example: 18,
        defaultValue: 22,
        minValue: 0,
        maxValue: 200,
      ),
    ],
  );

  /*───────────────────────────────────────────────────────────────────────*/
  /* ToolSpec: SET SINGOLO CAMPO                                          */
  /*───────────────────────────────────────────────────────────────────────*/
  static final List<String> _allFields = [
    // Identificativi
    'tipo','rischio','compagnia','numero',
    // Importi
    'premio_imponibile','imposte','premio_lordo',
    // Amministrativi / date
    'fraz','effetto','scadenza','scadenza_copertura','data_emissione','giorni_mora',
    // Broker
    'broker','broker_indirizzo',
    // Rinnovo
    'tacito_rinnovo','disdetta','proroga','regolazione_fine_periodo',
  ];

  static final ToolSpec setTool = ToolSpec(
    toolName: 'SetContractFieldWidget',
    description: 'Imposta un singolo campo del contratto con digitazione simulata. VALGONO LE STESSE INFO E DESCRIZIONI DEI CAMPI FORNITE PER [FillContractFormWidget].',
    params: [
      ToolParamSpec(
        name: 'field',
        paramType: ParamType.string,
        description: 'Nome del campo da impostare.',
        allowedValues: _allFields,
        example: 'numero',
      ),
      ToolParamSpec(
        name: 'value',
        paramType: ParamType.string,
        description: 'Valore del campo. Date: dd/MM/yyyy. Numeri: 1.234,56 o 1234.56. Boolean: "Sì"/"No" o "true"/"false".',
        example: 'POL-2025-001',
      ),
      ToolParamSpec(
        name: 'typing_ms',
        paramType: ParamType.integer,
        description: 'Millisecondi per carattere (digitazione simulata).',
        example: 20,
        defaultValue: 22,
        minValue: 0,
        maxValue: 200,
      ),
    ],
  );


  @override
  List<ToolSpec> get toolSpecs => [fillTool, setTool];

  @override
  Map<String, ChatWidgetBuilder> get extraWidgetBuilders => {
        'FillContractFormWidget': (json, onR, pCbs, hCbs) =>
            _FillContractFormExec(json: json, host: hCbs as _ContractFormHostCbs),
        'SetContractFieldWidget': (json, onR, pCbs, hCbs) =>
            _SetContractFieldExec(json: json, host: hCbs as _ContractFormHostCbs),
      };

  @override
  ChatBotHostCallbacks get hostCallbacks => const _ContractFormHostCbs();
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  STATE: controllers, digitazione, UI, export modello                    */
/*─────────────────────────────────────────────────────────────────────────*/
class ContractFormPaneState extends State<ContractFormPane> {
  static const double _kFormMaxWidth = 600;

  // Selettori a scelta vincolata
  static const List<String> _tipoOptions = ['COND', 'APP0', 'APP€'];
  static const List<String> _siNoOptions = ['Sì', 'No'];

  String _tipo = _tipoOptions.first;
  String _tacito = _siNoOptions.first;
  bool _regolazioneFinePeriodo = false;

  // Controllers
  final _c = <String, TextEditingController>{
    // Identificativi
    'rischio': TextEditingController(),
    'compagnia': TextEditingController(),
    'numero': TextEditingController(),

    // Importi
    'premio_imponibile': TextEditingController(text: '0'),
    'imposte': TextEditingController(text: '0'),
    'premio_lordo': TextEditingController(text: '0'),

    // Amministrativi / date
    'fraz': TextEditingController(text: 'Annuale'),
    'effetto': TextEditingController(),
    'scadenza': TextEditingController(),
    'scadenza_copertura': TextEditingController(),
    'data_emissione': TextEditingController(),
    'giorni_mora': TextEditingController(),

    // Broker
    'broker': TextEditingController(),
    'broker_indirizzo': TextEditingController(),

    // Rinnovo
    'disdetta': TextEditingController(),
    'proroga': TextEditingController(),
  };

  // Focus nodes
  final _f = { for (final k in ContractFormPane._allFields) k: FocusNode() };

  // typing
  final _gen = <String,int>{};
  static const _kDefaultTypingMs = 22;

  /* -------------------- Helpers -------------------- */
  InputDecoration _dec(String l) =>
      InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder());
  Widget _t(String key, String label, {String? hint}) =>
      TextField(controller: _c[key], focusNode: _f[key], decoration: _dec(label).copyWith(hintText: hint));

  static String _normSiNo(dynamic v) {
    if (v == null) return 'Sì';
    final s = v.toString().trim().toLowerCase();
    const yes = {'si','sì','true','1','y','yes'};
    const no  = {'no','false','0','n'};
    if (yes.contains(s)) return 'Sì';
    if (no.contains(s))  return 'No';
    return (s == 'app€' || s == 'app0' || s == 'cond') ? 'Sì' : (s.isEmpty ? 'Sì' : (v.toString())); // fallback
  }

  static String _normTipo(dynamic v) {
    if (v == null) return 'COND';
    final s = v.toString().trim().toUpperCase();
    if (s.startsWith('COND')) return 'COND';
    if (s == 'APP0' || s.contains('PREMIO NULLO')) return 'APP0';
    if (s == 'APP€' || s.contains('CON PREMIO'))  return 'APP€';
    return _tipoOptions.contains(s) ? s : 'COND';
  }

  // Digitazione simulata
  Future<void> _typeInto(String key, String target, {required int ms}) async {
    final ctrl = _c[key]; if (ctrl == null) return;
    final id = (_gen[key] ?? 0) + 1; _gen[key] = id;

    final cur = ctrl.text;
    final keep = _commonPrefixLen(cur, target);

    for (int i = cur.length; i > keep; i--) {
      if (_gen[key] != id) return;
      ctrl.text = cur.substring(0, i - 1);
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      await Future.delayed(Duration(milliseconds: ms));
    }
    for (int i = keep; i < target.length; i++) {
      if (_gen[key] != id) return;
      ctrl.text = target.substring(0, i + 1);
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  int _commonPrefixLen(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0; while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) i++;
    return i;
  }

  /* -------------------- Initial values -------------------- */
  void _setInitialValues(Map<String, String> m) {
    // testi
    for (final e in m.entries) {
      final k = e.key;
      final v = e.value;
      if (_c.containsKey(k)) {
        _c[k]!.text = v;
        _c[k]!.selection = TextSelection.collapsed(offset: _c[k]!.text.length);
      }
    }
    // select / booleani
    if (m.containsKey('tipo')) setState(() => _tipo = _normTipo(m['tipo']));
    if (m.containsKey('tacito_rinnovo')) setState(() => _tacito = _normSiNo(m['tacito_rinnovo']));
    if (m.containsKey('regolazione_fine_periodo')) {
      final v = m['regolazione_fine_periodo']!;
      setState(() => _regolazioneFinePeriodo =
          (v.toLowerCase() == 'true') || (v.toLowerCase() == 'sì') || (v.toLowerCase() == 'si') || (v == '1'));
    }
  }

  @override
  void initState() {
    super.initState();
    _ContractFormHostCbs.bind(this);
    if (widget.initialValues != null && widget.initialValues!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setInitialValues(widget.initialValues!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ContractFormPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValues != oldWidget.initialValues &&
        widget.initialValues != null) {
      _setInitialValues(widget.initialValues!);
    }
  }

  @override
  void dispose() { _ContractFormHostCbs.unbind(this); super.dispose(); }

  // Modello (chiavi "pulite" per il dialog utilizzatore)
  Map<String, String> get model => {
    'tipo'                 : _tipo,
    'rischio'              : _c['rischio']?.text.trim() ?? '',
    'compagnia'            : _c['compagnia']?.text.trim() ?? '',
    'numero'               : _c['numero']?.text.trim() ?? '',
    'premio_imponibile'    : _c['premio_imponibile']?.text.trim() ?? '',
    'imposte'              : _c['imposte']?.text.trim() ?? '',
    'premio_lordo'         : _c['premio_lordo']?.text.trim() ?? '',
    'fraz'                 : _c['fraz']?.text.trim() ?? '',
    'effetto'              : _c['effetto']?.text.trim() ?? '',
    'scadenza'             : _c['scadenza']?.text.trim() ?? '',
    'scadenza_copertura'   : _c['scadenza_copertura']?.text.trim() ?? '',
    'data_emissione'       : _c['data_emissione']?.text.trim() ?? '',
    'giorni_mora'          : _c['giorni_mora']?.text.trim() ?? '',
    'broker'               : _c['broker']?.text.trim() ?? '',
    'broker_indirizzo'     : _c['broker_indirizzo']?.text.trim() ?? '',
    'tacito_rinnovo'       : _tacito,
    'disdetta'             : _c['disdetta']?.text.trim() ?? '',
    'proroga'              : _c['proroga']?.text.trim() ?? '',
    'regolazione_fine_periodo' : _regolazioneFinePeriodo ? 'Sì' : 'No',
  };

  // Esposizione "raw" (debug)
  Map<String,String> get values =>
      { for (final e in _c.entries) e.key: e.value.text.trim() }
        ..addAll({
          'tipo': _tipo,
          'tacito_rinnovo': _tacito,
          'regolazione_fine_periodo': _regolazioneFinePeriodo ? 'Sì' : 'No',
        });

  // Host API (gestisce select/booleani)
  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    if (field == 'tipo') {
      setState(() => _tipo = _normTipo(value));
      return;
    }
    if (field == 'tacito_rinnovo') {
      setState(() => _tacito = _normSiNo(value));
      return;
    }
    if (field == 'regolazione_fine_periodo') {
      final v = (value is bool)
          ? value
          : (value.toString().toLowerCase() == 'true' ||
             value.toString().toLowerCase() == 'sì' ||
             value.toString().toLowerCase() == 'si'  ||
             value.toString() == '1');
      setState(() => _regolazioneFinePeriodo = v);
      return;
    }

    await _typeInto(field, value?.toString() ?? '', ms: ms);
    final node = _f[field];
    if (node != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
    }
  }

  Future<void> fill(Map<String, dynamic> m, {int? typingMs}) async {
    final ms = typingMs ?? _kDefaultTypingMs;

    // ordine “umano”
    final order = [
      'tipo','rischio','compagnia','numero',
      'premio_imponibile','imposte','premio_lordo',
      'fraz','effetto','scadenza','scadenza_copertura','data_emissione','giorni_mora',
      'broker','broker_indirizzo',
      'tacito_rinnovo','disdetta','proroga','regolazione_fine_periodo',
    ];

    final keys = [...order.where(m.containsKey), ...m.keys.where((k) => !order.contains(k))];
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      await setField(k, v, typingMs: ms);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /* ---------------------------- UI ---------------------------- */
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Identificativi
              Text('Identificativi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),

              // Tipo (dropdown vincolato)
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: _dec('Tipo *'),
                items: const [
                  DropdownMenuItem(value: 'COND', child: Text('Condizioni di Polizza (COND)')),
                  DropdownMenuItem(value: 'APP0', child: Text('Appendice a premio nullo (APP0)')),
                  DropdownMenuItem(value: 'APP€', child: Text('Appendice con premio (APP€)')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'COND'),
              ),
              const SizedBox(height: 8),

              _t('rischio', 'Rischio *'),
              const SizedBox(height: 8),

              Row(children: [
                Expanded(child: _t('compagnia', 'Compagnia *')),
                const SizedBox(width: 8),
                Expanded(child: _t('numero', 'Numero di Polizza/Appendice *')),
              ]),

              const Divider(height: 24),
              Text('Importi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('premio_imponibile', 'Premio Annuo Imponibile *')),
                const SizedBox(width: 8),
                Expanded(child: _t('imposte', 'Imposte *')),
              ]),
              const SizedBox(height: 8),
              _t('premio_lordo', 'Premio Annuo Lordo *'),

              const Divider(height: 24),
              Text('Amministrativi', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _t('fraz', 'Frazionamento *'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('effetto',   'Effetto *',  hint: 'gg/mm/aaaa')),
                const SizedBox(width: 8),
                Expanded(child: _t('scadenza',  'Scadenza *', hint: 'gg/mm/aaaa')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('scadenza_copertura', 'Scadenza Copertura *', hint: 'gg/mm/aaaa')),
                const SizedBox(width: 8),
                Expanded(child: _t('data_emissione', 'Data di Emissione *', hint: 'gg/mm/aaaa')),
              ]),
              const SizedBox(height: 8),
              _t('giorni_mora', 'Giorni di Mora'),

              const Divider(height: 24),
              Text('Broker & Rinnovo', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _t('broker', 'Broker *'),
              const SizedBox(height: 8),
              _t('broker_indirizzo', 'Indirizzo del Broker *'),
              const SizedBox(height: 8),
              Row(children: [
                // Tacito Rinnovo (dropdown Sì/No)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tacito,
                    decoration: _dec('Tacito Rinnovo *'),
                    items: _siNoOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _tacito = v ?? 'Sì'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _t('disdetta', 'Disdetta')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _t('proroga', 'Facoltà di Proroga')),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _regolazioneFinePeriodo ? 'Sì' : 'No',
                    decoration: _dec('Regolazione al termine del periodo *'),
                    items: _siNoOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _regolazioneFinePeriodo = (v == 'Sì')),
                  ),
                ),
              ]),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/* HostCallbacks: binding esplicito allo State                             */
/*─────────────────────────────────────────────────────────────────────────*/
class _ContractFormHostCbs extends ChatBotHostCallbacks {
  const _ContractFormHostCbs();

  static ContractFormPaneState? _bound;
  static void bind(ContractFormPaneState s) {
    _bound = s;
    debugPrint('[ContractHost] bound to ${s.hashCode}');
  }
  static void unbind(ContractFormPaneState s) {
    if (_bound == s) {
      _bound = null;
      debugPrint('[ContractHost] unbound');
    }
  }

  ContractFormPaneState? get _s => _bound;

  Future<void> setField(String field, dynamic value, {int? typingMs}) async {
    debugPrint('[ContractHost] setField $field="$value" typingMs=$typingMs bound=${_s!=null}');
    await _s?.setField(field, value, typingMs: typingMs);
  }

  Future<void> fillAll(Map<String, dynamic> payload, {int? typingMs}) async {
    debugPrint('[ContractHost] fillAll keys=${payload.keys} typingMs=$typingMs bound=${_s!=null}');
    await _s?.fill(payload, typingMs: typingMs);
  }
}

/*─────────────────────────────────────────────────────────────────────────*/
/*  Tool executors                                                         */
/*─────────────────────────────────────────────────────────────────────────*/
class _FillContractFormExec extends StatefulWidget {
  const _FillContractFormExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ContractFormHostCbs host;
  @override State<_FillContractFormExec> createState() => _FillContractFormExecState();
}
class _FillContractFormExecState extends State<_FillContractFormExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[FillContractExec] json=${widget.json} first=$first');
    if (!first) return;

    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;
    final keys = ContractFormPane._allFields;
    final map  = <String,dynamic>{
      for (final k in keys) if (widget.json.containsKey(k)) k: widget.json[k]
    };

    if (map.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.fillAll(map, typingMs: ms));
    }
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}

class _SetContractFieldExec extends StatefulWidget {
  const _SetContractFieldExec({required this.json, required this.host});
  final Map<String,dynamic> json; final _ContractFormHostCbs host;
  @override State<_SetContractFieldExec> createState() => _SetContractFieldExecState();
}
class _SetContractFieldExecState extends State<_SetContractFieldExec> {
  @override
  void initState() {
    super.initState();
    final first = widget.json['is_first_time'] as bool? ?? true;
    debugPrint('[SetContractExec] json=${widget.json} first=$first');
    if (!first) return;
    final field = (widget.json['field'] ?? '').toString();
    final value = widget.json['value'];
    final ms = (widget.json['typing_ms'] is int) ? widget.json['typing_ms'] as int : null;

    if (field.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.host.setField(field, value, typingMs: ms));
    }
  }
  @override Widget build(BuildContext _) => const SizedBox.shrink();
}
