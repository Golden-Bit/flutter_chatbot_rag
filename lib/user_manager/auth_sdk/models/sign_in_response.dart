/// Esempio di come potrebbe apparire la risposta di Cognito
/// che FastAPI restituisce dopo il login (`initiate_auth`).
/// Generalmente ti arriveranno un `AuthenticationResult` con
/// AccessToken, IdToken, RefreshToken, ecc.
class SignInResponse {
  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final String? message;
  final String? challengeName; // Se hai MFA o challenge particolari
  // ... Altri campi, se servono

  SignInResponse({
    this.accessToken,
    this.idToken,
    this.refreshToken,
    this.message,
    this.challengeName,
  });

  factory SignInResponse.fromJson(Map<String, dynamic> json) {
    // Nella tua API, "AuthenticationResult" potrebbe stare in `response['AuthenticationResult']`
    // oppure direttamente in `authenticationResult`. Adatta al tuo caso.
    final authResult = json['AuthenticationResult'];
    return SignInResponse(
      accessToken: authResult?['AccessToken'],
      idToken: authResult?['IdToken'],
      refreshToken: authResult?['RefreshToken'],
      challengeName: json['ChallengeName'],
      message: json['message'],
    );
  }
}
