import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_model.dart';
import 'dart:html'
    as html; // Necessario per modificare window.location in Flutter Web
import 'models/change_password_request.dart';
import 'models/confirm_forgot_password_request.dart';
import 'models/confirm_sign_up_request.dart';
import 'models/forgot_password_request.dart';
import 'models/get_user_info_request.dart';
import 'models/resend_confirm_request.dart';
import 'models/sign_up_request.dart';
import 'models/sign_up_response.dart';
import 'models/update_attribute_request.dart';
import 'package:http/http.dart' as http;

import 'models/sign_in_request.dart';
import 'models/sign_in_response.dart';

// --- ECCEZIONI TIPIZZATE ---

abstract class CognitoException implements Exception {
  final String message;
  const CognitoException(this.message);
  @override
  String toString() => message;
}

/// Eccezione di ripiego quando il messaggio AWS non è riconosciuto
class UnknownCognitoException extends CognitoException {
  const UnknownCognitoException(
      [String m = 'Si è verificato un errore inatteso'])
      : super(m);
}

class InvalidPassword extends CognitoException {
  const InvalidPassword([String m = 'Password non valida']) : super(m);
}

class UsernameExists extends CognitoException {
  const UsernameExists([String m = 'Utente già registrato']) : super(m);
}

class UserNotFound extends CognitoException {
  const UserNotFound([String m = 'Utente inesistente']) : super(m);
}

class UserNotConfirmed extends CognitoException {
  const UserNotConfirmed([String m = 'Utente non confermato']) : super(m);
}

class NotAuthorized extends CognitoException {
  const NotAuthorized([String m = 'Credenziali errate']) : super(m);
}

class CodeMismatch extends CognitoException {
  const CodeMismatch([String m = 'Codice errato']) : super(m);
}

class ExpiredCode extends CognitoException {
  const ExpiredCode([String m = 'Codice scaduto']) : super(m);
}

class LimitExceeded extends CognitoException {
  const LimitExceeded([String m = 'Troppe richieste, riprova']) : super(m);
}

typedef ErrorSetter = void Function(String);

void showCognitoError(State state, ErrorSetter setError, Object e) {
  final msg = (e is CognitoException)
      ? e.message
      : 'Si è verificato un errore inatteso';
  // setState solo per il rebuild
  state.setState(() => setError(msg));
}

CognitoException _parseError(String rawBody) {
  // Se il backend FastAPI risponde con JSON { "detail": "UserNotConfirmedException: ..." }
  String detail;
  try {
    final body = jsonDecode(rawBody);
    detail = (body['detail'] ?? '').toString().toLowerCase();
  } catch (_) {
    detail = rawBody.toLowerCase(); // fallback: non è JSON
  }

  if (detail.contains('invalidpassword')) return const InvalidPassword();
  if (detail.contains('usernameexists')) return const UsernameExists();
  if (detail.contains('usernotfound')) return const UserNotFound();
  if (detail.contains('usernotconfirmed')) return const UserNotConfirmed();
  if (detail.contains('notauthorized')) return const NotAuthorized();
  if (detail.contains('codemismatch')) return const CodeMismatch();
  if (detail.contains('expiredcode')) return const ExpiredCode();
  if (detail.contains('limitexceeded')) return const LimitExceeded();

  return const UnknownCognitoException(); // concrete fallback
}

/*class UserNotConfirmedException implements Exception {
  final String message;
  UserNotConfirmedException([this.message = 'Utente non confermato']);
  @override
  String toString() => message;
}*/

class CognitoApiClient {
  // Imposta qui il tuo endpoint base; ad esempio, se la tua API
  // gira in locale su http://localhost:8000:
  static const String baseUrl = 'https://teatek-llm.theia-innovation.com/auth';
  //static const String baseUrl = 'http://127.0.0.1:8001/auth';

  // Variabile per salvare l'ultimo access token e la sua scadenza
  String? lastAccessToken;
  int? lastExpiration; // Unix timestamp (in secondi) di scadenza

