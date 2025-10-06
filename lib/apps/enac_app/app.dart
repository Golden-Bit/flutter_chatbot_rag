// main.dart
import 'dart:html' as html;

import 'package:boxed_ai/apps/enac_app/ui_components/claim/all_claims_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/claim/claim_summary_panel.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/claim/client_claims_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/claim/contract_claims_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/all_contracts_table.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/gare/gare_detail_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/gare/gare_models.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/gare/gare_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/titles/client_titles_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/titles/contract_titles_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/titles/title_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/client_contracts_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/clients/client_detail_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/clients/client_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/contracts/contract_summary.dart';
import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/home_dashboard.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/search_results.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:boxed_ai/user_manager/components/settings_dialog.dart';
import 'package:boxed_ai/user_manager/pages/login_page_1.dart';
import 'package:google_fonts/google_fonts.dart'; // (resta se già usi GoogleFonts)

// *** in HomeScaffold (state) ***
enum _ClientSection {
  cliente, progetti, richieste, contratti, titoli,
  movimenti, sinistri, documenti, note, varie,
}
enum _ContractSection {
  riepilogo, titoli, sinistri, documenti, note, varie
}

_ContractSection _selContractSection = _ContractSection.riepilogo;
/// Voci della sidebar (replicano lo screenshot)
enum _SideItem {
  home,
  polizze,
  sinistri,
  proceduraGara,
}

enum _TopTab { docs, templates, contacts }

class HomeScaffold extends StatefulWidget {
  final User user;
  final Token token;

  const HomeScaffold({
    Key? key,
    required this.token,
    required this.user,
  }) : super(key: key);

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
// in _HomeScaffoldState
String? _selectedContractId;

  bool _chatsOpen = false;

// Id usati quando apro il dettaglio da "Tutti i sinistri"
String? _selectedClaimId;          // id sinistro selezionato (globale)
String? _selectedClaimEntityId;    // entityId del sinistro selezionato (globale)

  final DualPaneController _paneCtrl1 = DualPaneController();
  final DualPaneController _paneCtrl2 = DualPaneController();
  final DualPaneController _paneCtrl3 = DualPaneController();
  final DualPaneController _paneCtrlTitles = DualPaneController();
  final DualPaneController _paneCtrlPolicies = DualPaneController();
  // Controller per la vista "Tutti i sinistri"
final DualPaneController _paneCtrlAllClaims = DualPaneController();
// state in _HomeScaffoldState
final DualPaneController _paneCtrlGare = DualPaneController();
  /* ----------------- STATO ------------------ */
  Gara? _selectedGara; 
  String? _selectedClientId;
  _SideItem _selectedSide = _SideItem.home;
  _TopTab _selectedTab = _TopTab.docs;
late final Omnia8Sdk _sdk;
  // search nella TOP‑BAR
  final TextEditingController _topSearch = TextEditingController();

  // search nella SIDEBAR
  final TextEditingController _sideSearch = TextEditingController();
  String? _searchQuery; // ultima stringa cercata (placeholder)

  /*──────────────────────────────────────────────────────────
   *  Chiude tutte le chat e aggiorna l’icona della Top‑bar
   *────────────────────────────────────────────────────────*/
  void _resetChats() {
    if (_chatsOpen) {
      DualPaneRegistry.closeAll();
      _chatsOpen = false;
    }
  }

  // Badge numerico uniforme per "Documenti"
Widget _docBadge(int n) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.grey.shade600,
    borderRadius: BorderRadius.circular(2),
  ),
  child: Text(
    '$n',
    style: const TextStyle(color: Colors.white, fontSize: 11),
  ),
);

              // ← id del client aperto
_ClientSection _selClientSection = _ClientSection.cliente;
ContrattoOmnia8? _selectedContract;
Titolo? _selectedTitle;                          // NEW
Map<String, dynamic>? _selectedTitleRow;         // NEW
final DualPaneController _paneCtrlClaims = DualPaneController();  // NEW

