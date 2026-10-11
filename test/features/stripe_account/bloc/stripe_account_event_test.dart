// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StripeAccountStatusRefreshed : rafraîchissement silencieux par '
      'défaut, progression sur demande', () {
    expect(StripeAccountStatusRefreshed().showProgress, isFalse);
    expect(
      StripeAccountStatusRefreshed(showProgress: true).showProgress,
      isTrue,
    );
  });

  test('StripeAccountEvent : trois événements distincts', () {
    final events = <StripeAccountEvent>[
      StripeAccountStatusLoaded(),
      StripeAccountStatusRefreshed(),
      StripeAccountReset(),
    ];
    expect(events.map((e) => e.runtimeType).toSet(), hasLength(3));
  });
}