  // Helper: estrae il campo 'exp' dal payload del JWT (access token)
  int _getExpirationFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Token non valido');
    final payloadBase64 = parts[1];
    final normalized = base64.normalize(payloadBase64);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(normalized)))
        as Map<String, dynamic>;
    return payloadMap['exp'] as int;
  }

  // Helper: ottiene il tempo residuo in secondi dal token
  int getRemainingTime(String token) {
    final exp = _getExpirationFromToken(token);
    final current = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = exp - current;
    return remaining > 0 ? remaining : 0;
  }

  // Metodo per estrarre il nome utente dall'access token (assumendo che il payload contenga "username")
  String getUsernameFromAccessToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Token non valido');
    final payloadBase64 = parts[1];
    final normalized = base64.normalize(payloadBase64);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(normalized)))
        as Map<String, dynamic>;
    return payloadMap['username'] ?? '';
  }

  // Esempio di login
  Future<SignInResponse> signIn(SignInRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/signin');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final signInResponse = SignInResponse.fromJson(jsonBody);
      // Salva l'access token e la sua scadenza
      lastAccessToken = signInResponse.accessToken;
      lastExpiration = _getExpirationFromToken(signInResponse.accessToken!);
      // Al termine del login standard:
      html.window.localStorage['auth_method'] = 'standard';
      return signInResponse;
    } else {
      final body = response.body;
      // Cognito trasmette "UserNotConfirmedException" nel campo detail
      throw _parseError(response.body); // ✅ restituisce la classe giusta
    }
  }

  Future<SignUpResponse> signUp(SignUpRequest request) async {
    // Costruiamo la URL dell’endpoint
    final url = Uri.parse('$baseUrl/v1/user/signup');

    // Eseguiamo la POST
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      // Parsing JSON
      final jsonBody = jsonDecode(response.body);
      // Creiamo un SignUpResponse dal JSON
      return SignUpResponse.fromJson(jsonBody);
    } else {
      // UsernameExistsException, InvalidPasswordException, ecc. :contentReference[oaicite:0]{index=0}
      throw _parseError(response.body);
    }
  }

  // 1) Conferma registrazione utente
  Future<Map<String, dynamic>> confirmSignUpUser(
      ConfirmSignUpRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/confirm-signup-user');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore confirmSignUp: ${response.body}');
    }
  }

  // 2) Reinvia codice di conferma
  Future<Map<String, dynamic>> resendConfirmationCode(
      ResendConfirmationCodeRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/resend-confirmation-code');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore resendConfirmationCode: ${response.body}');
    }
  }

  // 1) Avvia reset password
  Future<Map<String, dynamic>> forgotPassword(
      ForgotPasswordRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/forgot-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      // Esempio di risposta: { "CodeDeliveryDetails": {...}, "ResponseMetadata": {...} }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore forgotPassword: ${response.body}');
    }
  }

  // 2) Conferma nuovo password con codice
  Future<Map<String, dynamic>> confirmForgotPassword(
      ConfirmForgotPasswordRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/confirm-forgot-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      // Esempio di risposta: { "ResponseMetadata": {...}, ... }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore confirmForgotPassword: ${response.body}');
    }
  }

  /// Metodo per cambiare la password di un utente autenticato.
  Future<Map<String, dynamic>> changePassword(
      ChangePasswordRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/change-password');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore changePassword: ${response.body}');
    }
  }

  /// Metodo per aggiornare (modificare) gli attributi dell’utente.
  Future<Map<String, dynamic>> updateAttributes(
      UpdateAttributesRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/update-attributes');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore updateAttributes: ${response.body}');
    }
  }

  /// Metodo per leggere le informazioni dell’utente (attributi standard e custom).
  Future<Map<String, dynamic>> getUserInfo(GetUserInfoRequest request) async {
    final url = Uri.parse('$baseUrl/v1/user/user-info');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Errore getUserInfo: ${response.body}');
    }
  }

  /// Metodo per effettuare il refresh token.
  Future<SignInResponse> refreshToken(
      {required String username, required String refreshToken}) async {
    final url = Uri.parse('$baseUrl/v1/user/refresh-token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'refresh_token': refreshToken,
      }),
    );
    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      final signInResponse = SignInResponse.fromJson(jsonBody);
      // Aggiorna l'access token e la scadenza
      lastAccessToken = signInResponse.accessToken;
      lastExpiration = _getExpirationFromToken(signInResponse.accessToken!);
      return signInResponse;
    } else {
      throw Exception('Errore refreshToken: ${response.body}');
    }
  }

  /// Metodo per ottenere l'ultimo token valido.
  /// Se l'ultimo access token è scaduto, lo aggiorna tramite refreshToken.
  Future<String> getLastValidToken() async {
    if (lastAccessToken == null) throw Exception('Nessun token disponibile');
    final remaining = getRemainingTime(lastAccessToken!);
    if (remaining > 0) {
      return lastAccessToken!;
    } else {
      // Il token è scaduto, aggiorna tramite refreshToken
      // NOTA: In questa implementazione non salviamo username e password, quindi è necessario passare username e refreshToken
      // Qui assumiamo che l'utente abbia già eseguito il login e abbia ottenuto refreshToken in altro modo
      throw Exception(
          'Il token è scaduto e non è disponibile un refresh token per aggiornarlo.');
    }
  }

  /// Restituisce l'URL di login federato di Cognito per Azure AD
  Future<String> getAzureLoginUrl() async {
    final url = Uri.parse('$baseUrl/v1/user/social/azure/login-url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Il backend risponde con {"auth_url": "<URL>"}
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['auth_url'] as String;
    } else {
      throw Exception('Errore getAzureLoginUrl: ${response.body}');
    }
  }

  Future<void> startAzureLogin() async {
    html.window.localStorage['pending_provider'] = 'azure';
    final authUrl = await getAzureLoginUrl();
    html.window.location.href = authUrl;
  }

  /// Scambia l'AWS Cognito authorization code (ottenuto dopo login Azure) in token JWT di Cognito
  Future<Token> exchangeAzureCodeForTokens(String code) async {
    final url = Uri.parse('$baseUrl/v1/user/social/azure/exchange-token');
    final payload = jsonEncode({'code': code});

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      // Il backend risponde con {"access_token": "...", "id_token": "...", "refresh_token": "...", ...}
      // Al termine del login Azure AD:
      html.window.localStorage['auth_method'] = 'azure';
      return Token.fromJson(data);
    } else {
      throw Exception('Errore exchangeAzureCodeForTokens: ${response.body}');
    }
  }

  Future<String> getAzureLogoutUrl() async {
    final url = Uri.parse('$baseUrl/v1/user/social/azure/logout-url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['logout_url'] as String;
    } else {
      throw Exception('Errore getAzureLogoutUrl: ${response.body}');
    }
  }

