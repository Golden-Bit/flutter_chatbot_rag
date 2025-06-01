class ExchangeTokenRequest {
  final String code;
  ExchangeTokenRequest({required this.code});

  Map<String, dynamic> toJson() {
    return {
      'code': code,
    };
  }
}
