// File: models/confirm_sign_up_request.dart
class ConfirmSignUpRequest {
  final String username;
  final String confirmationCode;

  ConfirmSignUpRequest({
    required this.username,
    required this.confirmationCode,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'confirmation_code': confirmationCode,
      };
}

