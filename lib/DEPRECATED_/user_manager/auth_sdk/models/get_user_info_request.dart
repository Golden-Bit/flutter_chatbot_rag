class GetUserInfoRequest {
  final String accessToken;

  GetUserInfoRequest({required this.accessToken});

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
    };
  }
}
