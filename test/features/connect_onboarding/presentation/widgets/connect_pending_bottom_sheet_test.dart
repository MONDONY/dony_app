import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/connect_onboarding/presentation/widgets/connect_pending_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockConnectOnboardingBloc
    extends MockBloc<ConnectOnboardingEvent, ConnectOnboardingState>
    implements ConnectOnboardingBloc {}

void main() {
  late MockConnectOnboardingBloc mockBloc;

  setUp(() {
    mockBloc = MockConnectOnboardingBloc();
    when(
      () => mockBloc.state,
    ).thenReturn(const ConnectOnboardingNeedsOnboarding());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget buildWidget() => MaterialApp(
    home: BlocProvider<ConnectOnboardingBloc>.value(
      value: mockBloc,
      child: const Scaffold(body: ConnectPendingBottomSheet()),
    ),
  );

  testWidgets('affiche le titre et la description', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.text('En attente de Stripe'), findsOneWidget);
    expect(
      find.text(
        'Revenez ici après avoir complété le formulaire Stripe dans votre navigateur.',
      ),
      findsOneWidget,
    );

    // Draine les timers flutter_animate de la mascotte avant la fin du test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('en anglais : titre et description traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(buildWidget());
    expect(find.text('Waiting for Stripe'), findsOneWidget);
    expect(
      find.text(
        'Come back here after completing the Stripe form in your browser.',
      ),
      findsOneWidget,
    );

    // Draine les timers flutter_animate de la mascotte avant la fin du test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