Sinistro? _selectedClaim;                                         // NEW
Map<String, dynamic>? _selectedClaimRow;                          // NEW

  /* ================= TOP‑BAR ================= */
  Widget _buildTopBar() {
    Widget tab(String label, _TopTab tab, {bool lock = false}) {
      final active = _selectedTab == tab;
      return InkWell(
        splashFactory: NoSplash.splashFactory,
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: active
              ? BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(2),
                )
              : null,
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.grey.shade200,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (lock)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child:
                      Icon(Icons.lock_outline, size: 15, color: Colors.white70),
                ),
            ],
          ),
        ),
      );
    }

    Widget vDivider() => Container(
          width: 1,
          height: 40,
          color: Colors.white.withOpacity(.4),
        );

    return Material(
      color: const Color(0xFF66A3FF),
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              /* LOGO */
              Text('App Name',
                  style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 32),

              /* TABS */
              //tab('Documenti', _TopTab.docs),
              //const SizedBox(width: 24),
              //tab('Modelli', _TopTab.templates),
              const Spacer(),

              /* SEARCH TOP‑BAR */
              /*SizedBox(
                width: 260,
                height: 40,
                child: TextField(
                  controller: _topSearch,
                  onSubmitted: (v) => debugPrint('top search: $v'),
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Cerca file o cartelle',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: Icon(Icons.search,
                        size: 20, color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 24),*/
 /* CHAT TOGGLE */
 IconButton(
   icon: Icon(
     _chatsOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
     color: Colors.white,
   ),
   tooltip: _chatsOpen ? 'Nascondi chat' : 'Mostra chat',
   onPressed: () {
     setState(() => _chatsOpen = DualPaneRegistry.toggleAll());
   },
 ),
 const SizedBox(width: 16),

              /* LINGUA */
              vDivider(),
              const SizedBox(width: 16),
              _LanguageMenu(
                current: 'it',
                onChange: (lang) => setState(() {}),
              ),
              const SizedBox(width: 16),
              vDivider(),

              /* HELP ‑ NOTIFICHE */
              IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  tooltip: 'Aiuto',
                  onPressed: () {}),
              vDivider(),
              IconButton(
                  icon:
                      const Icon(Icons.notifications_none, color: Colors.white),
                  tooltip: 'Notifiche',
                  onPressed: () {}),
              vDivider(),

              /* AVATAR + NOME */
              const SizedBox(width: 12),
              _UserMenu(accessToken: widget.token.accessToken),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------- SIDEBAR: SEARCH ------------ */
  Widget _buildSideSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 34,
        child: TextField(
          controller: _sideSearch,
          onSubmitted: (v) => setState(() {
            _resetChats();                    // ⬅️ NEW
            _searchQuery = v.trim();
          }),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Cerca…',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon: const Icon(Icons.search, size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildContractSideMenu() {
  TextStyle st(bool act) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: act ? Colors.blue : Colors.grey.shade700,
      );

Widget row(String txt, _ContractSection sec, {Widget? trailing}) => InkWell(
  onTap: () => setState(() {
    _resetChats();
    _selContractSection = sec;
    if (sec == _ContractSection.titoli) {   // reset selezione summary titolo
      _selectedTitle = null;
      _selectedTitleRow = null;
    }
    if (sec == _ContractSection.sinistri) { // reset selezione summary sinistro
      _selectedClaim = null;
      _selectedClaimRow = null;
    }
  }),
  child: Container(
    width: double.infinity,
    color: _selContractSection == sec ? const Color(0xFFE8F0FE) : Colors.transparent,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    child: Row(children: [
      Text(txt, style: st(_selContractSection == sec)),
      const Spacer(),
      if (trailing != null) trailing,
    ]),
  ),
);

  return Container(
    width: 220,
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
                        IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Risultati ricerca',
onPressed: () => setState(() {
  _resetChats(); 
  _selectedContract   = null;
  _selectedContractId = null;   // ⬅️ aggiunto
  _selectedClientId   = null;
}),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Contratti',
onPressed: () => setState(() {
  _resetChats(); 
  _selectedContract   = null;
  _selectedContractId = null;   // ⬅️ aggiunto
  _selClientSection   = _ClientSection.contratti;
}),
            ),
            const Text('Contratti'),
          ],
        ),
        const Divider(),
        row('Riepilogo', _ContractSection.riepilogo),
        row('Titoli',    _ContractSection.titoli),
        row('Sinistri',  _ContractSection.sinistri),
