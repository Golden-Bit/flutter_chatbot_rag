// user_model.dart
import '../../../databases_manager/database_model.dart'; // Import del modello Database

class User {
  final String username;
  String email;
  String fullName;
  final bool disabled;
  final List<dynamic> managedUsers;
  final List<dynamic> managerUsers;
  final List<Database> databases;

  User({
    required this.username,
    required this.email,
    required this.fullName,
    this.disabled = false,
    this.managedUsers = const [],
    this.managerUsers = const [],
    this.databases = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      disabled: json['disabled'],
      managedUsers: json['managed_users'] ?? [],
      managerUsers: json['manager_users'] ?? [],
      databases: (json['databases'] as List)
          .map((db) => Database.fromJson(db))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "email": email,
      "full_name": fullName,
      "disabled": disabled,
      "managed_users": managedUsers,
      "manager_users": managerUsers,
      "databases": databases.map((db) => db.toJson()).toList(),
    };
  }
}

class Token {
  late final String accessToken;
  late final String refreshToken;

  Token({required this.accessToken, required this.refreshToken});

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}
