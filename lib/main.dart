import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boxed_ai/user_manager/pages/login_page_1.dart';
import 'package:boxed_ai/user_manager/pages/registration_page_1.dart';
import 'package:boxed_ai/utilities/localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    // Per Web (e in generale): carica i profili una volta
  if (kIsWeb) {
    await langdetect.initLangDetect(); // carica i profili dal package
  }

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