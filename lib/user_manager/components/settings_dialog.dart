import 'package:flutter/material.dart';
import 'package:boxed_ai/context_api_sdk.dart';
import 'package:boxed_ai/user_manager/auth_sdk/cognito_api_client.dart';
import 'package:boxed_ai/user_manager/components/securety_settings_content.dart';
import 'package:boxed_ai/user_manager/components/general_settings_content.dart';
import 'package:boxed_ai/user_manager/components/subscription_settings_content.dart';
import 'package:boxed_ai/user_manager/components/user_profile_settings_content.dart';

/// Dialog che mostra le varie sezioni di impostazioni dell’app.
/// Tutti i sotto-widget ricevono la **stessa** istanza di [CognitoApiClient]
/// in modo da condividere token ed eventuale cache.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    Key? key,
    required this.accessToken,          // istanza condivisa dell’SDK
    required this.onArchiveAll,         // callback «Archivia tutte le chat»
    required this.onDeleteAll,          // callback «Elimina tutte le chat»
  }) : super(key: key);

  final String accessToken;
  final Future<void> Function() onArchiveAll;
  final Future<void> Function() onDeleteAll;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  // Breakpoint sotto il quale la sidebar diventa una griglia in alto.
  static const double _breakpointWidth = 700;
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Generale',
    'Utente',
    'Notifiche',
    // 'Personalizzazione',
    // 'Audio',
    // 'Controlli dati',
    // 'Profilo costruttore',
    'App collegate',
    'Sicurezza',
    'Abbonamento',
  ];

  final List<IconData> _menuIcons = [
    Icons.settings,
    Icons.person,
    Icons.notifications,
    // Icons.brush,
    // Icons.volume_up,
    // Icons.tune,
    // Icons.description,
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
        return SecuritySettingsContent(accessToken: widget.accessToken);
      case 5:
        return SubscriptionSettingsContent(                      // ⬅️ passa SDK
           accessToken: widget.accessToken,       // ⬅️ passa token
   );
      default:
        return Center(
          child: Text(
            _menuItems[index],
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        );
    }
  }

  /// Pulsante menu riutilizzabile per sidebar e griglia.
  Widget _buildMenuButton(int index, bool selected) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.grey[200] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _menuIcons[index],
              color: selected ? Colors.black87 : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              _menuItems[index],
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dialogTheme: DialogThemeData(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= _breakpointWidth;

              return SizedBox(
                width: isWide ? 800 : constraints.maxWidth,
                height: 600,
                child: Column(
                  children: [
                    // —————————— HEADER ——————————
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                      child: isWide
                          // ---------- LAYOUT “WIDE” ----------
                          ? Row(
                              children: [
                                // —— Sidebar sinistra ——
                                Container(
                                  width: 200,
                                  color: Colors.white,
                                  child: ListView.builder(
                                    itemCount: _menuItems.length,
                                    itemBuilder: (context, index) => Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      child: _buildMenuButton(
                                          index, index == _selectedIndex),
                                    ),
                                  ),
                                ),
                                // —— Contenuto destro ——
                                Expanded(
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    child:
                                        _buildContentForIndex(_selectedIndex),
                                  ),
                                ),
                              ],
                            )
                          // ---------- LAYOUT “COMPACT” ----------
                          : Column(
                              children: [
                                // —— Griglia di pulsanti in alto ——
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: GridView.builder(
                                    itemCount: _menuItems.length,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 200,
                                      mainAxisExtent: 48,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemBuilder: (context, index) =>
                                        _buildMenuButton(
                                            index, index == _selectedIndex),
                                  ),
                                ),
                                const Divider(height: 1),
                                // —— Contenuto ——
                                Expanded(
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    child:
                                        _buildContentForIndex(_selectedIndex),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
