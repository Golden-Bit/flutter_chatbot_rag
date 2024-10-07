import 'package:flutter/material.dart';
import 'chatbot.dart'; // Importa la pagina del chatbot
import 'package:flutter_app/user_manager/auth_pages.dart'; // Importa le pagine di login e registrazione

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