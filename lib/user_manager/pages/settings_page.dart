import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/change_password_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/get_user_info_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/update_attribute_request.dart';
import 'package:boxed_ai/user_manager/auth_sdk/models/user_attribute.dart';
import 'package:flutter/material.dart';


class UserProfilePage extends StatefulWidget {
  final String accessToken; // Token ottenuto dal login

  const UserProfilePage({Key? key, required this.accessToken}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final CognitoApiClient _apiClient = CognitoApiClient();

  // Controllers per gli attributi utente
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Controllers per il cambio password
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  // Recupera le informazioni dell’utente utilizzando l'access token
  Future<void> _fetchUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final request = GetUserInfoRequest(accessToken: widget.accessToken);
      final response = await _apiClient.getUserInfo(request);
      debugPrint('User info: $response');
      // Supponiamo che la risposta contenga una lista di attributi in "UserAttributes"
      // Esempio di risposta: {"Username": "user@example.com", "UserAttributes": [{"Name": "email", "Value": "user@example.com"}, {"Name": "phone_number", "Value": "+1234567890"}, {"Name": "custom:department", "Value": "IT"}]}
      if (response.containsKey('UserAttributes')) {
        for (var attr in response['UserAttributes']) {
          if (attr['Name'] == 'email') {
            _emailController.text = attr['Value'];
          } else if (attr['Name'] == 'phone_number') {
            _phoneController.text = attr['Value'];
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel recupero delle informazioni: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Aggiorna gli attributi utente
  Future<void> _onUpdateAttributes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Prepara la lista degli attributi da aggiornare
      final attributes = <UserAttribute>[
        UserAttribute(name: 'phone_number', value: _phoneController.text.trim()),
        //UserAttribute(name: 'custom:department', value: _departmentController.text.trim()),
      ];
      final request = UpdateAttributesRequest(
        accessToken: widget.accessToken,
        attributes: attributes,
      );
      final response = await _apiClient.updateAttributes(request);
      debugPrint('Attributi aggiornati: $response');
      // Puoi mostrare un messaggio di conferma
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nell’aggiornamento: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cambia la password
  Future<void> _onChangePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNewPassword = _confirmNewPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Tutti i campi password sono obbligatori.';
      });
      return;
    }
    if (newPassword != confirmNewPassword) {
      setState(() {
        _errorMessage = 'Le nuove password non coincidono.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final request = ChangePasswordRequest(
        accessToken: widget.accessToken,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      final response = await _apiClient.changePassword(request);
      debugPrint('Password cambiata: $response');
      // Puoi mostrare un messaggio di successo o navigare altrove
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel cambio password: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // UI: due sezioni (Attributi e Cambio Password)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo Utente')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Sezione Attributi Utente
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modifica Attributi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      // Email (sola lettura)
                      TextField(
                        controller: _emailController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Phone (modificabile)
                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Telefono',
                          labelStyle: const TextStyle(color: Colors.grey),
                          floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.focused)) {
                                return const TextStyle(color: Colors.lightBlue);
                              }
                              return const TextStyle(color: Colors.grey);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Colors.lightBlue,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _isLoading ? null : _onUpdateAttributes,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Aggiorna Attributi',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Sezione Cambio Password
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambia Password',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      // Campo Old Password
                      TextField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOldPassword,
                        decoration: InputDecoration(
                          labelText: 'Password Attuale',
                          labelStyle: const TextStyle(color: Colors.grey),
                          floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.focused)) {
                                return const TextStyle(color: Colors.lightBlue);
                              }
                              return const TextStyle(color: Colors.grey);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Colors.lightBlue,
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOldPassword
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.remove_red_eye,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureOldPassword = !_obscureOldPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo New Password
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Nuova Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.focused)) {
                                return const TextStyle(color: Colors.lightBlue);
                              }
                              return const TextStyle(color: Colors.grey);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Colors.lightBlue,
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.remove_red_eye,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Campo Conferma New Password
                      TextField(
                        controller: _confirmNewPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Conferma Nuova Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          floatingLabelStyle: MaterialStateTextStyle.resolveWith(
                            (Set<MaterialState> states) {
                              if (states.contains(MaterialState.focused)) {
                                return const TextStyle(color: Colors.lightBlue);
                              }
                              return const TextStyle(color: Colors.grey);
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Colors.lightBlue,
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.remove_red_eye_outlined
                                  : Icons.remove_red_eye,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: _isLoading ? null : _onChangePassword,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Cambia Password',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Mostra eventuali errori
              if (_errorMessage.isNotEmpty) ...[
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
              ],
            // Pulsante per accedere agli strumenti sviluppatore (TokenTestPage)
            ]
          ),
        ),
      ),
    );
  }
}
