import 'package:flutter/material.dart';

enum AdminConsoleSection {
  users,
  settings,
}

extension AdminConsoleSectionX on AdminConsoleSection {
  String get label {
    switch (this) {
      case AdminConsoleSection.users:
        return 'Users';
      case AdminConsoleSection.settings:
        return 'Impostazioni';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminConsoleSection.users:
        return Icons.people_alt_outlined;
      case AdminConsoleSection.settings:
        return Icons.settings_outlined;
    }
  }
}
