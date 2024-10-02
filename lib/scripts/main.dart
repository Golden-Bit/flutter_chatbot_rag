import 'package:flutter/material.dart';
import 'package:flutter_app/document_manager/documents_utils.dart';
import 'package:flutter_app/document_manager/file_manager_service.dart';
import 'user_manager/auth_pages.dart';
import 'user_manager/user_model.dart';
import 'databases_manager/database_pages.dart';
import 'calendar.dart';  // Importa il file del calendario
import 'task_board.dart';  // Importa il TaskBoard
import 'contacts.dart';  // Importa il ContactManager
import 'products.dart';  // Importa il ProductManagerPage
import 'services.dart';  // Importa il ServiceManagerPage
import 'esg_data_manager/euroistat.dart'; // Importa la pagina di analisi ESG
import 'esg_data_manager/yahoo_finance.dart'; // Importa la pagina di analisi ESG aziendale
import 'chatbot/chatbot.dart';
//import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';  // Importa il pacchetto per la WebView
import 'package:url_launcher/url_launcher.dart';  // Importa url_launcher

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  final User user;
  final Token token;

  HomePage({required this.user, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double gridWidth = constraints.maxWidth < 400 ? constraints.maxWidth : 400;
            return Container(
              width: gridWidth,
              child: GridView.count(
                crossAxisCount: 3,  // Tre schede per riga
                childAspectRatio: 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildGridCard(
                    context,
                    icon: Icons.settings,
                    label: 'Impostazioni',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AccountSettingsPage(user: user, token: token),
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.storage,
                    label: 'Databases',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DatabasePage(databases: user.databases, token: token.accessToken, user: user),
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.calendar_today,
                    label: 'Calendario',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarComponent(token: token.accessToken),  // Passa il token al CalendarComponent
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.task,
                    label: 'Task Manager',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskBoard(token: token.accessToken),  // Passa il token al TaskBoard
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.contacts,
                    label: 'Gestione Contatti',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ContactManagerPage(token: token.accessToken),  // Passa il token al ContactManagerPage
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.shopping_cart,
                    label: 'Gestione Prodotti',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductManagerPage(token: token.accessToken),  // Passa il token al ProductManagerPage
                        ),
                      );
                    },
                  ),
                  _buildGridCard(
                    context,
                    icon: Icons.build,
                    label: 'Gestione Servizi',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceManagerPage(token: token.accessToken),  // Passa il token al ServiceManagerPage
                        ),
                      );
                    },
                  ),
                    _buildGridCard(
    context,
    icon: Icons.description,  // Icona per i documenti
    label: 'Gestione Documenti',
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentManagerHomePage(
            currentFolder: FolderInfo.root(),
            path: "Root",
            token: token.accessToken,  // Passa il token al gestore dei documenti
          ),
        ),
      );
    },
  ),_buildGridCard(
   context,
   icon: Icons.bar_chart,  // Icona per l'analisi ESG
   label: 'MacroAnalisi ESG',
   onTap: () {
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => DataScreen(),  // Passa il token alla pagina di analisi ESG
       ),
     );
   },
 ),_buildGridCard(
  context,
  icon: Icons.bar_chart,  // Icona per l'analisi ESG
  label: 'Analisi ESG',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ESGDataScreen(),  // Pagina di analisi ESG
      ),
    );
  },
), _buildGridCard(
                    context,
                    icon: Icons.chat,  // Nuova icona per il ChatBot
                    label: 'ChatBot',
                    onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatBotPage(),  // Pagina di analisi ESG
      ),
    );
  },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;

          return MouseRegion(
            onEnter: (_) {
              setState(() => isHovered = true);
            },
            onExit: (_) {
              setState(() => isHovered = false);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              transform: Matrix4.identity()..scale(isHovered ? 1.05 : 1.0),
              curve: Curves.easeInOut,
              child: Card(
                elevation: isHovered ? 8.0 : 4.0,
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 32.0),
                        SizedBox(height: 4.0),
                        Text(
                          label,
                          style: TextStyle(fontSize: 12.0),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}



