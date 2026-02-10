import 'dart:html' as html;

import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';

import 'admin_console_models.dart';

/// Gestione localStorage per Admin Console (Web).
///
/// Chiavi:
/// - admin_console_admin_token       (nuovo token unico)
/// - admin_console_auth_base_url
/// - admin_console_rag_base_url
///
/// Legacy (retro-compat con vecchie versioni console):
/// - admin_console_auth_admin_key
/// - admin_console_rag_admin_key
class AdminConsoleStorage {
  // ───────────────────────────────────────────────────────────────────────────
  // Keys
  // ───────────────────────────────────────────────────────────────────────────
  static const kAdminTokenLS = 'admin_console_admin_token';

  static const kAuthBaseUrlLS = 'admin_console_auth_base_url';
  static const kRagBaseUrlLS = 'admin_console_rag_base_url';

  // Legacy keys
  static const kAuthAdminKeyLS = 'admin_console_auth_admin_key';
  static const kRagAdminKeyLS = 'admin_console_rag_admin_key';

  // ───────────────────────────────────────────────────────────────────────────
  // Defaults
  // ───────────────────────────────────────────────────────────────────────────
  static String get defaultAuthBaseUrl => CognitoApiClient.defaultBaseUrl;

  static const String defaultRagBaseUrl = 'http://34.77.241.172:8080/llm-rag';

  static AdminConsoleSettings defaults() {
    return const AdminConsoleSettings(
      adminToken: '',
      authBaseUrl: CognitoApiClient.defaultBaseUrl,
      ragBaseUrl: defaultRagBaseUrl,
    );
  }

  /// Carica settings da localStorage con fallback a defaults.
  static AdminConsoleSettings load() {
    final authDefault = defaultAuthBaseUrl;
    final ragDefault = defaultRagBaseUrl;

    final authBaseUrl =
        (html.window.localStorage[kAuthBaseUrlLS] ?? authDefault).trim();
    final ragBaseUrl =
        (html.window.localStorage[kRagBaseUrlLS] ?? ragDefault).trim();

    // Token: preferisci chiave nuova, fallback su legacy.
    final stored = (html.window.localStorage[kAdminTokenLS] ?? '').trim();
    if (stored.isNotEmpty) {
      return AdminConsoleSettings(
        adminToken: stored,
        authBaseUrl: authBaseUrl.isEmpty ? authDefault : authBaseUrl,
        ragBaseUrl: ragBaseUrl.isEmpty ? ragDefault : ragBaseUrl,
      );
    }

    final legacyAuth = (html.window.localStorage[kAuthAdminKeyLS] ?? '').trim();
    final legacyRag = (html.window.localStorage[kRagAdminKeyLS] ?? '').trim();
    final guess = legacyAuth.isNotEmpty ? legacyAuth : legacyRag;

    return AdminConsoleSettings(
      adminToken: guess,
      authBaseUrl: authBaseUrl.isEmpty ? authDefault : authBaseUrl,
      ragBaseUrl: ragBaseUrl.isEmpty ? ragDefault : ragBaseUrl,
    );
  }

  /// Salva settings in localStorage.
  /// Nota: salva anche le chiavi legacy per retro-compat.
  static void save(AdminConsoleSettings s) {
    html.window.localStorage[kAuthBaseUrlLS] = s.authBaseUrl.trim();
    html.window.localStorage[kRagBaseUrlLS] = s.ragBaseUrl.trim();

    final token = s.adminToken.trim();
    if (token.isNotEmpty) {
      html.window.localStorage[kAdminTokenLS] = token;
      html.window.localStorage[kAuthAdminKeyLS] = token;
      html.window.localStorage[kRagAdminKeyLS] = token;
    }
  }

  /// Pulisce SOLO il token (nuovo + legacy).
  static void clearToken() {
    html.window.localStorage.remove(kAdminTokenLS);
    html.window.localStorage.remove(kAuthAdminKeyLS);
    html.window.localStorage.remove(kRagAdminKeyLS);
  }

  /// Pulisce tutto (token + url).
  static void clearAll() {
    clearToken();
    html.window.localStorage.remove(kAuthBaseUrlLS);
    html.window.localStorage.remove(kRagBaseUrlLS);
  }
}
