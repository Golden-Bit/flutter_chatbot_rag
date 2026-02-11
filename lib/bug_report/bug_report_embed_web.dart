// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

/// WEB implementation: embeds the Jira form via <iframe>.
class BugReportEmbed extends StatefulWidget {
  const BugReportEmbed({super.key, required this.url});
  final String url;

  @override
  State<BugReportEmbed> createState() => _BugReportEmbedState();
}

class _BugReportEmbedState extends State<BugReportEmbed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();

    // Unique viewType to avoid collisions across multiple openings.
    _viewType = 'bug-report-iframe-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent'
        ..allow = 'clipboard-write; fullscreen';

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
