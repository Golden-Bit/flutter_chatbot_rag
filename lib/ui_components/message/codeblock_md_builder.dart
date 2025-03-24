import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:url_launcher/url_launcher.dart';
// Sostituiamo flutter_html con flutter_widget_from_html
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// Widget stateful che gestisce l'espansione verticale del blocco di codice
/// e, nel caso di codice HTML, la possibilità di visualizzare l'anteprima renderizzata
/// solo su richiesta, liberando la memoria quando la visualizzazione viene disattivata.
class ExpandableCodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final double maxCodeBlockHeight;
  final Map<String, TextStyle> theme;

  const ExpandableCodeBlockWidget({
    Key? key,
    required this.code,
    required this.language,
    required this.maxCodeBlockHeight,
    required this.theme,
  }) : super(key: key);

  @override
  _ExpandableCodeBlockWidgetState createState() =>
      _ExpandableCodeBlockWidgetState();
}

class _ExpandableCodeBlockWidgetState extends State<ExpandableCodeBlockWidget> {
  bool _isExpanded = false;
  bool _showHtmlPreview = false;

  @override
  Widget build(BuildContext context) {
    // Estrae il colore di sfondo dal tema (usando la chiave 'root').
    final Color themeBg =
        widget.theme['root']?.backgroundColor ?? Colors.grey[300]!;

    // Verifica se il blocco riguarda HTML (usiamo il nome del linguaggio).
    final bool isHtml = widget.language.toLowerCase() == "html";

    // Costruisce la lista delle icone nell'header.
    List<Widget> headerIcons = [];

    // Icona "copia negli appunti"
    headerIcons.add(
      IconButton(
        icon: const Icon(Icons.copy, size: 16.0, color: Colors.black87),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: 'Copia codice',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: widget.code));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Codice copiato negli appunti')),
          );
        },
      ),
    );

    // Se il codice è HTML, aggiunge l'icona di visualizzazione per l'anteprima.
    if (isHtml) {
      headerIcons.add(
        IconButton(
          icon: Icon(
            _showHtmlPreview ? Icons.visibility_off : Icons.remove_red_eye,
            size: 16.0,
            color: Colors.black87,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: _showHtmlPreview
              ? 'Nascondi anteprima HTML'
              : 'Visualizza anteprima HTML',
          onPressed: () {
            setState(() {
              _showHtmlPreview = !_showHtmlPreview;
              // Quando si disattiva la visualizzazione (_showHtmlPreview = false),
              // il widget HTML non viene più costruito e la memoria viene liberata.
            });
          },
        ),
      );
    }

    // Icona di espansione/compressione del blocco di codice.
    headerIcons.add(
      IconButton(
        icon: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          size: 16.0,
          color: Colors.black87,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: _isExpanded ? 'Comprimi codice' : 'Espandi codice',
        onPressed: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: mostra il nome del linguaggio + le icone di azione.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: themeBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4.0),
              topRight: Radius.circular(4.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nome del linguaggio in lettere maiuscole.
              Text(
                widget.language.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              // Gruppo di icone (copia, anteprima HTML, espandi).
              Row(children: headerIcons),
            ],
          ),
        ),

        // Corpo del codeblock: il contenuto evidenziato dal pacchetto highlight.
        ConstrainedBox(
          constraints: BoxConstraints(
            // Se non espanso, limitiamo l'altezza; altrimenti, mostriamo tutto.
            maxHeight:
                _isExpanded ? double.infinity : widget.maxCodeBlockHeight,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4.0),
              bottomRight: Radius.circular(4.0),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // Assicura che il contenuto occupi almeno tutta la larghezza disponibile.
                          minWidth: constraints.maxWidth,
                        ),
                        child: HighlightView(
                          widget.code,
                          language: widget.language,
                          theme: widget.theme,
                          padding: const EdgeInsets.all(8.0),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Renderizzazione condizionata del contenuto HTML:
        // viene costruito solo se il linguaggio è "html" *e* l'utente ha attivato la visualizzazione.
        if (isHtml && _showHtmlPreview)
          Container(
            margin: const EdgeInsets.only(top: 8.0),
            decoration: BoxDecoration(
              color: Colors.white, // Sfondo per l'anteprima HTML
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 300, // Limite verticale dell'anteprima
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: HtmlWidget(
                    widget.code,
                    // customStylesBuilder per personalizzare gli stili (es. tabelle)
                    customStylesBuilder: (element) {
                      if (element.localName == 'table') {
                        return {'border': '1px solid black'};
                      }
                      return null;
                    },
                    // customWidgetBuilder se servono widget custom
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Builder personalizzato per i blocchi di codice Markdown.
/// Distingue i blocchi triplo backtick (`<pre><code>...</code></pre>`)
/// dagli spezzoni inline a singolo backtick (`<code>...</code>` senza <pre>).
class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  /// Altezza massima del blocco di codice prima di abilitare lo scroll verticale.
  final double maxCodeBlockHeight;

  CodeBlockBuilder(this.context, {this.maxCodeBlockHeight = 200});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String code = element.textContent;

    // Se l'elemento ha class="language-...", lo consideriamo un block code (tripli backtick)
    // altrimenti lo consideriamo inline code (singolo backtick).
    bool isBlockCode = false;
    String language = 'plaintext';

    if (element.attributes.containsKey('class')) {
      final classAttr = element.attributes['class']!;
      if (classAttr.startsWith('language-')) {
        isBlockCode = true;
        // Recupera la parte dopo "language-"
        language = classAttr.substring('language-'.length);
        if (language.isEmpty) {
          language = 'plaintext';
        }
      }
    }

    if (isBlockCode) {
      return ExpandableCodeBlockWidget(
        code: code,
        language: language,
        maxCodeBlockHeight: maxCodeBlockHeight,
        theme: githubTheme,
      );
    } else {
      // Altrimenti, trattiamo questo <code> come inline (singolo backtick).
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
      );
    }
  }
}

/// Funzione che costruisce il widget per visualizzare il messaggio in Markdown,
/// integrando il nostro [CodeBlockBuilder] per i blocchi di codice.
Widget buildAdvancedMarkdownMessage(
  BuildContext context,
  String content,
  bool isUser, {
  Color? userMessageColor,
  double? userMessageOpacity,
  Color? assistantMessageColor,
  double? assistantMessageOpacity,
}) {
  // Imposta il colore di sfondo in base al ruolo del mittente.
  final bgColor = isUser
      ? (userMessageColor ?? Colors.blue[100])!.withOpacity(userMessageOpacity ?? 1.0)
      : (assistantMessageColor ?? Colors.grey[200])!.withOpacity(assistantMessageOpacity ?? 1.0);

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 4.0),
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: MarkdownBody(
      data: content,
      // Iniettiamo il builder personalizzato.
      builders: {
        'code': CodeBlockBuilder(context),
      },
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 16.0, color: Colors.black87),
        h1: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
        h3: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
        // Stile del codice "base" (inline): verrà in parte sovrascritto
        // dal nostro Container, ma resta qui come fallback.
        code: TextStyle(
          fontFamily: 'Courier',
          backgroundColor: Colors.grey[300],
          fontSize: 14.0,
        ),
        blockquote: const TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.blueGrey,
          fontSize: 14.0,
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href != null && await canLaunch(href)) {
          await launch(href);
        }
      },
    ),
  );
}
