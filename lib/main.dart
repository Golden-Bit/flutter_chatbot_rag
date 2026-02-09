import 'package:boxed_ai/admin_console/admin_console_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boxed_ai/user_manager/pages/login_page_1.dart';
import 'package:boxed_ai/user_manager/pages/registration_page_1.dart';
import 'package:boxed_ai/utilities/localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
      ],
      title: 'Boxed-AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyMedium: GoogleFonts.inter(fontSize: 14),
        ),
      ),

      // FIX: intercettiamo le deep-link iniziali (solo quando initialRoute è fornita
      // dalla piattaforma, es. /#/admin_console) per evitare che Flutter carichi prima '/'
      // e poi la route target. Nel tuo caso la LoginPage sotto faceva pushReplacement
      // e ti buttava fuori dalla Admin Console dopo pochi secondi.
      //
      // Firma (Flutter stable recente): List<Route<dynamic>> Function(String initialRoute)
      onGenerateInitialRoutes: (String initialRoute) {
        // 1) Admin Console: stack iniziale SOLO con /admin_console (nessuna '/')
        if (initialRoute == '/admin_console' ||
            initialRoute.startsWith('/admin_console/')) {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/admin_console'),
              builder: (_) => const AdminConsolePage(),
            ),
          ];
        }

        // 2) Fallback “simile al default” per le altre deep-link:
        //    includiamo prima '/' (LoginPage) e poi, se esiste, la route richiesta.
        final Map<String, WidgetBuilder> routeBuilders = {
          '/': (_) => LoginPage(),
          '/login': (_) => LoginPage(),
          '/register': (_) => RegistrationPage(),
          '/admin_console': (_) => const AdminConsolePage(),
        };

        final List<Route<dynamic>> routes = [
          MaterialPageRoute(
            settings: const RouteSettings(name: '/'),
            builder: routeBuilders['/']!,
          ),
        ];

        // Se la route richiesta è diversa da '/', e la conosciamo, la aggiungiamo.
        if (initialRoute != Navigator.defaultRouteName &&
            routeBuilders.containsKey(initialRoute)) {
          routes.add(
            MaterialPageRoute(
              settings: RouteSettings(name: initialRoute),
              builder: routeBuilders[initialRoute]!,
            ),
          );
        }

        return routes;
      },

      home: LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegistrationPage(),
        '/admin_console': (context) => const AdminConsolePage(),
      },
      showSemanticsDebugger: false,
    );
  }
}
