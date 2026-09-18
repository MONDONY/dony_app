import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRefundRequestCubit extends MockCubit<WalletRefundRequestState>
    implements WalletRefundRequestCubit {}

class MockWalletEligibleTopupsCubit extends MockCubit<WalletEligibleTopupsState>
    implements WalletEligibleTopupsCubit {}

// Réassignée à chaque test : la sheet la récupère via
// `getIt<WalletEligibleTopupsCubit>()` pour dériver le rail des recharges
// éligibles concernées (cf. `WalletRefundSelectionSheet`, même pattern).
late MockWalletEligibleTopupsCubit _currentTopupsCubit;

void main() {
  late MockWalletRefundRequestCubit cubit;

  // `CurrencyFormatter` insère une espace insécable avant le symbole : on
  // construit l'attendu à partir du formateur réel plutôt que de deviner
  // le séparateur exact.
  final expectedButtonLabel =
      'Rembourser ${CurrencyFormatter.format(35, SupportedCurrency.eur)}';

  setUpAll(() {
    if (!getIt.isRegistered<WalletEligibleTopupsCubit>()) {
      getIt.registerFactory<WalletEligibleTopupsCubit>(
        () => _currentTopupsCubit,
      );
    }
  });

  setUp(() {
    cubit = MockWalletRefundRequestCubit();
    when(() => cubit.state).thenReturn(const WalletRefundRequestState());
    when(() => cubit.submit(any())).thenAnswer((_) async {});

    _currentTopupsCubit = MockWalletEligibleTopupsCubit();
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(const WalletEligibleTopupsState(isLoading: false));
    when(
      () => _currentTopupsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentTopupsCubit.close()).thenAnswer((_) async {});
    when(() => _currentTopupsCubit.load(any())).thenAnswer((_) async {});
  });

  /// `topups` pilote le rail dérivé par la sheet : par défaut vide, donc
  /// rail carte (comportement inchangé sur l'ancien contrat, où `paymentRef`
  /// n'est jamais renseigné).
  Widget host({
    required double refundable,
    required double nonRefundable,
    double? feeAmount,
    double? netAmount,
    List<WalletEligibleTopupModel>? topups,
  }) {
    if (topups != null) {
      when(
        () => _currentTopupsCubit.state,
      ).thenReturn(WalletEligibleTopupsState(isLoading: false, topups: topups));
    }
    return MaterialApp(
      home: BlocProvider<WalletRefundRequestCubit>.value(
        value: cubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => WalletRefundConfirmSheet.show(
                context,
                currency: 'EUR',
                refundableAmount: refundable,
                nonRefundableAmount: nonRefundable,
                feeAmount: feeAmount,
                netAmount: netAmount,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('affiche le montant remboursable et le bouton avec le montant', (
    tester,
  ) async {
    await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('35,00'), findsWidgets);
    expect(find.text(expectedButtonLabel), findsOneWidget);
    expect(find.textContaining('ne sont pas remboursables'), findsNothing);
  });

  testWidgets('mentionne le bonus non remboursable quand il existe', (
    tester,
  ) async {
    await tester.pumpWidget(host(refundable: 35, nonRefundable: 5));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5,00'), findsWidgets);
    expect(find.textContaining('ne sont pas remboursables'), findsOneWidget);
  });

  testWidgets('le bouton appelle submit sans sélection', (tester) async {
    await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    verify(() => cubit.submit('EUR')).called(1);
  });

  testWidgets('se ferme avec true quand la demande est partie', (tester) async {
    // `BlocProvider` (ancêtre, réutilisé par `WalletRefundConfirmSheet.show`)
    // s'abonne au flux dès le premier `context.read`, avant même que la
    // sheet ne soit montée. Un `Stream.fromIterable` pré-rempli (via
    // `whenListen`) livre son événement à cet abonné-là et disparaît avant
    // que le `BlocConsumer` de la sheet n'ait pu s'abonner à son tour — un
    // vrai Cubit ne se comporte jamais ainsi : son flux reste ouvert tant
    // que rien n'a été émis. Un `StreamController.broadcast()`, alimenté
    // seulement une fois la sheet ouverte, reproduit fidèlement ce
    // comportement et n'a rien à perdre.
    final controller = StreamController<WalletRefundRequestState>.broadcast();
    addTearDown(controller.close);
    when(() => cubit.stream).thenAnswer(
      (_) => controller.stream.map((state) {
        when(() => cubit.state).thenReturn(state);
        return state;
      }),
    );

    await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    controller.add(const WalletRefundRequestState(isSubmitting: true));
    await tester.pump();
    controller.add(
      WalletRefundRequestState(
        result: WalletRefundRequestModel(
          id: 'r1',
          currency: 'EUR',
          amount: 35,
          channel: 'AUTOMATIC_STRIPE',
          status: 'PROCESSING',
          requestedAt: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(expectedButtonLabel), findsNothing);
  });

  testWidgets('affiche l\'erreur et reste ouverte quand la demande échoue', (
    tester,
  ) async {
    final controller = StreamController<WalletRefundRequestState>.broadcast();
    addTearDown(controller.close);
    when(() => cubit.stream).thenAnswer(
      (_) => controller.stream.map((state) {
        when(() => cubit.state).thenReturn(state);
        return state;
      }),
    );

    await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    controller.add(const WalletRefundRequestState(isSubmitting: true));
    await tester.pump();
    controller.add(
      const WalletRefundRequestState(error: NetworkException('Erreur réseau')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erreur réseau'), findsOneWidget);
    expect(find.text(expectedButtonLabel), findsOneWidget);
    // La sheet est toujours affichée (pas de pop) : son titre reste visible.
    expect(find.text('Rembourser mon solde'), findsOneWidget);
  });

  testWidgets(
    'succès alors qu\'une route est empilée par-dessus : ne dépop pas la route du dessus',
    (tester) async {
      final controller = StreamController<WalletRefundRequestState>.broadcast();
      addTearDown(controller.close);
      when(() => cubit.stream).thenAnswer(
        (_) => controller.stream.map((state) {
          when(() => cubit.state).thenReturn(state);
          return state;
        }),
      );

      await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Une autre route arrive au-dessus de la sheet pendant que la demande
      // est en vol (notification tapée, deep link, retour de webview).
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Par dessus')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Par dessus'), findsOneWidget);

      controller.add(const WalletRefundRequestState(isSubmitting: true));
      await tester.pump();
      controller.add(
        WalletRefundRequestState(
          result: WalletRefundRequestModel(
            id: 'r1',
            currency: 'EUR',
            amount: 35,
            channel: 'AUTOMATIC_STRIPE',
            status: 'PROCESSING',
            requestedAt: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La route du dessus est intacte : le listener n'a rien dépilé.
      expect(find.text('Par dessus'), findsOneWidget);

      // Et la sheet est toujours là, dessous : refermer la route du dessus
      // la révèle encore.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Rembourser mon solde'), findsOneWidget);
    },
  );

  group('frais de remboursement', () {
    testWidgets('feeAmount > 0 : montant affiché, bouton sur le net', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(refundable: 35, nonRefundable: 0, feeAmount: 3, netAmount: 32),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Frais de remboursement'), findsOneWidget);
      expect(find.textContaining('3,00'), findsWidgets);
      expect(find.text('Vous recevrez'), findsOneWidget);
      expect(find.textContaining('32,00'), findsWidgets);
      expect(
        find.text(
          'Rembourser ${CurrencyFormatter.format(32, SupportedCurrency.eur)}',
        ),
        findsOneWidget,
      );
      // Bandeau d'avertissement sur les frais retenus, texte figé du plan.
      expect(
        find.text(
          'Cette recharge n\'a jamais servi : les frais du prestataire de '
          'paiement sont retenus. Ils sont annulés dès qu\'une recharge a '
          'payé un envoi.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('feeAmount == 0 : "Offerts", pas de bandeau d\'avertissement', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(refundable: 35, nonRefundable: 0, feeAmount: 0, netAmount: 35),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Frais de remboursement'), findsOneWidget);
      expect(find.text('Offerts'), findsOneWidget);
      expect(find.text('Vous recevrez'), findsOneWidget);
      expect(
        find.textContaining('Cette recharge n\'a jamais servi'),
        findsNothing,
      );
    });

    testWidgets(
      'feeAmount et netAmount absents (ancien contrat) : affichage actuel '
      'inchangé, aucune ligne de frais',
      (tester) async {
        await tester.pumpWidget(host(refundable: 35, nonRefundable: 0));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Frais de remboursement'), findsNothing);
        expect(find.text('Vous recevrez'), findsNothing);
        expect(find.text('Offerts'), findsNothing);
        expect(find.text(expectedButtonLabel), findsOneWidget);
      },
    );
  });

  group('rail dérivé des recharges éligibles', () {
    testWidgets(
      'toutes les recharges concernées sont pawaPay : rail mobile money, '
      'aucun numéro affiché',
      (tester) async {
        await tester.pumpWidget(
          host(
            refundable: 35,
            nonRefundable: 0,
            topups: [
              WalletEligibleTopupModel(
                id: 't1',
                amount: 35,
                paymentRef: 'pawapay:op-123',
                createdAt: DateTime(2026, 9),
              ),
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Remboursable sur mobile money'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Le montant revient sur le numéro qui a payé la recharge, en '
            'général en quelques minutes. Votre solde EUR est gelé le '
            'temps du traitement.',
          ),
          findsOneWidget,
        );
        // Aucun numéro (masqué ou non) n'apparaît : inconnu avant la demande.
        expect(find.textContaining('+'), findsNothing);
        expect(
          find.textContaining('Le montant revient sur la carte'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'recharges concernées sur Stripe : rail carte, texte inchangé',
      (tester) async {
        await tester.pumpWidget(
          host(
            refundable: 35,
            nonRefundable: 0,
            topups: [
              WalletEligibleTopupModel(
                id: 't1',
                amount: 35,
                paymentRef: 'pi_123',
                createdAt: DateTime(2026, 9),
              ),
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Remboursable sur votre carte'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Le montant revient sur la carte utilisée'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'mix pawaPay et Stripe : pas toutes pawaPay, rail carte par défaut',
      (tester) async {
        await tester.pumpWidget(
          host(
            refundable: 35,
            nonRefundable: 0,
            topups: [
              WalletEligibleTopupModel(
                id: 't1',
                amount: 20,
                paymentRef: 'pawapay:op-123',
                createdAt: DateTime(2026, 9),
              ),
              WalletEligibleTopupModel(
                id: 't2',
                amount: 15,
                paymentRef: 'pi_123',
                createdAt: DateTime(2026, 9, 2),
              ),
            ],
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Remboursable sur votre carte'),
          findsOneWidget,
        );
      },
    );

    testWidgets('information absente (ancien contrat, aucune recharge éligible '
        'chargée) : garde l\'affichage actuel', (tester) async {
      await tester.pumpWidget(
        host(refundable: 35, nonRefundable: 0, topups: const []),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Remboursable sur votre carte'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Le montant revient sur la carte utilisée'),
        findsOneWidget,
      );
    });
  });
}
