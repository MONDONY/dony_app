import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/payments/cash/presentation/screens/commission_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/commission_grid_test_doubles.dart';
import '../../../../../helpers/currency_test_doubles.dart';
import '../../../../../helpers/l10n_test_helpers.dart';

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

class _FakeCommissionMethodEvent extends Fake
    implements CommissionMethodEvent {}

const _fakeCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2028,
  expirationStatus: ExpirationStatus.valid,
);

const _expiredCard = CommissionMethod(
  brand: 'mastercard',
  last4: '0001',
  expMonth: 1,
  expYear: 2023,
  expirationStatus: ExpirationStatus.expired,
);

Widget _wrap(Widget child, CommissionMethodBloc bloc) => MaterialApp(
  home: BlocProvider<CommissionMethodBloc>.value(value: bloc, child: child),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCommissionMethodEvent());
  });

  late MockCommissionMethodBloc bloc;

  setUp(() {
    bloc = MockCommissionMethodBloc();
  });

  tearDown(() {
    bloc.close();
  });

  testWidgets('shows skeleton when CommissionMethodLoading', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoading()),
      initialState: CommissionMethodLoading(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    expect(find.byType(DonyDetailSkeleton), findsOneWidget);
  });

  testWidgets('shows empty state when CommissionMethodNotConfigured', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodNotConfigured()),
      initialState: CommissionMethodNotConfigured(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    // pumpAndSettle : laisse l'animation flutter_animate de la mascotte
    // (empty state) se terminer, sinon "A Timer is still pending" au teardown.
    await tester.pumpAndSettle();
    expect(find.text('Ajouter une carte'), findsOneWidget);
  });

  testWidgets('shows card preview and action buttons when Loaded', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
    expect(find.text('Remplacer la carte'), findsOneWidget);
    expect(find.text('Supprimer la carte'), findsOneWidget);
  });

  testWidgets('shows expiration banner when card is expired', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_expiredCard)),
      initialState: CommissionMethodLoaded(_expiredCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    expect(find.textContaining('expiré'), findsOneWidget);
  });

  testWidgets('setup event dispatched when add card tapped', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodNotConfigured()),
      initialState: CommissionMethodNotConfigured(),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une carte'));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupRequested>())),
    ).called(1);
  });

  testWidgets('replace card button dispatches SetupRequested', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Remplacer la carte'));
    verify(
      () => bloc.add(any(that: isA<CommissionMethodSetupRequested>())),
    ).called(1);
  });

  testWidgets('delete button shows confirmation sheet', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer'), findsWidgets);
  });

  testWidgets('confirm delete dispatches DeleteRequested', (tester) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    verify(
      () => bloc.add(any(that: isA<CommissionMethodDeleteRequested>())),
    ).called(1);
  });

  testWidgets('cancel delete closes sheet without dispatching event', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    await tester.tap(find.text('Supprimer la carte'));
    await tester.pumpAndSettle();
    expect(find.text('Annuler'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    verifyNever(
      () => bloc.add(any(that: isA<CommissionMethodDeleteRequested>())),
    );
  });

  testWidgets('dispatches LoadRequested when app resumes from background', (
    tester,
  ) async {
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();
    clearInteractions(bloc);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(
      () => bloc.add(any(that: isA<CommissionMethodLoadRequested>())),
    ).called(1);
  });

  testWidgets('en anglais : texte de débit sans taux (FLUTTER-R6)', (
    tester,
  ) async {
    useEnglish();
    setDonyCommissionRate(0.12);
    addTearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));
    whenListen(
      bloc,
      Stream.value(CommissionMethodLoaded(_fakeCard)),
      initialState: CommissionMethodLoaded(_fakeCard),
    );
    await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
    await tester.pump();

    expect(find.text('Service fee card'), findsOneWidget);
    expect(
      find.textContaining('charged the service fee (min.'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Replace card'), findsOneWidget);
    expect(find.text('Delete card'), findsOneWidget);
  });

  group('minimum du texte de débit', () {
    Future<void> pumpLoaded(WidgetTester tester) async {
      whenListen(
        bloc,
        Stream.value(CommissionMethodLoaded(_fakeCard)),
        initialState: CommissionMethodLoaded(_fakeCard),
      );
      await tester.pumpWidget(_wrap(const CommissionMethodScreen(), bloc));
      await tester.pump();
    }

    String debitNotice(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('Cette carte sera débitée'));

    testWidgets('sous grille, devise active XOF : « min. 650 F CFA »', (
      tester,
    ) async {
      useTestCommissionGrid();
      registerCurrencyPreference('XOF');
      await pumpLoaded(tester);

      expect(
        debitNotice(tester),
        'Cette carte sera débitée des frais de service '
        '(min. ${formatPriceIn(650, 'XOF')}) à chaque colis en espèces accepté.',
      );
      expect(debitNotice(tester), allOf(contains('650'), contains('CFA')));
    });

    testWidgets(
      'sous grille, EUR : minimum lu de la grille (« min. 1,20 € »)',
      (tester) async {
        useTestCommissionGrid(
          CommissionGrid(
            id: 'grid-min-120',
            effectiveFrom: DateTime.utc(2026, 10),
            tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
            minimums: const {'EUR': 1.20},
          ),
        );
        await pumpLoaded(tester);

        expect(
          debitNotice(tester),
          contains('(min. ${formatPriceIn(1.2, 'EUR')})'),
        );
        expect(debitNotice(tester), contains('1,20'));
      },
    );

    testWidgets('sans grille, EUR : texte actuel au minimum de 1 €', (
      tester,
    ) async {
      await pumpLoaded(tester);

      expect(
        debitNotice(tester),
        'Cette carte sera débitée des frais de service '
        '(min. ${formatPriceIn(1, 'EUR')}) à chaque colis en espèces accepté.',
      );
    });

    testWidgets('sans grille, XOF : texte actuel sans minimum', (tester) async {
      registerCurrencyPreference('XOF');
      await pumpLoaded(tester);

      expect(
        debitNotice(tester),
        'Cette carte sera débitée des frais de service à chaque colis en '
        'espèces accepté.',
      );
    });
  });
}
