part of 'subscription_bloc.dart';

sealed class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

class SubscriptionLoaded extends SubscriptionState {
  const SubscriptionLoaded(this.subscription);

  final ProSubscriptionModel subscription;

  @override
  List<Object?> get props => [subscription];
}

class SubscriptionError extends SubscriptionState {
  const SubscriptionError(this.error);

  final AppException error;

  @override
  List<Object?> get props => [error];
}

/// État **transitoire de signalement**, jamais un drapeau porté par
/// [SubscriptionLoaded].
///
/// Le widget l'écoute dans un `BlocListener` pour afficher un message
/// d'échec ; le `builder` continue de rendre l'état chargé qui suit
/// immédiatement. Si cet échec était un booléen sur [SubscriptionLoaded],
/// `Equatable` empêcherait une seconde notification identique de repartir,
/// et l'utilisateur qui retape le bouton après un premier échec ne verrait
/// plus aucun message.
class SubscriptionPortalLaunchFailed extends SubscriptionState {
  const SubscriptionPortalLaunchFailed(this.subscription);

  /// `null` quand l'ouverture du portail est demandée alors qu'aucun
  /// abonnement n'a encore été chargé (ex: vue non abonnée).
  final ProSubscriptionModel? subscription;

  @override
  List<Object?> get props => [subscription];
}
