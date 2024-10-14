import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoadingProvider with ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();  // Notifica a tutti i listener che lo stato è cambiato
  }
}



// Questo sarà mostrato durante il controllo dello stato di login
class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Mostra un indicatore di caricamento
      ),
    );
  }
}
