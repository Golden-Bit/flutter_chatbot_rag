import 'package:flutter/material.dart';

import 'admin_console_controller.dart';
import 'admin_console_sections.dart';
import 'admin_console_settings_view.dart';
import 'admin_console_users_view.dart';

class AdminConsoleShell extends StatelessWidget {
  final AdminConsoleController controller;

  const AdminConsoleShell({
    super.key,
    required this.controller,
  });

  void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isWide = MediaQuery.of(context).size.width >= 980;
        final section = controller.section;

        return Scaffold(
          appBar: AppBar(
            title: Text('Admin Console · ${section.label}'),
            leading: isWide
                ? IconButton(
                    tooltip:
                        controller.navExpanded ? 'Riduci menu' : 'Espandi menu',
                    icon: Icon(
                        controller.navExpanded ? Icons.menu_open : Icons.menu),
                    onPressed: controller.toggleNavExpanded,
                  )
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Menu',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            actions: [
              IconButton(
                tooltip: 'Aggiorna whitelist',
                onPressed: controller.whitelistLoading
                    ? null
                    : () async {
                        try {
                          await controller.refreshWhitelist();
                          _snack(context, 'Whitelist aggiornata.');
                        } catch (e) {
                          _snack(context, 'Errore whitelist: $e', error: true);
                        }
                      },
                icon: const Icon(Icons.refresh_outlined),
              ),
              IconButton(
                tooltip: 'Blocca console',
                onPressed: () => controller.lock(clearToken: false),
                icon: const Icon(Icons.lock_outline),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: isWide ? null : Drawer(child: _DrawerNav(controller: controller)),
          body: Row(
            children: [
              if (isWide) _SideRail(controller: controller),
              if (isWide) const VerticalDivider(width: 1),
              Expanded(
                child: _SectionBody(controller: controller, section: section),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionBody extends StatelessWidget {
  final AdminConsoleController controller;
  final AdminConsoleSection section;

  const _SectionBody({
    required this.controller,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case AdminConsoleSection.users:
        return AdminConsoleUsersView(controller: controller);
      case AdminConsoleSection.settings:
        return AdminConsoleSettingsView(controller: controller);
    }
  }
}

class _SideRail extends StatelessWidget {
  final AdminConsoleController controller;

  const _SideRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: controller.section.index,
      onDestinationSelected: (idx) {
        controller.setSection(AdminConsoleSection.values[idx]);
      },
      extended: controller.navExpanded,
      labelType:
          controller.navExpanded ? null : NavigationRailLabelType.selected,
      backgroundColor: theme.colorScheme.surface,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt),
          label: Text('Users'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Impostazioni'),
        ),
      ],
    );
  }
}

class _DrawerNav extends StatelessWidget {
  final AdminConsoleController controller;

  const _DrawerNav({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin Console'),
            subtitle: Text(
              controller.settings.authBaseUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          _NavTile(
            selected: controller.section == AdminConsoleSection.users,
            icon: Icons.people_alt_outlined,
            title: 'Users',
            onTap: () {
              controller.setSection(AdminConsoleSection.users);
              Navigator.of(context).pop();
            },
          ),
          _NavTile(
            selected: controller.section == AdminConsoleSection.settings,
            icon: Icons.settings_outlined,
            title: 'Impostazioni',
            onTap: () {
              controller.setSection(AdminConsoleSection.settings);
              Navigator.of(context).pop();
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () {
                controller.lock(clearToken: false);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Blocca console'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NavTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      onTap: onTap,
    );
  }
}
