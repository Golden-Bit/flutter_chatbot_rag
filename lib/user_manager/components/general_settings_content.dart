import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class GeneralSettingsContent extends StatefulWidget {
  const GeneralSettingsContent({
    Key? key,
    required this.onArchiveAll,
    required this.onDeleteAll,
  }) : super(key: key);

  /// Callback che archivia **tutte** le chat presenti in `chats`
  final Future<void> Function() onArchiveAll;

  /// Callback che elimina **tutte** le chat presenti in `chats`
  final Future<void> Function() onDeleteAll;

  @override
  _GeneralSettingsContentState createState() => _GeneralSettingsContentState();
}

class _GeneralSettingsContentState extends State<GeneralSettingsContent> {
  // —————————————————— STATO COMMENTATO (TEMA / TOGGLE / LINGUA) ——————————————————
  //
  // Tutte le seguenti variabili di stato sono state commentate
  // per rendere non visibili:
  // 1) Il selettore di TEMA
  // 2) I due TOGGLE
  // 3) La selezione LINGUA con RILEVAMENTO AUTOMATICO

  // String _theme = 'Sistema';
  // bool _showCode = true;
  // bool _showFollowUp = true;
  // String _language = 'Rilevamento automatico';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ——————————————————— Tema (COMMENTATO, NON VISIBILE) ———————————————————
          // _buildLabel('Tema'),
          // _buildDropdown(
          //   value: _theme,
          //   items: ['Chiaro', 'Scuro', 'Sistema'],
          //   onChanged: (v) => setState(() => _theme = v!),
          // ),
          // const SizedBox(height: 24),

          // ——————————————————— Switch vari (COMMENTATI, NON VISIBILI) ———————————————————
          // _buildSwitchRow(
          //   'Mostra sempre il codice quando usi lo strumento di analisi dei dati',
          //   _showCode,
          //   (v) => setState(() => _showCode = v),
          // ),
          // const SizedBox(height: 12),
          // _buildSwitchRow(
          //   'Mostra i suggerimenti di follow-up nelle chat',
          //   _showFollowUp,
          //   (v) => setState(() => _showFollowUp = v),
          // ),
          // const SizedBox(height: 24),

          // ——————————————————— Lingua (COMMENTATA, NON VISIBILE) ———————————————————
          // _buildLabel('Lingua'),
          // _buildDropdown(
          //   value: _language,
          //   items: [
          //     'Italiano',
          //     'Inglese (US)',
          //     'Inglese (UK)',
          //     'Rilevamento automatico'
          //   ],
          //   onChanged: (v) => setState(() => _language = v!),
          // ),
          // const SizedBox(height: 24),

          // ——————————————————— Gestione archivio ———————————————————
          _buildActionRow(
            'Chat archiviate',
            'Gestisci',
            onPressed: () {
              // TODO: logica gestione archivio
            },
          ),
          const SizedBox(height: 16),

          // ———————————————— ARCHIVIA TUTTO ————————————————
          _buildActionRow(
            'Archivia tutte le chat',
            'Archivia tutto',
            onPressed: () async {
              await widget.onArchiveAll();
              if (mounted) Navigator.pop(context); // chiude il dialog
            },
          ),
          const SizedBox(height: 16),

          // ———————————————— ELIMINA TUTTO ————————————————
          Row(
            children: [
              Expanded(
                child: Text(
                  'Elimina tutte le chat',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () async {
                  final confirmed = await _confirmDeleteAll(context);
                  if (confirmed) {
                    await widget.onDeleteAll();
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Elimina tutto'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ——————————————————————————— Helpers UI ———————————————————————————
  Widget _buildLabel(String text) =>
      Text(text, style: const TextStyle(color: Colors.black54, fontSize: 14));

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            value: value,
            items: items
                .map((item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ))
                .toList(),
            onChanged: onChanged,
            buttonStyleData: const ButtonStyleData(
              padding: EdgeInsets.zero,
              height: 48,
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildActionRow(
    String label,
    String buttonText, {
    required VoidCallback onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      ],
    );
  }

  // ———————————————————— Dialog di conferma eliminazione ————————————————————
  Future<bool> _confirmDeleteAll(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Conferma eliminazione'),
            content: const Text(
                'Sei sicuro di voler eliminare definitivamente tutte le chat? '
                'Questa azione non può essere annullata.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
