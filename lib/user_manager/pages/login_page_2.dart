import 'package:flutter_app/chatbot.dart';
import 'package:flutter_app/databases_manager/database_service.dart';
import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/sign_in_request.dart';
import 'package:flutter_app/user_manager/pages/confirm_email_page.dart';
import 'package:flutter_app/user_manager/pages/forgot_password_page.dart';
import 'package:flutter_app/user_manager/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/user_model.dart';
import 'dart:html' as html;  // Importa per accedere a localStorage
import 'dart:convert';
import 'package:crypto/crypto.dart';


String generateUserName(String email) {
  // Calcola l'hash SHA-256 dell'email
  var bytes = utf8.encode(email);
  var digest = sha256.convert(bytes);

  // Codifica l'hash in Base64 e rimuove eventuali caratteri non alfanumerici
  var base64Str = base64Url.encode(digest.bytes).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  // Tronca la stringa a 9 caratteri
  return 'user-${base64Str.substring(0, 9)}';
}

class LoginPasswordPage extends StatefulWidget {
  final String email;

  /// Ricevi l'email come parametro dal "primo step" (pagina inserimento email)
  const LoginPasswordPage({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<LoginPasswordPage> createState() => _LoginPasswordPageState();
}


class _LoginPasswordPageState extends State<LoginPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final CognitoApiClient _apiClient = CognitoApiClient();
  //final CognitoApiClient _apiClient = CognitoApiClient();
final DatabaseService _databaseService = DatabaseService();
  bool _obscurePassword = true; // Mostra/nascondi la password
  bool _isLoading = false; // Indica se stiamo effettuando la chiamata login
  String _errorMessage = ''; // Per mostrare eventuali errori a schermo
void _setError(String msg) => _errorMessage = msg;
  
  Future<void> _onContinuePressed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final password = _passwordController.text.trim();

    try {
      // Creiamo il SignInRequest con email e password
      final signInRequest = SignInRequest(
        username: generateUserName(widget.email), // username == email
        password: password,
      );

      // Chiamata reale alla tua API Cognito
      final signInResponse = await _apiClient.signIn(signInRequest);

      debugPrint(
          'Login effettuato con successo: ${signInResponse.accessToken}');

      try {
        // Ottieni il token di accesso dopo il login

        // Memorizza il token nel localStorage
        //html.window.localStorage['token'] = token.accessToken;

        // Ottieni e memorizza anche l'utente
        //User user = await _authService.fetchCurrentUser(signInResponse.accessToken);
        //html.window.localStorage['user'] = user.toJson().toString();

        Token token = Token(
            accessToken: signInResponse.accessToken!,
            refreshToken: signInResponse.refreshToken!);
        //String username = _apiClient.getUsernameFromAccessToken(token.accessToken);

        final getUserInfoRequest = GetUserInfoRequest(
          accessToken: token.accessToken, // username == email
        );

        Map<String, dynamic> userInfo =
            await _apiClient.getUserInfo(getUserInfoRequest);

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

        // Memorizza il token nel localStorage
        html.window.localStorage['token'] = token.accessToken;
        html.window.localStorage['refreshToken'] = token.refreshToken!;
        html.window.localStorage['user'] = user.toJson().toString();

        // Naviga alla ChatBotPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: token),
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading =
              false; // Rimuovi lo stato di caricamento se c'è un errore
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante il login: $e'),
        ));
      }
    } on UserNotConfirmed {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => ConfirmEmailPage(email: widget.email)),
  );
} catch (e) {
    showCognitoError(this, _setError, e);
} finally {
      // Terminato il tentativo di login, disabilitiamo il caricamento
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: Colors.white,
      body: Center(
        // SingleChildScrollView per scrollare su schermi ridotti o con tastiera aperta
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                                  smallFullLogo,
                  // Titolo principale
                  Text(
                    'Inserisci la password',
                                      textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Campo "Indirizzo e-mail" disabilitato (o semplice testo), con pulsante "Modifica"
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(text: widget.email),
                          decoration: InputDecoration(
                            labelText: 'Indirizzo e-mail',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            enabled: false, // Campo disabilitato
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Torna alla pagina precedente per modificare l'email
                          Navigator.pop(context);
                        },
                        child: const Text('Modifica'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo password con icona "occhio" (mostra/nascondi)
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.focused)) {
                            return const TextStyle(color: Colors.lightBlue);
                          }
                          return const TextStyle(color: Colors.grey);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Colors.lightBlue,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.remove_red_eye_outlined
                              : Icons.remove_red_eye,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottone "Continua" - nero
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _isLoading ? null : _onContinuePressed,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Continua',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link "Password dimenticata?"
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        // Naviga alla pagina di ForgotPasswordPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text('Password dimenticata?'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mostriamo l'errore, se presente
                  if (_errorMessage.isNotEmpty) ...[
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  // Link Condizioni d'uso e Informativa sulla privacy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          debugPrint('Apri condizioni d\'uso');
                        },
                        child: const Text('Condizioni d’uso'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          debugPrint('Apri informativa sulla privacy');
                        },
                        child: const Text('Informativa sulla privacy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
