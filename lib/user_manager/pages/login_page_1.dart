import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_app/chatbot_auth.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:flutter_app/user_manager/components/social_button.dart';
import 'package:flutter_app/user_manager/pages/registration_page_1.dart';
import 'package:flutter_app/user_manager/user_model.dart';
import 'login_page_2.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  /// Variabile per mostrare il logo mentre carichiamo
  bool _isCheckingToken = true;

  @override
  void initState() {
    super.initState();
    _checkLocalStorageAndNavigate();
  }

  Future<void> _checkLocalStorageAndNavigate() async {
    final storedToken = html.window.localStorage['token'];
    final storedRefreshToken = html.window.localStorage['refreshToken'];

    final CognitoApiClient _apiClient = CognitoApiClient();

    if (storedToken != null && storedRefreshToken != null) {
      try {
        Token token = Token(
          accessToken: storedToken,
          refreshToken: storedRefreshToken,
        );

        final getUserInfoRequest = GetUserInfoRequest(
          accessToken: token.accessToken,
        );

        Map<String, dynamic> userInfo =
            await _apiClient.getUserInfo(getUserInfoRequest);

        String username = userInfo['Username'] ?? '';
        String email = '';

        if (userInfo['UserAttributes'] != null) {
          List attributes = userInfo['UserAttributes'];
          for (var attribute in attributes) {
            if (attribute['Name'] == 'email') {
              email = attribute['Value'];
              break;
            }
          }
        }

        User user = User(
          username: username,
          email: email,
          fullName: username,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatBotPage(user: user, token: token),
          ),
        );
        return;
      } catch (e) {
        debugPrint('Token/User non validi: $e');
      }
    }

    // Se arriviamo qui, mostriamo la UI di login
    setState(() {
      _isCheckingToken = false;
    });
  }

  Future<void> _onContinuePressed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _emailController.text.trim();

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPasswordPage(email: username),
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

  void _onRegisterPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationPage()),
    );
  }

  void _onSocialPressed(String providerName) {
    debugPrint('Hai cliccato su login con: $providerName');
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingToken) {
      return Scaffold(
        body: Center(
          child: Image.network(
            'https://static.wixstatic.com/media/63b1fb_396f7f30ead14addb9ef5709847b1c17~mv2.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ci fa piacere ritrovarti',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Non hai un account?'),
                    TextButton(
                      onPressed: _onRegisterPressed,
                      child: const Text('Registrati'),
                    ),
                  ],
                ),
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
                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
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
