part of 'subscription_bloc.dart';

/// Les deux pages du portail web externe où l'abonnement PRO se vend et se
/// gère. Une inversion des deux enverrait un prospect sur une page de
/// gestion vide et un abonné sur une page de vente.
enum ProPortalTarget { upgrade, manage }

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
