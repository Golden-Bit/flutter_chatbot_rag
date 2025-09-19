import 'dart:async';
import 'package:flutter/material.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/update_attribute_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_attribute.dart';

/// Widget che mostra e consente di modificare dinamicamente gli attributi
/// dell'utente memorizzati in Amazon Cognito.
///
/// * **accessToken** – token rilasciato da Cognito in fase di login.
/// * **hiddenFields** – lista di attributi da non mostrare.
/// * **readOnlyFields** – lista di attributi da mostrare ma non editare.
/// * **labelMap** – mappa di nomi attributo → etichette UI.
class UserProfileSettingsContent extends StatefulWidget {
  const UserProfileSettingsContent({
    super.key,
    required this.accessToken,
    this.hiddenFields = const ['email_verified', 'custom:databases', 'sub'],
    this.readOnlyFields = const ['email', 'username'],
    this.labelMap = const {
      'custom:databases': 'Databases',
      'email': 'Email',
    },
  });

  final String accessToken;
  final List<String> hiddenFields;
  final List<String> readOnlyFields;
  final Map<String, String> labelMap;

  @override
  State<UserProfileSettingsContent> createState() =>
      _UserProfileSettingsContentState();
}

class _UserProfileSettingsContentState
    extends State<UserProfileSettingsContent> {
  final CognitoApiClient _apiClient = CognitoApiClient();

  List<UserAttribute> _attributes = [];
  Map<String, TextEditingController> _controllers = {};

  bool _isLoading = false;
  String _errorMessage = '';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchAttributes();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchAttributes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await _apiClient.getUserInfo(
        GetUserInfoRequest(accessToken: widget.accessToken),
      );

      _attributes = [];
      _controllers = {};

      for (final raw in res['UserAttributes'] ?? []) {
        final name = raw['Name'] as String;
        // skip hidden
        if (widget.hiddenFields.contains(name)) continue;

        final value = (raw['Value'] ?? '').toString();
        final attr = UserAttribute(name: name, value: value);
        _attributes.add(attr);
        _controllers[name] = TextEditingController(text: value);
      }
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Impossibile recuperare i dati: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    final List<UserAttribute> changed = [];
    for (final attr in _attributes) {
      final newVal = _controllers[attr.name]!.text.trim();
      if (newVal != attr.value && !widget.readOnlyFields.contains(attr.name)) {
        changed.add(UserAttribute(name: attr.name, value: newVal));
      }
    }

    if (changed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuna modifica da salvare')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _apiClient.updateAttributes(
        UpdateAttributesRequest(
          accessToken: widget.accessToken,
          attributes: changed,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attributi aggiornati con successo')),
      );
      unawaited(_fetchAttributes());
    } catch (e) {
      setState(() => _errorMessage = 'Errore salvataggio: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ① SCHERMATA DI CARICAMENTO
    if (_isLoading && _attributes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(), // rotella centrata
      );
    }
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Input fields
                for (final attr in _attributes) _buildField(attr),
                const SizedBox(height: 24),
                // Pulsante salva allineato a destra
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _saveChanges,
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
                    child: const Text('Salva modifiche'),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),

        // ③ OVERLAY MENTRE SALVO (opzionale)
        if (_isLoading)
          const Positioned(
            right: 24, // «a lato destro»
            top: 24,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
      ],
    );
  }

  Widget _buildField(UserAttribute attr) {
    final controller = _controllers[attr.name]!;
    final readOnly = widget.readOnlyFields.contains(attr.name);
    final label = widget.labelMap[attr.name] ?? attr.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.white,
        ),
        onSaved: (val) => controller.text = val?.trim() ?? '',
      ),
    );
  }
}
