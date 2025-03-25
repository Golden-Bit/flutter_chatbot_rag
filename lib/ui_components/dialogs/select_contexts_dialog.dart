import 'package:flutter/material.dart';
import 'package:flutter_app/context_api_sdk.dart';
import 'package:flutter_app/utilities/localization.dart';

// Se serve importare user/token, puoi aggiungere:
// import 'package:flutter_app/user_manager/user_model.dart';
// import 'package:flutter_app/user_manager/auth_pages.dart';

/// Mostra un dialog per selezionare contesti e modello,
/// con design simile a quello mostrato in figura (angoli arrotondati, max 600px, ecc.).
/// [availableContexts]: elenco contesti caricati
/// [initialSelectedContexts]: contesti già selezionati all'apertura
/// [initialModel]: modello iniziale selezionato
/// [onConfirm]: callback per restituire i contesti selezionati e il modello
Future<void> showSelectContextDialog({
  required BuildContext context,
  required List<ContextMetadata> availableContexts,
  required List<String> initialSelectedContexts,
  required String initialModel,
  required void Function(List<String> selectedContexts, String model) onConfirm,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false, // Se vuoi impedire la chiusura cliccando fuori
    builder: (BuildContext context) {
      return _SelectContextDialogContent(
        availableContexts: availableContexts,
        initialSelectedContexts: initialSelectedContexts,
        initialModel: initialModel,
        onConfirm: onConfirm,
      );
    },
  );
}

class _SelectContextDialogContent extends StatefulWidget {
  final List<ContextMetadata> availableContexts;
  final List<String> initialSelectedContexts;
  final String initialModel;
  final void Function(List<String> selectedContexts, String model) onConfirm;

  const _SelectContextDialogContent({
    Key? key,
    required this.availableContexts,
    required this.initialSelectedContexts,
    required this.initialModel,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<_SelectContextDialogContent> createState() =>
      _SelectContextDialogContentState();
}

class _SelectContextDialogContentState
    extends State<_SelectContextDialogContent> {
  late List<ContextMetadata> _filteredContexts;
  late TextEditingController _searchController;

  /// Contesti selezionati localmente
  late List<String> _selectedContexts;

  /// Modello selezionato localmente
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredContexts = List.from(widget.availableContexts);
    _selectedContexts = List.from(widget.initialSelectedContexts);
    _selectedModel = widget.initialModel;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filtro contesti
  void _filterContexts(String query) {
    setState(() {
      _filteredContexts = widget.availableContexts.where((ctx) {
        return ctx.path.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  // Al click di Conferma
  void _handleConfirm() {
    widget.onConfirm(_selectedContexts, _selectedModel);
    Navigator.of(context).pop(); // chiude il dialog
  }

  @override
  Widget build(BuildContext context) {
    final localizations = LocalizationProvider.of(context);
    // Invece di AlertDialog, usiamo un Dialog personalizzato
    // per controllare meglio forma e dimensioni
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // angoli arrotondati
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 24.0,
      ), // margini del dialog su schermi piccoli
      child: ConstrainedBox(
        // Impostiamo una larghezza massima di 600 px,
        // e lasciamo che si riduca se lo schermo è più stretto
        constraints: const BoxConstraints(
          maxWidth: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // l'altezza si adatta al contenuto
          children: [
            // Titolo in alto
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                localizations.select_contexts_and_model,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Corpo principale scrollabile
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra di ricerca
                    TextField(
                      controller: _searchController,
                      onChanged: _filterContexts,
                      decoration: InputDecoration(
                        hintText: localizations.search_contexts,
                        prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black), // Bordi neri
                  ),
    enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black), // Bordi neri per lo stato normale
    ),
    focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Bordi neri più spessi per lo stato attivo
    ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Riquadro con lista contesti
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.black12,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      height: 220, // Altezza fissa per la lista
                      child: ListView.builder(
                        itemCount: _filteredContexts.length,
                        itemBuilder: (context, index) {
                          final ctx = _filteredContexts[index];
                          final isSelected =
                              _selectedContexts.contains(ctx.path);
                          return CheckboxListTile(
                            title: Text(
                              ctx.path,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  _selectedContexts.add(ctx.path);
                                } else {
                                  _selectedContexts.remove(ctx.path);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                            checkColor: Colors.white,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Scelta modello (chip)
                    _buildModelSelector(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Pulsanti in basso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Pulsante "Annulla x"
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(localizations.cancel),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Pulsante "Conferma >"
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _handleConfirm,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          localizations.confirm,
                          style: TextStyle(color: Colors.white),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    final List<String> models = ['gpt-4o', 'gpt-4o-mini'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: models.map((model) {
        final bool selected = (_selectedModel == model);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedModel = model;
                });
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color:Colors.grey[200], // Sfondo sempre bianco
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey[200]!,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // L'immagine viene mostrata senza effetto di tinting
                    ClipOval(
                      child: Image.network(
                        'https://static.wixstatic.com/media/63b1fb_48896f0cf8684eb7805d2b5a980e2d19~mv2.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      model,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
