import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Modello User
class User {
  final String username;
  String email;
  String fullName;
  final bool disabled;
  final List<dynamic> managedUsers;
  final List<dynamic> managerUsers;
  final List<Database> databases;

  User({
    required this.username,
    required this.email,
    required this.fullName,
    this.disabled = false,
    this.managedUsers = const [],
    this.managerUsers = const [],
    this.databases = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      disabled: json['disabled'],
      managedUsers: json['managed_users'] ?? [],
      managerUsers: json['manager_users'] ?? [],
      databases: (json['databases'] as List)
          .map((db) => Database.fromJson(db))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "email": email,
      "full_name": fullName,
      "disabled": disabled,
      "managed_users": managedUsers,
      "manager_users": managerUsers,
      "databases": databases.map((db) => db.toJson()).toList(),
    };
  }
}

// Modello Database
class Database {
  final String dbName;
  final String host;
  final int port;

  Database({
    required this.dbName,
    required this.host,
    required this.port,
  });

  factory Database.fromJson(Map<String, dynamic> json) {
    return Database(
      dbName: json['db_name'],
      host: json['host'],
      port: json['port'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "db_name": dbName,
      "host": host,
      "port": port,
    };
  }
}

// Modello Collection
class Collection {
  final String name;

  Collection({required this.name});

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {"name": name};
  }
}

class Token {
  late final String accessToken;
  late final String refreshToken;

  Token({required this.accessToken, required this.refreshToken});

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}

// Servizio di autenticazione
class AuthService {
  final String baseUrl = "http://127.0.0.1:8101";

   Future<List<Collection>> fetchCollections(String dbName, String token) async {
    final response = await http.get(
      Uri.parse("http://127.0.0.1:8101/mongo/$dbName/list_collections/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final List<dynamic> collectionsJson = jsonResponse['collections'];

      // Mappiamo ogni stringa a un oggetto Collection
      return collectionsJson.map((col) => Collection(name: col as String)).toList();
    } else {
      throw Exception('Failed to load collections');
    }
  }

  Future<void> deleteCollectionData(String dbName, String collectionName, String itemId, String token) async {
  final url = Uri.parse("http://127.0.0.1:8101/mongo/$dbName/delete_item/$collectionName/$itemId");

  final response = await http.delete(
    url,
    headers: {
      "Authorization": "Bearer $token",
      "accept": "application/json",
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete item: ${response.body}');
  }
}

Future<void> deleteCollection(String dbName, String collectionName, String token) async {
  // Costruzione dell'URL corretto secondo l'esempio curl fornito
  final url = Uri.parse("http://127.0.0.1:8101/mongo/$dbName/delete_collection/$collectionName/");

  final response = await http.delete(
    url,
    headers: {
      "Authorization": "Bearer $token",
      "accept": "application/json",
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to delete collection: ${response.body}');
  }
}

Future<void> updateCollectionData(String dbName, String collectionName, String itemId, Map<String, dynamic> data, String token) async {
  final url = Uri.parse("http://127.0.0.1:8101/mongo/$dbName/update_item/$collectionName/$itemId");

  final response = await http.put(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode(data),
  );
  print(response.reasonPhrase);
  if (response.statusCode != 200) {
    throw Exception('Failed to update data in collection');
  }
}


Future<void> addDataToCollection(String dbName, String collectionName, Map<String, dynamic> data, String token) async {
  final url = Uri.parse("http://127.0.0.1:8101/mongo/$dbName/$collectionName/add_item");

  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode(data),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to add data to collection');
  }
}
Future<void> createCollection(String dbName, String collectionName, String token) async {
  final url = Uri.parse("http://127.0.0.1:8101/mongo/$dbName/create_collection/")
    .replace(queryParameters: {"collection_name": collectionName});

  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
  );

  print(response.reasonPhrase);
  if (response.statusCode != 200) {
    throw Exception('Failed to create collection');
  }
}

  Future<void> register(User user, String password) async {
    final userJson = user.toJson();
    userJson['hashed_password'] = password;

    final response = await http.post(
      Uri.parse("$baseUrl/register/"),
      headers: {
        "Content-Type": "application/json",
        "accept": "application/json",
      },
      body: jsonEncode(userJson),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register user');
    }
  }

  Future<Token> login(String username, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login/"),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "accept": "application/json",
      },
      body: "username=$username&password=$password",
    );

