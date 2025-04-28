import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/ui_components/custom_components/general_components_v1.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/sign_up_request.dart';
import 'package:flutter_app/user_manager/pages/confirm_email_page.dart';

String generateUserName(String email) {
  final bytes = utf8.encode(email);
  final digest = sha256.convert(bytes);
  final base64Str = base64Url
      .encode(digest.bytes)
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  return 'user-${base64Str.substring(0, 9)}';
}

class RegistrationPasswordPage extends StatefulWidget {
  final String email;
  const RegistrationPasswordPage({Key? key, required this.email}) : super(key: key);

  @override
  State<RegistrationPasswordPage> createState() => _RegistrationPasswordPageState();
}

class _RegistrationPasswordPageState extends State<RegistrationPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final CognitoApiClient _apiClient = CognitoApiClient();

  // --- UI state ----------------------------------------------------------------
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;
  bool? _passwordsMatch;              // null = l'utente deve ancora digitare
  String _matchMessage = '';
  String _errorMessage = '';
  bool _isLoading = false;

  // setters "bridge" per showCognitoError helper
  void _setError(String msg) => _errorMessage = msg;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswords);
    _confirmPasswordController.addListener(_validatePasswords);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------------
  void _validatePasswords() {
    final pw = _passwordController.text;
    final cpw = _confirmPasswordController.text;

    setState(() {
      if (pw.isEmpty && cpw.isEmpty) {
        _passwordsMatch = null;
        _matchMessage = '';
      } else if (pw == cpw) {
        _passwordsMatch = true;
        _matchMessage = 'Le password coincidono';
      } else {
        _passwordsMatch = false;
        _matchMessage = 'Le password non coincidono';
      }
    });
  }

  Future<void> _onContinuePressed() async {
    if (_passwordsMatch != true) {
      showCognitoError(
        this,
        _setError,
        const UnknownCognitoException('Le password non coincidono'),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final signUpRequest = SignUpRequest(
        username: generateUserName(widget.email),
        password: _passwordController.text.trim(),
        email: widget.email,
      );

      await _apiClient.signUp(signUpRequest);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmEmailPage(email: widget.email),
        ),
      );
    } catch (e) {
      showCognitoError(this, _setError, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Per continuare, imposta la tua password per Boxed AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),

                  // e‑mail (readonly)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          controller: TextEditingController(text: widget.email),
                          decoration: InputDecoration(
                            labelText: 'Indirizzo e‑mail',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
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

                  // password
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword1,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      floatingLabelStyle: MaterialStateTextStyle.resolveWith((states) => states.contains(MaterialState.focused) ? const TextStyle(color: Colors.lightBlue) : const TextStyle(color: Colors.grey)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.lightBlue, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword1 ? Icons.remove_red_eye_outlined : Icons.remove_red_eye),
                        onPressed: () => setState(() => _obscurePassword1 = !_obscurePassword1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // conferma
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword2,
                    decoration: InputDecoration(
                      labelText: 'Conferma password',
                      labelStyle: const TextStyle(color: Colors.grey),
                      floatingLabelStyle: MaterialStateTextStyle.resolveWith((states) => states.contains(MaterialState.focused) ? const TextStyle(color: Colors.lightBlue) : const TextStyle(color: Colors.grey)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.lightBlue, width: 2)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword2 ? Icons.remove_red_eye_outlined : Icons.remove_red_eye),
                        onPressed: () => setState(() => _obscurePassword2 = !_obscurePassword2),
                      ),
                    ),
                  ),

                  // match feedback
                  if (_matchMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _passwordsMatch == true ? Icons.check_circle : Icons.error,
                          size: 18,
                          color: _passwordsMatch == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _matchMessage,
                          style: TextStyle(
                            color: _passwordsMatch == true ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // continua
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: (_isLoading || _passwordsMatch != true) ? null : _onContinuePressed,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Continua', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // cognito / altre eccezioni
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],

                  // footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => debugPrint('Apri condizioni d\'uso'),
                        child: const Text('Condizioni d’uso'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () => debugPrint('Apri informativa sulla privacy'),
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
