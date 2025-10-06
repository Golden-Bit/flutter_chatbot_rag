import 'package:flutter/material.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/change_password_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart'
    show showCognitoError;

class SecuritySettingsContent extends StatefulWidget {
  const SecuritySettingsContent({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  State<SecuritySettingsContent> createState() =>
      _SecuritySettingsContentState();
}

class _SecuritySettingsContentState extends State<SecuritySettingsContent> {
  final _formKey = GlobalKey<FormState>();
  final CognitoApiClient _api = CognitoApiClient();

  // state input
  String _oldPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';

  // visibilità
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _isLoading = false;
  String _errorMsg = '';

  // Requisiti: 1 minuscola, 1 maiuscola, 1 cifra, 1 speciale, ≥8
  final RegExp _pwdRules =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\w\s]).{8,}$');

  bool get _newEqualsOld =>
      _newPassword.isNotEmpty &&
      _oldPassword.isNotEmpty &&
      _newPassword == _oldPassword;

  bool get _isNewValid => _pwdRules.hasMatch(_newPassword);

  bool get _confirmMatches =>
      _confirmPassword.isNotEmpty && _confirmPassword == _newPassword;

  bool get _canSubmit =>
      !_isLoading &&
      _oldPassword.isNotEmpty &&
      _isNewValid &&
      !_newEqualsOld &&
      _confirmMatches;

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
        color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600);
    final descStyle = const TextStyle(color: Colors.black54, fontSize: 13);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Cambia password'),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    // ── Password attuale
                    _buildPasswordField(
                      label: 'Password attuale',
                      obscure: !_showOld,
                      onToggleVisibility: () =>
                          setState(() => _showOld = !_showOld),
                      onSaved: (val) => _oldPassword = val ?? '',
                      onChanged: (val) => setState(() => _oldPassword = val),
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'Inserisci la password attuale'
                          : null,
                      helperText: null,
                      helperColor: null,
                    ),
                    const SizedBox(height: 12),

                    // ── Nuova password
                    _buildPasswordField(
                      label: 'Nuova password',
                      obscure: !_showNew,
                      onToggleVisibility: () =>
                          setState(() => _showNew = !_showNew),
                      onSaved: (val) => _newPassword = val ?? '',
                      onChanged: (val) => setState(() => _newPassword = val),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Inserisci la nuova password';
                        }
                        if (!_pwdRules.hasMatch(val)) {
                          return 'Min 8 caratteri, una maiuscola, una minuscola, un numero e un carattere speciale.';
                        }
                        if (_oldPassword.isNotEmpty && val == _oldPassword) {
                          return 'La nuova password non può essere uguale a quella attuale.';
                        }
                        return null;
                      },
                      // guida sottile sempre visibile quando non c'è errore
                      helperText:
                          'Min 8 caratteri, una maiuscola, una minuscola, un numero e un carattere speciale.',
                      helperColor: Colors.black54,
                    ),
                    const SizedBox(height: 12),

                    // ── Conferma password
                    _buildPasswordField(
                      label: 'Conferma nuova password',
                      obscure: !_showConfirm,
                      onToggleVisibility: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      onSaved: (val) => _confirmPassword = val ?? '',
                      onChanged: (val) =>
                          setState(() => _confirmPassword = val),
                      validator: (val) =>
                          (val != _newPassword) ? 'Le password non coincidono' : null,
                      // helper verde se coincidono e non c'è errore
                      helperText: _confirmMatches
                          ? 'Le password coincidono.'
                          : null,
                      helperColor:
                          _confirmMatches ? Colors.green : Colors.black54,
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: _canSubmit ? _submitPasswordChange : null,
                        child: const Text('Aggiorna password'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // (sezione opzionale demo)
              _buildSecurityOption(
                title: 'Autenticazione a più fattori',
                description:
                    'Richiede una sfida di sicurezza aggiuntiva all\'accesso: se non riesci a superarla, potrai recuperare l’account via e-mail.',
                buttonLabel: 'Abilita',
                onPressed: () {
                  // TODO: implementa MFA
                },
                titleStyle: titleStyle,
                descStyle: descStyle,
              ),
              const SizedBox(height: 32),
              _buildSecurityOption(
                title: 'Esci da tutti i dispositivi',
                description:
                    'Esci da tutte le sessioni attive. La disconnessione remota può richiedere fino a 30 minuti.',
                buttonLabel: 'Esci da tutto',
                onPressed: () {
                  // TODO: implementa logout globale
                },
                titleStyle: titleStyle,
                descStyle: descStyle,
              ),
            ],
          ),
        ),

        // overlay caricamento
        if (_isLoading)
          Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  // ───────────────────────────────── UI helpers ─────────────────────────────────
  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required bool obscure,
    required VoidCallback onToggleVisibility,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    required ValueChanged<String> onChanged,
    String? helperText,
    Color? helperColor,
  }) {
    return TextFormField(
      obscureText: obscure,
      onSaved: onSaved,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        // mostra helper solo se fornito; Flutter lo nasconde automaticamente se c'è un errorText
        helperText: helperText,
        helperStyle: TextStyle(
          color: helperColor ?? Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Mostra' : 'Nascondi',
          onPressed: onToggleVisibility,
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
    required TextStyle titleStyle,
    required TextStyle descStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 8),
              Text(description, style: descStyle),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
          ),
          onPressed: onPressed,
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  // ───────────────────────────────── submit ─────────────────────────────────
  void _submitPasswordChange() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || !_canSubmit) return;

    _formKey.currentState?.save();

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      await _api.changePassword(
        ChangePasswordRequest(
          accessToken: widget.accessToken,
          oldPassword: _oldPassword,
          newPassword: _newPassword,
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata con successo')),
        );
        _formKey.currentState?.reset();
        setState(() {
          _oldPassword = '';
          _newPassword = '';
          _confirmPassword = '';
          _showOld = _showNew = _showConfirm = false;
        });
      }
    } catch (e) {
      showCognitoError(this, (msg) => _errorMsg = msg, e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMsg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
