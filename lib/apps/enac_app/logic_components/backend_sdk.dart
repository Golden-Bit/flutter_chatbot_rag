// lib/omnia8_sdk.dart
/* omnia8_sdk.dart
 * ---------------------------------------------------------------
 * SDK Flutter/Dart per l’API REST “Omnia 8 File-API”
 * Copre TUTTI gli end-point:
 *   - /ping
 *   - Entities (CRUD)
 *   - Contracts (CRUD)
 *   - Titles (CRUD)
 *   - Claims (CRUD)
 *   - Diary (CRUD per note del sinistro)
 *   - Documents (contratti/sinistri/titoli: list, create, get, update, delete, download)
 *   - Views & Searches (entity titles, entity claims, search by policy, dashboard due)
 *
 * Dipendenze:
 *   dependencies:
 *     http: ^1.2.0
 *
 * NOTE:
 * - I modelli rispettano le chiavi JSON dell’API (inclusi alias come "Identificativi", snake_case, ecc.)
 * - I campi data vengono serializzati in ISO-8601 (YYYY-MM-DD o YYYY-MM-DDTHH:mm:ssZ secondo il caso)
 * - Per i campi monetari/decimali l’API accetta numero o stringa: qui serializziamo come stringa
 */

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Eccezione generica per errori HTTP provenienti dall’API.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/* *****************************************************************
 *                        HELPERS                                   *
 * *****************************************************************/

String? _optStr(dynamic v) => v == null ? null : v.toString();

DateTime? _parseDateOpt(dynamic v) {
  if (v == null || (v is String && v.isEmpty)) return null;
  return DateTime.parse(v as String);
}

String? _dateToIsoOpt(DateTime? d, {bool dateOnly = true}) {
  if (d == null) return null;
  return dateOnly ? d.toIso8601String().split('T').first : d.toIso8601String();
}

/* *****************************************************************
 *                        MODELLI                                   *
 * *****************************************************************/

/* ---------------------------- ENTITIES -------------------------- */

class Entity {
  final String name;
  final String? address;
  final String? taxCode;
  final String? vat;
  final String? phone;
  final String? email;
  final String? sector;
  final String? legalRep;
  final String? legalRepTaxCode;
  final Map<String, dynamic> adminData;

  Entity({
    required this.name,
    this.address,
    this.taxCode,
    this.vat,
    this.phone,
    this.email,
    this.sector,
    this.legalRep,
    this.legalRepTaxCode,
    Map<String, dynamic>? adminData,
  }) : adminData = adminData ?? const {};

  factory Entity.fromJson(Map<String, dynamic> json) => Entity(
        name: json['name'],
        address: json['address'],
        taxCode: json['tax_code'],
        vat: json['vat'],
        phone: json['phone'],
        email: json['email'],
        sector: json['sector'],
        legalRep: json['legal_rep'],
        legalRepTaxCode: json['legal_rep_tax_code'],
        adminData: (json['admin_data'] is Map)
            ? Map<String, dynamic>.from(json['admin_data'])
            : {},
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'tax_code': taxCode,
        'vat': vat,
        'phone': phone,
        'email': email,
        'sector': sector,
        'legal_rep': legalRep,
        'legal_rep_tax_code': legalRepTaxCode,
        'admin_data': adminData,
      };
}

/* ---------------- CONTRATTO: Sotto-modelli ---------------------- */

class Identificativi {
  final String tipo; // 'Tipo'
  final String? tpCar; // 'TpCar'
  final String ramo; // 'Ramo'
  final String compagnia; // 'Compagnia'
  final String numeroPolizza; // 'NumeroPolizza'

  Identificativi({
    this.tipo = '-',
    this.tpCar,
    this.ramo = '-',
    required this.compagnia,
    required this.numeroPolizza,
  });

  factory Identificativi.fromJson(Map<String, dynamic> json) => Identificativi(
        tipo: json['Tipo'] ?? '-',
        tpCar: json['TpCar'],
        ramo: json['Ramo'] ?? '-',
        compagnia: json['Compagnia'],
        numeroPolizza: json['NumeroPolizza'],
      );

  Map<String, dynamic> toJson() => {
    'Tipo': tipo,
    'TpCar': tpCar,
    'Ramo': ramo,
    'Compagnia': compagnia,
    'NumeroPolizza': numeroPolizza,
  };
}

class UnitaVendita {
  final String puntoVendita;
  final String puntoVendita2;
  final String account;
  final String intermediario;

  UnitaVendita({
    this.puntoVendita = '-',
    this.puntoVendita2 = '-',
    this.account = 'Account Placeholder',
    this.intermediario = 'Intermediario Placeholder',
  });

  factory UnitaVendita.fromJson(Map<String, dynamic> json) => UnitaVendita(
        puntoVendita: json['PuntoVendita'] ?? '-',
        puntoVendita2: json['PuntoVendita2'] ?? '-',
        account: json['Account'] ?? 'Account Placeholder',
        intermediario: json['Intermediario'] ?? 'Intermediario Placeholder',
      );

  Map<String, dynamic> toJson() => {
        'PuntoVendita': puntoVendita,
        'PuntoVendita2': puntoVendita2,
        'Account': account,
        'Intermediario': intermediario,
      };
}

class Amministrativi {
  final DateTime effetto;
  final DateTime dataEmissione;
  final DateTime ultimaRataPagata;
  final String frazionamento; // "annuale" (stringa)
  final bool compresoFirma;
  final DateTime scadenza;
  final DateTime scadenzaOriginaria;
  final DateTime? scadenzaMora;
  final String? numeroProposta;
  final String modalitaIncasso;
  final String? codConvenzione;
  final DateTime? scadenzaVincolo;
  final DateTime? scadenzaCopertura;
  final DateTime? fineCoperturaProroga;

