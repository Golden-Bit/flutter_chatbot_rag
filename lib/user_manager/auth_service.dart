import 'dart:convert';
//import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_model.dart';


class AuthService {
  final String baseUrl = "http://34.140.110.56:8095";

  Future<void> register(User user, String password) async {
    final userJson = user.toJson();
    userJson['hashed_password'] = password;

    final response = await http.post(
      Uri.parse("$baseUrl/register/"),
      headers: {
        "Content-Type": "application/json",
        "accept": "application/json",
      },
      body: jsonEncode(userJson),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register user');
    }
  }

  Future<Token> login(String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login/"),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "accept": "application/json",
      },
      body: "username=$username&password=$password",
    );

    if (response.statusCode == 200) {
      return Token.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<User> fetchCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/users_collection/me/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load user');
    }
  }

  Future<void> updateUser(User user, String token) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users_collection/me/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(user.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user');
    }
  }

  Future<void> changePassword(String username, String oldPassword, String newPassword, String token) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users_collection/me/change_password/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "username": username,
        "old_password": oldPassword,
        "new_password": newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to change password');
    }
  }

  Future<Token> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse("$baseUrl/refresh_token/"),
      headers: {
        "Content-Type": "application/json",
        "accept": "application/json",
      },
      body: jsonEncode({"refresh_token": refreshToken}),
    );

    if (response.statusCode == 200) {
      return Token.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to refresh token');
    }
  }

  Future<void> deleteUser(String username, String password, String token, String email) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/users_collection/me/delete"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }
}
