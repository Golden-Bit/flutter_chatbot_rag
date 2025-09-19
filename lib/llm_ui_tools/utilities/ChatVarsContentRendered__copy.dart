import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:boxed_ai/ui_components/message/codeblock_md_builder.dart';
import 'package:boxed_ai/ui_components/message/table_md_builder.dart';
import 'package:flutter/material.dart';
import '../../chatbot.dart';

  // serve per accedere a ChatBotPageState.widgetMap

/// Un singolo segmento di testo OPPURE di widget da montare
class Segment {
  final String? text;
  final String? widgetId;
  final Map<String, dynamic>? widgetData;
  const Segment({this.text, this.widgetId, this.widgetData});
}

/// Parsifica tutta la stringa in un elenco di Segment.
/// Non usa placeholder, ma lascia i widget inline.
List<Segment> parseContent(String fullText) {
  final List<Segment> segments = [];
  int last = 0;

  // regex che cattura < TYPE='WIDGET' WIDGET_ID='…' | {…json…} | TYPE='WIDGET' >
  final widgetRe = RegExp(
    r"< TYPE='WIDGET'\s+WIDGET_ID='([^']+)'\s*\|\s*([\s\S]+?)\s*\|\s*TYPE='WIDGET'\s*>",
    multiLine: true,
  );

  for (final m in widgetRe.allMatches(fullText)) {
    // prima del widget, testo normale
    if (m.start > last) {
      segments.add(Segment(text: fullText.substring(last, m.start)));
    }
    // estrai widgetId + JSON
    final id = m.group(1)!;
    final rawJson = m.group(2)!;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    segments.add(Segment(widgetId: id, widgetData: data));
    last = m.end;
  }
  // eventuale testo residuo
  if (last < fullText.length) {
    segments.add(Segment(text: fullText.substring(last)));
  }
  return segments;
}

/// Renderizza la lista di Segment in widget (MarkdownBody + tool UI)
List<Widget> renderContent(
  BuildContext context,
  List<Segment> segments,
    ChatBotPageCallbacks  pageCbs,     // ��� nuovo
  ChatBotHostCallbacks  hostCbs, 
  Map<String, ChatWidgetBuilder>     widgetBuilders,   // <-- di nuovo qui
  
  void Function(String) onReply,
) {

  final List<Widget> out = [];

  for (final seg in segments) {
    if (seg.text != null && seg.text!.isNotEmpty) {
      out.add(MarkdownBody(
        data: seg.text!,
        extensionSet: md.ExtensionSet.gitHubWeb,
        selectable: true,
        builders: {
          'code': CodeBlockBuilder(context),
          'table': ScrollableTableBuilder(onDownload: (_) {}),
        },
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 16.0, color: Colors.black87),
          code: const TextStyle(fontFamily: 'Courier', fontSize: 14.0),
        ),
        onTapLink: (text, href, title) async {
          if (href != null && await canLaunch(href)) await launch(href);
        },
      ));
    }
    if (seg.widgetId != null) {
      final builder = widgetBuilders[seg.widgetId!];
      if (builder != null) {
        out.add(builder(seg.widgetData ?? {}, onReply, pageCbs, hostCbs));
      } else {
        out.add(Text("[Widget sconosciuto: ${seg.widgetId}]"));
      }
    }
  }

  return out;
}

