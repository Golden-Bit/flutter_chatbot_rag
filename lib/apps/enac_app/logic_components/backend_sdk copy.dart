/* omnia8_sdk.dart
 * ---------------------------------------------------------------
 * SDK Flutter/Dart per l’API REST “Omnia 8 File‑API”
 * Copre tutti gli end‑point (Clients & Contracts) + /ping
 * Dipendenze:
 *   dependencies:
 *     http: ^1.2.0
 *
 * Qualsiasi modifica o estensione futura dovrebbe mantenere la
 * stessa struttura di modellazione (factory fromJson / toJson).
 */
import 'dart:convert';
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
 *                        MODELLI                                   *
 * *****************************************************************/

class Client {
  final String name;
  final String? address;
  final String? taxCode;
  final String? vat;
  final String? phone;
  final String? email;
  final String? sector;
  final String? legalRep;
  final String? legalRepTaxCode;

  Client({
    required this.name,
    this.address,
    this.taxCode,
    this.vat,
    this.phone,
    this.email,
    this.sector,
    this.legalRep,
    this.legalRepTaxCode,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        name: json['name'],
        address: json['address'],
        taxCode: json['tax_code'],
        vat: json['vat'],
        phone: json['phone'],
        email: json['email'],
        sector: json['sector'],
        legalRep: json['legal_rep'],
        legalRepTaxCode: json['legal_rep_tax_code'],
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
      };
}

class ClientListItem {
  final String clientId;
  ClientListItem({required this.clientId});

  factory ClientListItem.fromJson(Map<String, dynamic> json) =>
      ClientListItem(clientId: json['client_id']);

  Map<String, dynamic> toJson() => {'client_id': clientId};
}

class ContractListItem {
  final String contractId;
  ContractListItem({required this.contractId});

  factory ContractListItem.fromJson(Map<String, dynamic> json) =>
      ContractListItem(contractId: json['contract_id']);

  Map<String, dynamic> toJson() => {'contract_id': contractId};
}

/* ---------------  Modelli Complessi Contratto ------------------ */
/* ---------------- Identificativi (NEW) ------------------------- */

class Identificativi {
  final String tipo; // 'Tipo'
  final String? tpCar; // 'TpCar'
  final String ramo; // 'Ramo'
  final String compagnia; // 'Compagnia'
  final String numeroPolizza; // 'NumeroPolizza'

  Identificativi({
    required this.tipo,
    this.tpCar,
    required this.ramo,
    required this.compagnia,
    required this.numeroPolizza,
  });

  factory Identificativi.fromJson(Map<String, dynamic> json) => Identificativi(
        tipo: json['Tipo'],
        tpCar: json['TpCar'],
        ramo: json['Ramo'],
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
    required this.puntoVendita,
    required this.puntoVendita2,
    required this.account,
    required this.intermediario,
  });

