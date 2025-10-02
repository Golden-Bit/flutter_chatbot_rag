// lib/services/lang_auto.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LangAuto {
  // Unico identificatore ML Kit riusato.
  static final LanguageIdentifier _id =
      LanguageIdentifier(confidenceThreshold: 0.5);

  /// Rileva il codice lingua (es. "it", "en") dal testo.
  static Future<String?> detectLangCode(String text) async {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      return await _id.identifyLanguage(t); // "und" se non certa
    } catch (_) {
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
      FlutterTts tts, String langCode) async {
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
      FlutterTts tts, String locale) async {
    final voices = await tts.getVoices;
    if (voices is! List) return null;

    // cerca prima voce con stessa locale
    try {
      final v = voices.cast<Map>().firstWhere(
        (v) => (v['locale'] as String?)?.toLowerCase() == locale.toLowerCase(),
      );
      return v.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}

    // altrimenti prima voce che inizia per "xx-"
    try {
      final langCode = locale.split('-').first.toLowerCase();
      final v = voices.cast<Map>().firstWhere(
        (v) => (v['locale'] as String?)
                ?.toLowerCase()
                .startsWith('$langCode-') ??
            false,
      );
      return v.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}

    return null;
  }

  /// Sceglie la locale migliore per **STT** tra quelle supportate dal device.
  static Future<String?> pickBestSttLocale(
      stt.SpeechToText speech, String langCode) async {
    final locales = await speech.locales(); // List<LocaleName>
    // match perfetto 'xx-YY'
    final preferred = _preferredLocaleFor(langCode).toLowerCase();
    final exact = locales.firstWhere(
      (l) => l.localeId.toLowerCase() == preferred,
      orElse: () => stt.LocaleName('',''),
    );
    if (exact.localeId.isNotEmpty) return exact.localeId;

    // match che inizia per 'xx-'
    final starts = locales.firstWhere(
      (l) => l.localeId.toLowerCase().startsWith('${langCode.toLowerCase()}-'),
      orElse: () => stt.LocaleName('',''),
    );
    if (starts.localeId.isNotEmpty) return starts.localeId;

    return null; // niente di meglio
  }
}
