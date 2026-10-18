import 'package:flutter/widgets.dart';

/// Préfixe des noms de route posés par `DonyBottomSheet.show(analyticsName:)`.
const kAnalyticsSheetRoutePrefix = '/sheet/';

/// Routes suivies par `PosthogObserver` (`$screen`).
///
/// Le filtre par défaut du SDK ne garde que les [PageRoute] : aucune feuille
/// du bas n'apparaissait dans PostHog, ni la feuille de paiement, ni
/// l'acceptation d'offre. On garde les pages, et seulement les feuilles
/// explicitement nommées `/sheet/…` : un dialogue ou une feuille tierce,
/// nommée ou non, reste hors du suivi.
bool posthogRouteFilter(Route<dynamic>? route) {
  if (route is PageRoute) return true;
  if (route is! PopupRoute) return false;
  return route.settings.name?.startsWith(kAnalyticsSheetRoutePrefix) ?? false;
}
