import 'package:flutter/material.dart';

class HoverableNewChatButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const HoverableNewChatButton({
    Key? key,
    required this.onPressed,
    this.label = 'Nuova Chat',
  }) : super(key: key);

  @override
  _HoverableNewChatButtonState createState() => _HoverableNewChatButtonState();
}

class _HoverableNewChatButtonState extends State<HoverableNewChatButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isHovered ? Colors.white : Colors.blue;
    final textColor = _isHovered ? Colors.blue : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: double.infinity, // Occupa l'intera larghezza
          margin: const EdgeInsets.all(4.0),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: Colors.blue,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Centra icona + testo
            children: [
              Icon(
                Icons.add,
                color: textColor,
              ),
              const SizedBox(width: 8.0),
              Text(
                widget.label,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
