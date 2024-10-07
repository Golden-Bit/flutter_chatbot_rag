import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'user_model.dart';
import '../main.dart'; // Importa main.dart per navigazione
import 'package:flutter_app/chatbot.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  void _register() async {
    if (_formKey.currentState!.validate()) {
      User user = User(
        username: _usernameController.text,
        email: _emailController.text,
        fullName: _fullNameController.text,
      );

      try {
        await _authService.register(user, _passwordController.text);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registrazione avvenuta con successo'),
        ));
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante la registrazione: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: IntrinsicHeight(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrazione',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(labelText: 'Username'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo username';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua email';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(labelText: 'Full Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo nome completo';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua password';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(labelText: 'Conferma Password'),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Conferma la tua password';
                            }
                            if (value != _passwordController.text) {
                              return 'Le password non coincidono';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: _register,
                            child: Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        Token token = await _authService.login(
          _usernameController.text,
          _passwordController.text,
        );
        User user = await _authService.fetchCurrentUser(token.accessToken);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: token),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante il login: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: IntrinsicHeight(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(labelText: 'Username'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo username';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                            onPressed: _login,
                            child: Text('Login'),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: Text('Non hai un account? Registrati'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountSettingsPage extends StatefulWidget {
  final User user;
  final Token token;

  AccountSettingsPage({required this.user, required this.token});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _fullNameController;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _fullNameController = TextEditingController(text: widget.user.fullName);

    _refreshTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      _refreshToken();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshToken() async {
    try {
      Token newToken = await _authService.refreshToken(widget.token.refreshToken);
      setState(() {
        widget.token.accessToken = newToken.accessToken;
        widget.token.refreshToken = newToken.refreshToken;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Errore durante il refresh del token: $e'),
      ));
    }
  }

  void _updateProfile() async {
    if (_profileFormKey.currentState!.validate()) {
      User updatedUser = User(
        username: widget.user.username,
        email: _emailController.text,
        fullName: _fullNameController.text,
        disabled: widget.user.disabled,
        managedUsers: widget.user.managedUsers,
        managerUsers: widget.user.managerUsers,
        databases: widget.user.databases,
      );

      try {
        await _authService.updateUser(updatedUser, widget.token.accessToken);

        User refreshedUser = await _authService.fetchCurrentUser(widget.token.accessToken);
        setState(() {
          widget.user.email = refreshedUser.email;
          widget.user.fullName = refreshedUser.fullName;
          _emailController.text = refreshedUser.email;
          _fullNameController.text = refreshedUser.fullName;
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profilo aggiornato con successo!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante l\'aggiornamento del profilo: $e'),
        ));
      }
    }
  }

  void _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      try {
        await _authService.changePassword(
          widget.user.username,
          _oldPasswordController.text,
          _newPasswordController.text,
          widget.token.accessToken,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password cambiata con successo!'),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante il cambio della password: $e'),
        ));
      }
    }
  }

  void _deleteAccount() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController usernameController = TextEditingController();
        final TextEditingController passwordController = TextEditingController();

        return AlertDialog(
          title: Text('Conferma Eliminazione Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Annulla'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Elimina',                    
              style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
              onPressed: () async {
                if (usernameController.text == widget.user.username) {
                  try {
                    await _authService.deleteUser(
                      usernameController.text,
                      passwordController.text,
                      widget.token.accessToken,
                      widget.user.email,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Account eliminato con successo!'),
                    ));
                    Navigator.of(context).pushReplacementNamed('/login');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante l\'eliminazione dell\'account: $e'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Username non corrisponde!'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Impostazioni Account'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Form(
                  key: _profileFormKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modifica Profilo',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(labelText: 'Email'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Inserisci la tua email';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: _fullNameController,
                            decoration: InputDecoration(labelText: 'Nome Completo'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Inserisci il tuo nome completo';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                              onPressed: _updateProfile,
                              child: Text('Aggiorna Profilo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Form(
                  key: _passwordFormKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modifica Password',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _oldPasswordController,
                            decoration: InputDecoration(labelText: 'Vecchia Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Inserisci la vecchia password';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(labelText: 'Nuova Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Inserisci la nuova password';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: _confirmNewPasswordController,
                            decoration: InputDecoration(labelText: 'Conferma Nuova Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Conferma la nuova password';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Le password non coincidono';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                              onPressed: _changePassword,
                              child: Text('Cambia Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _deleteAccount,
                  child: Text(
                    'Elimina Account',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
