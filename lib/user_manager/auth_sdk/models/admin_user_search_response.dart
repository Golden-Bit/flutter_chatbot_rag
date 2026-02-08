import 'admin_user_record.dart';

class AdminUserSearchResponse {
  final String? appliedFilter;
  final int count;
  final List<AdminUserRecord> users;
  final String? paginationToken;

  const AdminUserSearchResponse({
    this.appliedFilter,
    required this.count,
    required this.users,
    this.paginationToken,
  });

  factory AdminUserSearchResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['users'] is List) ? (j['users'] as List) : const [];
    return AdminUserSearchResponse(
      appliedFilter: j['applied_filter']?.toString(),
      count: (j['count'] is num) ? (j['count'] as num).toInt() : list.length,
      users: list.map((e) {
        if (e is Map<String, dynamic>) {
          return AdminUserRecord.fromJson(e);
        }
        if (e is Map) {
          return AdminUserRecord.fromJson(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<AdminUserRecord>().toList(),
      paginationToken: j['pagination_token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (appliedFilter != null) 'applied_filter': appliedFilter,
        'count': count,
        'users': users.map((u) => u.toJson()).toList(),
        if (paginationToken != null) 'pagination_token': paginationToken,
      };
}
