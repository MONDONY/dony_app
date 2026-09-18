import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_screen.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_method_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

/// Écran de choix de méthode de recharge : tuile mobile money (numéro +
/// checklist d'opérateurs), garde du bouton « Suivant » et parcours Stripe
/// inchangé.
class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepository repo;
  late MockAnalyticsBackend analyticsBackend;
  WalletTopupMethodSelection? capturedSelection;

  const catalog = MobileMoneyProviderCatalog(
    country: 'SN',
    currency: 'XOF',
    msisdnMasked: '+221 ** ** 12 34',
    detected: 'ORANGE_SEN',
    providers: [
      MobileMoneyProviderOption(
        code: 'ORANGE_SEN',
        label: 'Orange Money',
        detected: true,
      ),
      MobileMoneyProviderOption(code: 'WAVE_SEN', label: 'Wave'),
    ],
  );

  setUp(() {
    repo = _MockWalletRepository();
    analyticsBackend = MockAnalyticsBackend();
    capturedSelection = null;
    when(() => repo.topupProviders(any())).thenAnswer((_) async => catalog);
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/method',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/method',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>(
                create: (_) => WalletTopupMobileMoneyCubit(
                  repo,
                  makeEnabledAnalytics(analyticsBackend),
                ),
                child: const WalletTopupMethodScreen(),
              ),
        ),
        GoRoute(
          path: '/payments/wallet/topup/amount',
          builder: (context, state) {
            capturedSelection = state.extra as WalletTopupMethodSelection;
            return const Scaffold(body: Text('Montant'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  /// Sélectionne la tuile mobile money, laisse le temps à sa section (avec
  /// ses `.animate()`) de se monter complètement, puis saisit un numéro et
  /// perd le focus pour déclencher `loadProviders`.
  Future<void> selectMobileMoneyAndTypePhone(WidgetTester tester) async {
    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wallet-topup-payer-phone-field')),
      '+221 77 123 45 67',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('tuile mobile money visible et sélectionnable', (tester) async {
    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    expect(find.text('Mobile money'), findsOneWidget);
    expect(find.text('Orange Money, Wave, MTN MoMo'), findsOneWidget);

    await tester.tap(find.text('Mobile money'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('wallet-topup-payer-phone-field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'saisie du numéro puis perte de focus : opérateurs chargés, opérateur '
    'détecté coché, bouton actif',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      // Bouton désactivé tant qu'aucune méthode n'est choisie.
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
      );

      await tester.tap(find.text('Mobile money'));
      await tester.pumpAndSettle();

      // Toujours désactivé : aucun opérateur prêt.
      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNull,
      );

      await tester.enterText(
        find.byKey(const Key('wallet-topup-payer-phone-field')),
        '+221 77 123 45 67',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('network-ORANGE_SEN')), findsOneWidget);
      final orangeTile = tester.widget<DonyOperatorTile>(
        find.byKey(const Key('network-ORANGE_SEN')),
      );
      expect(orangeTile.selected, isTrue);

      final waveTile = tester.widget<DonyOperatorTile>(
        find.byKey(const Key('network-WAVE_SEN')),
      );
      expect(waveTile.selected, isFalse);

      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'Stripe inchangé : sélection puis Suivant transmet method STRIPE sans cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carte bancaire'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DonyButton>(find.byType(DonyButton).last).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection, isNotNull);
      expect(capturedSelection!.method, 'STRIPE');
      expect(capturedSelection!.cubit, isNull);
      expect(capturedSelection!.phoneNumber, isNull);
    },
  );

  testWidgets(
    'mobile money : Suivant transmet numéro, opérateur, devise et la même '
    'instance de cubit',
    (tester) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      final cubit = BlocProvider.of<WalletTopupMobileMoneyCubit>(
        tester.element(find.byType(WalletTopupMethodScreen)),
      );

      await selectMobileMoneyAndTypePhone(tester);

      await tester.tap(find.text('Suivant → Montant'));
      await tester.pumpAndSettle();

      expect(capturedSelection, isNotNull);
      expect(capturedSelection!.method, 'MOBILE_MONEY');
      expect(capturedSelection!.phoneNumber, '+221771234567');
      expect(capturedSelection!.provider, 'ORANGE_SEN');
      expect(capturedSelection!.currency, 'XOF');
      expect(capturedSelection!.cubit, same(cubit));
    },
  );
}
