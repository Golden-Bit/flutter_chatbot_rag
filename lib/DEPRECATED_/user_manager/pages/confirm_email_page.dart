import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/confirm_sign_up_request.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/resend_confirm_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/user_manager/pages/login_page_2.dart';
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
class ConfirmEmailPage extends StatefulWidget {
  final String email;

  /// Ricevi l’email dall'esterno, per mostrarla all’utente.
  const ConfirmEmailPage({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  final TextEditingController _codeController = TextEditingController();

  // Istanza del nostro CognitoApiClient
  final CognitoApiClient _apiClient = CognitoApiClient();

  bool _isLoading = false;
  String _errorMessage = '';

  /// Funzione per gestire la conferma dell'email
  /// chiama l'endpoint /v1/user/confirm-signup-user tramite lo SDK.
  Future<void> _onContinuePressed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final code = _codeController.text.trim();
    try {
      // Creiamo la richiesta
      final requestData = ConfirmSignUpRequest(
        username: generateUserName(widget.email),     // username == email
        confirmationCode: code,     // codice inserito
      );

      // Chiamata allo SDK
      final response = await _apiClient.confirmSignUpUser(requestData);
      // Esempio di output: { "ResponseMetadata": {...}, ... }

      debugPrint('Conferma avvenuta: $response');

      // Se tutto ok, naviga al passaggio successivo o mostra un messaggio di successo
      // Esempio:
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (_) => LoginPasswordPage(email: widget.email)),
       );

    } catch (e) {
      // In caso di errore, lo mostriamo a schermo
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Funzione per reinviare l'email di conferma
  /// chiama l'endpoint /v1/user/resend-confirmation-code tramite lo SDK.
  void _onResendEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final resendRequest = ResendConfirmationCodeRequest(username: widget.email);
      final response = await _apiClient.resendConfirmationCode(resendRequest);
      // Esempio di output: { "CodeDeliveryDetails": {...}, "ResponseMetadata": {...} }

      debugPrint('Reinviata mail di conferma: $response');
      // Puoi mostrare un banner "Email rinviata con successo"

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // SingleChildScrollView per evitare overflow su schermi piccoli
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titolo principale
                Text(
                  'Controlla la posta in arrivo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Testo descrittivo
                Text(
                  'Inserisci il codice di verifica che abbiamo appena inviato all’indirizzo ${widget.email}.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                // Campo Codice
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Codice',
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
                  ),
                ),

                const SizedBox(height: 24),

                // Bottone Continua (nero)
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

                // Link "Reinvia e-mail"
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _onResendEmail,
                    child: const Text('Reinvia e-mail'),
                  ),
                ),

                // Mostra errori eventuali
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 32),

                // Footer: Condizioni d’uso e Informativa sulla privacy
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
    );
  }
}
