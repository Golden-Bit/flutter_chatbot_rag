import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/sign_up_request.dart';
import 'package:flutter_app/user_manager/pages/confirm_email_page.dart';
import 'package:flutter/material.dart';

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

class RegistrationPasswordPage extends StatefulWidget {
  final String email;

  /// Ricevi l'email (già inserita nella pagina precedente) come parametro
  const RegistrationPasswordPage({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<RegistrationPasswordPage> createState() => _RegistrationPasswordPageState();
}

class _RegistrationPasswordPageState extends State<RegistrationPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
final CognitoApiClient _apiClient = CognitoApiClient();
  bool _obscurePassword1 = true; // per mostrare/nascondere il primo campo password
  bool _obscurePassword2 = true; // per mostrare/nascondere il secondo campo (conferma password)

  /// Esempio di funzione per la logica di "Continua"
  /// Potrebbe validare le due password (uguali?), poi fare signup Cognito, ecc.
Future<void> _onContinuePressed() async {
  final password = _passwordController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();

  // Validazioni base
  if (password.isEmpty || confirmPassword.isEmpty) {
    debugPrint('Uno dei campi password è vuoto!');
    return;
  }
  if (password != confirmPassword) {
    debugPrint('Le password non coincidono!');
    return;
  }

  try {
    // 1) Prepariamo la richiesta
    final signUpRequest = SignUpRequest(
      username: generateUserName(widget.email),
      password: password,
      email: widget.email,
    );

    // 2) Chiamata Cognito signUp
    final response = await _apiClient.signUp(signUpRequest);
    debugPrint('SignUp Response: $response');

    // 3) Se OK, andiamo alla pagina di conferma email
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmEmailPage(email: widget.email),
      ),
    );
  } catch (e) {
    debugPrint('Errore signUp: $e');
    // Qui potresti mostrare un messaggio d’errore a schermo
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: Colors.white,
      body: Center(
        // Usiamo SingleChildScrollView per adattarci a schermi piccoli o tastiera aperta
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
                    'Crea un account',
                                      textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  // Testo descrittivo secondario
                  const SizedBox(height: 8),
                  const Text(
                    'Per continuare, imposta la tua password per Boxed AI',
                                      textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // Campo email (non modificabile), con link "Modifica"
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
                            enabled: false, // disabilitato
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Torna alla pagina precedente per cambiare email
                          Navigator.pop(context);
                        },
                        child: const Text('Modifica'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo Password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword1,
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
                          _obscurePassword1
                              ? Icons.remove_red_eye_outlined
                              : Icons.remove_red_eye,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword1 = !_obscurePassword1;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo Conferma Password
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword2,
                    decoration: InputDecoration(
                      labelText: 'Conferma password',
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
                          _obscurePassword2
                              ? Icons.remove_red_eye_outlined
                              : Icons.remove_red_eye,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword2 = !_obscurePassword2;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottone "Continua" (sfondo nero)
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
                      onPressed: _onContinuePressed,
                      child: const Text(
                        'Continua',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer con Condizioni e Privacy
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
