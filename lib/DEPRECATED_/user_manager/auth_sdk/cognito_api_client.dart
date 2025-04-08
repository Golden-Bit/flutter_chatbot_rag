import 'dart:convert';
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

class CognitoApiClient {
  // Imposta qui il tuo endpoint base; ad esempio, se la tua API
  // gira in locale su http://localhost:8000:
  static const String baseUrl = 'https://teatek-llm.theia-innovation.com/auth';

  // Variabile per salvare l'ultimo access token e la sua scadenza
  String? lastAccessToken;
  int? lastExpiration; // Unix timestamp (in secondi) di scadenza

  // Helper: estrae il campo 'exp' dal payload del JWT (access token)
  int _getExpirationFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw Exception('Token non valido');
    final payloadBase64 = parts[1];
    final normalized = base64.normalize(payloadBase64);
    final payloadMap = json.decode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
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
    final payloadMap = json.decode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
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
      return signInResponse;
    } else {
      throw Exception('Errore nella chiamata signIn: ${response.body}');
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
    throw Exception('Errore nella chiamata signUp: ${response.body}');
  }
}
  // 1) Conferma registrazione utente
  Future<Map<String, dynamic>> confirmSignUpUser(ConfirmSignUpRequest request) async {
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
  Future<Map<String, dynamic>> resendConfirmationCode(ResendConfirmationCodeRequest request) async {
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
  Future<Map<String, dynamic>> forgotPassword(ForgotPasswordRequest request) async {
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
  Future<Map<String, dynamic>> confirmForgotPassword(ConfirmForgotPasswordRequest request) async {
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
  Future<Map<String, dynamic>> changePassword(ChangePasswordRequest request) async {
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
  Future<Map<String, dynamic>> updateAttributes(UpdateAttributesRequest request) async {
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
  Future<SignInResponse> refreshToken({required String username, required String refreshToken}) async {
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
      throw Exception('Il token è scaduto e non è disponibile un refresh token per aggiornarlo.');
    }
  }


}
