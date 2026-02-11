import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bug_report_embed.dart';

/// Dialog professionale per "Segnala bug" con embed (iframe su Web) e chiusura via X.
class BugReportDialog extends StatelessWidget {
  static const String jiraFormUrl =
      'https://teatek.atlassian.net/jira/software/c/form/930e6b7c-ac75-429d-8987-a99dbb782c63';

  const BugReportDialog({super.key, this.url = jiraFormUrl});
  final String url;

  static Future<void> open(BuildContext context, {String url = jiraFormUrl}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // chiusura SOLO via X
      builder: (_) => BugReportDialog(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    final maxW = (mq.size.width * 0.92).clamp(360.0, 1100.0);
    final maxH = (mq.size.height * 0.90).clamp(520.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Segnala un bug',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Consigliato: Atlassian può bloccare l'iframe (CSP/X-Frame-Options).
                  IconButton(
                    tooltip: 'Apri in nuova scheda',
                    icon: const Icon(Icons.open_in_new_outlined),
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      webOnlyWindowName: '_blank',
                    ),
                  ),

                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: BugReportEmbed(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
