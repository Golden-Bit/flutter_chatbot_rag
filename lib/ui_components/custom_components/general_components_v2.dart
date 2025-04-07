import 'package:flutter/material.dart';

dynamic largeFullLogo = Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center, // Allinea in alto
  children: [
    Image.network(
      'https://static.wixstatic.com/media/63b1fb_9cfc0e4bc4dc4fc6a6fd1e374540712b~mv2.png',
      height: 100, // Imposta l'altezza desiderata per il logo
      fit: BoxFit.contain,
      isAntiAlias: true,
    ),
    const SizedBox(width: 8.0), // Spazio tra il testo e l'immagine
    RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 50, // Regola la dimensione del testo a piacere
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: 'stock',
            style: TextStyle(color: Colors.green),
          ),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: const Color.fromARGB(255, 0, 84, 153)),
          ),
        ],
      ),
    ),
  ],
);

dynamic fullLogo = // Titolo a sinistra
    Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center, // Allinea in alto
  children: [
        Image.network(
      'https://static.wixstatic.com/media/63b1fb_595ba1e1dfae4072b8f901bf2adcea92~mv2.jpg',
      height: 42, // Imposta l'altezza desiderata per il logo
      fit: BoxFit.contain,
      isAntiAlias: true,
    ),
        const SizedBox(width: 8.0), // Spazio tra il testo e l'immagine
    RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 20, // Regola la dimensione del testo a piacere
          fontWeight: FontWeight.bold,
        ),
        children: [
          TextSpan(
            text: 'stock',
            style: TextStyle(color: Colors.green),
          ),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: const Color.fromARGB(255, 0, 84, 153)),
          ),
        ],
      ),
    ),

  ],
);

dynamic assistantAvatar = CircleAvatar(
  backgroundColor: Colors.transparent,
  child: Image.network(
    'https://static.wixstatic.com/media/63b1fb_595ba1e1dfae4072b8f901bf2adcea92~mv2.jpg',
    height: 42,
    fit: BoxFit.contain,
    isAntiAlias: true,
  ),
);

String assistantName = "stock-ai";