row('Documenti', _ContractSection.documenti,
    trailing: _docBadge(0)),
        row('Note',      _ContractSection.note),
        row('Varie',     _ContractSection.varie),
      ],
    ),
  );
}


/* ======== SIDEBAR – modalità CLIENTE ======== */
/* ======== SIDEBAR – modalità CLIENTE ======== */
Widget _buildClientSideMenu() {
  TextStyle st(bool act) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: act ? Colors.blue : Colors.grey.shade700,
      );

  Widget row(String txt, _ClientSection sec,
      {Widget? trailing}) =>
      InkWell(
onTap: () => setState(() {
  _resetChats();
  _selClientSection = sec;
  if (sec == _ClientSection.titoli) {           // NEW: reset vista summary
    _selectedTitle = null;
    _selectedTitleRow = null;
  }
    if (sec == _ClientSection.sinistri) {     // NEW
    _selectedClaim = null;
    _selectedClaimRow = null;
  }
}),
        child: Container(
          width: double.infinity,
          color: _selClientSection == sec
              ? const Color(0xFFE8F0FE)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Text(txt, style: st(_selClientSection == sec)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
        ),
      );

// 🔧 Dentro _buildClientSideMenu(), sostituisci la colonna delle voci
return Container(
  width: 220,
  color: Colors.white,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
              _resetChats();
              _selectedClientId = null; // torna ai risultati
            }),
          ),
          const Text('Risultati ricerca'),
        ],
      ),
      const Divider(),
      row('Cliente',   _ClientSection.cliente),
      row('Contratti', _ClientSection.contratti),
      row('Titoli',    _ClientSection.titoli),
row('Sinistri',  _ClientSection.sinistri),              // ← niente chevron
row('Documenti', _ClientSection.documenti,              // ← badge fisso a 0
    trailing: _docBadge(0),
),
    ],
  ),
);

}

Widget _buildSideMenu() {
  if (_selectedContract != null) return _buildContractSideMenu();
  if (_selectedClientId != null) return _buildClientSideMenu();
  return _buildStandardSideMenu();
}

  /* ================= SIDEBAR ================ */
  Widget _buildStandardSideMenu() {
    TextStyle itemStyle(bool active) => TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: active ? Colors.blue : Colors.grey.shade700,
        );

    Widget tile(String label, _SideItem item) {
      final active = _selectedSide == item;
      return InkWell(
        splashFactory: NoSplash.splashFactory,
onTap: () => setState(() {
  _resetChats();
  _selectedSide = item;
  _searchQuery = null;

  // quando apro la sezione Sinistri globale, azzero eventuali selezioni
  if (item == _SideItem.sinistri) {
    _selectedClientId = null;
    _selClientSection = _ClientSection.cliente;
    _selectedClaim = null;
    _selectedClaimRow = null;
    _selectedClaimId = null;
    _selectedClaimEntityId = null;
    _selectedContractId = null;
  }
        // ✅ QUI l'inserimento per "Procedure di Gara"
      if (item == _SideItem.proceduraGara) {
        _selectedGara = null;        // reset selezione gara
        // (opzionale) pulizie extra se vuoi partire “pulito”
        // _selectedClientId = null;
        // _selectedContract = null;
        // _selectedContractId = null;
        // _selectedClaim = null;
        // _selectedClaimRow = null;
      }
}),

        child: Container(
          width: double.infinity,
          color: active ? const Color(0xFFE8F0FE) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Text(label, style: itemStyle(active)),
        ),
      );
    }

