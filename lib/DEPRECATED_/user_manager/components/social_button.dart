// file: social_button.dart

import 'package:flutter/material.dart';

/// Enum (facoltativo) per i vari provider di login
enum SocialProvider {
  google,
  microsoft,
  apple,
  phone,
}

/// Widget riutilizzabile per un pulsante social.
/// Seleziona automaticamente l'icona e il testo in base al provider.
///
/// Adesso l'icona e il testo sono allineati a SINISTRA.
class SocialButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback onTap;

  const SocialButton({
    Key? key,
    required this.provider,
    required this.onTap,
  }) : super(key: key);

  /// Mappa dei loghi (URL, asset locali, o network image) associati ai provider.
  static const Map<SocialProvider, String> _logoUrls = {
    SocialProvider.google:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
    SocialProvider.microsoft:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Microsoft_logo.svg/2048px-Microsoft_logo.svg.png',
    SocialProvider.apple:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Apple_logo_black.svg/625px-Apple_logo_black.svg.png',
    SocialProvider.phone: 'assets/phone_icon.png', // Se preferisci un asset locale
  };

  /// Mappa dei label (testi) associati ai provider.
  static const Map<SocialProvider, String> _labels = {
    SocialProvider.google: 'Continua con Google',
    SocialProvider.microsoft: 'Continua con l’account Microsoft',
    SocialProvider.apple: 'Continua con Apple',
    SocialProvider.phone: 'Continua con il telefono',
  };

  @override
  Widget build(BuildContext context) {
    final logoUrl = _logoUrls[provider]!;
    final label = _labels[provider]!;

    // Se l'icona è un asset locale "phone_icon.png", useremo Image.asset.
    // Altrimenti, se è un link (Google/Microsoft/Apple), usiamo Image.network.
    final bool isLocalAsset = provider == SocialProvider.phone;

    // Icona (asset o network) lasciata
    Widget iconWidget = isLocalAsset
        ? Image.asset(
            logoUrl,
            width: 24,
            height: 24,
          )
        : Image.network(
            logoUrl,
            width: 24,
            height: 24,
          );

    // Creiamo un pulsante con Row -> allineamento a sinistra
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            iconWidget,
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
