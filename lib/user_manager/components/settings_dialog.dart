import 'package:flutter/material.dart';
import 'package:flutter_app/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:flutter_app/user_manager/components/securety_settings_content.dart';
import 'package:flutter_app/user_manager/components/general_settings_content.dart';
import 'package:flutter_app/user_manager/components/subscription_settings_content.dart';
import 'package:flutter_app/user_manager/components/user_profile_settings_content.dart';

/// Dialog che mostra le varie sezioni di impostazioni dell’app.
/// Tutti i sotto‑widget ricevono la **stessa** istanza di [CognitoApiClient]
/// in modo da condividere token ed eventuale cache.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    Key? key,
    required this.accessToken,              // istanza condivisa dell’SDK
    required this.onArchiveAll,           // callback «Archivia tutte le chat»
    required this.onDeleteAll,            // callback «Elimina tutte le chat»
  }) : super(key: key);

  final String accessToken;
  final Future<void> Function() onArchiveAll;
  final Future<void> Function() onDeleteAll;

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Generale',
    'Utente',
    'Notifiche',
    //'Personalizzazione',
    //'Audio',
    //'Controlli dati',
    //'Profilo costruttore',
    'App collegate',
    'Sicurezza',
    'Abbonamento',
  ];

  final List<IconData> _menuIcons = [
    Icons.settings,
    Icons.person,
    Icons.notifications,
    //Icons.brush,
    //Icons.volume_up,
    //Icons.tune,
    //Icons.description,
    Icons.link,
    Icons.security,
    Icons.card_membership,
  ];

  /// Restituisce il widget di contenuto in base alla voce selezionata.
  Widget _buildContentForIndex(int index) {
    switch (index) {
      case 0:
        return GeneralSettingsContent(
          onArchiveAll: widget.onArchiveAll,
          onDeleteAll: widget.onDeleteAll,
        );
      case 1:
        return UserProfileSettingsContent(accessToken: widget.accessToken);
      case 4:
   return SecuritySettingsContent(
     accessToken: widget.accessToken,   //  ← nuovo argomento
   );
      case 5:
        return SubscriptionSettingsContent();
      default:
        return                 Center(
          child: Text(
            _menuItems[index],
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 800,
            height: 600,
            child: Column(
              children: [
                // —————————— HEADER ——————————
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Impostazioni',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[300], height: 1),
                // —————————— BODY ——————————
                Expanded(
                  child: Row(
                    children: [
                      // ——— Sidebar sinistra ———
                      Container(
                        width: 200,
                        color: Colors.white,
                        child: ListView.builder(
                          itemCount: _menuItems.length,
                          itemBuilder: (context, index) {
                            final bool selected = index == _selectedIndex;

                            return InkWell(
                              onTap: () => setState(() => _selectedIndex = index),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.grey[200] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _menuIcons[index],
                                      color: selected ? Colors.black87 : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _menuItems[index],
                                        style: TextStyle(
                                          color: selected ? Colors.black87 : Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // ——— Contenuto destro ———
Expanded(
  child: Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildContentForIndex(_selectedIndex),
        ),
      ],
    ),
  ),
),
                    ],
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
