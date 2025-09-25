// main.dart
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/client_contracts_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/client_detail_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/client_page.dart';
import 'package:boxed_ai/apps/enac_app/ui_components/contract_summary.dart';
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
  portafoglio,
  sinistri,
  comunicazioni,
  contabilita,
  documentale,
  report,
  sistema,
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

  bool _chatsOpen = false;

  final DualPaneController _paneCtrl1 = DualPaneController();
  final DualPaneController _paneCtrl2 = DualPaneController();
  final DualPaneController _paneCtrl3 = DualPaneController();
  /* ----------------- STATO ------------------ */
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
              // ← id del client aperto
_ClientSection _selClientSection = _ClientSection.cliente;
ContrattoOmnia8? _selectedContract;
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

  Widget row(String txt, _ContractSection sec,
      {Widget? trailing}) =>
      InkWell(
            onTap: () => setState(() {
          _resetChats();                        // ← chiude e spegne icona
          _selContractSection = sec;
        }),
        child: Container(
          width: double.infinity,
          color: _selContractSection == sec
              ? const Color(0xFFE8F0FE)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              Text(txt, style: st(_selContractSection == sec)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
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
                _selectedContract = null;
                _selectedClientId = null;          // ⬅️ torni ai risultati
              }),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Contratti',
              onPressed: () => setState(() {
                _resetChats(); 
                _selectedContract = null;          // ⬅️ torni a lista contratti
                _selClientSection = _ClientSection.contratti;
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
            trailing: const Text('1', style: TextStyle(fontSize: 11))),
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
        onTap: () => setState(() => _selClientSection = sec),
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
                 _selectedClientId = null;
                 
                 }),
            ),
            const Text('Risultati ricerca'),
          ],
        ),
        const Divider(),
        row('Cliente',    _ClientSection.cliente),
        row('Progetti',   _ClientSection.progetti),
        row('Richieste',  _ClientSection.richieste),
        row('Contratti',  _ClientSection.contratti),
        row('Titoli',     _ClientSection.titoli),
        row('Movimenti',  _ClientSection.movimenti),
        row('Sinistri',   _ClientSection.sinistri,
            trailing: const Icon(Icons.chevron_right, size: 16)),
        row('Documenti',  _ClientSection.documenti,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2)),
              child: const Text('83',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            )),
        row('Note',       _ClientSection.note),
        row('Varie',      _ClientSection.varie),
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
        _resetChats();          // ⬅️ NEW
        _selectedSide = item;
        _searchQuery = null;
      }),
        child: Container(
          width: double.infinity,
          color: active ? const Color(0xFFE8F0FE) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Text(label, style: itemStyle(active)),
        ),
      );
    }

    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildSideSearch(),
          tile('Home', _SideItem.home),
          tile('Portafoglio', _SideItem.portafoglio),
          tile('Sinistri', _SideItem.sinistri),
          tile('Comunicazioni', _SideItem.comunicazioni),
          tile('Contabilità', _SideItem.contabilita),
          tile('Documentale', _SideItem.documentale),
          tile('Report', _SideItem.report),
          tile('Sistema', _SideItem.sistema),
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
  controller : _paneCtrl3,
  leftChild  :ContractDetailPage(contratto: _selectedContract!));

    case _ContractSection.titoli:
      return const Center(child: Text('Titoli – placeholder'));
    case _ContractSection.sinistri:
      return const Center(child: Text('Sinistri – placeholder'));
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
  return FutureBuilder<Client>(
    future: _sdk.getClient(widget.user.username, _selectedClientId!),
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
    onOpenContract: (c) {
      setState(() {
        _resetChats();                        // ⬅️ NEW
        _selectedContract   = c;
        _selContractSection = _ContractSection.riepilogo;
      });
    },
  ));
    case _ClientSection.titoli:
      return const Center(child: Text('Titoli – placeholder'));
    case _ClientSection.movimenti:
      return const Center(child: Text('Movimenti – placeholder'));
    case _ClientSection.sinistri:
      return const Center(child: Text('Sinistri – placeholder'));
    case _ClientSection.documenti:
      return const Center(child: Text('Documenti – placeholder'));
    case _ClientSection.note:
      return const Center(child: Text('Note – placeholder'));
    case _ClientSection.varie:
      return const Center(child: Text('Varie – placeholder'));
  }
}


  // 2) risultati di ricerca
  if (_searchQuery != null)  {
    return DualPaneWrapper(
      user: widget.user,
      token: widget.token,
  controller : _paneCtrl2,
  leftChild  : SearchResultsPanel(
      query: _searchQuery!,
      user: widget.user,
      token: widget.token,
      sdk: _sdk,
        onOpenClient: (id) {
          setState(() {
            _resetChats();                    // ⬅️ NEW
            _selectedClientId = id;
            _selClientSection = _ClientSection.cliente;
          });
        },
    ));
  }

    // caso 2: mostra placeholder sezione
    switch (_selectedSide) {
      case _SideItem.home:
        return const HomeDashboard(); // ⟵ nuovo widget
      case _SideItem.portafoglio:
        return const Center(
            child: Text('Portafoglio – elenco polizze (placeholder)'));
      case _SideItem.sinistri:
        return const Center(
            child: Text('Sinistri – gestione sinistri (placeholder)'));
      case _SideItem.comunicazioni:
        return const Center(
            child: Text('Comunicazioni – messaggi (placeholder)'));
      case _SideItem.contabilita:
        return const Center(
            child: Text('Contabilità – movimenti (placeholder)'));
      case _SideItem.documentale:
        return const Center(
            child: Text('Documentale – archivio (placeholder)'));
      case _SideItem.report:
        return const Center(child: Text('Report – statistiche (placeholder)'));
      case _SideItem.sistema:
        return const Center(
            child: Text('Sistema – impostazioni (placeholder)'));
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
