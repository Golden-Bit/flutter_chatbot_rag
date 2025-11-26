// main.dart
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:boxed_ai/dual_pane_wrapper.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'package:boxed_ai/user_manager/components/settings_dialog.dart';
import 'package:boxed_ai/user_manager/pages/login_page_1.dart';
import 'package:boxed_ai/apps/enac_app/logic_components/backend_sdk.dart'; // per Token

// Colori “brand” AON (puoi affinarli)
const kAonRed = Color(0xFFE30613);
const kAonDark = Color(0xFF333333);
const kAonLightGrey = Color(0xFFF6F6F6);
const kAonMidGrey = Color(0xFFE0E0E0);

/// Pagina che si apre DOPO il login.
/// Mantiene la firma (User, Token) come nel tuo esempio ENAC.
class HomeScaffold extends StatefulWidget {
  final User user;
  final Token token;

  const HomeScaffold({
    super.key,
    required this.user,
    required this.token,
  });

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  // Stato apertura chat
  bool _chatsOpen = false;

  // Controller per DualPane della home
  final DualPaneController _paneCtrlHome = DualPaneController();

  /*────────────────────────────
   *   Gestione Chat / Registry
   *──────────────────────────*/
  void _resetChats() {
    // chiude tutti i mini-panel registrati
    DualPaneRegistry.closeAll();
  }

