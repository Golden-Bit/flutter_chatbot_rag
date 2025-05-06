import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/user_manager/pages/login_page_1.dart';
import 'package:flutter_app/user_manager/pages/registration_page_1.dart';
import 'package:flutter_app/utilities/localization.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    LocalizationProviderWrapper(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boxed-AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyMedium: GoogleFonts.inter(fontSize: 14),
        ),
      ),
      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegistrationPage(),
      },
    );
  }
}