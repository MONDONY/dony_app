import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_topup_mobile_money_awaiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Écran d'attente de la recharge mobile money : textes figés, carte de
/// détails, `Confirmed` -> retour au portefeuille, `Failed` -> message et
/// bouton de reprise.
///
/// L'icône pulsée de `_AwaitingBody` tourne en boucle (`repeat(reverse:
/// true)`) : jamais de `pumpAndSettle()` pendant qu'elle est montée (elle ne
/// se stabilise jamais), toujours des `pump()` bornés — comme
/// `mobile_money_awaiting_screen_test.dart` (référence de cet écran) le
/// fait déjà pour son propre compte à rebours.
class _MockCubit extends MockCubit<WalletTopupMobileMoneyState>
    implements WalletTopupMobileMoneyCubit {}

void main() {
  late _MockCubit cubit;
  Object? capturedWalletExtra;
  var didNavigateToWallet = false;

  const topup = WalletTopupModel(
    topupId: 'topup-1',
    currency: 'XOF',
    provider: 'ORANGE_SEN',
    providerLabel: 'Orange Money',
    msisdnMasked: '+221 ** ** 12 34',
  );

  final startedAt = DateTime.now();

  setUp(() {
    cubit = _MockCubit();
    capturedWalletExtra = null;
    didNavigateToWallet = false;
    when(
      () => cubit.initiate(
        amount: any(named: 'amount'),
        phoneNumber: any(named: 'phoneNumber'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/payments/wallet/topup/mobile-money/awaiting',
      routes: [
        GoRoute(
          path: '/payments/wallet/topup/mobile-money/awaiting',
          builder: (context, state) =>
              BlocProvider<WalletTopupMobileMoneyCubit>.value(
                value: cubit,
                child: const WalletTopupMobileMoneyAwaitingScreen(
                  phoneNumber: '+221771234567',
                  amount: 5000,
                ),
              ),
        ),
        GoRoute(
          path: '/payments/wallet',
          builder: (context, state) {
            didNavigateToWallet = true;
            capturedWalletExtra = state.extra;
            return const Scaffold(body: Text('Portefeuille'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  testWidgets(
    'textes figés de l\'écran d\'attente (Orange Money, sans redirection)',
    (tester) async {
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: WalletTopupMobileMoneyAwaiting(
          topup: topup,
          startedAt: startedAt,
        ),
      );

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump();

      expect(find.text('Valide le paiement sur ton téléphone'), findsOneWidget);
      expect(find.textContaining('+221 ** ** 12 34'), findsOneWidget);
      expect(find.textContaining('Orange Money'), findsWidgets);
      expect(
        find.text('La confirmation est automatique, garde cet écran ouvert.'),
        findsOneWidget,
      );
      expect(find.text('Montant'), findsOneWidget);
      expect(find.text('Crédité sur'), findsOneWidget);
      expect(find.text('Expire dans'), findsOneWidget);
      // Pas de bouton d'ouverture externe : aucune authorizationUrl (Orange
      // Money, PIN saisi côté opérateur, pas de redirection comme Wave).
      expect(
        find.byKey(const Key('mobile-money-awaiting-open-authorization')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mobile-money-awaiting-other-number')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Wave : bouton « Ouvrir Wave » avec authorizationUrl', (
    tester,
  ) async {
    const waveTopup = WalletTopupModel(
      topupId: 'topup-2',
      currency: 'XOF',
      provider: 'WAVE_SEN',
      providerLabel: 'Wave',
      msisdnMasked: '+221 ** ** 56 78',
      authorizationUrl: 'https://pay.wave.com/abc123',
    );
    whenListen(
      cubit,
      const Stream<WalletTopupMobileMoneyState>.empty(),
      initialState: WalletTopupMobileMoneyAwaiting(
        topup: waveTopup,
        startedAt: startedAt,
      ),
    );

    await tester.pumpWidget(buildHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ouvrir Wave'), findsOneWidget);
  });

  testWidgets(
    '« Payer avec un autre numéro » revient à l\'écran précédent (pop)',
    (tester) async {
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: WalletTopupMobileMoneyAwaiting(
          topup: topup,
          startedAt: startedAt,
        ),
      );

      final router = GoRouter(
        initialLocation: '/choice',
        routes: [
          GoRoute(
            path: '/choice',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push(
                    '/payments/wallet/topup/mobile-money/awaiting',
                  ),
                  child: const Text('Ouvrir attente'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/payments/wallet/topup/mobile-money/awaiting',
            builder: (context, state) =>
                BlocProvider<WalletTopupMobileMoneyCubit>.value(
                  value: cubit,
                  child: const WalletTopupMobileMoneyAwaitingScreen(
                    phoneNumber: '+221771234567',
                    amount: 5000,
                  ),
                ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pump();

      await tester.tap(find.text('Ouvrir attente'));
      // Transition de page (~300 ms) puis deux pumps pour flusher le timer
      // de démarrage de l'icône pulsée — jamais pumpAndSettle() (l'icône
      // pulse en boucle, la pile ne se stabilise jamais).
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump();

      expect(find.text('Valide le paiement sur ton téléphone'), findsOneWidget);

      await tester.tap(find.text('Payer avec un autre numéro'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Ouvrir attente'), findsOneWidget);
      // La recharge en cours doit être abandonnée AVANT le pop, sans quoi
      // le cubit (partagé avec l'écran de choix) resterait Awaiting et
      // continuerait de sonder — voir la vraie réinitialisation testée sur
      // le cubit lui-même et sur l'écran de choix réel ci-dessous.
      verify(() => cubit.reset()).called(1);
    },
  );

  testWidgets('Confirmed -> retour au portefeuille avec le statut en extra', (
    tester,
  ) async {
    const status = WalletTopupStatusModel(
      topupId: 'topup-1',
      status: 'CONFIRMED',
      amount: 5000,
      currency: 'XOF',
      provider: 'ORANGE_SEN',
      providerLabel: 'Orange Money',
      msisdnMasked: '+221 ** ** 12 34',
      walletBalance: 15000,
    );
    whenListen(
      cubit,
      Stream.fromIterable([const WalletTopupMobileMoneyConfirmed(status)]),
      initialState: WalletTopupMobileMoneyAwaiting(
        topup: topup,
        startedAt: startedAt,
      ),
    );

    await tester.pumpWidget(buildHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(didNavigateToWallet, isTrue);
    expect(capturedWalletExtra, {'topupConfirmed': status});
  });

  testWidgets('Failed -> message affiché et bouton « Réessayer »', (
    tester,
  ) async {
    whenListen(
      cubit,
      Stream.fromIterable([
        const WalletTopupMobileMoneyFailed('Solde insuffisant.'),
      ]),
      initialState: WalletTopupMobileMoneyAwaiting(
        topup: topup,
        startedAt: startedAt,
      ),
    );

    await tester.pumpWidget(buildHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Solde insuffisant.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(
      () => cubit.initiate(amount: 5000, phoneNumber: '+221771234567'),
    ).called(1);
  });

  testWidgets(
    'IMPORTANT — Error (réseau coupé pendant « Réessayer ») : message et '
    'bouton de reprise, jamais une roue infinie',
    (tester) async {
      const failure = NetworkException('boom');
      whenListen(
        cubit,
        Stream.fromIterable([const WalletTopupMobileMoneyError(failure)]),
        initialState: const WalletTopupMobileMoneyFailed('Refusé.'),
      );

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.text(ErrorPresenter.resolve(failure).message),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      verify(
        () => cubit.initiate(amount: 5000, phoneNumber: '+221771234567'),
      ).called(1);
    },
  );

  testWidgets(
    'CRITIQUE — le bouton retour de l\'AppBar abandonne la recharge, comme '
    '« Payer avec un autre numéro »',
    (tester) async {
      whenListen(
        cubit,
        const Stream<WalletTopupMobileMoneyState>.empty(),
        initialState: WalletTopupMobileMoneyAwaiting(
          topup: topup,
          startedAt: startedAt,
        ),
      );

      final router = GoRouter(
        initialLocation: '/choice',
        routes: [
          GoRoute(
            path: '/choice',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => context.push(
                    '/payments/wallet/topup/mobile-money/awaiting',
                  ),
                  child: const Text('Ouvrir attente'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/payments/wallet/topup/mobile-money/awaiting',
            builder: (context, state) =>
                BlocProvider<WalletTopupMobileMoneyCubit>.value(
                  value: cubit,
                  child: const WalletTopupMobileMoneyAwaitingScreen(
                    phoneNumber: '+221771234567',
                    amount: 5000,
                  ),
                ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      );
      await tester.pump();

      await tester.tap(find.text('Ouvrir attente'));
      // Jamais pumpAndSettle() : l'icône pulsée tourne en boucle.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.pump();
      expect(find.text('Valide le paiement sur ton téléphone'), findsOneWidget);

      await tester.tap(find.byType(DonyAppBarBackButton));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Ouvrir attente'), findsOneWidget);
      verify(() => cubit.reset()).called(1);
    },
  );
}