  Amministrativi({
    required this.effetto,
    required this.dataEmissione,
    required this.ultimaRataPagata,
    this.frazionamento = 'annuale',
    this.compresoFirma = false,
    required this.scadenza,
    required this.scadenzaOriginaria,
    this.scadenzaMora,
    this.numeroProposta,
    this.modalitaIncasso = '-',
    this.codConvenzione,
    this.scadenzaVincolo,
    this.scadenzaCopertura,
    this.fineCoperturaProroga,
  });

  factory Amministrativi.fromJson(Map<String, dynamic> json) => Amministrativi(
        effetto: DateTime.parse(json['Effetto']),
        dataEmissione: DateTime.parse(json['DataEmissione']),
        ultimaRataPagata: DateTime.parse(json['UltRataPagata']),
        frazionamento: json['Frazionamento'] ?? 'annuale',
        compresoFirma: (json['CompresoFirma'] ?? false) as bool,
        scadenza: DateTime.parse(json['Scadenza']),
        scadenzaOriginaria: DateTime.parse(json['ScadenzaOriginaria']),
        scadenzaMora: _parseDateOpt(json['ScadenzaMora']),
        numeroProposta: _optStr(json['NumeroProposta']),
        modalitaIncasso: json['ModalitaIncasso'] ?? '-',
        codConvenzione: _optStr(json['CodConvenzione']),
        scadenzaVincolo: _parseDateOpt(json['ScadenzaVincolo']),
        scadenzaCopertura: _parseDateOpt(json['ScadenzaCopertura']),
        fineCoperturaProroga: _parseDateOpt(json['FineCoperturaProroga']),
      );

  Map<String, dynamic> toJson() => {
        'Effetto': _dateToIsoOpt(effetto),
        'DataEmissione': _dateToIsoOpt(dataEmissione),
        'UltRataPagata': _dateToIsoOpt(ultimaRataPagata),
        'Frazionamento': frazionamento,
        'CompresoFirma': compresoFirma,
        'Scadenza': _dateToIsoOpt(scadenza),
        'ScadenzaOriginaria': _dateToIsoOpt(scadenzaOriginaria),
        'ScadenzaMora': _dateToIsoOpt(scadenzaMora),
        'NumeroProposta': numeroProposta,
        'ModalitaIncasso': modalitaIncasso,
        'CodConvenzione': codConvenzione,
        'ScadenzaVincolo': _dateToIsoOpt(scadenzaVincolo),
        'ScadenzaCopertura': _dateToIsoOpt(scadenzaCopertura),
        'FineCoperturaProroga': _dateToIsoOpt(fineCoperturaProroga),
      };
}

class Premi {
  final String premio;
  final String netto;
  final String accessori;
  final String diritti;
  final String imposte;
  final String spese;
  final String fondo;
  final String? sconto;

  Premi({
    this.premio = '0.00',
    this.netto = '0.00',
    this.accessori = '0.00',
    this.diritti = '0.00',
    this.imposte = '0.00',
    this.spese = '0.00',
    this.fondo = '0.00',
    this.sconto,
  });

  factory Premi.fromJson(Map<String, dynamic> json) => Premi(
        premio: _optStr(json['Premio']) ?? '0.00',
        netto: _optStr(json['Netto']) ?? '0.00',
        accessori: _optStr(json['Accessori']) ?? '0.00',
        diritti: _optStr(json['Diritti']) ?? '0.00',
        imposte: _optStr(json['Imposte']) ?? '0.00',
        spese: _optStr(json['Spese']) ?? '0.00',
        fondo: _optStr(json['Fondo']) ?? '0.00',
        sconto: _optStr(json['Sconto']),
      );

  Map<String, dynamic> toJson() => {
        'Premio': premio,
        'Netto': netto,
        'Accessori': accessori,
        'Diritti': diritti,
        'Imposte': imposte,
        'Spese': spese,
        'Fondo': fondo,
        'Sconto': sconto,
      };
}

class Rinnovo {
  final String rinnovo;
  final String disdetta;
  final String giorniMora;
  final String proroga;

  Rinnovo({
    this.rinnovo = 'da definire',
    this.disdetta = '-',
    this.giorniMora = '0 giorni',
    this.proroga = '-',
  });

  factory Rinnovo.fromJson(Map<String, dynamic> json) => Rinnovo(
        rinnovo: json['Rinnovo'] ?? 'da definire',
        disdetta: json['Disdetta'] ?? '-',
        giorniMora: json['GiorniMora'] ?? '0 giorni',
        proroga: json['Proroga'] ?? '-',
      );

  Map<String, dynamic> toJson() => {
        'Rinnovo': rinnovo,
        'Disdetta': disdetta,
        'GiorniMora': giorniMora,
        'Proroga': proroga,
      };
}

class ParametriRegolazione {
  final DateTime inizio;
  final DateTime fine;
  final DateTime? ultimaRegEmessa;
  final int? giorniInvioDati;
  final int? giorniPagReg;
  final int? giorniMoraRegolazione;
  final String cadenzaRegolazione;

  ParametriRegolazione({
    required this.inizio,
    required this.fine,
    this.ultimaRegEmessa,
    this.giorniInvioDati,
    this.giorniPagReg,
    this.giorniMoraRegolazione,
    this.cadenzaRegolazione = 'annuale',
  });

  factory ParametriRegolazione.fromJson(Map<String, dynamic> json) =>
      ParametriRegolazione(
        inizio: DateTime.parse(json['Inizio']),
        fine: DateTime.parse(json['Fine']),
        ultimaRegEmessa: _parseDateOpt(json['UltimaRegEmessa']),
        giorniInvioDati: json['GiorniInvioDati'],
        giorniPagReg: json['GiorniPagReg'],
        giorniMoraRegolazione: json['GiorniMoraRegolazione'],
        cadenzaRegolazione: json['CadenzaRegolazione'] ?? 'annuale',
      );

