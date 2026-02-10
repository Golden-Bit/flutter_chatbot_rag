import 'package:flutter/foundation.dart';

import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/admin_user_record.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/admin_user_search_request.dart';

import 'admin_console_api.dart';
import 'admin_console_models.dart';
import 'admin_console_sections.dart';
import 'admin_console_storage.dart';

class AdminConsoleController extends ChangeNotifier {
  AdminConsoleSettings _settings;

  bool _unlocked = false;

  AdminConsoleSection _section = AdminConsoleSection.users;
  bool _navExpanded = true;

  // ───────────────────────────────────────────────────────────────────────────
  // USERS state
  // ───────────────────────────────────────────────────────────────────────────
  bool usersLoading = false;
  List<AdminUserRecord> users = const [];
  int usersCount = 0;
  String? appliedFilter;
  String? paginationToken;

  // ───────────────────────────────────────────────────────────────────────────
  // WHITELIST state
  // ───────────────────────────────────────────────────────────────────────────
  bool whitelistLoading = false;
  bool whitelistUpdating = false;
  Set<String> whitelist = <String>{};

  AdminConsoleController(this._settings);

  AdminConsoleSettings get settings => _settings;
  bool get unlocked => _unlocked;

  AdminConsoleSection get section => _section;
  bool get navExpanded => _navExpanded;

  AdminConsoleApi get _api => AdminConsoleApi(_settings);

  // ───────────────────────────────────────────────────────────────────────────
  // Navigation
  // ───────────────────────────────────────────────────────────────────────────
  void setSection(AdminConsoleSection s) {
    _section = s;
    notifyListeners();
  }

  void toggleNavExpanded() {
    _navExpanded = !_navExpanded;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Settings mutations
  // ───────────────────────────────────────────────────────────────────────────
  void updateAdminToken(String token) {
    _settings = _settings.copyWith(adminToken: token);
    notifyListeners();
  }

  void updateAuthBaseUrl(String url) {
    _settings = _settings.copyWith(authBaseUrl: url);
    notifyListeners();
  }

  void updateRagBaseUrl(String url) {
    _settings = _settings.copyWith(ragBaseUrl: url);
    notifyListeners();
  }

  void restoreDefaultUrls() {
    _settings = _settings.copyWith(
      authBaseUrl: AdminConsoleStorage.defaultAuthBaseUrl,
      ragBaseUrl: AdminConsoleStorage.defaultRagBaseUrl,
    );
    notifyListeners();
  }

  void saveSettings() {
    AdminConsoleStorage.save(_settings);
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Session
  // ───────────────────────────────────────────────────────────────────────────
  void unlock() {
    final token = _settings.adminToken.trim();
    if (token.isEmpty) {
      throw Exception('Admin token mancante.');
    }

    // Persist
    AdminConsoleStorage.save(_settings);

    _unlocked = true;
    notifyListeners();
  }

  /// Blocca la console e torna alla schermata di accesso.
  /// - clearToken = true  → rimuove anche il token da localStorage
  /// - clearToken = false → conserva token in localStorage (accesso rapido)
  void lock({bool clearToken = true}) {
    if (clearToken) {
      AdminConsoleStorage.clearToken();
      _settings = _settings.copyWith(adminToken: '');
    } else {
      // Mantieni token e settings.
      AdminConsoleStorage.save(_settings);
    }

    _unlocked = false;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // API actions
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> refreshWhitelist() async {
    if (whitelistLoading) return;
    whitelistLoading = true;
    notifyListeners();

    try {
      final sdk = _api.contextSdk();
      final res = await sdk.getPaymentsWhitelist();
      whitelist = res.whitelist.toSet();
    } finally {
      whitelistLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchUsers(AdminUserSearchRequest request) async {
    if (usersLoading) return;
    usersLoading = true;
    notifyListeners();

    try {
      final client = _api.authClient();
      final res = await client.adminSearchUsers(request);

      users = res.users;
      usersCount = res.count;
      appliedFilter = res.appliedFilter;
      paginationToken = res.paginationToken;
    } finally {
      usersLoading = false;
      notifyListeners();
    }
  }

  bool isWhitelisted(String userId) => whitelist.contains(userId);

  /// Imposta whitelist per un singolo userId (sub).
  /// Aggiorna lo stato dalla risposta server.
  Future<void> setWhitelisted(String userId, bool shouldBeWhitelisted) async {
    final id = userId.trim();
    if (id.isEmpty) throw Exception('UserId vuoto.');

    if (whitelistUpdating) return;
    whitelistUpdating = true;
    notifyListeners();

    try {
      final sdk = _api.contextSdk();

      final req = PaymentsWhitelistPatchRequest(
        add: shouldBeWhitelisted ? [id] : const [],
        remove: shouldBeWhitelisted ? const [] : [id],
      );

      final res = await sdk.patchPaymentsWhitelist(req);

      whitelist = res.whitelist.toSet();
    } finally {
      whitelistUpdating = false;
      notifyListeners();
    }
  }
}
