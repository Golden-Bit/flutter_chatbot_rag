import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ChatSettingsPage extends StatefulWidget {
  final Function(Color) onUserMessageColorChanged;
  final Function(double) onUserMessageOpacityChanged;
  final Function(Color) onAssistantMessageColorChanged;
  final Function(double) onAssistantMessageOpacityChanged;
  final Function(Color) onChatBackgroundColorChanged;
  final Function(double) onChatBackgroundOpacityChanged;

  ChatSettingsPage({
    required this.onUserMessageColorChanged,
    required this.onUserMessageOpacityChanged,
    required this.onAssistantMessageColorChanged,
    required this.onAssistantMessageOpacityChanged,
    required this.onChatBackgroundColorChanged,
    required this.onChatBackgroundOpacityChanged,
  });

  @override
  _ChatSettingsPageState createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  Color _userMessageColor = Colors.blue[100]!;
  double _userMessageOpacity = 1.0;
  Color _assistantMessageColor = Colors.grey[200]!;
  double _assistantMessageOpacity = 1.0;
  Color _chatBackgroundColor = Colors.white;
  double _chatBackgroundOpacity = 1.0;

  // Funzione per aprire il color picker
  void _showColorPickerDialog(Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Seleziona il colore'),
           backgroundColor: Colors.white, // Sfondo del popup
      elevation: 6, // Intensità dell'ombra
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4), // Arrotondamento degli angoli
        //side: BorderSide(
        //  color: Colors.blue, // Colore del bordo
        //  width: 2, // Spessore del bordo
        //),
      ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                setState(() {
                  onColorChanged(color); // Aggiorna il colore selezionato
                });
              },
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            ElevatedButton(
              child: Text('Chiudi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
                                      color: Colors.white, // Imposta lo sfondo bianco
                                                          elevation: 6, // Intensità dell'ombra (0 = nessuna ombra)
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(4), // Angoli arrotondati
    //side: BorderSide(
    //  color: Colors.grey, // Colore dei bordi
    //  width: 0, // Spessore dei bordi
    //),
  ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impostazioni Chat',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Personalizzazione Grafica',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildColorOption(
              label: 'Colore Messaggi Utente',
              currentColor: _userMessageColor,
              onColorChanged: (color) {
                widget.onUserMessageColorChanged(color);
              },
            ),
            _buildOpacitySlider(
              label: 'Opacità Messaggi Utente',
              currentOpacity: _userMessageOpacity,
              onOpacityChanged: (value) {
                widget.onUserMessageOpacityChanged(value);
              },
            ),
            _buildColorOption(
              label: 'Colore Messaggi Assistente',
              currentColor: _assistantMessageColor,
              onColorChanged: (color) {
                widget.onAssistantMessageColorChanged(color);
              },
            ),
            _buildOpacitySlider(
              label: 'Opacità Messaggi Assistente',
              currentOpacity: _assistantMessageOpacity,
              onOpacityChanged: (value) {
                widget.onAssistantMessageOpacityChanged(value);
              },
            ),
            _buildColorOption(
              label: 'Colore Sfondo Chat',
              currentColor: _chatBackgroundColor,
              onColorChanged: (color) {
                widget.onChatBackgroundColorChanged(color);
              },
            ),
            _buildOpacitySlider(
              label: 'Opacità Sfondo Chat',
              currentOpacity: _chatBackgroundOpacity,
              onOpacityChanged: (value) {
                widget.onChatBackgroundOpacityChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget per le opzioni di selezione del colore
  Widget _buildColorOption({
    required String label,
    required Color currentColor,
    required Function(Color) onColorChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14)),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: Icon(Icons.color_lens, color: currentColor),
            onPressed: () {
              _showColorPickerDialog(currentColor, onColorChanged);
            },
          ),
        ),
        Divider(),
      ],
    );
  }

  // Widget per le opzioni di selezione dell'opacità
  Widget _buildOpacitySlider({
    required String label,
    required double currentOpacity,
    required Function(double) onOpacityChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14)),
        Slider(
          value: currentOpacity,
          min: 0.0,
          max: 1.0,
          onChanged: (value) {
            setState(() {
              onOpacityChanged(value);
            });
          },
        ),
        Divider(),
      ],
    );
  }
}
