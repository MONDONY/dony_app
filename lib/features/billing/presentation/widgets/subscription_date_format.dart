import 'package:dony/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// Formate une date dans la langue de l'app, ex. « 24 décembre 2026 ».
///
/// `intl` est déjà une dépendance directe du projet (voir
/// `lib/features/matching/presentation/widgets/trip_card.dart`) et
/// initialisée pour toutes les locales au démarrage (`main.dart`) : on
/// réutilise ce même utilitaire plutôt que d'ajouter une troisième liste de
/// noms de mois écrite à la main dans le dépôt.
///
/// Partagée par [SubscriptionStatusBanner] et [SubscriptionStatusCard] pour
/// que les deux widgets affichent une même date exactement de la même façon.
String formatSubscriptionDate(DateTime local) =>
    DateFormat('d MMMM yyyy', AppL10n.localeName).format(local);
