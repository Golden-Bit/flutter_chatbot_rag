class ChangePasswordRequest {
  final String accessToken;
  final String oldPassword;
  final String newPassword;

  ChangePasswordRequest({
    required this.accessToken,
    required this.oldPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'old_password': oldPassword,
      'new_password': newPassword,
    };
  }
}
