import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
// Solo per Web: per accedere a window.location / window.open
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PaymentPage extends StatefulWidget {
  final String url;
  const PaymentPage({Key? key, required this.url}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  @override
  void initState() {
    super.initState();
    // Al caricamento del widget facciamo subito il redirect
    if (kIsWeb) {
      // Stessa finestra
      html.window.location.assign(widget.url);
      // Se volessi un nuovo tab, usa:
      // html.window.open(widget.url, '_blank');
    } else {
      // Su mobile apri il browser esterno
      html.window.open(widget.url, '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Non mostriamo nulla: l'utente è già in fase di redirect.
    return const SizedBox.shrink();
  }
}
