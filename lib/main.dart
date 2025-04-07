import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:flutter_app/user_manager/pages/login_page_1.dart';
import 'package:flutter_app/user_manager/pages/registration_page_1.dart';
import 'package:flutter_app/utilities/localization.dart';
import 'dart:html' as html;
import 'user_manager/auth_service.dart';
import 'chatbot_auth.dart';
import 'user_manager/user_model.dart';
import 'utils.dart';
import 'databases_manager/database_service_auth.dart';

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
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyMedium: GoogleFonts.inter(fontSize: 14),
        ),
      ),
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegistrationPage(),
      },
    );
  }
}

/*class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true; // Stato per gestire la schermata di caricamento
  //final AuthService _authService = AuthService();
  final CognitoApiClient _apiClient = CognitoApiClient();
final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

// Verifica lo stato di login dell'utente
void _checkLoginStatus() async {
  String? accessToken = html.window.localStorage['token'];
  String? refreshToken = html.window.localStorage['refreshToken'];

  if (accessToken != null) {
    try {

            final getUserInfoRequest = GetUserInfoRequest(
      accessToken: accessToken, // username == email
    );

Map<String, dynamic> userInfo = await _apiClient.getUserInfo(getUserInfoRequest);

// Estrai il valore di username direttamente dal campo "Username"
String username = userInfo['Username'] ?? '';

// Inizializza la variabile email
String email = '';

// Se sono presenti gli attributi utente, cerca quello relativo all'email
if (userInfo['UserAttributes'] != null) {
  List attributes = userInfo['UserAttributes'];
  for (var attribute in attributes) {
    if (attribute['Name'] == 'email') {
      email = attribute['Value'];
      break;
    }
  }
}

// Costruisci l'oggetto User impostando fullName uguale a username
User user = User(
  username: username,
  email: email,
  fullName: username,
);

      // Crea il database dell'utente se non esiste
      await _createUserDatabase(user.username, accessToken);

      // Naviga alla ChatBotPage se il token è valido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: Token(accessToken: accessToken!, refreshToken: refreshToken!)),
          ),
        );
      });
    } catch (e) {
      // Se il token è invalido, rimuovilo e mostra la pagina di login
      html.window.localStorage.remove('token');
      html.window.localStorage.remove('refreshToken');
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
}*/