  factory UnitaVendita.fromJson(Map<String, dynamic> json) => UnitaVendita(
        puntoVendita: json['PuntoVendita'],
        puntoVendita2: json['PuntoVendita2'],
        account: json['Account'],
        intermediario: json['Intermediario'],
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
  final String frazionamento;
  final bool compresoFirma;
  final DateTime scadenza;
  final DateTime scadenzaOriginaria;
  final DateTime? scadenzaMora;
  final String? numeroProposta;
  final String modalitaIncasso;
  final String? codConvenzione;
  final DateTime? scadenzaVincolo;
  final DateTime? scadenzaCopertura; // NEW
  final DateTime? fineCoperturaProroga; // NEW

  Amministrativi({
    required this.effetto,
    required this.dataEmissione,
    required this.ultimaRataPagata,
    required this.frazionamento,
    required this.compresoFirma,
    required this.scadenza,
    required this.scadenzaOriginaria,
    this.scadenzaMora,
    this.numeroProposta,
    required this.modalitaIncasso,
    this.codConvenzione,
    this.scadenzaVincolo,
    this.scadenzaCopertura,
    this.fineCoperturaProroga,
  });

  factory Amministrativi.fromJson(Map<String, dynamic> json) => Amministrativi(
        effetto: DateTime.parse(json['Effetto']),
        dataEmissione: DateTime.parse(json['DataEmissione']),
        ultimaRataPagata: DateTime.parse(json['UltRataPagata']),
        frazionamento: json['Frazionamento'],
        compresoFirma: json['CompresoFirma'],
        scadenza: DateTime.parse(json['Scadenza']),
        scadenzaOriginaria: DateTime.parse(json['ScadenzaOriginaria']),
        scadenzaMora: json['ScadenzaMora'] != null
            ? DateTime.parse(json['ScadenzaMora'])
            : null,
        numeroProposta: json['NumeroProposta'],
        modalitaIncasso: json['ModalitaIncasso'],
        codConvenzione: json['CodConvenzione'],
        scadenzaVincolo: json['ScadenzaVincolo'] != null
            ? DateTime.parse(json['ScadenzaVincolo'])
            : null,
        scadenzaCopertura: json['ScadenzaCopertura'] != null
            ? DateTime.parse(json['ScadenzaCopertura'])
            : null,
        fineCoperturaProroga: json['FineCoperturaProroga'] != null
            ? DateTime.parse(json['FineCoperturaProroga'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'Effetto': effetto.toIso8601String(),
        'DataEmissione': dataEmissione.toIso8601String(),
        'UltRataPagata': ultimaRataPagata.toIso8601String(),
        'Frazionamento': frazionamento,
        'CompresoFirma': compresoFirma,
        'Scadenza': scadenza.toIso8601String(),
        'ScadenzaOriginaria': scadenzaOriginaria.toIso8601String(),
        'ScadenzaMora': scadenzaMora?.toIso8601String(),
        'NumeroProposta': numeroProposta,
        'ModalitaIncasso': modalitaIncasso,
        'CodConvenzione': codConvenzione,
        'ScadenzaVincolo': scadenzaVincolo?.toIso8601String(),
        'ScadenzaCopertura': scadenzaCopertura?.toIso8601String(),
        'FineCoperturaProroga': fineCoperturaProroga?.toIso8601String(),
      };
}

class Premi {
  final double premio;
  final double netto;
  final double accessori;
  final double diritti;
  final double imposte;
  final double spese;
  final double fondo;
  final double? sconto;

  Premi({
    required this.premio,
    required this.netto,
    required this.accessori,
    required this.diritti,
    required this.imposte,
    required this.spese,
    required this.fondo,
    this.sconto,
  });

  factory Premi.fromJson(Map<String, dynamic> json) => Premi(
        premio: double.parse(json['Premio'].toString()),
        netto: double.parse(json['Netto'].toString()),
        accessori: double.parse(json['Accessori'].toString()),
        diritti: double.parse(json['Diritti'].toString()),
        imposte: double.parse(json['Imposte'].toString()),
        spese: double.parse(json['Spese'].toString()),
        fondo: double.parse(json['Fondo'].toString()),
        sconto: json['Sconto'] != null
            ? double.parse(json['Sconto'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'Premio': premio.toStringAsFixed(2),
        'Netto': netto.toStringAsFixed(2),
        'Accessori': accessori.toStringAsFixed(2),
        'Diritti': diritti.toStringAsFixed(2),
        'Imposte': imposte.toStringAsFixed(2),
        'Spese': spese.toStringAsFixed(2),
        'Fondo': fondo.toStringAsFixed(2),
        'Sconto': sconto?.toStringAsFixed(2),
      };
}

class Rinnovo {
  final String rinnovo;
  final String disdetta;
  final String giorniMora;
  final String proroga;

  Rinnovo({
    required this.rinnovo,
    required this.disdetta,
    required this.giorniMora,
    required this.proroga,
  });

  factory Rinnovo.fromJson(Map<String, dynamic> json) => Rinnovo(
        rinnovo: json['Rinnovo'],
        disdetta: json['Disdetta'],
        giorniMora: json['GiorniMora'],
        proroga: json['Proroga'],
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
    required this.cadenzaRegolazione,
  });

  factory ParametriRegolazione.fromJson(Map<String, dynamic> json) =>
      ParametriRegolazione(
        inizio: DateTime.parse(json['Inizio']),
        fine: DateTime.parse(json['Fine']),
        ultimaRegEmessa: json['UltimaRegEmessa'] != null
            ? DateTime.parse(json['UltimaRegEmessa'])
            : null,
        giorniInvioDati: json['GiorniInvioDati'],
        giorniPagReg: json['GiorniPagReg'],
        giorniMoraRegolazione: json['GiorniMoraRegolazione'],
        cadenzaRegolazione: json['CadenzaRegolazione'],
      );

  Map<String, dynamic> toJson() => {
        'Inizio': inizio.toIso8601String(),
        'Fine': fine.toIso8601String(),
        'UltimaRegEmessa': ultimaRegEmessa?.toIso8601String(),
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
    required this.regolazione,
    required this.parametriRegolazione,
  });

  factory Operativita.fromJson(Map<String, dynamic> json) => Operativita(
        regolazione: json['Regolazione'],
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
  RamiEl({required this.descrizione});

  factory RamiEl.fromJson(Map<String, dynamic> json) =>
      RamiEl(descrizione: json['Descrizione']);

  Map<String, dynamic> toJson() => {'Descrizione': descrizione};
}

/// Modello principale di contratto Omnia 8 (con alias JSON originali)
class ContrattoOmnia8 {
  final Identificativi identificativi;
  final UnitaVendita unitaVendita;
  final Amministrativi amministrativi;
  final Premi premi;
  final Rinnovo rinnovo;
  final Operativita operativita;
  final RamiEl ramiEl;

  ContrattoOmnia8({
    required this.identificativi,
    required this.unitaVendita,
    required this.amministrativi,
    required this.premi,
    required this.rinnovo,
    required this.operativita,
    required this.ramiEl,
  });

  factory ContrattoOmnia8.fromJson(Map<String, dynamic> json) =>
      ContrattoOmnia8(
        identificativi: Identificativi.fromJson(json['Identificativi']), // 🆕
        unitaVendita: UnitaVendita.fromJson(json['UnitaVendita']),
        amministrativi: Amministrativi.fromJson(json['Amministrativi']),
        premi: Premi.fromJson(json['Premi']),
        rinnovo: Rinnovo.fromJson(json['Rinnovo']),
        operativita: Operativita.fromJson(json['Operativita']),
        ramiEl: RamiEl.fromJson(json['RamiEl']),
      );

  Map<String, dynamic> toJson() => {
    'Identificativi': identificativi.toJson(), 
        'UnitaVendita': unitaVendita.toJson(),
        'Amministrativi': amministrativi.toJson(),
        'Premi': premi.toJson(),
        'Rinnovo': rinnovo.toJson(),
        'Operativita': operativita.toJson(),
        'RamiEl': ramiEl.toJson(),
      };
}

class CreateContractResponse {
  final String contractId;
  final ContrattoOmnia8 contratto;

  CreateContractResponse({required this.contractId, required this.contratto});

  factory CreateContractResponse.fromJson(Map<String, dynamic> json) =>
      CreateContractResponse(
        contractId: json['contract_id'],
        contratto: ContrattoOmnia8.fromJson(json['contratto']),
      );

  Map<String, dynamic> toJson() =>
      {'contract_id': contractId, 'contratto': contratto.toJson()};
}

class DeleteResponse {
  final bool deleted;
  final String id;

  DeleteResponse({required this.deleted, required this.id});

  factory DeleteResponse.fromJson(Map<String, dynamic> json) =>
      DeleteResponse(deleted: json['deleted'], id: json['id']);

  Map<String, dynamic> toJson() => {'deleted': deleted, 'id': id};
}

/* *****************************************************************
 *                         SDK HTTP                                *
 * *****************************************************************/

class Omnia8Sdk {
  /// Base URL dell’API (es. http://127.0.0.1:8000).
  final String baseUrl;

  /// Client HTTP sottostante (iniettabile per test).
  final http.Client _http;

  Omnia8Sdk({this.baseUrl = 'https://www.goldbitweb.com/enac-api', http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Chiude il client HTTP.
  void dispose() => _http.close();

  /* ------------------------- Helpers privati -------------------- */

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    late http.Response res;

    switch (method) {
      case 'GET':
        res = await _http.get(_uri(path), headers: headers);
        break;
      case 'POST':
        res = await _http.post(_uri(path),
            headers: headers, body: jsonEncode(body));
        break;
      case 'PUT':
        res = await _http.put(_uri(path),
            headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        res = await _http.delete(_uri(path), headers: headers);
        break;
      default:
        throw ArgumentError('Metodo HTTP non supportato: $method');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isNotEmpty ? jsonDecode(res.body) : null;
    }
    throw ApiException(res.statusCode, res.body);
  }

  /* --------------------------- /ping ----------------------------- */

  Future<bool> ping() async {
    final data = await _request('GET', '/ping') as Map<String, dynamic>;
    return data['status'] == 'ok';
  }

  /* ------------------------- CLIENTS ---------------------------- */

  Future<Client> createClient(
      String userId, String clientId, Client payload) async {
    final json = await _request('POST', '/users/$userId/clients/$clientId',
        body: payload.toJson()) as Map<String, dynamic>;
    return Client.fromJson(json);
  }

  Future<List<ClientListItem>> listClients(String userId) async {
    final data =
        await _request('GET', '/users/$userId/clients') as List<dynamic>;
    return data.map((e) => ClientListItem.fromJson(e)).toList();
  }

  Future<Client> getClient(String userId, String clientId) async {
    final json = await _request('GET', '/users/$userId/clients/$clientId')
        as Map<String, dynamic>;
    return Client.fromJson(json);
  }

  Future<Client> updateClient(
      String userId, String clientId, Client payload) async {
    final json = await _request('PUT', '/users/$userId/clients/$clientId',
        body: payload.toJson()) as Map<String, dynamic>;
    return Client.fromJson(json);
  }

  Future<DeleteResponse> deleteClient(String userId, String clientId) async {
    final json = await _request('DELETE', '/users/$userId/clients/$clientId')
        as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }

  /* ------------------------- CONTRACTS -------------------------- */

  Future<CreateContractResponse> createContract(
      String userId, String clientId, ContrattoOmnia8 payload) async {
    final json = await _request(
        'POST', '/users/$userId/clients/$clientId/contracts',
        body: payload.toJson()) as Map<String, dynamic>;
    return CreateContractResponse.fromJson(json);
  }

  Future<List<ContractListItem>> listContracts(
      String userId, String clientId) async {
    final data =
        await _request('GET', '/users/$userId/clients/$clientId/contracts')
            as List<dynamic>;
    return data.map((e) => ContractListItem.fromJson(e)).toList();
  }

  Future<ContrattoOmnia8> getContract(
      String userId, String clientId, String contractId) async {
    final json = await _request(
            'GET', '/users/$userId/clients/$clientId/contracts/$contractId')
        as Map<String, dynamic>;
    return ContrattoOmnia8.fromJson(json);
  }

  Future<ContrattoOmnia8> updateContract(String userId, String clientId,
      String contractId, ContrattoOmnia8 payload) async {
    final json = await _request(
        'PUT', '/users/$userId/clients/$clientId/contracts/$contractId',
        body: payload.toJson()) as Map<String, dynamic>;
    return ContrattoOmnia8.fromJson(json);
  }

  Future<DeleteResponse> deleteContract(
      String userId, String clientId, String contractId) async {
    final json = await _request(
            'DELETE', '/users/$userId/clients/$clientId/contracts/$contractId')
        as Map<String, dynamic>;
    return DeleteResponse.fromJson(json);
  }
}