// SDK – performAzureLogout
Future<void> performAzureLogout() async {
  // pulizia locale completa
  html.window.localStorage.remove('token');
  html.window.localStorage.remove('refreshToken');
  html.window.localStorage.remove('user');
  html.window.localStorage.remove('auth_method');
  html.window.localStorage.remove('pending_provider');

  final logoutUrl = await getAzureLogoutUrl();
  html.window.location.href = logoutUrl; // Azure → Cognito → SPA
}

// ===============================
// ======  GOOGLE — LOGIN  =======
// ===============================

  /// Restituisce l'URL di login Hosted UI forzato sul provider Google
  Future<String> getGoogleLoginUrl() async {
    final url = Uri.parse('$baseUrl/v1/user/social/google/login-url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['auth_url'] as String;
    } else {
      throw Exception('Errore getGoogleLoginUrl: ${response.body}');
    }
  }

  /// Avvia il login con Google: salva il provider "pendente" e reindirizza il browser.
  /// (Utile in Flutter Web; su mobile puoi aprire in browser esterno/deeplink).
  Future<void> startGoogleLogin() async {
    // memorizzo il provider scelto: servirà alla callback per sapere quale endpoint di exchange chiamare
    html.window.localStorage['pending_provider'] = 'google';

    final authUrl = await getGoogleLoginUrl();
    html.window.location.href = authUrl; // redirect alla Hosted UI
  }

// ===============================
// ===  GOOGLE — EXCHANGE CODE ===
// ===============================

  /// Scambia il code (ritornato su redirect_uri) con i token Cognito.
  /// Imposta 'auth_method'='google' sul successo (coerente con Azure).
  Future<Token> exchangeGoogleCodeForTokens(String code) async {
    final url = Uri.parse('$baseUrl/v1/user/social/google/exchange-token');
    final payload = jsonEncode({'code': code});

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Se vuoi allinearti alla gestione "sessione SDK" come per signIn():
      // salva access token e scadenza (opzionale ma consigliato)
      try {
        final accessToken = (data['access_token'] as String?) ?? '';
        if (accessToken.isNotEmpty) {
          lastAccessToken = accessToken;
          lastExpiration = _getExpirationFromToken(accessToken);
        }
      } catch (_) {/* no-op */}

      // marca il metodo di autenticazione
      html.window.localStorage['auth_method'] = 'google';

      return Token.fromJson(data);
    } else {
      throw Exception('Errore exchangeGoogleCodeForTokens: ${response.body}');
    }
  }

// ===============================
// ======  GOOGLE — LOGOUT  ======
// ===============================

  /// Restituisce l'URL di logout Cognito (post-logout verso la SPA).
  Future<String> getGoogleLogoutUrl() async {
    final url = Uri.parse('$baseUrl/v1/user/social/google/logout-url');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['logout_url'] as String;
    } else {
      throw Exception('Errore getGoogleLogoutUrl: ${response.body}');
    }
  }

  /// Esegue il logout "app": pulizia storage + redirect all'URL di logout Cognito.
  /// (Google non ha un RP-initiated logout standard; invalidiamo la sessione Cognito).
// SDK – performGoogleLogout
Future<void> performGoogleLogout() async {
  // pulizia locale completa
  html.window.localStorage.remove('token');
  html.window.localStorage.remove('refreshToken');
  html.window.localStorage.remove('user');
  html.window.localStorage.remove('auth_method');
  html.window.localStorage.remove('pending_provider');

  final logoutUrl = await getGoogleLogoutUrl();
  html.window.location.href = logoutUrl; // Cognito → SPA
}

}
