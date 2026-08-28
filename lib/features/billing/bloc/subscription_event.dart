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

/// Vrai quand l'action portée par [subscription] mène réellement quelque part,
/// et peut donc être proposée.
///
/// Le critère n'est pas « filtrer partout sur la source », il dépend de la
/// destination :
///
///  - une action qui mène à la page de **vente** est toujours légitime, cette
///    page étant publique ;
///  - une action qui mène à la **gestion** exige une source Stripe. Sans
///    abonnement Stripe il n'y a pas d'espace de gestion, et le serveur
///    n'expose délibérément aucun identifiant qui permettrait d'en juger
///    autrement.
///
/// Vit ici pour que les deux hôtes du bandeau (écran Profil et écran PRO)
/// tranchent identiquement. Sans ce partage, un impayé de source inconnue se
/// voyait offrir « Régler » sur un hôte tandis que « Gérer mon abonnement »
/// lui était masqué sur l'autre — deux règles opposées pour la même page de
/// destination.
bool proPortalActionIsLegitimate(ProSubscriptionModel subscription) =>
    proPortalTargetFor(subscription.status) == ProPortalTarget.upgrade ||
    proPortalManageIsLegitimate(subscription);

/// Vrai quand un espace de gestion existe pour [subscription], c'est-à-dire
/// quand l'abonnement vient de Stripe.
///
/// Seule porte d'entrée de cette décision : tout appelant qui réécrirait
/// `source == stripe` à la main recréerait la divergence que
/// [proPortalActionIsLegitimate] existe pour supprimer.
bool proPortalManageIsLegitimate(ProSubscriptionModel subscription) =>
    subscription.source == ProSubscriptionSource.stripe;

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
