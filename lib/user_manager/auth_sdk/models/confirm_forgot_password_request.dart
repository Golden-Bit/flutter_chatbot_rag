class ConfirmForgotPasswordRequest {
  final String username;
  final String confirmationCode;
  final String newPassword;

  ConfirmForgotPasswordRequest({
    required this.username,
    required this.confirmationCode,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'confirmation_code': confirmationCode,
      'new_password': newPassword,
    };
  }
}
