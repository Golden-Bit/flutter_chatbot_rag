import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:boxed_ai/ui_components/custom_components/general_components_v1.dart';
import 'package:boxed_ai/ui_components/custom_components/prompts_config_v1.dart';
// prompts_config.dart contiene la lista "promptsData" con
// { "categoryName", "icon", "examples": [...] }

/// Custom scroll behavior to support mouse and touch drag devices.
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

/// Costruisce la schermata vuota con categorie e prompt cards,
/// con scrollbar visibili in orizzontale e verticale.
/// Il parametro onPromptSelected viene invocato con il testo del prompt
/// quando l'utente clicca su una scheda.
Widget buildEmptyChatScreen(
    BuildContext context, void Function(String) onPromptSelected) {
  // 1) ScrollController per lo scroll orizzontale
  final horizontalController = ScrollController();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (horizontalController.hasClients) {
      horizontalController
          .jumpTo(horizontalController.position.maxScrollExtent / 2);
    }
  });
  return Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo posizionato in alto al centro
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Center(child: largeFullLogo),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final double rightContainerWidth = constraints.maxWidth;
          final double containerWidth =
              800; // puoi decidere di adattarlo se necessario
          final bool isMobile =
              Theme.of(context).platform == TargetPlatform.android ||
                  Theme.of(context).platform == TargetPlatform.iOS;

          return Container(
            width: containerWidth,
            child: isMobile
                ? ScrollConfiguration(
                    behavior: MyCustomScrollBehavior(),
                    child: SingleChildScrollView(
                      controller: horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var category in promptsData)
                            _buildCategoryColumn(category, onPromptSelected),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true, // Mostra la "thumb" della scrollbar
                    trackVisibility:
                        true, // Mostra il "binario" della scrollbar
                    interactive: true, // Consente l'interazione tramite mouse
                    controller: horizontalController,
                    thickness: 8.0,
                    child: ScrollConfiguration(
                      behavior: MyCustomScrollBehavior(),
                      child: SingleChildScrollView(
                        controller: horizontalController,
                        scrollDirection: Axis.horizontal,
                        // Avvolgo il Row in un ConstrainedBox per imporre una larghezza minima
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: containerWidth),
                          child: Row(
                            // Centriamo le colonne se c'è spazio in eccesso
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var category in promptsData)
                                _buildCategoryColumn(
                                    category, onPromptSelected),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        })
      ],
    ),
  );
}

/// Colonna di categoria, con scrollbar verticale interna per i prompt.
/// Propaga il callback onPromptSelected a ciascuna scheda prompt.
Widget _buildCategoryColumn(
    Map<String, dynamic> category, void Function(String) onPromptSelected) {
  // 2) ScrollController per lo scroll verticale in ciascuna colonna
  final verticalController = ScrollController();

  final iconData = category["icon"] as IconData?;
  final categoryName = category["categoryName"] as String? ?? "";
  final examples = category["examples"] as List<String>? ?? [];

  return Container(
    width: 200, // Larghezza fissa/minima per la colonna
    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // (A) Icona e nome categoria in nero
        if (iconData != null) Icon(iconData, size: 24, color: Colors.black),
        const SizedBox(height: 8),
        Text(
          categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // (B) Scrollbar verticale per i prompt
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            controller: verticalController,
            thickness: 8.0,
            child: ScrollConfiguration(
              behavior: MyCustomScrollBehavior(),
              child: SingleChildScrollView(
                controller: verticalController,
                child: Column(
                  children: examples
                      .map((ex) => PromptCard(
                          text: ex, onPromptSelected: onPromptSelected))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Widget per la scheda prompt con effetto hover e callback al click.
class PromptCard extends StatefulWidget {
  final String text;
  final void Function(String) onPromptSelected;

  const PromptCard(
      {Key? key, required this.text, required this.onPromptSelected})
      : super(key: key);

  @override
  _PromptCardState createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: () {
          // Al click, invia il testo del prompt tramite il callback
          widget.onPromptSelected(widget.text);
        },
        child: Container(
          width: 250, // Larghezza fissa della card
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            // Sfumatura blu verticale; se in hover, usa colori leggermente più scuri
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isHovered
                  ? [
                      const Color(0xFF1976D2), // Blu più scuro
                      const Color.fromARGB(255, 80, 150, 210),
                    ]
                  : [
                      const Color(0xFF2196F3), // Blu
                      const Color.fromARGB(255, 100, 180, 246),
                    ],
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          // Testo bianco, centrato
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
