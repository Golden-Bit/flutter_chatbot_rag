import 'package:flutter/material.dart';

import 'admin_console_controller.dart';
import 'admin_console_storage.dart';
import 'admin_console_widgets.dart';

class AdminConsoleSettingsView extends StatefulWidget {
  final AdminConsoleController controller;

  const AdminConsoleSettingsView({
    super.key,
    required this.controller,
  });

  @override
  State<AdminConsoleSettingsView> createState() =>
      _AdminConsoleSettingsViewState();
}

class _AdminConsoleSettingsViewState extends State<AdminConsoleSettingsView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _authUrlC;
  late final TextEditingController _ragUrlC;

  @override
  void initState() {
    super.initState();
    _authUrlC = TextEditingController(text: widget.controller.settings.authBaseUrl);
    _ragUrlC = TextEditingController(text: widget.controller.settings.ragBaseUrl);
  }

  @override
  void dispose() {
    _authUrlC.dispose();
    _ragUrlC.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    widget.controller.updateAuthBaseUrl(_authUrlC.text.trim());
    widget.controller.updateRagBaseUrl(_ragUrlC.text.trim());
    widget.controller.saveSettings();

    _snack('Impostazioni salvate.');
  }

  void _restoreDefaults() {
    setState(() {
      _authUrlC.text = AdminConsoleStorage.defaultAuthBaseUrl;
      _ragUrlC.text = AdminConsoleStorage.defaultRagBaseUrl;
    });

    widget.controller.restoreDefaultUrls();
    widget.controller.saveSettings();

    _snack('Ripristinati URL di default.');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final theme = Theme.of(context);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(
              title: 'Impostazioni',
              subtitle: 'Configura gli URL dei servizi usati dalla Admin Console.',
              icon: Icons.settings_outlined,
            ),
            const SizedBox(height: 12),

            AdminCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servizi',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _authUrlC,
                      decoration: const InputDecoration(
                        labelText: 'Auth base URL',
                        hintText: 'es. https://.../auth',
                        prefixIcon: Icon(Icons.security_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Campo obbligatorio';
                        if (!(t.startsWith('http://') || t.startsWith('https://'))) {
                          return 'Deve iniziare con http:// oppure https://';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ragUrlC,
                      decoration: const InputDecoration(
                        labelText: 'LLM-RAG base URL',
                        hintText: 'es. http://localhost:8080/llm-rag',
                        prefixIcon: Icon(Icons.hub_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Campo obbligatorio';
                        if (!(t.startsWith('http://') || t.startsWith('https://'))) {
                          return 'Deve iniziare con http:// oppure https://';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salva'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _restoreDefaults,
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Ripristina default'),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: c.whitelistLoading
                              ? null
                              : () async {
                                  try {
                                    await c.refreshWhitelist();
                                    _snack('Connessione whitelist OK.');
                                  } catch (e) {
                                    _snack('Errore whitelist: $e', error: true);
                                  }
                                },
                          icon: const Icon(Icons.wifi_tethering_outlined),
                          label: const Text('Test whitelist'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sessione admin',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.key_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Token: ${maskSecret(c.settings.adminToken)}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => c.lock(clearToken: false),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Blocca'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => c.lock(clearToken: true),
                        icon: const Icon(Icons.logout_outlined),
                        label: const Text('Esci e dimentica token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
