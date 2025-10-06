import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/ui_components/custom_components/general_components_v1.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/sign_up_request.dart';
import 'package:boxed_ai/user_manager/pages/confirm_email_page.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart' show showCognitoError;

String generateUserName(String email) {
  final bytes = utf8.encode(email);
  final digest = sha256.convert(bytes);
  final base64Str =
      base64Url.encode(digest.bytes).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  return 'user-${base64Str.substring(0, 9)}';
}

class RegistrationPasswordPage extends StatefulWidget {
  final String email;
  const RegistrationPasswordPage({Key? key, required this.email})
      : super(key: key);

  @override
  State<RegistrationPasswordPage> createState() =>
      _RegistrationPasswordPageState();
}

class _RegistrationPasswordPageState extends State<RegistrationPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final CognitoApiClient _apiClient = CognitoApiClient();

  // visibilità
  bool _showPwd = false;
  bool _showConfirm = false;

  // stato di rete
  bool _isLoading = false;
  String _errorMessage = '';

  // Regole: ≥8, una minuscola, una maiuscola, un numero, un carattere speciale
  final RegExp _pwdRules =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$');

  // helper dinamici
  String? get _confirmHelper =>
      _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _pwdCtrl.text
          ? 'Le password coincidono.'
          : null;

  bool get _confirmMatches =>
      _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _pwdCtrl.text;

  bool get _pwdValid => _pwdRules.hasMatch(_pwdCtrl.text);

  bool get _canContinue =>
      !_isLoading && _pwdValid && _confirmMatches && _pwdCtrl.text.isNotEmpty;

  // bridge per showCognitoError
  void _setError(String msg) => _errorMessage = msg;

  @override
  void initState() {
    super.initState();
    _pwdCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    // valida form (errorText sotto i campi)
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || !_canContinue) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final req = SignUpRequest(
        username: generateUserName(widget.email),
        password: _pwdCtrl.text.trim(),
        email: widget.email,
      );

      await _apiClient.signUp(req);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmEmailPage(email: widget.email),
        ),
      );
    } catch (e) {
      showCognitoError(this, _setError, e);
      if (mounted) setState(() {}); // per mostrare _errorMessage
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      smallFullLogo,
                      Text(
                        'Crea un account',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Per continuare, imposta la tua password per Boxed AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),

                      // e-mail (readonly)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              readOnly: true,
                              controller:
                                  TextEditingController(text: widget.email),
                              decoration: InputDecoration(
                                labelText: 'Indirizzo e-mail',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                enabled: false,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Modifica'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ───────────────────────── Form ─────────────────────────
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: [
                            // Password
                            TextFormField(
                              controller: _pwdCtrl,
                              obscureText: !_showPwd,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle:
                                    const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                        color: Colors.lightBlue, width: 2)),
                                suffixIcon: IconButton(
                                  icon: Icon(!_showPwd
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () =>
                                      setState(() => _showPwd = !_showPwd),
                                ),
                                // helper sottile (grigio) – scompare se c'è un errore
                                helperText:
                                    'Min 8 caratteri, una maiuscola, una minuscola, un numero e un carattere speciale.',
                                    helperMaxLines: 3,
                                helperStyle: const TextStyle(
                                    color: Colors.black54, fontSize: 12),
                                    errorMaxLines: 3,
                                    hintMaxLines: 3,
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Inserisci la password';
                                }
                                if (!_pwdRules.hasMatch(val)) {
                                  return 'La password non rispetta i requisiti. Min 8 caratteri, una maiuscola, una minuscola, un numero e un carattere speciale.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Conferma password
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: !_showConfirm,
                              decoration: InputDecoration(
                                labelText: 'Conferma password',
                                labelStyle:
                                    const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(
                                        color: Colors.lightBlue, width: 2)),
                                suffixIcon: IconButton(
                                  icon: Icon(!_showConfirm
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setState(
                                      () => _showConfirm = !_showConfirm),
                                ),
                                // helper verde se coincidono
                                helperText: _confirmHelper,
                                helperStyle: TextStyle(
                                  color: _confirmMatches
                                      ? Colors.green
                                      : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Conferma la password';
                                }
                                if (val != _pwdCtrl.text) {
                                  return 'Le password non coincidono.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Continua
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed:
                              (_canContinue) ? _onContinuePressed : null,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Continua',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // errori Cognito / generici
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],

                      // footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                debugPrint('Apri condizioni d\'uso'),
                            child: const Text('Condizioni d’uso'),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () =>
                                debugPrint('Apri informativa sulla privacy'),
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

          // overlay caricamento (oscura leggermente)
          if (_isLoading)
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
