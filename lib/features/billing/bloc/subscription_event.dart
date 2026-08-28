part of 'subscription_bloc.dart';

/// Les deux pages du portail web externe où l'abonnement PRO se vend et se
/// gère. Une inversion des deux enverrait un prospect sur une page de
/// gestion vide et un abonné sur une page de vente.
enum ProPortalTarget { upgrade, manage }

/// La page du portail vers laquelle mène l'action portée par un abonnement
/// dans l'état [status].
///
/// Seule une grâce historique (jamais payé, donc rien à gérer) doit atteindre
/// la page de vente. Tous les autres statuts porteurs d'une action (impayé à
/// régulariser, abonnement actif dont on gère la résiliation) mènent à la
/// gestion du moyen de paiement.
///
/// Vit ici, à côté de l'énumération qu'elle produit, parce que plusieurs
/// écrans montent le même bandeau et doivent tous trancher de la même façon.
ProPortalTarget proPortalTargetFor(ProSubscriptionStatus status) =>
    status == ProSubscriptionStatus.legacyGrace
    ? ProPortalTarget.upgrade
    : ProPortalTarget.manage;

sealed class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionRequested extends SubscriptionEvent {
  const SubscriptionRequested();
}

class ProPortalOpenRequested extends SubscriptionEvent {
  const ProPortalOpenRequested(this.target);

  final ProPortalTarget target;

  @override
  List<Object?> get props => [target];
}