  Map<String, dynamic> toJson() => {
        'Inizio': _dateToIsoOpt(inizio),
        'Fine': _dateToIsoOpt(fine),
        'UltimaRegEmessa': _dateToIsoOpt(ultimaRegEmessa),
        'GiorniInvioDati': giorniInvioDati,
        'GiorniPagReg': giorniPagReg,
        'GiorniMoraRegolazione': giorniMoraRegolazione,
        'CadenzaRegolazione': cadenzaRegolazione,
      };
}

class Operativita {
  final bool regolazione;
  final ParametriRegolazione parametriRegolazione;

  Operativita({
    this.regolazione = false,
    ParametriRegolazione? parametriRegolazione,
  }) : parametriRegolazione =
            parametriRegolazione ??
            ParametriRegolazione(
              inizio: DateTime.now(),
              fine: DateTime.now(),
            );

  factory Operativita.fromJson(Map<String, dynamic> json) => Operativita(
        regolazione: (json['Regolazione'] ?? false) as bool,
        parametriRegolazione:
            ParametriRegolazione.fromJson(json['ParametriRegolazione']),
      );

  Map<String, dynamic> toJson() => {
        'Regolazione': regolazione,
        'ParametriRegolazione': parametriRegolazione.toJson(),
      };
}

class RamiEl {
  final String descrizione;
  RamiEl({this.descrizione = 'Descrizione Generica Rischio'});

  factory RamiEl.fromJson(Map<String, dynamic> json) =>
      RamiEl(descrizione: json['Descrizione'] ?? 'Descrizione Generica Rischio');

  Map<String, dynamic> toJson() => {'Descrizione': descrizione};
}

/// Modello principale di contratto Omnia 8 (alias JSON originali)
class ContrattoOmnia8 {
  final Identificativi identificativi; // "Identificativi"
  final UnitaVendita? unitaVendita; // "UnitaVendita" (opz.)
  final Amministrativi? amministrativi; // "Amministrativi" (opz.)
  final Premi? premi; // "Premi" (opz.)
  final Rinnovo? rinnovo; // "Rinnovo" (opz.)
  final Operativita? operativita; // "Operativita" (opz.)
  final RamiEl? ramiEl; // "RamiEl" (opz.)

  ContrattoOmnia8({
    required this.identificativi,
    this.unitaVendita,
    this.amministrativi,
    this.premi,
    this.rinnovo,
    this.operativita,
    this.ramiEl,
  });

  factory ContrattoOmnia8.fromJson(Map<String, dynamic> json) =>
      ContrattoOmnia8(
        identificativi: Identificativi.fromJson(json['Identificativi']),
        unitaVendita:
            json['UnitaVendita'] != null ? UnitaVendita.fromJson(json['UnitaVendita']) : null,
        amministrativi: json['Amministrativi'] != null
            ? Amministrativi.fromJson(json['Amministrativi'])
            : null,
        premi: json['Premi'] != null ? Premi.fromJson(json['Premi']) : null,
        rinnovo: json['Rinnovo'] != null ? Rinnovo.fromJson(json['Rinnovo']) : null,
        operativita: json['Operativita'] != null
            ? Operativita.fromJson(json['Operativita'])
            : null,
        ramiEl: json['RamiEl'] != null ? RamiEl.fromJson(json['RamiEl']) : null,
      );

  Map<String, dynamic> toJson() => {
        'Identificativi': identificativi.toJson(),
        if (unitaVendita != null) 'UnitaVendita': unitaVendita!.toJson(),
        if (amministrativi != null) 'Amministrativi': amministrativi!.toJson(),
        if (premi != null) 'Premi': premi!.toJson(),
        if (rinnovo != null) 'Rinnovo': rinnovo!.toJson(),
        if (operativita != null) 'Operativita': operativita!.toJson(),
        if (ramiEl != null) 'RamiEl': ramiEl!.toJson(),
      };
}

/* ----------------------------- TITOLI --------------------------- */

class Titolo {
  // Obbligatori
  final String tipo; // enum: RATA/QUIETANZA/APPENDICE/VARIAZIONE
  final DateTime effettoTitolo;
  final DateTime scadenzaTitolo;
  // Opzionali/economici
  final String? descrizione;
  final String? progressivo;
  final String stato; // enum: DA_PAGARE/PAGATO/ANNULLATO/INSOLUTO
  final String imponibile; // string per coerenza API
  final String premioLordo;
  final String imposte;
  final String accessori;
  final String diritti;
  final String spese;
  final String frazionamento; // enum ANNUALE/SEMESTRALE/TRIMESTRALE/MENSILE
  final int giorniMora;
  final String? cig;
  final String? pv;
  final String? pv2;
  final String? quietanzaNumero;
  final DateTime? dataPagamento;
  final String? metodoIncasso;
  // Denormalizzazioni
  final String? numeroPolizza;
  final String? entityId;

  Titolo({
    required this.tipo,
    required this.effettoTitolo,
    required this.scadenzaTitolo,
    this.descrizione,
    this.progressivo,
    this.stato = 'DA_PAGARE',
    this.imponibile = '0.00',
    this.premioLordo = '0.00',
    this.imposte = '0.00',
    this.accessori = '0.00',
    this.diritti = '0.00',
    this.spese = '0.00',
    this.frazionamento = 'ANNUALE',
    this.giorniMora = 0,
    this.cig,
    this.pv,
    this.pv2,
    this.quietanzaNumero,
    this.dataPagamento,
    this.metodoIncasso,
    this.numeroPolizza,
    this.entityId,
  });

