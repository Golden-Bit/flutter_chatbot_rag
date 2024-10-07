import 'package:flutter/foundation.dart';

class LoadingProvider with ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();  // Notifica a tutti i listener che lo stato è cambiato
  }
}