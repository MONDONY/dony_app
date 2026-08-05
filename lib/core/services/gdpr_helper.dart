import 'dart:ui';

import 'package:dony/core/storage/hive_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

/// Action à effectuer pour le consentement analytics d'un utilisateur, une
/// fois son pays connu (cf. [GdprHelper.requiresConsent]).
enum AnalyticsConsentAction {
  /// Rien à faire : service pas configuré, ou consentement déjà répondu.
  none,

  /// Zone RGPD (ou pays indéterminé) sans réponse → demander explicitement
  /// via l'écran de consentement.
  askConsent,

  /// Zone hors RGPD sans réponse → consentement accordé automatiquement,
  /// aucune confirmation utilisateur requise hors UE/EEE/UK/Suisse.
  autoGrantNonGdpr,
}

/// Détermine si le pays de l'utilisateur est soumis au RGPD
/// (UE + EEE + Royaume-Uni + Suisse).
///
/// **Ordre de priorité pour le pays détecté :**
/// 1. Code pays stocké dans Hive via GPS (mis à jour à chaque connexion
///    si la permission est accordée) — le plus précis.
/// 2. Locale du device (langue/région système) — fallback sans GPS.
/// 3. Inconnu → `true` par défaut (approche conservative).
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
    // Suisse (nFADP, exigences similaires au RGPD)
    'CH',
  };

  /// `true` si le pays de l'utilisateur exige un consentement explicite.
  ///
  /// [countryCode] : code pays à forcer (utilisé en test).
  /// [prefs] : box Hive contenant le pays détecté par GPS.
  ///   Si absent, utilise uniquement la locale du device.
  static bool requiresConsent({String? countryCode, Box? prefs}) {
    final storedCode = prefs?.get(HiveService.kDetectedCountryCode) as String?;
    final code =
        (countryCode ??
                storedCode ??
                PlatformDispatcher.instance.locale.countryCode ??
                '')
            .toUpperCase();
    if (code.isEmpty) return true;
    return _gdprCountries.contains(code);
  }

  /// Détermine l'action de consentement à effectuer au login.
  ///
  /// Pure : ne dépend d'aucun GPS/Firebase, [requiresConsent] doit déjà avoir
  /// été évalué en amont (GPS si dispo, sinon locale device).
  static AnalyticsConsentAction resolveConsentAction({
    required bool isConfigured,
    required bool hasAnswered,
    required bool requiresConsent,
  }) {
    if (!isConfigured || hasAnswered) return AnalyticsConsentAction.none;
    return requiresConsent
        ? AnalyticsConsentAction.askConsent
        : AnalyticsConsentAction.autoGrantNonGdpr;
  }

  /// Détermine le pays à partir d'une position GPS et le stocke dans Hive.
  ///
  /// Appelé à chaque ouverture de l'app si la permission de localisation
  /// est déjà accordée. Échoue silencieusement si le géocodage inverse
  /// est indisponible (pas de réseau, service iOS/Android down).
  static Future<void> updateFromPosition(Position position, Box prefs) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final countryCode = placemarks.firstOrNull?.isoCountryCode;
      if (countryCode != null && countryCode.isNotEmpty) {
        await prefs.put(
          HiveService.kDetectedCountryCode,
          countryCode.toUpperCase(),
        );
      }
    } catch (_) {
      // Géocodage non-fatal : on garde le pays précédemment stocké ou la locale.
    }
  }
}
