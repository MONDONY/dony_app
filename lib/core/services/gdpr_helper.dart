import 'dart:ui';

/// Détermine si le pays détecté sur l'appareil est soumis au RGPD
/// (UE + EEE + Royaume-Uni + Suisse).
///
/// Utilisé pour décider si l'écran de consentement analytics doit
/// être affiché. Pour les pays hors périmètre RGPD (ex: Sénégal,
/// Côte d'Ivoire, Mali, Cameroun), le consentement est accordé
/// automatiquement sans interaction utilisateur.
abstract final class GdprHelper {
  static const _gdprCountries = {
    // États membres de l'UE
    'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI',
    'FR', 'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT',
    'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK',
    // EEE hors UE
    'IS', 'LI', 'NO',
    // Royaume-Uni (UK GDPR)
    'GB',
    // Suisse (nFADP, exigences similaires)
    'CH',
  };

  /// Retourne `true` si le pays du device exige un consentement RGPD explicite.
  ///
  /// [countryCode] permet d'injecter un code pays en test sans mocker
  /// [PlatformDispatcher]. En production, laisser `null` pour utiliser
  /// la locale du device.
  ///
  /// Par défaut `true` si le code pays est indisponible (approche conservative).
  static bool requiresConsent({String? countryCode}) {
    final code = (countryCode ??
            PlatformDispatcher.instance.locale.countryCode ??
            '')
        .toUpperCase();
    if (code.isEmpty) return true;
    return _gdprCountries.contains(code);
  }
}
