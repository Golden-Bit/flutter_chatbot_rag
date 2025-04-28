import 'package:flutter/material.dart';
import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/confirm_forgot_password_request.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/forgot_password_request.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_app/user_manager/pages/login_page_2.dart';

String generateUserName(String email) {
  // Calcola l'hash SHA-256 dell'email
  var bytes = utf8.encode(email);
  var digest = sha256.convert(bytes);

  // Codifica l'hash in Base64 e rimuove eventuali caratteri non alfanumerici
  var base64Str = base64Url.encode(digest.bytes).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  // Tronca la stringa a 9 caratteri
  return 'user-${base64Str.substring(0, 9)}';
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Istanza dell'API Client
  final CognitoApiClient _apiClient = CognitoApiClient();
    bool _obscurePassword = true; // Controlla se la password è nascosta
    
  // Controlliamo su quale step siamo:
  // 0 = Utente deve inserire l'email per inviare codice
  // 1 = Utente deve inserire codice + nuova password
  int _step = 0;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  // Step 1: l’utente inserisce l’email e richiede un codice
  Future<void> _onSendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Inserisci un indirizzo email valido.';
      });
      return;
    }

    try {
      final request = ForgotPasswordRequest(username: generateUserName(email));
      final response = await _apiClient.forgotPassword(request);
      // Esempio di output: { "CodeDeliveryDetails": {...}, "ResponseMetadata": {...} }
      debugPrint('Codice di reset inviato: $response');

      // Passiamo allo step 1: l'utente deve inserire codice, nuova password
      setState(() {
        _step = 1;
      });
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

  // Step 2: l’utente inserisce codice, nuova password e la conferma
  Future<void> _onConfirmPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmNewPasswordController.text.trim();
    final email = _emailController.text.trim(); // email inserita allo step 1

    // Validazioni di base
    if (code.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tutti i campi sono obbligatori.';
      });
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Le password non coincidono.';
      });
      return;
    }

    try {
final request = ConfirmForgotPasswordRequest(
  username: generateUserName(email),   // ✅ stesso alias del passo 1
  confirmationCode: code,
  newPassword: newPassword,
);
      final response = await _apiClient.confirmForgotPassword(request);
      // Esempio di output: { "ResponseMetadata": {...} }
      debugPrint('Password reimpostata con successo: $response');

      // Potresti navigare alla pagina di login
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (_) => LoginPasswordPage(email: email)),
       );

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

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
                                smallFullLogo,
        Text(
          'Password dimenticata?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inserisci il tuo indirizzo e-mail per ricevere un codice di reset.',
                    textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),

        // Campo email
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Indirizzo e-mail',
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

        // Bottone "Invia codice" (nero)
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
            onPressed: _isLoading ? null : _onSendCode,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Invia codice',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
                        smallFullLogo,
        Text(
          'Codice ricevuto?',
                            textAlign: TextAlign.center,
                            
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inserisci il codice di verifica e imposta la tua nuova password.',
                            textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),

        // Campo codice
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: 'Codice di verifica',
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
        const SizedBox(height: 16),

        // Campo nuova password
        TextField(
          controller: _newPasswordController,
  obscureText: _obscurePassword, // Aggiunto per nascondere i caratteri
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
  suffixIcon: IconButton( // <--- Nuova riga
    icon: Icon(         // <--- Nuova riga
      _obscurePassword         // <--- Nuova riga
          ? Icons.remove_red_eye_outlined // <--- Se la password è nascosta, mostra l'icona "occhio barrato"
          : Icons.remove_red_eye,         // <--- Altrimenti, mostra l'icona "occhio"
    ),
    onPressed: () {      // <--- Nuova riga
      setState(() {      // <--- Nuova riga
        _obscurePassword = !_obscurePassword; // Inverte il valore di _obscurePassword
      });
    },
  ),
),

        ),
        const SizedBox(height: 16),

        // Campo conferma password
        TextField(
          controller: _confirmNewPasswordController,
  obscureText: _obscurePassword, // Aggiunto per nascondere i caratteri
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
  suffixIcon: IconButton( // <--- Nuova riga
    icon: Icon(         // <--- Nuova riga
      _obscurePassword         // <--- Nuova riga
          ? Icons.remove_red_eye_outlined // <--- Se la password è nascosta, mostra l'icona "occhio barrato"
          : Icons.remove_red_eye,         // <--- Altrimenti, mostra l'icona "occhio"
    ),
    onPressed: () {      // <--- Nuova riga
      setState(() {      // <--- Nuova riga
        _obscurePassword = !_obscurePassword; // Inverte il valore di _obscurePassword
      });
    },
  ),
),

        ),
        const SizedBox(height: 24),

        // Bottone "Reimposta password"
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
            onPressed: _isLoading ? null : _onConfirmPassword,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Reimposta password',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: Colors.white,
      body: Center(
        // Scroll se la tastiera copre i campi
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mostra un blocco UI diverso a seconda di _step
                  if (_step == 0) _buildStep0() else _buildStep1(),
                  const SizedBox(height: 16),

                  // Mostra eventuale errore
                  if (_errorMessage.isNotEmpty) ...[
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 40),

                  // Link "Condizioni d’uso" e "Informativa sulla privacy"
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
