import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:mocktail/mocktail.dart';

/// Doublures partagées par les tests qui montent un widget lisant la
/// couverture Stripe du pays.
///
/// `StripeAccountBloc` est fourni à l'échelle de l'application dans
/// `app.dart` : tout harnais qui monte un de ces widgets sans le fournir
/// échoue en `ProviderNotFoundException`. Elles vivent ici plutôt que
/// recopiées dans chaque fichier parce que le nombre d'écrans concernés ne
/// fait que croître.

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

/// Prépare un [StripeAccountBloc] mocké posé sur [state].
///
/// `stream` est stubé à la main plutôt que via `whenListen` : ce dernier
/// enveloppe la source dans un `asBroadcastStream()` consommé dès l'appel,
/// laissant un flux clos aux abonnés tardifs.
MockStripeAccountBloc stubStripeAccountBloc({
  StripeAccountState state = const StripeAccountReady(
    ConnectAccountStatus(status: 'NOT_CREATED'),
  ),
}) {
  final bloc = MockStripeAccountBloc();
  when(() => bloc.state).thenReturn(state);
  when(() => bloc.stream).thenAnswer((_) => Stream.value(bloc.state));
  return bloc;
}

/// Statut chargé dans un pays où Stripe n'ouvre pas de compte connecté :
/// zones XOF et XAF, États-Unis, Canada.
const stripeCountryUnavailableState = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED', connectAvailableInCountry: false),
);