  factory Titolo.fromJson(Map<String, dynamic> json) => Titolo(
        tipo: json['tipo'],
        effettoTitolo: DateTime.parse(json['effetto_titolo']),
        scadenzaTitolo: DateTime.parse(json['scadenza_titolo']),
        descrizione: _optStr(json['descrizione']),
        progressivo: _optStr(json['progressivo']),
        stato: json['stato'] ?? 'DA_PAGARE',
        imponibile: _optStr(json['imponibile']) ?? '0.00',
        premioLordo: _optStr(json['premio_lordo']) ?? '0.00',
        imposte: _optStr(json['imposte']) ?? '0.00',
        accessori: _optStr(json['accessori']) ?? '0.00',
        diritti: _optStr(json['diritti']) ?? '0.00',
        spese: _optStr(json['spese']) ?? '0.00',
        frazionamento: json['frazionamento'] ?? 'ANNUALE',
        giorniMora: (json['giorni_mora'] ?? 0) as int,
        cig: _optStr(json['cig']),
        pv: _optStr(json['pv']),
        pv2: _optStr(json['pv2']),
        quietanzaNumero: _optStr(json['quietanza_numero']),
        dataPagamento: _parseDateOpt(json['data_pagamento']),
        metodoIncasso: _optStr(json['metodo_incasso']),
        numeroPolizza: _optStr(json['numero_polizza']),
        entityId: _optStr(json['entity_id']),
      );

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'effetto_titolo': _dateToIsoOpt(effettoTitolo),
        'scadenza_titolo': _dateToIsoOpt(scadenzaTitolo),
        'descrizione': descrizione,
        'progressivo': progressivo,
        'stato': stato,
        'imponibile': imponibile,
        'premio_lordo': premioLordo,
        'imposte': imposte,
        'accessori': accessori,
        'diritti': diritti,
        'spese': spese,
        'frazionamento': frazionamento,
        'giorni_mora': giorniMora,
        'cig': cig,
        'pv': pv,
        'pv2': pv2,
        'quietanza_numero': quietanzaNumero,
        'data_pagamento': _dateToIsoOpt(dataPagamento),
        'metodo_incasso': metodoIncasso,
        'numero_polizza': numeroPolizza,
        'entity_id': entityId,
      };
}

/* ----------------------------- SINISTRI ------------------------- */

class Sinistro {
  final int esercizio;
  final String numeroSinistro;
  final String? numeroSinistroCompagnia;
  final String? numeroPolizza;
  final String? compagnia;
  final String? rischio;
  final String? intermediario;
  final String? descrizioneAssicurato;
  final DateTime dataAvvenimento;
  final String? citta;
  final String? indirizzo;
  final String? cap;
  final String? provincia;
  final String? codiceStato;
  final String? targa;
  final String? dinamica;
  final String? statoCompagnia;
  final DateTime dataApertura;
  final DateTime? dataChiusura;

  Sinistro({
    required this.esercizio,
    required this.numeroSinistro,
    this.numeroSinistroCompagnia,
    this.numeroPolizza,
    this.compagnia,
    this.rischio,
    this.intermediario,
    this.descrizioneAssicurato,
    required this.dataAvvenimento,
    this.citta,
    this.indirizzo,
    this.cap,
    this.provincia,
    this.codiceStato,
    this.targa,
    this.dinamica,
    this.statoCompagnia,
    DateTime? dataApertura,
    this.dataChiusura,
  }) : dataApertura = dataApertura ?? DateTime.now();

  factory Sinistro.fromJson(Map<String, dynamic> json) => Sinistro(
        esercizio: json['esercizio'],
        numeroSinistro: json['numero_sinistro'],
        numeroSinistroCompagnia: _optStr(json['numero_sinistro_compagnia']),
        numeroPolizza: _optStr(json['numero_polizza']),
        compagnia: _optStr(json['compagnia']),
        rischio: _optStr(json['rischio']),
        intermediario: _optStr(json['intermediario']),
        descrizioneAssicurato: _optStr(json['descrizione_assicurato']),
        dataAvvenimento: DateTime.parse(json['data_avvenimento']),
        citta: _optStr(json['città']) ?? _optStr(json['citta']),
        indirizzo: _optStr(json['indirizzo']),
        cap: _optStr(json['cap']),
        provincia: _optStr(json['provincia']),
        codiceStato: _optStr(json['codice_stato']),
        targa: _optStr(json['targa']),
        dinamica: _optStr(json['dinamica']),
        statoCompagnia: _optStr(json['stato_compagnia']),
        dataApertura: _parseDateOpt(json['data_apertura']),
        dataChiusura: _parseDateOpt(json['data_chiusura']),
      );

  Map<String, dynamic> toJson() => {
        'esercizio': esercizio,
        'numero_sinistro': numeroSinistro,
        'numero_sinistro_compagnia': numeroSinistroCompagnia,
        'numero_polizza': numeroPolizza,
        'compagnia': compagnia,
        'rischio': rischio,
        'intermediario': intermediario,
        'descrizione_assicurato': descrizioneAssicurato,
        'data_avvenimento': _dateToIsoOpt(dataAvvenimento),
        'città': citta,
        'indirizzo': indirizzo,
        'cap': cap,
        'provincia': provincia,
        'codice_stato': codiceStato,
        'targa': targa,
        'dinamica': dinamica,
        'stato_compagnia': statoCompagnia,
        'data_apertura': _dateToIsoOpt(dataApertura),
        'data_chiusura': _dateToIsoOpt(dataChiusura),
      };
}

/* ----------------------------- DIARIO --------------------------- */

class DiarioEntry {
  final String autore;
  final DateTime? timestamp; // server-side default se assente
  final String testo;

  DiarioEntry({required this.autore, required this.testo, this.timestamp});

  factory DiarioEntry.fromJson(Map<String, dynamic> json) => DiarioEntry(
        autore: json['autore'],
        testo: json['testo'],
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      );

  Map<String, dynamic> toJson() => {
        'autore': autore,
        'testo': testo,
        if (timestamp != null) 'timestamp': _dateToIsoOpt(timestamp, dateOnly: false),
      };
}

class DiaryEntryItem {
  final String entryId;
  final DiarioEntry entry;
  DiaryEntryItem({required this.entryId, required this.entry});

