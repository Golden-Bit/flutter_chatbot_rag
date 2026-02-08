class AdminUserDetailResponse {
  final String requestedRef;
  final String resolvedUsername;
  final bool? enabled;
  final String? userStatus;
  final DateTime? created;
  final DateTime? lastModified;
  final Map<String, dynamic> attributes;
  final String? sub;
  final String? email;

  /// Risposta completa (opzionale) se ti serve debug.
  final Map<String, dynamic>? raw;

  const AdminUserDetailResponse({
    required this.requestedRef,
    required this.resolvedUsername,
    this.enabled,
    this.userStatus,
    this.created,
    this.lastModified,
    this.attributes = const {},
    this.sub,
    this.email,
    this.raw,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory AdminUserDetailResponse.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] is Map)
        ? (j['attributes'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    return AdminUserDetailResponse(
      requestedRef: (j['requested_ref'] ?? '').toString(),
      resolvedUsername: (j['resolved_username'] ?? '').toString(),
      enabled: (j['enabled'] is bool) ? (j['enabled'] as bool) : null,
      userStatus: j['user_status']?.toString(),
      created: _parseDate(j['created']),
      lastModified: _parseDate(j['last_modified']),
      attributes: attrs,
      sub: (j['sub'] ?? attrs['sub'])?.toString(),
      email: (j['email'] ?? attrs['email'])?.toString(),
      raw: (j['raw'] is Map) ? (j['raw'] as Map).cast<String, dynamic>() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'requested_ref': requestedRef,
        'resolved_username': resolvedUsername,
        if (enabled != null) 'enabled': enabled,
        if (userStatus != null) 'user_status': userStatus,
        if (created != null) 'created': created!.toIso8601String(),
        if (lastModified != null) 'last_modified': lastModified!.toIso8601String(),
        'attributes': attributes,
        if (sub != null) 'sub': sub,
        if (email != null) 'email': email,
        if (raw != null) 'raw': raw,
      };
}
