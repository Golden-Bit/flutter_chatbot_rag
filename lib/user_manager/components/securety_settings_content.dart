import 'package:flutter/material.dart';

class SecuritySettingsContent extends StatefulWidget {
  const SecuritySettingsContent({super.key});

  @override
  State<SecuritySettingsContent> createState() => _SecuritySettingsContentState();
}

class _SecuritySettingsContentState extends State<SecuritySettingsContent> {
  final _formKey = GlobalKey<FormState>();

  String _oldPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600);
    final descStyle = TextStyle(color: Colors.black54, fontSize: 13);

    return SingleChildScrollView(
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
                  validator: (val) => (val == null || val.isEmpty) ? 'Inserisci la password attuale' : null,
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  label: 'Nuova password',
                  onSaved: (val) => _newPassword = val ?? '',
                  validator: (val) => (val == null || val.length < 6)
                      ? 'La nuova password deve contenere almeno 6 caratteri'
                      : null,
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  label: 'Conferma nuova password',
                  onSaved: (val) => _confirmPassword = val ?? '',
                  validator: (val) =>
                      (val != _newPassword) ? 'Le password non coincidono' : null,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      obscureText: true,
      onSaved: onSaved,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

  void _submitPasswordChange() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid) {
      _formKey.currentState?.save();

      if (_newPassword != _confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nuove password non coincidono')),
        );
        return;
      }

      // TODO: Logica di aggiornamento password

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password aggiornata con successo')),
      );
    }
  }
}
