// lib/services/lang_auto.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// NEW: rilevamento lingua offline compatibile Web
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;

class LangAuto {
  /// Inizializzazione lazy dei profili di language detection.
  static bool _inited = false;
  static Future<void> _ensureInit() async {
    if (_inited) return;
    try {
      await langdetect.initLangDetect(); // carica i profili inclusi nel package
    } finally {
      _inited = true; // evita retry multipli
    }
  }

  /// Rileva il codice lingua (es. "it", "en") dal testo (compatibile Web).
  static Future<String?> detectLangCode(String text) async {
    final t = text.trim();
    if (t.isEmpty) return null;

    await _ensureInit();

    try {
      // Restituisce codici tipo 'it', 'en', 'pt-BR', 'zh-cn' a seconda del modello.
      final codeRaw = langdetect.detect(t);
      if (codeRaw == null || codeRaw.toString().isEmpty) return null;

      var code = codeRaw.toString().toLowerCase();

      // Normalizzazioni comuni per TTS:
      // - tieni solo il language base quando non serve la regione
      // - compatta varianti in un base code gestibile dalla mappa TTS
      if (code.startsWith('pt')) code = 'pt'; // pt, pt-br -> 'pt'
      if (code.startsWith('zh')) code = 'zh'; // zh-cn/zh-tw -> 'zh'
      if (code.contains('-')) code = code.split('-').first;

      // Alcuni modelli possono restituire 'unknown' o simili: scarta
      if (code.length < 2 || code == 'und' || code == 'unknown') return null;
      return code;
    } catch (_) {
      // In caso di eccezione, lascia che il TTS usi la lingua di default
      return null;
    }
  }

  /// Mappa "it" -> "it-IT", "en" -> "en-US", ecc. (fallback generico).
  static String _preferredLocaleFor(String langCode) {
    const map = {
      'en': 'en-US',
      'it': 'it-IT',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'pt': 'pt-PT',
      'pt-br': 'pt-BR',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'ru': 'ru-RU',
      'ar': 'ar-SA',
      'hi': 'hi-IN',
      'tr': 'tr-TR',
      'nl': 'nl-NL',
      'pl': 'pl-PL',
      'sv': 'sv-SE',
      'no': 'no-NO',
      'da': 'da-DK',
      'fi': 'fi-FI',
      'el': 'el-GR',
      'cs': 'cs-CZ',
      'he': 'he-IL',
      'uk': 'uk-UA',
      'vi': 'vi-VN',
      'id': 'id-ID',
      'th': 'th-TH',
      'ro': 'ro-RO',
      'hu': 'hu-HU',
      'bg': 'bg-BG',
    };
    final k = langCode.toLowerCase();
    return map[k] ?? '$langCode-${langCode.toUpperCase()}';
  }

  /// Sceglie la locale migliore disponibile per **TTS** dato un langCode.
  static Future<String?> pickBestTtsLocale(
    FlutterTts tts,
    String langCode,
  ) async {
    final langs = await tts.getLanguages; // es. ['en-US','it-IT',...]
    if (langs is! List) return null;

    final preferred = _preferredLocaleFor(langCode);
    if (langs.contains(preferred)) return preferred;

    try {
      return (langs.cast<String>())
          .firstWhere((l) => l.toLowerCase().startsWith('${langCode.toLowerCase()}-'));
    } catch (_) {
      return null;
    }
  }

  /// Sceglie la voce più adatta per la locale TTS (se disponibile).
  static Future<Map<String, String>?> pickBestTtsVoice(
    FlutterTts tts,
    String locale,
  ) async {
    final voices = await tts.getVoices;
    if (voices is! List) return null;

    // 1) voce con locale esatto
    try {
      final v = voices.cast<Map>().firstWhere(
        (v) => (v['locale'] as String?)?.toLowerCase() == locale.toLowerCase(),
      );
      return v.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}

    // 2) voce che inizia per 'xx-'
    try {
      final langCode = locale.split('-').first.toLowerCase();
      final v = voices.cast<Map>().firstWhere(
        (v) => (v['locale'] as String?)?.toLowerCase().startsWith('$langCode-') ?? false,
      );
      return v.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}

    return null;
  }

  /// Sceglie la locale migliore per **STT** tra quelle supportate dal device.
  static Future<String?> pickBestSttLocale(
    stt.SpeechToText speech,
    String langCode,
  ) async {
    final locales = await speech.locales(); // List<LocaleName>
    final preferred = _preferredLocaleFor(langCode).toLowerCase();

    // match perfetto 'xx-YY'
    final exact = locales.firstWhere(
      (l) => l.localeId.toLowerCase() == preferred,
      orElse: () => stt.LocaleName('', ''),
    );
    if (exact.localeId.isNotEmpty) return exact.localeId;

    // match che inizia per 'xx-'
    final starts = locales.firstWhere(
      (l) => l.localeId.toLowerCase().startsWith('${langCode.toLowerCase()}-'),
      orElse: () => stt.LocaleName('', ''),
    );
    if (starts.localeId.isNotEmpty) return starts.localeId;

    return null;
  }
}
