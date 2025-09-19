import 'package:flutter/material.dart';
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

  final String accessToken; //  ← token dell’utente loggato

  @override
  State<SecuritySettingsContent> createState() =>
      _SecuritySettingsContentState();
}

class _SecuritySettingsContentState extends State<SecuritySettingsContent> {
  final _formKey = GlobalKey<FormState>();
  final CognitoApiClient _api = CognitoApiClient(); // SDK
  String _oldPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  String _errorMsg = '';
  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
        color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600);
    final descStyle = TextStyle(color: Colors.black54, fontSize: 13);

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Cambia password'),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildPasswordField(
                    label: 'Password attuale',
                    onSaved: (val) => _oldPassword = val ?? '',
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Inserisci la password attuale'
                        : null,
                    onChanged: (val) => _newPassword = val,       // ← aggiorna in tempo reale
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    label: 'Nuova password',
                    onSaved: (val) => _newPassword = val ?? '',
                    validator: (val) => (val == null || val.length < 6)
                        ? 'La nuova password deve contenere almeno 6 caratteri'
                        : null,
                    onChanged: (val) => _newPassword = val,       // ← aggiorna in tempo reale
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordField(
                    label: 'Conferma nuova password',
                    onSaved: (val) => _confirmPassword = val ?? '',
                    validator: (val) => (val != _newPassword)
                        ? 'Le password non coincidono'
                        : null,
                    onChanged: (val) => _newPassword = val,       // ← aggiorna in tempo reale
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
                      onPressed: _submitPasswordChange,
                      child: const Text('Aggiorna password'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSecurityOption(
              title: 'Autenticazione a più fattori',
              description:
                  'Richiede una sfida di sicurezza aggiuntiva all\'accesso: se non riesci a superare la sfida, potrai recuperare il tuo account via e‑mail.',
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
                  'Esci da tutte le sessioni attive su tutti i dispositivi, inclusa la sessione corrente. Potrebbero essere necessari fino a 30 minuti perché venga effettuata la disconnessione sugli altri dispositivi.',
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
      if (_isLoading)
        Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
    ]);
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    ValueChanged<String>? onChanged, 
  }) {
    return TextFormField(
      obscureText: true,
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

  void _submitPasswordChange() async {
    print("1");
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
print("2");
    _formKey.currentState?.save();

    if (_newPassword != _confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nuove password non coincidono')),
      );
      return;
    }
print("3");
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

      // Successo ✅
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata con successo')),
        );
        _formKey.currentState?.reset();
      }
    } catch (e) {
      // Decodifica errori Cognito → msg leggibile
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
