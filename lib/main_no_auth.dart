import 'package:flutter/material.dart';
import 'package:flutter_app/utilities/localization.dart';
import 'dart:html' as html;
import 'user_manager/auth_service.dart';
import 'chatbot.dart';
import 'user_manager/auth_pages.dart'; // Pagina di login e registrazione
import 'user_manager/user_model.dart'; // Modello utente
import 'utils.dart'; // Schermata di caricamento
import 'databases_manager/database_service.dart'; // Schermata di caricamento

void main() {
  runApp(
    LocalizationProviderWrapper(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'teatek LLM',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AppInitializer(), // Usa il widget per l'inizializzazione
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true; // Stato per gestire la schermata di caricamento
  final AuthService _authService = AuthService();
final DatabaseService _databaseService = DatabaseService();
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

// Verifica lo stato di login dell'utente
void _checkLoginStatus() async {
  String? token = html.window.localStorage['token'];

  if (token != null) {
    try {
      // Verifica la validità del token
      User user = await _authService.fetchCurrentUser(token);

      // Crea il database dell'utente se non esiste
      await _createUserDatabase(user.username, token);

      // Naviga alla ChatBotPage se il token è valido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: Token(accessToken: token, refreshToken: "")),
          ),
        );
      });
    } catch (e) {
      // Se il token è invalido, rimuovilo e mostra la pagina di login
      html.window.localStorage.remove('token');
      html.window.localStorage.remove('user');
      _showLoginPage();
    }
  } else {
    _showLoginPage(); // Mostra la pagina di login se non esiste token
  }
}

// Funzione per creare il database dell'utente
Future<void> _createUserDatabase(String userName, String token) async {
  try {
    await _databaseService.createDatabase("database", token);
    print("User database created successfully.");
  } catch (e) {
    print("Error creating user database: $e");
  }
}

  // Funzione per mostrare la pagina di login
  void _showLoginPage() {
    // Usa addPostFrameCallback per evitare problemi di build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostra una schermata di caricamento mentre si verifica lo stato del login
    return _isLoading ? LoadingScreen() : Container();
  }
}
