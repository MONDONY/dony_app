import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_amount_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/currency_test_doubles.dart';
import '../../../helpers/mock_analytics_backend.dart';

/// Régression : sous le minimum Stripe (5 € équivalent), le bouton doit
/// rester désactivé plutôt que de laisser partir un PaymentIntent que Stripe
/// refuserait — quelle que soit la devise active, comparée à l'EUR via
/// `SupportedCurrency.unitsPerEur`.
class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository walletRepository;

  setUp(() {
    walletRepository = _MockWalletRepository();
    when(
      () => walletRepository.topupStripe(amount: any(named: 'amount')),
    ).thenAnswer((_) async => 'pi_test_secret');

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  Widget buildSubject(WalletBloc bloc) => MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<WalletBloc>.value(
      value: bloc,
      child: const WalletTopupAmountScreen(paymentMethod: 'STRIPE'),
    ),
  );

  testWidgets(
    'un montant EUR sous 5 € désactive le bouton et affiche le minimum',
    (tester) async {
      final bloc = WalletBloc(
        walletRepository,
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(buildSubject(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3'));
      await tester.pump();

      // Comparaison via `contains` : le formateur fr_FR insère une espace
      // insécable entre le montant et le symbole, pas une espace classique.
      final minimumLabel = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data ?? '').startsWith('Minimum') &&
            (w.data ?? '').contains('5,00') &&
            (w.data ?? '').contains('€'),
      );
      expect(minimumLabel, findsOneWidget);

      await tester.tap(minimumLabel);
      await tester.pump();

      verifyNever(
        () => walletRepository.topupStripe(amount: any(named: 'amount')),
      );
    },
  );

  testWidgets('un montant EUR de 5 € exactement active le bouton', (
    tester,
  ) async {
    final bloc = WalletBloc(
      walletRepository,
      makeEnabledAnalytics(MockAnalyticsBackend()),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(buildSubject(bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump();

    expect(find.text('Recharger 5 € via Carte bancaire'), findsOneWidget);
  });

  testWidgets(
    'devise USD sous le seuil converti (5 \$ ≈ 4,63 €) désactive le bouton',
    (tester) async {
      // unitsPerEur(USD) = 1.08 → 5 $ ≈ 4,63 €, sous le seuil de 5 €. Un
      // seuil naïf comparé au montant brut ("amount >= 5") aurait laissé
      // passer 5 $ alors que Stripe l'aurait refusé.
      registerCurrencyPreference('USD');
      final bloc = WalletBloc(
        walletRepository,
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(buildSubject(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('5'));
      await tester.pump();

      expect(find.textContaining('Minimum'), findsOneWidget);
      expect(find.text('Recharger 5 \$ via Carte bancaire'), findsNothing);
    },
  );

  testWidgets(
    'devise USD au-dessus du seuil converti (9 \$ ≈ 8,33 €) active le bouton',
    (tester) async {
      registerCurrencyPreference('USD');
      final bloc = WalletBloc(
        walletRepository,
        makeEnabledAnalytics(MockAnalyticsBackend()),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(buildSubject(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('9'));
      await tester.pump();

      expect(find.text('Recharger 9 \$ via Carte bancaire'), findsOneWidget);
    },
  );
}
