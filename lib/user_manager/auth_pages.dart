import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'user_model.dart';
import '../main.dart'; // Importa main.dart per navigazione
import 'package:flutter_app/chatbot.dart';
import 'dart:html' as html;  // Importa per accedere a localStorage

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
      backgroundColor: Colors.white, // Imposta lo sfondo bianco
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: IntrinsicHeight(
                child: Card(
                  color: Colors.white, // Imposta lo sfondo bianco
                    elevation: 6, // Intensità dell'ombra (0 = nessuna ombra)
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4), // Angoli arrotondati
    //side: BorderSide(
    //  color: Colors.grey, // Colore dei bordi
    //  width: 0, // Spessore dei bordi
    //),
  ),
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
                            decoration: InputDecoration(
    labelText: 'Username',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo username';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20), // Spazio verticale dopo l'ultimo campo di input
                        TextFormField(
                          controller: _emailController,
                            decoration: InputDecoration(
    labelText: 'Email',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20), // Spazio verticale dopo l'ultimo campo di input
                        TextFormField(
                          controller: _fullNameController,
                            decoration: InputDecoration(
    labelText: 'Full Name',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo nome completo';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20), // Spazio verticale dopo l'ultimo campo di input
                        TextFormField(
                          controller: _passwordController,
                            decoration: InputDecoration(
    labelText: 'Password',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci la tua password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20), // Spazio verticale dopo l'ultimo campo di input
                        TextFormField(
                          controller: _confirmPasswordController,
                            decoration: InputDecoration(
    labelText: 'Conferma Password',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
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
  bool _isLoading = true; // Stato per gestire il caricamento

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Controlla se c'è un token valido all'avvio
  }

  // Controllo dello stato del login
  Future<void> _checkLoginStatus() async {
    String? token = html.window.localStorage['token'];
    if (token != null) {
      try {
        // Verifica se il token è ancora valido
        User user = await _authService.fetchCurrentUser(token);

        // Se il token è valido, naviga alla ChatBotPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: Token(accessToken: token, refreshToken: "")),
          ),
        );
      } catch (e) {
        // Token non valido o scaduto
        setState(() {
          _isLoading = false; // Mostra la pagina di login
        });
      }
    } else {
      // Nessun token, mostra la pagina di login
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Mostra lo stato di caricamento durante il login
      });

      try {
        // Ottieni il token di accesso dopo il login
        Token token = await _authService.login(
          _usernameController.text,
          _passwordController.text,
        );

        // Memorizza il token nel localStorage
        html.window.localStorage['token'] = token.accessToken;

        // Ottieni e memorizza anche l'utente
        User user = await _authService.fetchCurrentUser(token.accessToken);
        html.window.localStorage['user'] = user.toJson().toString();

        // Naviga alla ChatBotPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotPage(user: user, token: token),
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false; // Rimuovi lo stato di caricamento se c'è un errore
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore durante il login: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostra schermata di caricamento finché stiamo verificando il token
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white, // Imposta lo sfondo bianco
        body: Center(
          child: CircularProgressIndicator(), // Schermata di caricamento
        ),
      );
    }

    // Mostra il form di login solo se non stiamo caricando
    return Scaffold(
      //appBar: AppBar(
      //  title: Text('Login'),
      //),
      backgroundColor: Colors.white, // Imposta lo sfondo bianco
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: IntrinsicHeight(
                child: Card(
                                    color: Colors.white, // Imposta lo sfondo bianco
                                                        elevation: 6, // Intensità dell'ombra (0 = nessuna ombra)
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4), // Angoli arrotondati
    //side: BorderSide(
    //  color: Colors.grey, // Colore dei bordi
    //  width: 0, // Spessore dei bordi
    //),
  ),
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
                            decoration: InputDecoration(
    labelText: 'Username',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci il tuo username';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20), // Spazio verticale dopo l'ultimo campo di input
                        TextFormField(
                          controller: _passwordController,
                            decoration: InputDecoration(
    labelText: 'Password',
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
  ),
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
                     backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
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
    //appBar: AppBar(
    //  title: Text('Impostazioni Account'),
    //),
    backgroundColor: Colors.transparent, // Imposta lo sfondo bianco
    body: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // UNICO RIQUADRO CHE CONTIENE SIA "MODIFICA PROFILO" CHE "MODIFICA PASSWORD"
              Card(
                color: Colors.white, // Sfondo bianco
                elevation: 6, // Intensità dell'ombra
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), // Angoli arrotondati
                  //side: BorderSide(
                  //  color: Colors.grey, // Colore dei bordi
                  //  width: 0, // Spessore dei bordi
                  //),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sezione "Modifica profilo"
                      Text(
                        'Modifica profilo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Form per il profilo
                      Form(
                        key: _profileFormKey,
                        child: Column(
                          children: [
                            // Campo Email
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                hintText: 'Inserisci email...',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci la tua email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20),

                            // Campo Full Name
                            TextFormField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                hintText: 'Inserisci user name...',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci il tuo nome completo';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Pulsante "Aggiorna profilo"
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(42),
                            ),
                          ),
                          child: Text(
                            'Aggiorna profilo',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Sezione "Modifica password"
                      Text(
                        'Modifica password',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Form per la password
                      Form(
                        key: _passwordFormKey,
                        child: Column(
                          children: [
                            // Campo "Vecchia password"
                            TextFormField(
                              controller: _oldPasswordController,
                              decoration: InputDecoration(
                                hintText: 'Vecchia password...',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci la vecchia password';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20),

                            // Campo "Nuova password"
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: InputDecoration(
                                hintText: 'Nuova password...',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Inserisci la nuova password';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20),

                            // Campo "Conferma nuova password"
                            TextFormField(
                              controller: _confirmNewPasswordController,
                              decoration: InputDecoration(
                                hintText: 'Conferma nuova password...',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
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
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Pulsante "Cambia password"
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(42),
                            ),
                          ),
                          child: Text(
                            'Cambia password',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Pulsante "Elimina Account" fuori dal riquadro, in basso
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
    ));
  }
}
