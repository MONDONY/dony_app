import 'package:dony/core/di/injection.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';

/// Consomme la pastille « nouveau » d'un abonnement quand la notification qui
/// l'annonce est ouverte.
///
/// Sans cet appel, `has_new` ne retombait qu'à l'ouverture du hub du voyageur :
/// ouvrir la notification menait au détail de l'annonce, donc l'utilisateur
/// avait lu le trajet et le retrouvait quand même marqué comme nouveau dans
/// « Mes abonnements ».
///
/// Silencieux par construction : c'est un effet de bord d'affichage, il ne doit
/// jamais empêcher la navigation ni remonter une erreur à l'utilisateur.
Future<void> consumeSubscriptionBadge(
  String? type,
  Map<String, dynamic> data,
) async {
  if (type != 'TRAVELER_NEW_ANNOUNCEMENT') return;
  final travelerId = data['travelerId'];
  if (travelerId is! String || travelerId.isEmpty) return;
  if (!getIt.isRegistered<SubscriptionsRepository>()) return;
  try {
    await getIt<SubscriptionsRepository>().markSeen(travelerId);
  } catch (_) {
    // Pastille non consommée : elle le sera à l'ouverture du profil.
  }
}