// 🔧 Dentro _buildStandardSideMenu(), sostituisci il blocco dei "tile(...)"
return Container(
  width: 220,
  color: Colors.white,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      _buildSideSearch(),
      tile('Home', _SideItem.home),
      tile('Polizze', _SideItem.polizze),
      tile('Sinistri', _SideItem.sinistri),
      tile('Procedura di Gara', _SideItem.proceduraGara),
    ],
  ),
);

  }

  /* ========== CONTENUTO PRINCIPALE ========== */
  Widget _buildContent() {
    // caso 1: c’è una ricerca dalla sidebar
  // 1) vista CLIENTE aperta
// primo controllo in _buildContent()

// ---------- vista CONTRATTO ----------
if (_selectedContract != null) {
  switch (_selContractSection) {
case _ContractSection.riepilogo:
  return DualPaneWrapper(
    user: widget.user,
    token: widget.token,
    controller: _paneCtrl3,
    leftChild: ContractDetailPage(
      contratto : _selectedContract!,
      sdk       : _sdk,
      user      : widget.user,
      userId    : widget.user.username,
      entityId  : _selectedClientId!,     // cliente corrente
      contractId: _selectedContractId!,   // <-- serve per le API Documenti
      initialTab: 0,                      // Riepilogo
    ),
  );

case _ContractSection.titoli:
  if (_selectedTitle == null) {
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrl3,
      leftChild: ContractTitlesPage(
        userId    : widget.user.username,
        entityId  : _selectedClientId!,        // cliente corrente
        contractId: _selectedContractId!,      // contratto corrente
        sdk       : _sdk,
        onOpenTitle: (titolo, viewRow) {
          setState(() {
            _resetChats();
            _selectedTitle    = titolo;
            _selectedTitleRow = viewRow;
          });
        },
      ),
    );
  } else {
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrl3,
      leftChild: TitleSummaryPanel(
        titolo : _selectedTitle!,
        viewRow: _selectedTitleRow ?? const {},
      ),
    );
  }

case _ContractSection.sinistri:
  if (_selectedClaim == null) {
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrl3,
      leftChild: ContractClaimsPage(
        userId    : widget.user.username,
        entityId  : _selectedClientId!,
        contractId: _selectedContractId!,
        sdk       : _sdk,
        onOpenClaim: (sinistro, viewRow) {
          setState(() {
            _resetChats();
            _selectedClaim    = sinistro;
            _selectedClaimRow = viewRow; // contiene già contract_id e claim_id
          });
        },
      ),
    );
  } else {
    final String contractId = _selectedContractId!;
    final String claimId = (
      _selectedClaimRow?['claim_id'] ??
      _selectedClaimRow?['id'] ??
      ''
    ).toString();

    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrl3,
      leftChild: ClaimSummaryPanel(
        sinistro  : _selectedClaim!,
        viewRow   : _selectedClaimRow ?? const {},
        sdk       : _sdk,
        user      : widget.user,
        userId    : widget.user.username,
        entityId  : _selectedClientId!,
        contractId: contractId,
        claimId   : claimId,
      ),
    );
  }

    case _ContractSection.documenti:
      return const Center(child: Text('Documenti – placeholder'));
    case _ContractSection.note:
      return const Center(child: Text('Note – placeholder'));
    case _ContractSection.varie:
      return const Center(child: Text('Varie – placeholder'));
  }
}

