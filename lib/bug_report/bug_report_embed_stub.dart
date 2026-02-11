import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Non-WEB fallback:
/// - shows a friendly message and opens the Jira form in an external browser/app.
class BugReportEmbed extends StatelessWidget {
  const BugReportEmbed({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_browser_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Il form Jira è incorporabile come iframe solo su Web.\n'
              'Aprilo nel browser per continuare.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Apri modulo'),
            ),
          ],
        ),
      ),
    );
  }
}
