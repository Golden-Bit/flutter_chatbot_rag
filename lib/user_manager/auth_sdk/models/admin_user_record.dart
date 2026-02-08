class AdminUserRecord {
  final String username;
  final bool? enabled;
  final String? userStatus;
  final DateTime? created;
  final DateTime? lastModified;

  /// Tutti gli attributi Cognito (Name->Value) ritornati dal backend.
  final Map<String, dynamic> attributes;

  /// Convenience fields (se presenti in attributes)
  final String? sub;
  final String? email;

  const AdminUserRecord({
    required this.username,
    this.enabled,
    this.userStatus,
    this.created,
    this.lastModified,
    this.attributes = const {},
    this.sub,
    this.email,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  factory AdminUserRecord.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] is Map)
        ? (j['attributes'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    return AdminUserRecord(
      username: (j['username'] ?? '').toString(),
      enabled: (j['enabled'] is bool) ? (j['enabled'] as bool) : null,
      userStatus: j['user_status']?.toString(),
      created: _parseDate(j['created']),
      lastModified: _parseDate(j['last_modified']),
      attributes: attrs,
      sub: (j['sub'] ?? attrs['sub'])?.toString(),
      email: (j['email'] ?? attrs['email'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        if (enabled != null) 'enabled': enabled,
        if (userStatus != null) 'user_status': userStatus,
        if (created != null) 'created': created!.toIso8601String(),
        if (lastModified != null) 'last_modified': lastModified!.toIso8601String(),
        'attributes': attributes,
        if (sub != null) 'sub': sub,
        if (email != null) 'email': email,
      };
}
