import 'package:url_launcher/url_launcher.dart';

/// Helper riusabile per aprire la pagina Debug/Bug Report in una nuova scheda.
/// - Su Web usa window.open sotto al cofano tramite url_launcher.
/// - Richiamalo SOLO da un gesto utente (onPressed), altrimenti popup-blocker.
class BugReportLauncher {
  static const String jiraFormUrl =
      'https://teatek.atlassian.net/jira/software/c/form/930e6b7c-ac75-429d-8987-a99dbb782c63';

  /// Ritorna `true` se il browser ha aperto correttamente la pagina.
  static Future<bool> openNewTab({String url = jiraFormUrl}) async {
    final uri = Uri.parse(url);

    return launchUrl(
      uri,
      // web: nuova scheda
      webOnlyWindowName: '_blank',
      // lascia al platform la scelta corretta (web → window.open)
      mode: LaunchMode.platformDefault,
    );
  }
}
