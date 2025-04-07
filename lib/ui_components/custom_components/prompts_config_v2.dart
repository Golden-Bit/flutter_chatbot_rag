// prompts_config.dart

import 'package:flutter/material.dart';

// Struttura di esempio per categorie, icone e prompt
final List<Map<String, dynamic>> promptsData = [
  {
    "categoryName": "Rating",
    "icon": Icons.radar_outlined, // icona es. lampadina
    "examples": [
      "Calcola il rating della mia azienda",
      "Calcola il rating ESG della mia azienda",
      "Confronta il rating della mia azienda con il rating medio di settore"
    ]
  },
  {
    "categoryName": "Anaisi",
    "icon": Icons.show_chart, // icona es. saetta
    "examples": [
      "Vorrei un’analisi macroeconomica dettagliata per il mercato USA",
      "Migliori asset per operazioni Long in questo scenario macroeconomico",
      "Analisi techina Apple e opportunità operative"
    ]
  },
  {
    "categoryName": "Aggiornamenti",
    "icon": Icons.newspaper, // icona es. avvertimento
    "examples": [
      "Aggiornamenti recenti sul mercato finanziario USA",
      "Ultime notizie economiche globali",
      "Aggiornamenti sui tassi d'interesse e sulla politica monetaria"
    ]
  },
];