if (_selectedClientId != null) {
  switch (_selClientSection) {
case _ClientSection.cliente:
  return FutureBuilder<Entity>(
    future: _sdk.getEntity(widget.user.username, _selectedClientId!),
    builder: (ctx, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(child: Text('Errore: ${snap.error}'));
      }
      return ClientDetailPage(client: snap.data!);   //  ← oggetto reale
    },
  );
    case _ClientSection.progetti:
      return const Center(child: Text('Progetti – placeholder'));
    case _ClientSection.richieste:
      return const Center(child: Text('Richieste – placeholder'));
case _ClientSection.contratti:
  return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
  controller : _paneCtrl1,
  leftChild  :ClientContractsPage(
    user: widget.user,
    token: widget.token,
    userId: widget.user.username,
    clientId: _selectedClientId!,
    sdk: _sdk,
onOpenContract: (String contractId, ContrattoOmnia8 c) {
  setState(() {
    _resetChats();
    _selectedContractId = contractId;   // ⬅️ salvi anche l’ID
    _selectedContract   = c;
    _selContractSection = _ContractSection.riepilogo;
  });
},
  ));
case _ClientSection.titoli:
  if (_selectedTitle == null) {
    // Lista titoli
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrlTitles,
      leftChild: ClientTitlesPage(
        user: widget.user,
        token: widget.token,
        userId: widget.user.username,
        clientId: _selectedClientId!,
        sdk: _sdk,
        onOpenTitle: (titolo, viewRow) {           // NEW: callback richiesto
          setState(() {
            _resetChats();
            _selectedTitle    = titolo;
            _selectedTitleRow = viewRow;
          });
        },
      ),
    );
  } else {
    // Summary titolo “incastrato” (niente Navigator, sidebar+topbar restano)
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrlTitles,
      leftChild: TitleSummaryPanel(
        titolo: _selectedTitle!,
        viewRow: _selectedTitleRow ?? const {},
      ),
    );
  }

    case _ClientSection.movimenti:
      return const Center(child: Text('Movimenti – placeholder'));
case _ClientSection.sinistri:
  if (_selectedClaim == null) {
    // Lista sinistri
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrlClaims,
      leftChild: ClientClaimsPage(
        user: widget.user,
        token: widget.token,
        userId: widget.user.username,
        clientId: _selectedClientId!,
        sdk: _sdk,
        onOpenClaim: (sinistro, viewRow) {
          setState(() {
            _resetChats();
            _selectedClaim    = sinistro;
            _selectedClaimRow = viewRow; // deve contenere contract_id e claim_id
          });
        },
      ),
    );
  } else {
    // Summary incastrato
    final String contractId = (
      _selectedClaimRow?['contract_id'] ??
      _selectedClaimRow?['contractId']
    )?.toString() ?? '';

    final String claimId = (
      _selectedClaimRow?['claim_id'] ??
      _selectedClaimRow?['ClaimId']  ??
      _selectedClaimRow?['id']
    )?.toString() ?? '';

    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
      controller: _paneCtrlClaims,
      leftChild: ClaimSummaryPanel(
        sinistro: _selectedClaim!,
        viewRow : _selectedClaimRow ?? const {},
        // ↓↓↓ nuovi parametri richiesti dal pannello ↓↓↓
        sdk: _sdk,
        user: widget.user,
        userId: widget.user.username,
        entityId: _selectedClientId!,
        contractId: contractId,
        claimId: claimId,
      ),
    );
  }


    case _ClientSection.documenti:
      return const Center(child: Text('Documenti – placeholder'));
    case _ClientSection.note:
      return const Center(child: Text('Note – placeholder'));
    case _ClientSection.varie:
      return const Center(child: Text('Varie – placeholder'));
  }
}


  // 2) risultati di ricerca
