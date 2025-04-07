// prompts_config.dart

import 'package:flutter/material.dart';

// Struttura di esempio per categorie, icone e prompt
final List<Map<String, dynamic>> promptsData = [
  {
    "categoryName": "Esempi",
    "icon": Icons.lightbulb_outline, // icona es. lampadina
    "examples": [
      "Spiegami la relatività in modo semplice",
      "Idee creative per una festa di 10 anni",
      "Come faccio una chiamata HTTP in Dart?"
    ]
  },
  {
    "categoryName": "Capacità",
    "icon": Icons.bolt_outlined, // icona es. saetta
    "examples": [
      "Ricorda ciò che l’utente ha detto prima",
      "Permette correzioni su risposte precedenti",
      "È addestrato a gestire conversazioni complesse"
    ]
  },
  {
    "categoryName": "Limiti",
    "icon": Icons.warning_amber_outlined, // icona es. avvertimento
    "examples": [
      "Potrebbe generare informazioni non accurate",
      "Potrebbe fornire risposte distorte",
      "Conoscenza limitata a certi eventi/data"
    ]
  },
];
