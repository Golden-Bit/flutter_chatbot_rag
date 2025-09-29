import 'dart:convert';
import 'dart:html' as html;

//import 'package:boxed_ai/apps/example_app_2/app.dart';
//import 'package:boxed_ai/apps/example_app_3/app.dart';
import 'package:flutter/material.dart';
import 'package:boxed_ai/apps/enac_app/app.dart';
import 'package:boxed_ai/chatbot.dart';
import 'package:boxed_ai/ui_components/custom_components/general_components_v1.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:boxed_ai/user_manager/components/social_button.dart';
import 'package:boxed_ai/user_manager/pages/registration_page_1.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'login_page_2.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final CognitoApiClient _apiClient = CognitoApiClient();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isCheckingToken = true; 

  @override
  void initState() {
    super.initState();
    //_checkLocalStorageAndNavigate();
    _handleRedirectOrLocalToken();
  }

 /// 1) Controlla se esiste `token` in localStorage; se sì, prova a usare GetUserInfo.
  /// 2) Se non c'è token o non è valido, controlla se nella URL è presente `code=...`.
  ///    Se `code` esiste, chiama exchangeAzureCodeForTokens e procedi al login.
  Future<void> _handleRedirectOrLocalToken() async {
    final storedToken = html.window.localStorage['token'];
    final storedRefresh = html.window.localStorage['refreshToken'];

    // 1) Se ho token e refresh token salvati, provo a recuperarli
    if (storedToken != null && storedRefresh != null) {
      try {
        final token = Token(
          accessToken: storedToken,
          refreshToken: storedRefresh,
        );

        // Provo a leggere le info utente
        final userInfoRequest = GetUserInfoRequest(accessToken: token.accessToken);
        final userInfo = await _apiClient.getUserInfo(userInfoRequest);

        // Se vanno a buon fine, navigo direttamente
        _navigateToChatBot(userInfo: userInfo, token: token);
        return;
      } catch (_) {
        // Se fallisce, cadremo al “non ho token valido” e proveremo il redirect
      }
    }

    // 2) Se non ho un token valido, controllo se nella URL del browser c'è “?code=...”
    final urlSearch = html.window.location.search; // es. "?code=a55463c9-..."
    if (urlSearch!.startsWith('?code=')) {
      // Estraggo il valore di code
      final code = Uri.parse(html.window.location.href).queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        try {
          // Scambio il code per i token Cognito
          final token = await _apiClient.exchangeAzureCodeForTokens(code);

          // Memorizzo in localStorage
          html.window.localStorage['token'] = token.accessToken;
          if (token.refreshToken != null) {
            html.window.localStorage['refreshToken'] = token.refreshToken!;
          }

          // Ora richiedo GetUserInfo per recuperare l'utente
          final userInfoRequest = GetUserInfoRequest(accessToken: token.accessToken);
          final userInfo = await _apiClient.getUserInfo(userInfoRequest);

          // Pulisco la querystring dalla URL per evitare di rifare login se ricarico
          html.window.history.replaceState(null, 'LoggedIn', html.window.location.pathname);

          // Navigo a ChatBotPage
          _navigateToChatBot(userInfo: userInfo, token: token);
          return;
        } catch (e) {
          // Se lo scambio code/token fallisce, mostro un errore
          setState(() {
            _isCheckingToken = false;
            _errorMessage = 'Errore durante login federato: $e';
          });
          return;
        }
      }
    }

    // 3) Nessun token valido e nessun code in URL → mostro la UI di login
    setState(() {
      _isCheckingToken = false;
    });
  }

  /// Dato `userInfo` e `token`, istanzia il modello User e naviga alla ChatBotPage
  void _navigateToChatBot({
    required Map<String, dynamic> userInfo,
    required Token token,
  }) {
    // Estraggo Username
    final username = userInfo['Username'] as String? ?? '';
    // Estraggo email dal campo UserAttributes
    String email = '';
    if (userInfo['UserAttributes'] != null) {
      for (final attr in (userInfo['UserAttributes'] as List<dynamic>)) {
        if (attr['Name'] == 'email') {
          email = attr['Value'] as String;
          break;
        }
      }
    }
    // Creo il modello User (fullName = username, come prima)
    final user = User(
      username: username,
      email: email,
      fullName: username,
    );
    // Navigo sostituendo la pagina corrente
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatBotPage(user: user, token: token), //ChatBotPage(user: user, token: token)), //HomeScaffold(user: user, token: token)), //DualPaneChatPage(user: user, token: token)), //ChatBotPage(user: user, token: token),
    ));
  }

  /// Quando l'utente clicca “Continua con Microsoft”, recupero l'URL di login da backend
  /// e ridirigo il browser verso quell'endpoint (Hosted UI Cognito → Azure AD).
  Future<void> _onSocialPressed(String providerName) async {
    if (providerName != 'Microsoft') {
      // Per ora gestiamo solo Microsoft; per gli altri (Google/Apple) metti un fallback
      debugPrint('Provider non gestito: $providerName');
      return;
    }
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });
    try {
      final loginUrl = await _apiClient.getAzureLoginUrl();
      // Effettuo il redirect del browser intero verso Cognito Hosted UI
      html.window.location.href = loginUrl;
      // Non serve fare altro: verrà richiamato initState alla redirect
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore Invio al login federato: $e';
        _isLoading = false;
      });
    }
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
            builder: (_) => ChatBotPage(user: user, token: token), //ChatBotPage(user: user, token: token), // HomeScaffold(user: user, token: token), //DualPaneChatPage(user: user, token: token)), //ChatBotPage(user: user, token: token), //ChatBotPage(user: user, token: token),
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

  /*void _onSocialPressed(String providerName) {
    debugPrint('Hai cliccato su login con: $providerName');
  }*/

  @override
  Widget build(BuildContext context) {
    if (_isCheckingToken) {
      return Scaffold(
        backgroundColor: Colors.white,
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
              backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                smallFullLogo,
                Text(
                  'Ci fa piacere ritrovarti',
                  textAlign: TextAlign.center,
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
                /*SocialButton(
                  provider: SocialProvider.apple,
                  onTap: () => _onSocialPressed('Apple'),
                ),
                const SizedBox(height: 12),*/
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