// dentro _buildContent()
// ...
if (_searchQuery != null)  {
  return DualPaneWrapper(
    user: widget.user,
    token: widget.token,
    controller: _paneCtrl2,
    leftChild: SearchResultsPanel(
      query: _searchQuery!,
      user: widget.user,
      token: widget.token,
      sdk: _sdk,

      // ERA già presente
      onOpenClient: (id) {
        setState(() {
          _resetChats();
          _selectedClientId = id;
          _selClientSection = _ClientSection.cliente;
          // pulizia di selezioni precedenti
          _selectedContract = null;
          _selectedContractId = null;
          _selectedClaim = null;
          _selectedClaimRow = null;
        });
      },

      // ✨ NUOVO: click su CONTRATTO dai risultati
      onOpenContract: (entityId, contractId, contratto) {
        setState(() {
          _resetChats();

          // fai entrare nel contesto CONTRATTO → Riepilogo
          _selectedClientId   = entityId;            // serve per documenti
          _selectedContractId = contractId;
          _selectedContract   = contratto;           // oggetto pieno dal fetch eseguito nel panel
          _selContractSection = _ContractSection.riepilogo;

          // pulizia di eventuali sinistri selezionati
          _selectedClaim = null;
          _selectedClaimRow = null;
          _selClientSection = _ClientSection.cliente;
        });
      },

      // ✨ NUOVO: click su SINISTRO dai risultati
      onOpenClaim: (entityId, contractId, claimId, viewRow, sinistro) {
        setState(() {
          _resetChats();

          // entra nel contesto CLIENTE → Sinistri (mostra subito il Summary)
          _selectedClientId = entityId;
          _selClientSection = _ClientSection.sinistri;

          _selectedClaim    = sinistro ?? ClaimSummaryPanel.claimFromViewRow(viewRow);
          _selectedClaimRow = {
            ...viewRow,
            'contract_id': contractId,
            'claim_id'   : claimId,
          };

          // (facoltativo ma utile se poi navighi tra documenti, ecc.)
          _selectedContractId    = contractId;
          _selectedClaimId       = claimId;
          _selectedClaimEntityId = entityId;

          // nessun contratto “incastrato” in questo flusso
          _selectedContract = null;
        });
      },
    ),
  );
}


    // caso 2: mostra placeholder sezione
// 🔧 Dentro _buildContent(), sostituisci lo switch(_selectedSide) finale
switch (_selectedSide) {
  case _SideItem.home:
    return HomeDashboard(
      user: widget.user,
      token: widget.token,
      sdk: _sdk,
      onOpenClient: (id) {
        setState(() {
          _resetChats();
          _selectedClientId = id;                 // apri il cliente dalla Home
          _selClientSection = _ClientSection.cliente;
        });
      },
    );
case _SideItem.polizze:
  return DualPaneWrapper(
    user: widget.user,
    token: widget.token,
    controller: _paneCtrlPolicies,
    leftChild: PolizzePage(
      userId: widget.user.username,
      sdk: _sdk,
      onOpenContract: (entityId, contractId, c) {
        setState(() {
          _resetChats();
          // apri il dettaglio contratto riusando la stessa vista già in uso
          _selectedClientId   = entityId;       // serve per ContractDetailPage (documenti)
          _selectedContractId = contractId;
          _selectedContract   = c;
          _selContractSection = _ContractSection.riepilogo;
        });
      },
    ),
  );

case _SideItem.sinistri:
  // Sempre lista "Tutti i sinistri". Al click su una card
  // ENTRO nel contesto CLIENTE → Sinistri (Summary),
  // così la sidebar cambia in quella cliente (come per i contratti).
  return DualPaneWrapper(
    user: widget.user,
    token: widget.token,
    controller: _paneCtrlAllClaims,
    leftChild: AllClaimsPage(
      userId: widget.user.username,
      sdk: _sdk,
      onOpenClaim: (entityId, contractId, claimId, viewRow, sinistro) {
        setState(() {
          _resetChats();

          // ⬇️ Passo al contesto CLIENTE
          _selectedClientId   = entityId;                     // sidebar diventa "cliente"
          _selClientSection   = _ClientSection.sinistri;      // pagina cliente → sinistri

          // ⬇️ Preparo la selezione per mostrare SUBITO il Summary
          _selectedClaim      = sinistro ?? ClaimSummaryPanel.claimFromViewRow(viewRow);
          _selectedClaimRow   = {
            ...viewRow,
            // mi assicuro che i campi ci siano, per sicurezza
            'contract_id': contractId,
            'claim_id'   : claimId,
          };

          // (opzionale) salvo questi ID se ti tornano utili altrove
          _selectedContractId    = contractId;
          _selectedClaimId       = claimId;
          _selectedClaimEntityId = entityId;
        });
      },
    ),
  );

case _SideItem.proceduraGara:
  return DualPaneWrapper(
    user: widget.user,
    token: widget.token,
    controller: _paneCtrlGare,
    leftChild: _selectedGara == null
      ? GarePage(
          user: widget.user,
          token: widget.token,
          sdk: _sdk,
          onOpenGara: (g) {
            setState(() {
              _resetChats();
              _selectedGara = g; // apre il dettaglio "incastrato"
            });
          },
        )
      : GaraDetailPage(gara: _selectedGara!),
  );


}
  }