    if (response.statusCode == 200) {
      return Token.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<User> fetchCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/users_collection/me/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load user');
    }
  }

  Future<void> updateUser(User user, String token) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users_collection/me/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(user.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user');
    }
  }

  Future<void> changePassword(
      String username, String oldPassword, String newPassword, String token) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users_collection/me/change_password/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "username": username,
        "old_password": oldPassword,
        "new_password": newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to change password');
    }
  }

  Future<Token> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse("$baseUrl/refresh_token/"),
      headers: {
        "Content-Type": "application/json",
        "accept": "application/json",
      },
      body: jsonEncode({"refresh_token": refreshToken}),
    );

    if (response.statusCode == 200) {
      return Token.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to refresh token');
    }
  }

  Future<void> deleteUser(String username, String password, String token, String email) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/users_collection/me/delete"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  // Metodi per gestire i database
  Future<List<Database>> fetchDatabases(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/databases/"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((db) => Database.fromJson(db))
          .toList();
    } else {
      throw Exception('Failed to load databases');
    }
  }

  Future<void> createDatabase(String dbName, String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/mongo/create_user_database/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"db_name": dbName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create database');
    }
  }

  Future<void> deleteDatabase(String databaseName, String token) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/mongo/delete_database/$databaseName"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete database');
    }
  }

  // Nuovi metodi per gestire le collection e i dati
  //Future<List<Collection>> fetchCollections(String dbName, String token) async {
  //  final response = await http.get(
  //    Uri.parse("$baseUrl/databases/$dbName/collections"),
  //    headers: {
  //      "Authorization": "Bearer $token",
  //    },
  //  );

  //  if (response.statusCode == 200) {
  //    return (jsonDecode(response.body) as List)
  //        .map((col) => Collection.fromJson(col))
  //        .toList();
  //  } else {
  //    throw Exception('Failed to load collections');
  //  }
  //}

  Future<List<Map<String, dynamic>>> fetchCollectionData(String dbName, String collectionName, String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/mongo/$dbName/get_items/$collectionName"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load collection data');
    }
  }
}

// Pagina di registrazione
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
// Pagina di login
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
            builder: (context) => HomePage(user: user, token: token),
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
                    crossAxisAlignment: CrossAxisAlignment.start, // Allinea il contenuto a sinistra
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
                      Align( // Sposta il pulsante di login in basso a destra
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: Text('Login'),
                        ),
                      ),
                      Align( // Allinea il pulsante di registrazione a destra
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

// Pagina iniziale dopo il login con due opzioni: Impostazioni e Databases
class HomePage extends StatelessWidget {
  final User user;
  final Token token;

  HomePage({required this.user, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AccountSettingsPage(user: user, token: token),
                  ),
                );
              },
              child: Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings, size: 64.0),
                    Text('Impostazioni'),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DatabasePage(
      databases: user.databases,
      token: token.accessToken,
      user: user, // Aggiungi questo argomento
    ),
  ),
);
              },
              child: Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storage, size: 64.0),
                    Text('Databases'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pagina delle impostazioni dell'account
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
              child: Text('Conferma'),
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



// Pagina dei databases
class DatabasePage extends StatefulWidget {
  final List<Database> databases;
  final String token;
  final User user; // Aggiungi questa riga

  DatabasePage({required this.databases, required this.token, required this.user});

  @override
  _DatabasePageState createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final TextEditingController _dbNameController = TextEditingController();
  final AuthService _authService = AuthService();

void _createCollection(String dbName) async {
  final TextEditingController _collectionNameController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Crea nuova Collection'),
        content: TextField(
          controller: _collectionNameController,
          decoration: InputDecoration(labelText: 'Nome Collection'),
        ),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Crea'),
            onPressed: () async {
              if (_collectionNameController.text.isNotEmpty) {
                try {
                  await _authService.createCollection(dbName, _collectionNameController.text, widget.token);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Collection creata con successo!'),
                  ));
                  Navigator.of(context).pop(); // Chiude il dialog
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante la creazione della collection: $e'),
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Inserisci il nome della collection!'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}

 void _createDatabase() async {
  if (_dbNameController.text.isNotEmpty) {
    final String inputDbName = _dbNameController.text;
    final String fullDbName = "${widget.user.username}-$inputDbName";
    
    try {
      await _authService.createDatabase(inputDbName, widget.token); // Invio solo il nome base al backend
      setState(() {
        widget.databases.add(Database(
            dbName: fullDbName, // Uso del nome completo con il prefisso
            host: "localhost", // or wherever the host is defined
            port: 27017));
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Database creato con successo!'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Errore durante la creazione del database: $e'),
      ));
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Inserisci il nome del database!'),
    ));
  }
}

  void _deleteDatabase(String dbName) async {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Conferma Eliminazione Database'),
        content: Text('Sei sicuro di voler eliminare il database $dbName?'),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Elimina'),
            onPressed: () async {
              try {
                await _authService.deleteDatabase(dbName, widget.token);
                setState(() {
                  widget.databases.removeWhere((db) => db.dbName == dbName);
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Database eliminato con successo!'),
                ));
                Navigator.of(context).pop(); // Chiude il dialog
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Errore durante l\'eliminazione del database: $e'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}

void _showCollections(String dbName) async {
  try {
    List<Collection> collections = await _authService.fetchCollections(dbName, widget.token);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Collections in $dbName'),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return ListTile(
                  title: Text(collection.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.green),
                        onPressed: () => _addDataToCollection(dbName, collection.name),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCollection(dbName, collection.name),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCollectionData(dbName, collection.name); // Modifica qui
                  },
                );
              },
            ),
          ),
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Errore durante il caricamento delle collection: $e'),
    ));
  }
}
void _addDataToCollection(String dbName, String collectionName) async {
  final TextEditingController _jsonController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Aggiungi Dato a $collectionName'),
            //IconButton(
            //  icon: Icon(Icons.close),
            //  onPressed: () {
            //    Navigator.of(context).pop();
            //  },
            //),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  try {
                    final jsonData = jsonDecode(_jsonController.text);
                    _jsonController.text = JsonEncoder.withIndent('  ').convert(jsonData);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante la formattazione del JSON: $e'),
                    ));
                  }
                },
                child: Text('Formatta JSON'),
              ),
            ),
            TextField(
              controller: _jsonController,
              decoration: InputDecoration(
                labelText: 'Inserisci il dato in formato JSON',
              ),
              maxLines: 8,
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
            child: Text('Aggiungi'),
            onPressed: () async {
              if (_jsonController.text.isNotEmpty) {
                try {
                  final jsonData = jsonDecode(_jsonController.text);
                  await _authService.addDataToCollection(dbName, collectionName, jsonData, widget.token);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Dato aggiunto con successo a $collectionName!'),
                  ));
                  Navigator.of(context).pop(); // Chiude il dialog
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante l\'aggiunta del dato: $e'),
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Inserisci un dato valido in formato JSON!'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}


void _deleteCollection(String dbName, String collectionName) async {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Conferma Eliminazione Collection'),
        content: Text('Sei sicuro di voler eliminare la collection $collectionName?'),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Elimina'),
            onPressed: () async {
              try {
                await _authService.deleteCollection(dbName, collectionName, widget.token);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Collection $collectionName eliminata con successo!'),
                ));
                Navigator.of(context).pop(); // Chiude il dialog
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Errore durante l\'eliminazione della collection: $e'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}

void _showCollectionData(String dbName, String collectionName) async {
  try {
    List<Map<String, dynamic>> data =
        await _authService.fetchCollectionData(dbName, collectionName, widget.token);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dati in $collectionName'),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return ExpandableCard(
                  item: item,
                  dbName: dbName,
                  collectionName: collectionName,
                  onEdit: (item) => _editCollectionData(dbName, collectionName, item),
                  onDelete: (itemId) => _deleteCollectionData(dbName, collectionName, itemId),
                );
              },
            ),
          ),
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Errore durante il caricamento dei dati della collection: $e'),
    ));
  }
}


