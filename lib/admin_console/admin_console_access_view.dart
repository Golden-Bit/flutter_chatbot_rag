import 'package:flutter/material.dart';

import 'admin_console_controller.dart';
import 'admin_console_widgets.dart';

class AdminConsoleAccessView extends StatefulWidget {
  final AdminConsoleController controller;

  const AdminConsoleAccessView({
    super.key,
    required this.controller,
  });

  @override
  State<AdminConsoleAccessView> createState() => _AdminConsoleAccessViewState();
}

class _AdminConsoleAccessViewState extends State<AdminConsoleAccessView> {
  final _formKey = GlobalKey<FormState>();
  final _tokenC = TextEditingController();
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    _tokenC.text = widget.controller.settings.adminToken;
  }

  @override
  void dispose() {
    _tokenC.dispose();
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

  void _onLogin() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = _tokenC.text.trim();
    widget.controller.updateAdminToken(token);

    try {
      widget.controller.unlock();
      _snack('Accesso admin attivo.');
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdminCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Admin Console',
                      subtitle:
                          'Accesso con Admin Token (header X-API-Key). Nessun JWT utente viene usato qui.',
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    const SizedBox(height: 18),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Token',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _tokenC,
                            obscureText: !_showToken,
                            decoration: InputDecoration(
                              hintText: 'Incolla qui il tuo Admin Token (X-API-Key)',
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                tooltip: _showToken ? 'Nascondi' : 'Mostra',
                                icon: Icon(
                                  _showToken ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () => setState(() => _showToken = !_showToken),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) {
                                return 'Inserisci un Admin Token valido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _InfoPill(
                                label: 'Auth URL',
                                value: widget.controller.settings.authBaseUrl,
                                icon: Icons.security_outlined,
                              ),
                              _InfoPill(
                                label: 'LLM-RAG URL',
                                value: widget.controller.settings.ragBaseUrl,
                                icon: Icons.hub_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _onLogin,
                                  icon: const Icon(Icons.lock_open_outlined),
                                  label: const Text('Accedi'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _tokenC.clear();
                                  widget.controller.updateAdminToken('');
                                  _snack('Token pulito.');
                                },
                                icon: const Icon(Icons.cleaning_services_outlined),
                                label: const Text('Pulisci'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gli URL dei servizi sono modificabili dopo il login in: Impostazioni.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
        color: theme.colorScheme.primary.withOpacity(0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
