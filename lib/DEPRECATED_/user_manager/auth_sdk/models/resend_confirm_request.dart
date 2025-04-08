// File: models/resend_confirmation_code_request.dart
class ResendConfirmationCodeRequest {
  final String username;

  ResendConfirmationCodeRequest({required this.username});

  Map<String, dynamic> toJson() => {
        'username': username,
      };
}
