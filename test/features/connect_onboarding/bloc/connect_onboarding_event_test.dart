// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConnectOnboardingEvent : quatre événements distincts du parcours', () {
    final events = <ConnectOnboardingEvent>[
      ConnectOnboardingStatusRequested(),
      ConnectOnboardingLinkRequested(),
      ConnectOnboardingPollingRequested(),
      ConnectOnboardingLaunchFailed(),
    ];
    expect(events.map((e) => e.runtimeType).toSet(), hasLength(4));
  });
}
