import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/admin_user_search_request.dart';
import 'package:boxed_ai/context_api_sdk.dart';

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage>
    with TickerProviderStateMixin {
  // localStorage keys
  static const _kAuthBaseUrlLS = 'admin_console_auth_base_url';
  static const _kAuthAdminKeyLS = 'admin_console_auth_admin_key';
  static const _kRagBaseUrlLS = 'admin_console_rag_base_url';
  static const _kRagAdminKeyLS = 'admin_console_rag_admin_key';

  // Controllers (Auth Admin)
  final _authBaseUrlC = TextEditingController();
  final _authAdminKeyC = TextEditingController();
  final _confirmUsernameC = TextEditingController();

  // search users (Auth Admin)
  final _searchRawFilterC = TextEditingController();
  final _searchEmailC = TextEditingController();
  final _searchSubC = TextEditingController();
  final _searchPhoneC = TextEditingController();
  final _searchLimitC = TextEditingController(text: '20');
  final _searchPaginationTokenC = TextEditingController();

  final _getUserRefC = TextEditingController();

  // Controllers (Whitelist Admin via LLM-RAG Context API)
  final _ragBaseUrlC = TextEditingController();
  final _ragAdminKeyC = TextEditingController();

  final _wlReplaceC = TextEditingController();
  final _wlAddC = TextEditingController();
  final _wlRemoveC = TextEditingController();

  // Output
  String _status = '';
  String _output = '';
  bool _busy = false;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Defaults + localStorage
    final authDefault = CognitoApiClient.defaultBaseUrl;
    final ragDefault = 'http://34.77.241.172:8080/llm-rag'; // coerente col tuo ContextApiSdk.loadConfig()

    _authBaseUrlC.text =
        html.window.localStorage[_kAuthBaseUrlLS] ?? authDefault;
    _authAdminKeyC.text = html.window.localStorage[_kAuthAdminKeyLS] ?? '';

    _ragBaseUrlC.text =
        html.window.localStorage[_kRagBaseUrlLS] ?? ragDefault;
    _ragAdminKeyC.text = html.window.localStorage[_kRagAdminKeyLS] ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();

    _authBaseUrlC.dispose();
    _authAdminKeyC.dispose();
    _confirmUsernameC.dispose();

    _searchRawFilterC.dispose();
    _searchEmailC.dispose();
    _searchSubC.dispose();
    _searchPhoneC.dispose();
    _searchLimitC.dispose();
    _searchPaginationTokenC.dispose();

    _getUserRefC.dispose();

    _ragBaseUrlC.dispose();
    _ragAdminKeyC.dispose();
    _wlReplaceC.dispose();
    _wlAddC.dispose();
    _wlRemoveC.dispose();

    super.dispose();
  }

  void _saveSettings() {
    html.window.localStorage[_kAuthBaseUrlLS] = _authBaseUrlC.text.trim();
    html.window.localStorage[_kAuthAdminKeyLS] = _authAdminKeyC.text;
    html.window.localStorage[_kRagBaseUrlLS] = _ragBaseUrlC.text.trim();
    html.window.localStorage[_kRagAdminKeyLS] = _ragAdminKeyC.text;

    setState(() {
      _status = 'Salvato in localStorage.';
    });
  }

  String _prettyJson(dynamic v) {
    try {
      return const JsonEncoder.withIndent('  ').convert(v);
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _run(String label, Future<dynamic> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Eseguo: $label...';
      _output = '';
    });

    try {
      final res = await fn();
      setState(() {
        _status = 'OK: $label';
        _output = _prettyJson(res);
      });
    } catch (e) {
      setState(() {
        _status = 'ERRORE: $label';
        _output = e.toString();
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  // -----------------------------
  // AUTH ADMIN actions
  // -----------------------------
  CognitoApiClient _authClient() {
    return CognitoApiClient(
      baseUrl: _authBaseUrlC.text.trim(),
      adminApiKey: _authAdminKeyC.text,
    );
  }

  // -----------------------------
  // WHITELIST admin actions (LLM-RAG)
  // -----------------------------
  ContextApiSdk _contextSdk() {
    final sdk = ContextApiSdk();
    sdk.baseUrl = _ragBaseUrlC.text.trim(); // override diretto
    sdk.whitelistAdminKey = _ragAdminKeyC.text; // richiede che tu abbia aggiunto questa property nello SDK
    return sdk;
  }

  List<String> _parseCommaList(String s) {
    final t = s.trim();
    if (t.isEmpty) return const [];
    return t
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final busy = _busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console (Auth + Whitelist)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Auth Admin'),
            Tab(text: 'Whitelist Admin'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: busy ? null : _saveSettings,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: AUTH ADMIN
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Configurazione (Auth service)'),
                TextField(
                  controller: _authBaseUrlC,
                  decoration: const InputDecoration(
                    labelText: 'Auth base URL',
                    hintText:
                        'es. https://.../auth oppure http://localhost:8000/auth',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _authAdminKeyC,
                  decoration: const InputDecoration(
                    labelText: 'Admin API Key (X-API-Key)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Questi endpoint admin richiedono SOLO X-API-Key (no JWT).',
                  style: TextStyle(color: Colors.grey.shade700),
                ),

                _sectionTitle('Operazioni Admin: Confirm signup'),
                TextField(
                  controller: _confirmUsernameC,
                  decoration: const InputDecoration(
                    labelText: 'Username da confermare',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Auth Admin: confirm-signup', () async {
                            final client = _authClient();
                            return await client.adminConfirmSignup(
                              username: _confirmUsernameC.text.trim(),
                            );
                          }),
                  child: const Text('POST /v1/admin/confirm-signup'),
                ),

                _sectionTitle('Operazioni Admin: Attribute schema'),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Auth Admin: attribute-schema', () async {
                            final client = _authClient();
                            final schema = await client.adminGetAttributeSchema();
                            return schema; // list/dynamic
                          }),
                  child: const Text('GET /v1/admin/attribute-schema'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run(
                            'Auth Admin: update-attribute-schema (atteso 501)',
                            () async {
                              final client = _authClient();
                              return await client.adminUpdateAttributeSchema();
                            },
                          ),
                  child: const Text('POST /v1/admin/update-attribute-schema'),
                ),

                _sectionTitle('Operazioni Admin: Search users'),
                TextField(
                  controller: _searchRawFilterC,
                  decoration: const InputDecoration(
                    labelText: 'raw_filter (Cognito Filter string)',
                    hintText: 'es: email = "a@b.com"  OR  sub = "uuid"',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchEmailC,
                      decoration: const InputDecoration(
                        labelText: 'email (alternativa)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchSubC,
                      decoration: const InputDecoration(
                        labelText: 'sub (alternativa)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchPhoneC,
                      decoration: const InputDecoration(
                        labelText: 'phone_number (alternativa)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _searchLimitC,
                      decoration: const InputDecoration(
                        labelText: 'limit',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchPaginationTokenC,
                  decoration: const InputDecoration(
                    labelText: 'pagination_token (opzionale)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Auth Admin: users/search', () async {
                            final client = _authClient();
                            final limit =
                                int.tryParse(_searchLimitC.text.trim()) ?? 20;

                            final req = AdminUserSearchRequest(
                              rawFilter: _searchRawFilterC.text.trim().isEmpty
                                  ? null
                                  : _searchRawFilterC.text.trim(),
                              email: _searchEmailC.text.trim().isEmpty
                                  ? null
                                  : _searchEmailC.text.trim(),
                              sub: _searchSubC.text.trim().isEmpty
                                  ? null
                                  : _searchSubC.text.trim(),
                              phoneNumber: _searchPhoneC.text.trim().isEmpty
                                  ? null
                                  : _searchPhoneC.text.trim(),
                              limit: limit,
                              paginationToken:
                                  _searchPaginationTokenC.text.trim().isEmpty
                                      ? null
                                      : _searchPaginationTokenC.text.trim(),
                            );

                            final res = await client.adminSearchUsers(req);
                            return res.toJson(); // ✅ così lo stampi bene
                          }),
                  child: const Text('POST /v1/admin/users/search'),
                ),

                _sectionTitle('Operazioni Admin: Get user detail'),
                TextField(
                  controller: _getUserRefC,
                  decoration: const InputDecoration(
                    labelText: 'user_ref (username oppure sub oppure email)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Auth Admin: users/{user_ref}', () async {
                            final client = _authClient();

                            // ✅ encoding qui, perché nello SDK adminGetUser non fa encode
                            final ref =
                                Uri.encodeComponent(_getUserRefC.text.trim());

                            final res = await client.adminGetUser(ref);
                            return res.toJson();
                          }),
                  child: const Text('GET /v1/admin/users/{user_ref}'),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // TAB 2: WHITELIST ADMIN
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Configurazione (LLM-RAG Context API)'),
                TextField(
                  controller: _ragBaseUrlC,
                  decoration: const InputDecoration(
                    labelText: 'LLM-RAG base URL',
                    hintText:
                        'es. http://localhost:8080/llm-rag  oppure https://.../llm-rag',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ragAdminKeyC,
                  decoration: const InputDecoration(
                    labelText: 'Whitelist Admin Key (X-API-Key)',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Text(
                  'Questi endpoint richiedono SOLO X-API-Key (LLM_RAG_WHITELIST_ADMIN_KEY).',
                  style: TextStyle(color: Colors.grey.shade700),
                ),

                _sectionTitle('Whitelist: read'),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Whitelist: GET /payments/whitelist',
                          () async {
                            final sdk = _contextSdk();
                            final res = await sdk.getPaymentsWhitelist();
                            return res.toJson(); // ✅ evita dipendenza da "raw"
                          }),
                  child: const Text('GET /payments/whitelist'),
                ),

                _sectionTitle('Whitelist: patch (replace/add/remove)'),
                TextField(
                  controller: _wlReplaceC,
                  decoration: const InputDecoration(
                    labelText:
                        'replace (lista, separata da virgole) - opzionale',
                    hintText: 'id1,id2,id3',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _wlAddC,
                  decoration: const InputDecoration(
                    labelText: 'add (lista, separata da virgole)',
                    hintText: 'id1,id2',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _wlRemoveC,
                  decoration: const InputDecoration(
                    labelText: 'remove (lista, separata da virgole)',
                    hintText: 'id3,id4',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => _run('Whitelist: POST /payments/whitelist',
                          () async {
                            final sdk = _contextSdk();
                            final replaceList =
                                _parseCommaList(_wlReplaceC.text);

                            final body = PaymentsWhitelistPatchRequest(
                              replace:
                                  replaceList.isEmpty ? null : replaceList,
                              add: _parseCommaList(_wlAddC.text),
                              remove: _parseCommaList(_wlRemoveC.text),
                            );

                            final res =
                                await sdk.patchPaymentsWhitelist(body);
                            return res.toJson();
                          }),
                  child: const Text('POST /payments/whitelist'),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: TextStyle(
                color: _status.startsWith('ERRORE') ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _output.isEmpty ? 'Output...' : _output,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
