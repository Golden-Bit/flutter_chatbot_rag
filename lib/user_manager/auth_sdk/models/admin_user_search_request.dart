class AdminUserSearchRequest {
  /// Filtro Cognito nativo (ListUsers Filter), es:
  /// - email = "user@example.com"
  /// - sub = "uuid..."
  /// - phone_number = "+391234567890"
  final String? rawFilter;

  /// Convenience: filtro per email.
  final String? email;

  /// Convenience: filtro per Cognito sub.
  final String? sub;

  /// Convenience: filtro per phone_number (E.164).
  final String? phoneNumber;

  /// Numero massimo risultati (Cognito tipicamente max ~60 per call).
  final int limit;

  /// Token di paginazione restituito da Cognito.
  final String? paginationToken;

  const AdminUserSearchRequest({
    this.rawFilter,
    this.email,
    this.sub,
    this.phoneNumber,
    this.limit = 20,
    this.paginationToken,
  });

  Map<String, dynamic> toJson() {
    return {
      if (rawFilter != null && rawFilter!.trim().isNotEmpty)
        'raw_filter': rawFilter!.trim(),
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (sub != null && sub!.trim().isNotEmpty) 'sub': sub!.trim(),
      if (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
        'phone_number': phoneNumber!.trim(),
      'limit': limit,
      if (paginationToken != null && paginationToken!.trim().isNotEmpty)
        'pagination_token': paginationToken!.trim(),
    };
  }
}
