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
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final int? expiresIn;
  final String? tokenType;

  Token({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresIn,
    this.tokenType,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      tokenType: json['token_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (idToken != null) 'id_token': idToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (tokenType != null) 'token_type': tokenType,
    };
  }
}