  factory DiaryEntryItem.fromJson(Map<String, dynamic> json) => DiaryEntryItem(
        entryId: json['entry_id'] ?? json['id'] ?? '',
        entry: DiarioEntry.fromJson(json),
      );
}

/* --------------------------- DOCUMENTI -------------------------- */

class DocumentoMeta {
  final String scope; // enum: CONTRATTO,TITOLO,SINISTRO,GARA
  final String categoria; // enum: CND,APP,CLAIM,ALTRO
  final String mime;
  final String nomeOriginale;
  final int size;
  final String? hash;
  final String? pathRelativo;
  final Map<String, dynamic> metadati;

  DocumentoMeta({
    required this.scope,
    required this.categoria,
    required this.mime,
    required this.nomeOriginale,
    required this.size,
    this.hash,
    this.pathRelativo,
    Map<String, dynamic>? metadati,
  }) : metadati = metadati ?? const {};

  factory DocumentoMeta.fromJson(Map<String, dynamic> json) => DocumentoMeta(
        scope: json['scope'],
        categoria: json['categoria'],
        mime: json['mime'],
        nomeOriginale: json['nome_originale'],
        size: (json['size'] as num).toInt(),
        hash: _optStr(json['hash']),
        pathRelativo: _optStr(json['path_relativo']),
        metadati: (json['metadati'] is Map) ? Map<String, dynamic>.from(json['metadati']) : {},
      );

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'categoria': categoria,
        'mime': mime,
        'nome_originale': nomeOriginale,
        'size': size,
        'hash': hash,
        'path_relativo': pathRelativo,
        'metadati': metadati,
      };
}

class CreateDocumentRequest {
  final DocumentoMeta meta;
  final String? contentBase64;

  CreateDocumentRequest({required this.meta, this.contentBase64});

  Map<String, dynamic> toJson() =>
      {'meta': meta.toJson(), if (contentBase64 != null) 'content_base64': contentBase64};
}

class CreateResponse {
  final String id;
  CreateResponse({required this.id});
  factory CreateResponse.fromJson(Map<String, dynamic> json) => CreateResponse(id: json['id']);
}

class DeleteResponse {
  final bool deleted;
  final String id;
  DeleteResponse({required this.deleted, required this.id});
  factory DeleteResponse.fromJson(Map<String, dynamic> json) =>
      DeleteResponse(deleted: (json['deleted'] ?? true) as bool, id: json['id']);
}

/* --------------------------- RESPONSES VARIE -------------------- */

class CreateContractResponse {
  final String contractId;
  final ContrattoOmnia8 contratto;
  CreateContractResponse({required this.contractId, required this.contratto});
  factory CreateContractResponse.fromJson(Map<String, dynamic> json) =>
      CreateContractResponse(
        contractId: json['contract_id'],
        contratto: ContrattoOmnia8.fromJson(json['contratto']),
      );
}

class CreateTitleResponse {
  final String titleId;
  final Titolo titolo;
  CreateTitleResponse({required this.titleId, required this.titolo});
  factory CreateTitleResponse.fromJson(Map<String, dynamic> json) =>
      CreateTitleResponse(
        titleId: json['title_id'],
        titolo: Titolo.fromJson(json['titolo']),
      );
}

class CreateClaimResponse {
  final String claimId;
  final Sinistro sinistro;
  CreateClaimResponse({required this.claimId, required this.sinistro});
  factory CreateClaimResponse.fromJson(Map<String, dynamic> json) =>
      CreateClaimResponse(
        claimId: json['claim_id'],
        sinistro: Sinistro.fromJson(json['sinistro']),
      );
}

class AddDiaryEntryResponse {
  final String id;
  AddDiaryEntryResponse({required this.id});
  factory AddDiaryEntryResponse.fromJson(Map<String, dynamic> json) => AddDiaryEntryResponse(id: json['id']);
}

/* *****************************************************************
 *                         SDK HTTP                                *
 * *****************************************************************/

class Omnia8Sdk {
  /// Base URL dell’API (es. http://127.0.0.1:8111).
  final String baseUrl;

  /// Client HTTP sottostante (iniettabile per test).
  final http.Client _http;

  /// Header di default (es. Authorization).
  final Map<String, String> defaultHeaders;

  Omnia8Sdk({
    this.baseUrl = 'https://www.goldbitweb.com/enac-api/', //'https://www.goldbitweb.com/enac-api/', //'http://127.0.0.1:8111',
    http.Client? httpClient,
    Map<String, String>? headers,
  })  : _http = httpClient ?? http.Client(),
        defaultHeaders = {
          'Content-Type': 'application/json',
          if (headers != null) ...headers,
        };

