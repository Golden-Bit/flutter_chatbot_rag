import 'package:flutter/material.dart';
import 'package:boxed_ai/ui_components/custom_components/general_components_v1.dart';
import 'package:boxed_ai/user_manager/components/social_button.dart';
import 'package:boxed_ai/user_manager/pages/login_page_1.dart';
import 'package:boxed_ai/user_manager/pages/registration_page_2.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  /// Esempio di funzione placeholder per la logica del pulsante "Continua".
  /// Potrebbe avviare un flusso di registrazione su Cognito o passare a uno step successivo.
  Future<void> _onContinuePressed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final email = _emailController.text.trim();

    try {
// 2) Naviga alla seconda pagina di registrazione (per inserire password)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationPasswordPage(email: email),
        ),
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

  /// Naviga verso la pagina di login
  void _onLoginPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  // Esempio di placeholders per i social login
  void _onSocialPressed(String providerName) {
    // In un contesto reale, potresti chiamare /v1/user/social/login-url?provider=providerName
    // e poi aprire l'URL in un browser. Qui mostriamo solo un log:
    debugPrint('Hai cliccato su registrazione con: $providerName');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
              backgroundColor: Colors.white,
      body: Center(
        // SingleChildScrollView per scrollare se la tastiera copre i campi
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
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
                const SizedBox(height: 20),

                // Campo email con bordi arrotondati e focus blu chiaro
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

                const SizedBox(height: 20),

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

                // Link "Hai già un account? Accedi"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hai già un account?'),
                    TextButton(
                      onPressed: _onLoginPressed,
                      child: const Text('Accedi'),
                    ),
                  ],
                ),

                // Divider con la scritta "OPPURE" al centro
                Row(
                  children: const [
                    Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OPPURE'),
                    ),
                    Expanded(child: Divider(thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),

                // SocialButton
                SocialButton(
                  provider: SocialProvider.google,
                  onTap: () => _onSocialPressed('Google'),
                ),
                const SizedBox(height: 12),

                SocialButton(
                  provider: SocialProvider.microsoft,
                  onTap: () => _onSocialPressed('Microsoft'),
                ),
                const SizedBox(height: 12),

                SocialButton(
                  provider: SocialProvider.apple,
                  onTap: () => _onSocialPressed('Apple'),
                ),

                // Mostra eventuali errori (es. registrazione fallita)
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 20),

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
    );
  }
}