  /*────────────────────────────
   *         APP BAR
   *──────────────────────────*/
  AppBar _buildAppBar() {
    Widget navItem(String label) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kAonDark,
            ),
          ),
        );

    Widget vDivider() => Container(
          width: 1,
          height: 28,
          color: Colors.grey.shade300,
        );

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.6,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 24,
      toolbarHeight: 70,
      title: Row(
        children: [
          // Logo AON testuale (puoi sostituire con Image.asset)
          Text(
            'AON',
            style: GoogleFonts.roboto(
              color: kAonRed,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 24),
          navItem('Fisioterapisti'),
          navItem('Chi Siamo'),
          navItem('Assicurazioni'),
          navItem('Supporto'),
          navItem('Contatti'),
        ],
      ),
      actions: [
        // Toggle CHAT
        IconButton(
          tooltip: _chatsOpen ? 'Nascondi chat' : 'Mostra chat',
          icon: Icon(
            _chatsOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
            color: kAonDark,
          ),
          onPressed: () {
            setState(() {
              _chatsOpen = !_chatsOpen;
              if (_chatsOpen) {
                DualPaneRegistry.openAll();
              } else {
                DualPaneRegistry.closeAll();
              }
            });
          },
        ),
        const SizedBox(width: 8),
        vDivider(),
        const SizedBox(width: 8),
        _LanguageMenu(
          current: 'it',
          onChange: (lang) => setState(() {
            // qui eventualmente potresti cambiare la localizzazione
          }),
        ),
        const SizedBox(width: 8),
        vDivider(),
        const SizedBox(width: 8),
        _UserMenu(accessToken: widget.token.accessToken),
        const SizedBox(width: 24),
      ],
    );
  }

  /*────────────────────────────
   *           BODY
   *──────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    final themed = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: kAonRed,
        secondary: kAonRed,
        onPrimary: Colors.white,
      ),
      primaryColor: kAonRed,
      textTheme: GoogleFonts.robotoTextTheme(base.textTheme),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Container(
          color: Colors.white,
          child: DualPaneWrapper(
            // il DualPaneWrapper ingloba tutta la home e ospita il mini-panel chat
            user: widget.user,
            token: widget.token,
            controller: _paneCtrlHome,
            leftChild: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      _buildHeroSection(),
                      const SizedBox(height: 48),
                      _buildHowToSection(),
                      const SizedBox(height: 48),
                      _buildPoliciesSection(),
                      const SizedBox(height: 56),
                      _buildSupportSection(),
                      const SizedBox(height: 56),
                      const Divider(height: 1),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*────────────────────────────
   *     SEZIONE 1 – HERO
   *──────────────────────────*/
  Widget _buildHeroSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 900;

        final left = Expanded(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.only(
              right: narrow ? 0 : 40,
              bottom: narrow ? 24 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Benvenuto nel portale\nriservato ai\nfisioterapisti',
                  style: GoogleFonts.roboto(
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: kAonDark,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'La copertura di responsabilità civile professionale '
                  'offerta in convenzione TSRM – PSTRP con Italiana Ass.ni '
                  'può essere rinnovata alle stesse condizioni economiche '
                  'nel periodo compreso tra il 1° gennaio 2025 e il 30 aprile 2025.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un pagamento effettuato, ad esempio, nel mese di marzo 2025 '
                  'preserva la continuità assicurativa come se fosse stato eseguito '
                  'entro il 31 dicembre 2024.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'I fisioterapisti iscritti ai nuovi Ordini potranno continuare a '
                  'rinnovare la polizza in convenzione nazionale TSRM–PSTRP, '
                  'in coerenza con il decreto istitutivo degli Ordini '
                  'e con il regolamento della federazione nazionale.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    // qui potresti aprire un PDF/tutoriel
                  },
                  child: Text(
                    'TUTORIAL ACQUISTO POLIZZA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kAonRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final right = Expanded(
          flex: 3,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    kAonLightGrey,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  // Placeholder per l’immagine a “ingranaggi” del portale AON.
                  // Sostituisci con Image.asset(...) quando hai lo screenshot.
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.settings_suggest_outlined,
                      size: 140,
                      color: Colors.blueAccent.withOpacity(0.35),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Area riservata\nFisioterapisti',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    left,
                    right,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    left,
                    right,
                  ],
                ),
        );
      },
    );
  }

  /*────────────────────────────
   *  SEZIONE 2 – COME FARE PER
   *──────────────────────────*/
  Widget _buildHowToSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Come fare per',
            style: GoogleFonts.roboto(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: kAonDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La nostra assistenza sinistri ti segue passo dopo passo '
            'nella gestione delle pratiche.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 960;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 2,
                    child: _HowToCard.newClient(),
                  ),
                  SizedBox(
                    width: narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 2,
                    child: _HowToCard.existingClient(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /*────────────────────────────
   *   SEZIONE 3 – LE NOSTRE POLIZZE
   *──────────────────────────*/
  Widget _buildPoliciesSection() {
    return Container(
      color: kAonLightGrey,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Le nostre polizze',
                style: GoogleFonts.roboto(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: kAonDark,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // naviga alla pagina con tutte le polizze
                },
                child: Text(
                  'SCOPRI TUTTE LE POLIZZE',
                  style: TextStyle(
                    color: kAonRed,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PolicyCard(),
        ],
      ),
    );
  }

  /*────────────────────────────
   *   SEZIONE 4 – SUPPORTO / SINISTRI
   *──────────────────────────*/
  Widget _buildSupportSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 960;
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              SizedBox(
                width: narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 2,
                child: _SupportCard.contact(),
              ),
              SizedBox(
                width: narrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 2,
                child: _SupportCard.claim(),
              ),
            ],
          );
        },
      ),
    );
  }

  /*────────────────────────────
   *            FOOTER
   *──────────────────────────*/
  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prima riga: logo + colonne link
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonna logo + dati base
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AON',
                      style: GoogleFonts.roboto(
                        color: kAonRed,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'P. IVA 11274970158\n'
                      'Via Calindri, 6 – 20143 Milano\n'
                      'Iscrizione RUI B000117871',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Colonne di link come nel footer originale
              Expanded(
                flex: 2,
                child: _FooterColumn(
                  title: 'Aon',
                  items: const [
                    'Chi Siamo',
                    'Contatti',
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _FooterColumn(
                  title: 'Polizze',
                  items: const [
                    'Tsrm-pstrp Rc Professionale\nsezione Fisioterapisti',
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _FooterColumn(
                  title: 'Supporto',
                  items: const [
                    'FAQ',
                    'In caso di sinistro',
                    'Documenti utili',
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _FooterColumn(
                  title: 'Informative',
                  items: const [
                    'Privacy policy',
                    'Cookie policy',
                    'Modalità dell\'informativa\nassicurativa',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'AON S.p.A. è società con socio unico soggetta alla direzione e '
            'coordinamento di AON Italia S.r.l. Iscritta al Registro delle '
            'Imprese di Milano. L’iscrizione al Registro Unico degli '
            'Intermediari assicurativi è consultabile sul sito IVASS.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

/*──────────────────────────────────────────────
 *   CARD “COME FARE PER”
 *────────────────────────────────────────────*/

class _HowToCard extends StatelessWidget {
  final bool dark;
  final String title;
  final String subtitle;
  final Color bg;
  final Color fg;

  const _HowToCard._({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.fg,
  });

  factory _HowToCard.newClient() => _HowToCard._(
        dark: false,
        title: 'Nuovo Cliente',
        subtitle:
            'Vuoi calcolare un preventivo o acquistare una polizza?\n'
            'Compila il form e scegli il metodo di pagamento che preferisci.',
        bg: Colors.white,
        fg: kAonDark,
      );

  factory _HowToCard.existingClient() => _HowToCard._(
        dark: true,
        title: 'Già Cliente',
        subtitle:
            'Accedi alla tua area riservata per calcolare un preventivo o '
            'rinnovare la tua polizza con il metodo di pagamento che preferisci.',
        bg: kAonDark,
        fg: Colors.white,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              dark ? Icons.umbrella_outlined : Icons.gavel_outlined,
              color: dark ? Colors.white : kAonRed,
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vuoi calcolare un preventivo?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            Row(
              children: [
                Text(
                  'Compila il form e ottieni una quotazione adatta a te.',
                  style: TextStyle(
                    fontSize: 13,
                    color: fg.withOpacity(0.85),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: fg,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vuoi acquistare una polizza?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: fg.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*──────────────────────────────────────────────
 *     CARD POLIZZA
 *────────────────────────────────────────────*/

class _PolicyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.balance_outlined,
              color: kAonRed,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'TSRM-PSTRP RC Professionale – Sezione Fisioterapisti',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kAonDark,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                // dettagli polizza
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAonRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text(
                'SCOPRI DI PIÙ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*──────────────────────────────────────────────
 *     CARD SUPPORTO / SINISTRO
 *────────────────────────────────────────────*/

class _SupportCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _SupportCard._({
    required this.title,
    required this.body,
    required this.icon,
  });

  factory _SupportCard.contact() => const _SupportCard._(
        title: 'Aon è qui per aiutarti, contattaci',
        body:
            'I nostri call center sono a tua disposizione per offrirti supporto '
            'e consigli personalizzati.',
        icon: Icons.phone_in_talk_outlined,
      );

  factory _SupportCard.claim() => const _SupportCard._(
        title: 'Sei stato coinvolto in un sinistro?',
        body:
            'Consulta la nostra assistenza sinistri: ti accompagniamo passo '
            'passo nella gestione delle pratiche.',
        icon: Icons.cloud_off_outlined,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: kAonRed),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kAonDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.arrow_forward,
              size: 18,
              color: kAonRed,
            ),
          ],
        ),
      ),
    );
  }
}

/*──────────────────────────────────────────────
 *          FOOTER COLUMN
 *────────────────────────────────────────────*/

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;

  const _FooterColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kAonDark,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Text(
              item,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/*──────────────────────────────────────────────
 *           USER MENU (LOGOUT)
 *────────────────────────────────────────────*/

class _UserMenu extends StatelessWidget {
  final String accessToken;
  const _UserMenu({required this.accessToken});

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
            // LOGOUT: come nel tuo esempio
            html.window.localStorage
              ..remove('token')
              ..remove('refreshToken')
              ..remove('user');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            );
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
            child: const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'User Name',
            style: TextStyle(color: kAonDark),
          ),
          const Icon(Icons.arrow_drop_down, color: kAonDark),
        ],
      ),
    );
  }

  PopupMenuItem<int> _item(int v, String label, IconData icon) =>
      PopupMenuItem<int>(
        value: v,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );
}

/*──────────────────────────────────────────────
 *            LANGUAGE MENU
 *────────────────────────────────────────────*/

class _LanguageMenu extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChange;
  const _LanguageMenu({required this.current, required this.onChange});

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
            child: Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 12),
                Text(label[code]!),
                if (code == current) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: kAonRed),
                ],
              ],
            ),
          ),
      ],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Lingua',
            style: TextStyle(color: kAonDark, fontSize: 11),
          ),
          Row(
            children: [
              Text(
                label[current]!,
                style: const TextStyle(
                  color: kAonDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: kAonDark, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