void _deleteCollectionData(String dbName, String collectionName, String itemId) async {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Conferma Eliminazione Dato'),
        content: Text('Sei sicuro di voler eliminare questo dato?'),
        actions: [
          TextButton(
            child: Text('Annulla'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Elimina'),
            onPressed: () async {
              try {
                await _authService.deleteCollectionData(dbName, collectionName, itemId, widget.token);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Dato eliminato con successo!'),
                ));
                Navigator.of(context).pop(); // Chiude il dialog e ritorna alla lista dei dati
                _showCollectionData(dbName, collectionName); // Ricarica i dati aggiornati
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Errore durante l\'eliminazione del dato: $e'),
                ));
              }
            },
          ),
        ],
      );
    },
  );
}


void _editCollectionData(String dbName, String collectionName, Map<String, dynamic> item) async {
  // Rimuovi il campo _id dal JSON visualizzato
  Map<String, dynamic> itemCopy = Map.from(item);
  itemCopy.remove('_id');

  final TextEditingController _jsonController = TextEditingController(
    text: JsonEncoder.withIndent('  ').convert(itemCopy)  // Formatta il JSON con indentazione
  );

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Modifica Dato in $collectionName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                onPressed: () {
                  try {
                    final jsonData = jsonDecode(_jsonController.text);
                    _jsonController.text = JsonEncoder.withIndent('  ').convert(jsonData);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Errore durante la formattazione del JSON: $e'),
                    ));
                  }
                },
                child: Text('Formatta JSON'),
              ),
            ),
            TextField(
              controller: _jsonController,
              decoration: InputDecoration(
                labelText: 'Modifica il dato in formato JSON',
              ),
              maxLines: 8,
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
            child: Text('Salva'),
            onPressed: () async {
              if (_jsonController.text.isNotEmpty) {
                try {
                  // Rimuovi il campo _id dal JSON da inviare
                  final jsonData = jsonDecode(_jsonController.text);

                  await _authService.updateCollectionData(
                    dbName,
                    collectionName,
                    item['_id'], // Utilizza _id solo per identificare il documento da aggiornare
                    jsonData, // Invia il JSON senza _id
                    widget.token,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Dato aggiornato con successo in $collectionName!'),
                  ));
                  Navigator.of(context).pop(); // Chiude il dialog
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Errore durante l\'aggiornamento del dato: $e'),
                  ));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Inserisci un dato valido in formato JSON!'),
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
        title: Text('Databases'),
      ),
      body: ListView.builder(
        itemCount: widget.databases.length,
        itemBuilder: (context, index) {
          final db = widget.databases[index];
          return ListTile(
  title: Text(db.dbName),
  subtitle: Text('Host: ${db.host}, Port: ${db.port}'),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(Icons.add, color: Colors.green),
        onPressed: () => _createCollection(db.dbName),
      ),
      IconButton(
        icon: Icon(Icons.delete, color: Colors.red),
        onPressed: () => _deleteDatabase(db.dbName),
      ),
    ],
  ),
  onTap: () => _showCollections(db.dbName),
);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Crea Database'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _dbNameController,
                      decoration: InputDecoration(labelText: 'Nome Database'),
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
                    child: Text('Crea'),
                    onPressed: () {
                      _createDatabase();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class ExpandableCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String dbName;
  final String collectionName;
  final Function onEdit;
  final Function onDelete;

  ExpandableCard({
    required this.item,
    required this.dbName,
    required this.collectionName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  _ExpandableCardState createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mostra sempre il campo _id
                Text(
                  '_id: ${widget.item["_id"]}',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Se espanso, mostra tutti i campi, altrimenti solo _id
                if (isExpanded)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...widget.item.entries
                          .where((entry) => entry.key != '_id')
                          .map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: JsonViewer(
                            json: {entry.key: entry.value},
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                // Aggiungi l'icona per espandere/collassare al centro in basso
                Center(
                  child: IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
                ),
              ],
            ),
            // Icone di modifica ed eliminazione ancorate in alto a destra
            Positioned(
              right: 0,
              top: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      widget.onEdit(widget.item);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      widget.onDelete(widget.item['_id']);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JsonViewer extends StatefulWidget {
  final dynamic json;
  final double indent;

  JsonViewer({required this.json, this.indent = 0});

  @override
  _JsonViewerState createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  Map<String, bool> expandedStateMap = {};

  @override
  Widget build(BuildContext context) {
    if (widget.json is Map) {
      return Padding(
        padding: EdgeInsets.only(left: widget.indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.json.entries.map<Widget>((entry) {
            return _buildKeyValue(entry.key, entry.value);
          }).toList(),
        ),
      );
    } else if (widget.json is List) {
      return Padding(
        padding: EdgeInsets.only(left: widget.indent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.json.asMap().entries.map<Widget>((entry) {
            return _buildKeyValue(entry.key.toString(), entry.value);
          }).toList(),
        ),
      );
    } else {
      return _buildSimpleValue(widget.json);
    }
  }

  Widget _buildKeyValue(String key, dynamic value) {
    bool isExpanded = expandedStateMap[key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (value is Map || value is List)
              IconButton(
                icon: Icon(isExpanded
                    ? Icons.expand_less
                    : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    expandedStateMap[key] = !isExpanded;
                  });
                },
              ),
            Text(
              '$key: ',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!(value is Map || value is List)) _buildSimpleValue(value),
          ],
        ),
        if (isExpanded && (value is Map || value is List))
          JsonViewer(json: value, indent: widget.indent + 16),
      ],
    );
  }

  Widget _buildSimpleValue(dynamic value) {
    TextStyle textStyle;

    if (value is int) {
      textStyle = TextStyle(color: Colors.blueAccent);
    } else if (value is double) {
      textStyle = TextStyle(color: Colors.orange);
    } else if (value is bool) {
      textStyle = TextStyle(color: value ? Colors.blue : Colors.red);
    } else if (value is String) {
      textStyle = TextStyle(color: Colors.green);
    } else {
      textStyle = TextStyle(color: Colors.black);
    }

    return Text(
      value.toString(),
      style: textStyle,
    );
  }
}



class CollectionDataPage extends StatelessWidget {
  final String dbName;
  final String collectionName;
  final String token;
  final AuthService _authService = AuthService();

  CollectionDataPage({
    required this.dbName,
    required this.collectionName,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dati in $collectionName'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _authService.fetchCollectionData(dbName, collectionName, token),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nessun dato disponibile.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: JsonViewer(json: item),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
// Main
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
      },
    );
  }
}
