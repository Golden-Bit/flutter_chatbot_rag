import 'package:flutter/material.dart';

dynamic largeFullLogo = Image.network(
  'https://static.wixstatic.com/media/63b1fb_3e1530fd4a2e479983c1b3cd9f379290~mv2.png',
  //'',//'https://static-00.iconduck.com/assets.00/openai-icon-2021x2048-4rpe5x7n.png',
  height: 100,
);

dynamic fullLogo = // Titolo a sinistra
    Image.network(
  'https://static.wixstatic.com/media/63b1fb_3e1530fd4a2e479983c1b3cd9f379290~mv2.png',
  //'', //'https://static-00.iconduck.com/assets.00/openai-icon-2021x2048-4rpe5x7n.png',
  height: 42, // Imposta l'altezza desiderata per il logo
  fit: BoxFit.contain,
  isAntiAlias: true,
);

dynamic smallFullLogo = // Titolo a sinistra
    Image.network(
  'https://static.wixstatic.com/media/63b1fb_3e1530fd4a2e479983c1b3cd9f379290~mv2.png',
  // '', // 'https://static-00.iconduck.com/assets.00/openai-icon-2021x2048-4rpe5x7n.png',
  height: 32, // Imposta l'altezza desiderata per il logo
  fit: BoxFit.contain,
  isAntiAlias: true,
);

dynamic assistantAvatar = CircleAvatar(
  backgroundColor: Colors.transparent,
  child: Image.network(
    //'https://static.wixstatic.com/media/63b1fb_396f7f30ead14addb9ef5709847b1c17~mv2.png',
    'https://i.imgur.com/thZjAGJ.png' ,//'https://static-00.iconduck.com/assets.00/openai-icon-2021x2048-4rpe5x7n.png',
    height: 42,
    fit: BoxFit.contain,
    isAntiAlias: true,
  ),
);

//String assistantName = "boxed-ai";
String assistantName = "assistant";