@override
void initState() {
  super.initState();
  _sdk = Omnia8Sdk();          // oppure passagli baseUrl diverso
}

@override
void dispose() {
  _sdk.dispose();
  super.dispose();
}

  /* ---------------- BUILD ---------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildSideMenu(),                  // sidebar dinamica   // 🔄 due varianti sidebar
                VerticalDivider(
                    width: 1, thickness: 1, color: Colors.grey.shade300),
                Expanded(
                  child: Container(
                   color: Colors.white,
                    alignment: Alignment.topCenter,      // ⬅ forza l’allineamento in alto
                    padding: const EdgeInsets.all(24),
                    child: _buildContent()),
            )],
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------- USER MENU POPUP ------------- */
class _UserMenu extends StatelessWidget {
  final String accessToken;
  const _UserMenu({Key? key, required this.accessToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Account',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      color: Colors.white,
      onSelected: (v) {
        switch (v) {
          case 0:
            showDialog(
              context: context,
              builder: (_) => SettingsDialog(
                accessToken: accessToken,
                onArchiveAll: () async {},
                onDeleteAll: () async {},
              ),
            );
            break;
          case 4:
            html.window.localStorage
              ..remove('token')
              ..remove('refreshToken')
              ..remove('user');
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false);
            break;
        }
      },
      itemBuilder: (_) => [
        _item(0, 'Il mio profilo', Icons.person_outline),
        _item(1, 'Abbonamento', Icons.description_outlined),
        _item(2, 'Le mie identità', Icons.face_retouching_natural_outlined),
        _item(3, 'Invita un amico', Icons.person_add_alt_outlined),
        const PopupMenuDivider(),
        _item(4, 'Esci', Icons.logout_outlined),
      ],
      child: Row(
        children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade400,
              child: const Text('S',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          const Text('User Name', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  PopupMenuItem<int> _item(int v, String label, IconData icon) =>
      PopupMenuItem<int>(
        value: v,
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Text(label),
        ]),
      );
}

/* ----------- LANGUAGE MENU -------------- */
class _LanguageMenu extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _LanguageMenu({Key? key, required this.current, required this.onChange})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const label = {'it': 'Italiano', 'en': 'English'};
    return PopupMenuButton<String>(
      tooltip: 'Lingua',
      offset: const Offset(0, 46),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onSelected: onChange,
      itemBuilder: (_) => [
        for (final code in label.keys)
          PopupMenuItem<String>(
            value: code,
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(label[code]!),
              if (code == current) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18, color: Colors.blue),
              ],
            ]),
          ),
      ],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Lingua',
              style: TextStyle(color: Colors.white, fontSize: 11)),
          Row(children: [
            Text(label[current]!,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ]),
        ],
      ),
    );
  }
}