  /// Chiude il client HTTP.
  void dispose() => _http.close();

Uri _buildUri(String path, [Map<String, dynamic>? query]) {
  // 1) normalizza la base: forziamo il trailing slash
  final base = Uri.parse(baseUrl);
  final normalizedBase = base.replace(
    path: base.path.endsWith('/') ? base.path : '${base.path}/',
  );

  // 2) normalizza il child: rimuovi l'eventuale leading slash
  final childPath = path.startsWith('/') ? path.substring(1) : path;

  // 3) prepara i query params come stringhe
  final qp = <String, String>{};
  (query ?? {}).forEach((k, v) {
    if (v != null) qp[k] = v.toString();
  });

  // 4) risolvi come *relativo* sulla base normalizzata
  final child = Uri(path: childPath, queryParameters: qp);
  return normalizedBase.resolveUri(child);
}


  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    int? expectedStatus, // opzionale, altrimenti accetta 2xx
  }) async {
    final uri = _buildUri(path, query);
    final hdrs = {...defaultHeaders, if (headers != null) ...headers};
    late http.Response res;

    switch (method) {
      case 'GET':
        res = await _http.get(uri, headers: hdrs);
        break;
      case 'POST':
        res = await _http.post(uri, headers: hdrs, body: jsonEncode(body ?? {}));
        break;
      case 'PUT':
        res = await _http.put(uri, headers: hdrs, body: jsonEncode(body ?? {}));
        break;
      case 'DELETE':
        res = await _http.delete(uri, headers: hdrs);
        break;
      default:
        throw ArgumentError('Metodo HTTP non supportato: $method');
    }

    final ok = expectedStatus != null
        ? (res.statusCode == expectedStatus)
        : (res.statusCode >= 200 && res.statusCode < 300);

    if (!ok) {
      throw ApiException(res.statusCode, res.body);
    }
    return res.body.isNotEmpty ? jsonDecode(res.body) : null;
  }

  Future<Uint8List> _requestBytes(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, query);
    final hdrs = {...defaultHeaders, if (headers != null) ...headers};
    late http.Response res;

    switch (method) {
      case 'GET':
        res = await _http.get(uri, headers: hdrs);
        break;
      default:
        throw ArgumentError('Metodo HTTP non supportato (bytes): $method');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, res.body);
    }
    return res.bodyBytes;
  }

  /* --------------------------- /ping ----------------------------- */

  Future<bool> ping() async {
    final data = await _request('GET', '/ping') as Map<String, dynamic>;
    // Alcune implementazioni possono restituire semplicemente {}:
    // interpretiamo qualunque 200 come "ok".
    if (data.isEmpty) return true;
    return data['status'] == 'ok' || data['ping'] == 'ok';
  }

  /* ------------------------- ENTITIES ---------------------------- */

  Future<Entity> createEntity(String userId, String entityId, Entity payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId',
      body: payload.toJson(),
      expectedStatus: 201,
    ) as Map<String, dynamic>;
    return Entity.fromJson(json);
  }

  Future<List<String>> listEntities(String userId) async {
    final data = await _request('GET', '/users/$userId/entities') as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<Entity> getEntity(String userId, String entityId) async {
    final json = await _request('GET', '/users/$userId/entities/$entityId') as Map<String, dynamic>;
    return Entity.fromJson(json);
  }

  Future<Entity> updateEntity(String userId, String entityId, Entity payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return Entity.fromJson(json);
  }

  Future<DeleteResponse> deleteEntity(String userId, String entityId) async {
    final json = await _request('DELETE', '/users/$userId/entities/$entityId') as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* ------------------------- CONTRACTS --------------------------- */

  Future<CreateContractResponse> createContract(
      String userId, String entityId, ContrattoOmnia8 payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateContractResponse.fromJson(json);
  }

  Future<List<String>> listContracts(String userId, String entityId) async {
    final data =
        await _request('GET', '/users/$userId/entities/$entityId/contracts') as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<ContrattoOmnia8> getContract(String userId, String entityId, String contractId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId',
    ) as Map<String, dynamic>;
    return ContrattoOmnia8.fromJson(json);
  }

  Future<ContrattoOmnia8> updateContract(
      String userId, String entityId, String contractId, ContrattoOmnia8 payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return ContrattoOmnia8.fromJson(json);
  }

  Future<DeleteResponse> deleteContract(String userId, String entityId, String contractId) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId',
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* --------------------------- TITLES ---------------------------- */

  Future<CreateTitleResponse> createTitle(
      String userId, String entityId, String contractId, Titolo payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateTitleResponse.fromJson(json);
  }

  Future<List<String>> listTitles(String userId, String entityId, String contractId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles',
    ) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<Titolo> getTitle(
      String userId, String entityId, String contractId, String titleId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId',
    ) as Map<String, dynamic>;
    return Titolo.fromJson(json);
  }

  Future<Titolo> updateTitle(
      String userId, String entityId, String contractId, String titleId, Titolo payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return Titolo.fromJson(json);
  }

  Future<DeleteResponse> deleteTitle(
      String userId, String entityId, String contractId, String titleId) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId',
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* --------------------------- CLAIMS ---------------------------- */

  Future<CreateClaimResponse> createClaim(
      String userId, String entityId, String contractId, Sinistro payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateClaimResponse.fromJson(json);
  }

  Future<List<String>> listClaims(String userId, String entityId, String contractId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims',
    ) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<Sinistro> getClaim(
      String userId, String entityId, String contractId, String claimId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId',
    ) as Map<String, dynamic>;
    return Sinistro.fromJson(json);
  }

  Future<Sinistro> updateClaim(String userId, String entityId, String contractId, String claimId,
      Sinistro payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return Sinistro.fromJson(json);
  }

  Future<DeleteResponse> deleteClaim(
      String userId, String entityId, String contractId, String claimId) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId',
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* ---------------------------- DIARY ---------------------------- */

  Future<AddDiaryEntryResponse> addDiaryEntry(String userId, String entityId, String contractId,
      String claimId, DiarioEntry payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/diary',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return AddDiaryEntryResponse.fromJson(json);
  }

  Future<List<DiaryEntryItem>> listDiaryEntries(
      String userId, String entityId, String contractId, String claimId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/diary',
    ) as List<dynamic>;
    return data
        .map((e) => DiaryEntryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DiaryEntryItem> getDiaryEntry(
      String userId, String entityId, String contractId, String claimId, String entryId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/diary/$entryId',
    ) as Map<String, dynamic>;
    return DiaryEntryItem.fromJson(json);
  }

  Future<DiaryEntryItem> updateDiaryEntry(String userId, String entityId, String contractId,
      String claimId, String entryId, DiarioEntry payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/diary/$entryId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return DiaryEntryItem.fromJson(json);
  }

  Future<DeleteResponse> deleteDiaryEntry(
      String userId, String entityId, String contractId, String claimId, String entryId) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/diary/$entryId',
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* --------------------------- DOCUMENTS ------------------------- */
  // --------- Contract docs

  Future<List<String>> listContractDocs(
      String userId, String entityId, String contractId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents',
    ) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<CreateResponse> createContractDoc(
      String userId, String entityId, String contractId, CreateDocumentRequest payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> getContractDocMeta(
      String userId, String entityId, String contractId, String docId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents/$docId',
    ) as Map<String, dynamic>;
    return json;
  }

  Future<Map<String, dynamic>> updateContractDoc(String userId, String entityId,
      String contractId, String docId, CreateDocumentRequest payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents/$docId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return json;
  }

  Future<DeleteResponse> deleteContractDoc(
      String userId, String entityId, String contractId, String docId,
      {bool deleteBlob = false}) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents/$docId',
      query: {'delete_blob': deleteBlob},
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  Future<Uint8List> downloadContractDoc(
      String userId, String entityId, String contractId, String docId) async {
    return _requestBytes(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/documents/$docId/download',
    );
  }

  // --------- Claim docs

  Future<List<String>> listClaimDocs(
      String userId, String entityId, String contractId, String claimId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents',
    ) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<CreateResponse> createClaimDoc(String userId, String entityId, String contractId,
      String claimId, CreateDocumentRequest payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> getClaimDocMeta(
      String userId, String entityId, String contractId, String claimId, String docId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents/$docId',
    ) as Map<String, dynamic>;
    return json;
  }

  Future<Map<String, dynamic>> updateClaimDoc(String userId, String entityId, String contractId,
      String claimId, String docId, CreateDocumentRequest payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents/$docId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return json;
  }

  Future<DeleteResponse> deleteClaimDoc(String userId, String entityId, String contractId,
      String claimId, String docId, {bool deleteBlob = false}) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents/$docId',
      query: {'delete_blob': deleteBlob},
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  Future<Uint8List> downloadClaimDoc(
      String userId, String entityId, String contractId, String claimId, String docId) async {
    return _requestBytes(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/claims/$claimId/documents/$docId/download',
    );
  }

  // --------- Title docs

  Future<List<String>> listTitleDocs(
      String userId, String entityId, String contractId, String titleId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents',
    ) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<CreateResponse> createTitleDoc(String userId, String entityId, String contractId,
      String titleId, CreateDocumentRequest payload) async {
    final json = await _request(
      'POST',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return CreateResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> getTitleDocMeta(
      String userId, String entityId, String contractId, String titleId, String docId) async {
    final json = await _request(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents/$docId',
    ) as Map<String, dynamic>;
    return json;
  }

  Future<Map<String, dynamic>> updateTitleDoc(String userId, String entityId, String contractId,
      String titleId, String docId, CreateDocumentRequest payload) async {
    final json = await _request(
      'PUT',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents/$docId',
      body: payload.toJson(),
    ) as Map<String, dynamic>;
    return json;
  }

  Future<DeleteResponse> deleteTitleDoc(String userId, String entityId, String contractId,
      String titleId, String docId, {bool deleteBlob = false}) async {
    final json = await _request(
      'DELETE',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents/$docId',
      query: {'delete_blob': deleteBlob},
    ) as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  Future<Uint8List> downloadTitleDoc(
      String userId, String entityId, String contractId, String titleId, String docId) async {
    return _requestBytes(
      'GET',
      '/users/$userId/entities/$entityId/contracts/$contractId/titles/$titleId/documents/$docId/download',
    );
  }

  /* ---------------------------- VIEWS ---------------------------- */

  Future<List<Map<String, dynamic>>> viewEntityTitles(String userId, String entityId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/titles',
    ) as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> viewEntityClaims(String userId, String entityId) async {
    final data = await _request(
      'GET',
      '/users/$userId/entities/$entityId/claims',
    ) as List<dynamic>;
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> searchByPolicy(String userId, String numeroPolizza) async {
    final data = await _request(
      'GET',
      '/users/$userId/search/policy/$numeroPolizza',
    ) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> dashboardDue(String userId, {int days = 120}) async {
    final data = await _request(
      'GET',
      '/users/$userId/dashboard/due',
      query: {'days': days},
    ) as Map<String, dynamic>;
    return data;
  }

  // -------- Derived Views (Contracts) -----------------------------------
/// Vista contratti per una singola entità, costruita client-side
/// proiettando i campi più utili per la UI.
Future<List<Map<String, dynamic>>> viewEntityContracts(
  String userId,
  String entityId,
) async {
  final ids = await listContracts(userId, entityId);
  final rows = <Map<String, dynamic>>[];

  // fetch in piccoli lotti per non saturare la rete
  const chunk = 10;
  for (var i = 0; i < ids.length; i += chunk) {
    final slice = ids.sublist(i, (i + chunk > ids.length) ? ids.length : i + chunk);

    final contracts = await Future.wait(slice.map((cid) async {
      try {
        final c = await getContract(userId, entityId, cid);
        return MapEntry(cid, c);
      } catch (_) {
        return null; // skip in caso d'errore su uno specifico contratto
      }
    }));

    for (final pair in contracts) {
      if (pair == null) continue;
      final cid = pair.key;
      final c   = pair.value;

      final amm   = c.amministrativi;
      final premi = c.premi;

      rows.add({
        'entity_id'     : entityId,
        'contract_id'   : cid,
        'compagnia'     : c.identificativi.compagnia,
        'numero_polizza': c.identificativi.numeroPolizza,
        'ramo'          : c.identificativi.ramo,
        'decorrenza'    : _dateToIsoOpt(amm?.effetto),
        'scadenza'      : _dateToIsoOpt(amm?.scadenza),
        'premio'        : premi?.premio,
        'premio_annuo'  : premi?.premio,
        'stato'         : c.rinnovo?.rinnovo, // se presente/ha senso
      });
    }
  }

  return rows;
}

/// Vista contratti globale (tutte le entità dell’utente), aggregata client-side.
Future<List<Map<String, dynamic>>> viewAllContracts(String userId) async {
  final entityIds = await listEntities(userId);
  final out = <Map<String, dynamic>>[];
  for (final eid in entityIds) {
    try {
      final rows = await viewEntityContracts(userId, eid);
      out.addAll(rows);
    } catch (_) {
      // ignora singola entità in errore
    }
  }
  return out;
}

/// Vista TITOLI per un contratto specifico (proiezione client-side)
Future<List<Map<String, dynamic>>> viewContractTitles(
  String userId,
  String entityId,
  String contractId,
) async {
  // carico il contratto una sola volta per campi condivisi (compagnia, polizza, rischio…)
  ContrattoOmnia8? contratto;
  try {
    contratto = await getContract(userId, entityId, contractId);
  } catch (_) {
    // opzionale: puoi ignorare se il BE non espone il contratto
  }

  final titleIds = await listTitles(userId, entityId, contractId);
  final out = <Map<String, dynamic>>[];

  const chunk = 10;
  for (var i = 0; i < titleIds.length; i += chunk) {
    final slice = titleIds.sublist(i, (i + chunk > titleIds.length) ? titleIds.length : i + chunk);

    final fetched = await Future.wait(slice.map((tid) async {
      try {
        final t = await getTitle(userId, entityId, contractId, tid);
        return MapEntry(tid, t);
      } catch (_) {
        return null; // skip singolo elemento in errore
      }
    }));

    for (final p in fetched) {
      if (p == null) continue;
      final tid = p.key;
      final t   = p.value;

      final rischio = contratto?.ramiEl?.descrizione ?? contratto?.identificativi.ramo ?? '';
      final compagnia = contratto?.identificativi.compagnia ?? '';
      final numPolizza = contratto?.identificativi.numeroPolizza ?? '';

      out.add({
        // identificativi e riferimenti
        'entity_id'     : entityId,
        'contract_id'   : contractId,
        'title_id'      : tid,
        'id'            : tid,         // alias comodo
        'TitleId'       : tid,         // altro alias

        // contesto contratto utile alla UI
        'compagnia'     : compagnia,
        'numero_polizza': numPolizza,
        'rischio'       : rischio,

        // campi del titolo (con alias)
        'tipo'            : t.tipo,
        'effetto_titolo'  : _dateToIsoOpt(t.effettoTitolo),
        'scadenza_titolo' : _dateToIsoOpt(t.scadenzaTitolo),
        'stato'           : t.stato,
        'pv'              : t.pv,
        'PV'              : t.pv,              // alias
        'pv2'             : t.pv2,
        'PV2'             : t.pv2,             // alias
        'premio_lordo'    : t.premioLordo,
        'PremioLordo'     : t.premioLordo,     // alias
        'premio'          : t.premioLordo,     // fallback usato in alcune viste
      });
    }
  }

  return out;
}

/// Vista SINISTRI per un contratto specifico (proiezione client-side)
Future<List<Map<String, dynamic>>> viewContractClaims(
  String userId,
  String entityId,
  String contractId,
) async {
  // carico il contratto una volta per info condivise
  ContrattoOmnia8? contratto;
  try {
    contratto = await getContract(userId, entityId, contractId);
  } catch (_) {}

  final claimIds = await listClaims(userId, entityId, contractId);
  final out = <Map<String, dynamic>>[];

  const chunk = 10;
  for (var i = 0; i < claimIds.length; i += chunk) {
    final slice = claimIds.sublist(i, (i + chunk > claimIds.length) ? claimIds.length : i + chunk);

    final fetched = await Future.wait(slice.map((cid) async {
      try {
        final c = await getClaim(userId, entityId, contractId, cid);
        return MapEntry(cid, c);
      } catch (_) {
        return null;
      }
    }));

    for (final p in fetched) {
      if (p == null) continue;
      final claimId = p.key;
      final s       = p.value;

      final compagnia  = s.compagnia ?? contratto?.identificativi.compagnia ?? '';
      final numPolizza = s.numeroPolizza ?? contratto?.identificativi.numeroPolizza ?? '';
      final rischio    = s.rischio ?? contratto?.ramiEl?.descrizione ?? contratto?.identificativi.ramo ?? '';

      out.add({
        // riferimenti
        'entity_id'   : entityId,
        'contract_id' : contractId,
        'claim_id'    : claimId,
        'id'          : claimId,        // alias
        'SinistroId'  : claimId,        // alias

        // contesto contratto utile alla UI
        'compagnia'      : compagnia,
        'numero_polizza' : numPolizza,
        'rischio'        : rischio,

        // campi sinistro (con alias compatibili con le tabelle)
        'esercizio'        : s.esercizio,
        'Esercizio'        : s.esercizio,                 // alias
        'numero_sinistro'  : s.numeroSinistro,
        'NumeroSinistro'   : s.numeroSinistro,            // alias
        'num_sinistro'     : s.numeroSinistro,            // alias
        'data_avvenimento' : _dateToIsoOpt(s.dataAvvenimento),
        'DataAvvenimento'  : _dateToIsoOpt(s.dataAvvenimento), // alias

        // l’SDK del modello base non ha importo: lo lasciamo nullo (la UI gestisce '—')
        'importo_liquidato': null,
        'ImportoLiquidato' : null,
        'importo'          : null,

        'targa'           : s.targa ?? '',
        'Targa'           : s.targa ?? '',                // alias
        'dinamica'        : s.dinamica ?? '',
        'Dinamica'        : s.dinamica ?? '',
        'danneggiamento'  : s.dinamica ?? '',             // alias alternativo usato in alcune viste
        'stato_compagnia' : s.statoCompagnia ?? '',
        'StatoCompagnia'  : s.statoCompagnia ?? '',
        'codice_stato'    : s.codiceStato ?? '',
        'CodiceStato'     : s.codiceStato ?? '',
        'data_apertura'   : _dateToIsoOpt(s.dataApertura, dateOnly: false),
        'data_chiusura'   : _dateToIsoOpt(s.dataChiusura, dateOnly: false),
      });
    }
  }

  return out;
}


}
