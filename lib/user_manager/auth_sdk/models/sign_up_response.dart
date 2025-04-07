class SignUpResponse {
  final bool userConfirmed;
  final String? userSub;
  final Map<String, dynamic>? codeDeliveryDetails;

  SignUpResponse({
    required this.userConfirmed,
    this.userSub,
    this.codeDeliveryDetails,
  });

  factory SignUpResponse.fromJson(Map<String, dynamic> json) {
    // Alcuni campi potrebbero non essere presenti sempre
    return SignUpResponse(
      userConfirmed: json['UserConfirmed'] ?? false,
      userSub: json['UserSub'],
      codeDeliveryDetails: json['CodeDeliveryDetails'],
    );
  }
}
