class AdminConsoleSettings {
  final String adminToken;
  final String authBaseUrl;
  final String ragBaseUrl;

  const AdminConsoleSettings({
    required this.adminToken,
    required this.authBaseUrl,
    required this.ragBaseUrl,
  });

  AdminConsoleSettings copyWith({
    String? adminToken,
    String? authBaseUrl,
    String? ragBaseUrl,
  }) {
    return AdminConsoleSettings(
      adminToken: adminToken ?? this.adminToken,
      authBaseUrl: authBaseUrl ?? this.authBaseUrl,
      ragBaseUrl: ragBaseUrl ?? this.ragBaseUrl,
    );
  }
}
