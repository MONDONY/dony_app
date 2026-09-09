// Tests de la bascule « Mobile money » de PrixConditionsStep — étape 2 du
// formulaire "Publier un trajet" (Tâche 9).
//
// Fichier dédié (prix_conditions_step_test.dart fait déjà 32 Ko) : reprend le
// harnais de construction de ce fichier voisin (mêmes mocks, même style de
// host), mais uniquement pour la section mobile money.
//
// Les deux dispositions de la section paiement (Stripe configuré / Stripe non
// configuré, cf. prix_conditions_step.dart) sont toutes les deux vivantes en
// production selon que le voyageur a terminé l'onboarding Stripe Connect —
// indépendant du rail mobile money. La bascule (même clé
// 'payment-method-mobile-money') doit donc exister dans les deux : le premier
// groupe ci-dessous la couvre en détail (disposition Stripe configuré), le
// second vérifie qu'elle est identique dans la disposition Stripe non
// configuré.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

class _MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _stripeConfiguredState = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);

const _stripeNotConfiguredState = StripeAccountInitial();

// ── Host builder ──────────────────────────────────────────────────────────────

/// Construit l'arbre minimal pour tester la bascule mobile money de
/// PrixConditionsStep, avec un GoRouter réel : le CTA "Activer le versement"
/// pousse `/payments/mobile-money/account`, dont la destination est stubée.
Widget _host({
  StripeAccountState? stripeState,
  SupportedCurrency initialCurrency = SupportedCurrency.eur,
  ValueNotifier<bool>? mobileMoneyEnabledNotifier,
  ValueNotifier<SupportedCurrency>? currencyNotifier,
  bool mobileMoneyAccountActive = false,
}) {
  final mockStripeBloc = _MockStripeAccountBloc();
  when(
    () => mockStripeBloc.state,
  ).thenReturn(stripeState ?? _stripeConfiguredState);
  when(() => mockStripeBloc.stream).thenAnswer((_) => const Stream.empty());

  final mockCommissionBloc = _MockCommissionMethodBloc();
  when(
    () => mockCommissionBloc.state,
  ).thenReturn(CommissionMethodNotConfigured());
  when(() => mockCommissionBloc.stream).thenAnswer((_) => const Stream.empty());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementFormBloc>(
                create: (_) => AnnouncementFormBloc(
                  analytics: makeDisabledAnalytics(MockAnalyticsBackend()),
                ),
              ),
              BlocProvider<StripeAccountBloc>.value(value: mockStripeBloc),
              BlocProvider<CommissionMethodBloc>.value(
                value: mockCommissionBloc,
              ),
            ],
            child: SingleChildScrollView(
              child: PrixConditionsStep(
                currency: initialCurrency,
                priceOptionNotifier: ValueNotifier<int>(0),
                customPriceNotifier: ValueNotifier<double>(0),
                availableKgNotifier: ValueNotifier<double>(10),
                cashEnabledNotifier: ValueNotifier<bool>(false),
                kgPriceEnabledNotifier: ValueNotifier<bool>(true),
                mobileMoneyEnabledNotifier:
                    mobileMoneyEnabledNotifier ?? ValueNotifier<bool>(false),
                currencyNotifier:
                    currencyNotifier ??
                    ValueNotifier<SupportedCurrency>(initialCurrency),
                mobileMoneyAccountActive: mobileMoneyAccountActive,
                negotiableNotifier: ValueNotifier<bool>(false),
                selectedContentNotifier: ValueNotifier<Set<String>>({}),
                customAcceptedNotifier: ValueNotifier<Set<String>>({}),
                refusedTypesNotifier: ValueNotifier<Set<String>>({}),
                catalogLabelsNotifier: ValueNotifier<List<String>>(
                  fallbackCatalog.map((c) => c.label).toList(),
                ),
                descriptionCtrl: TextEditingController(),
                customAcceptedCtrl: TextEditingController(),
                refusedCtrl: TextEditingController(),
                customPriceCtrl: TextEditingController(),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/payments/mobile-money/account',
        builder: (context, state) =>
            const Scaffold(body: Text('mobile-money-account-stub')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

/// Pompe le widget et draine les animations flutter_animate (delay ≤ 180 ms).
Future<void> _pump(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump();
}

void main() {
  group('PrixConditionsStep — bascule mobile money (Stripe configuré)', () {
    testWidgets(
      'devise EUR : bascule visible mais désactivée, sous-titre XOF/XAF',
      (tester) async {
        // EUR est la devise par défaut de _host().
        await _pump(tester, _host());

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        expect(tile.value, isFalse);
        expect(
          tile.onChanged,
          isNull,
          reason: 'Hors CFA, la bascule reste désactivée',
        );
        expect(
          find.text('Disponible pour les trajets en XOF ou XAF'),
          findsOneWidget,
        );
        expect(find.text('Mobile money'), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, 'Activer le versement'),
          findsNothing,
          reason: 'Rien à activer hors zone CFA',
        );
      },
    );

    testWidgets(
      'devise XOF sans compte actif : désactivée, invite à activer le '
      'versement, le CTA pousse /payments/mobile-money/account',
      (tester) async {
        await _pump(
          tester,
          // mobileMoneyAccountActive: false est déjà la valeur par défaut.
          _host(initialCurrency: SupportedCurrency.xof),
        );

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        expect(tile.value, isFalse);
        expect(tile.onChanged, isNull);
        expect(
          find.text('Active d\'abord ton versement mobile money'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Activer le versement'),
          findsOneWidget,
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Activer le versement'),
        );
        await tester.pumpAndSettle();

        expect(find.text('mobile-money-account-stub'), findsOneWidget);
      },
    );

    testWidgets(
      'devise XOF avec compte actif : bascule active, tap met le notifier '
      'à true',
      (tester) async {
        final notifier = ValueNotifier<bool>(false);
        await _pump(
          tester,
          _host(
            initialCurrency: SupportedCurrency.xof,
            mobileMoneyAccountActive: true,
            mobileMoneyEnabledNotifier: notifier,
          ),
        );

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        expect(tile.value, isFalse);
        expect(tile.onChanged, isNotNull);
        expect(find.text('Orange Money, Wave, MTN'), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, 'Activer le versement'),
          findsNothing,
          reason: 'Compte déjà actif : rien à activer',
        );

        await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
        await tester.pump();

        expect(notifier.value, isTrue);
      },
    );

    testWidgets(
      'devise XAF avec compte actif : zone CFA aussi éligible, bascule active',
      (tester) async {
        await _pump(
          tester,
          _host(
            initialCurrency: SupportedCurrency.xaf,
            mobileMoneyAccountActive: true,
          ),
        );

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        expect(tile.onChanged, isNotNull);
        expect(find.text('Orange Money, Wave, MTN'), findsOneWidget);
      },
    );
  });

  group('PrixConditionsStep — bascule mobile money (Stripe non configuré)', () {
    testWidgets('devise XOF sans compte actif : même clé, même comportement '
        'désactivé + CTA que la disposition Stripe configuré', (tester) async {
      await _pump(
        tester,
        // mobileMoneyAccountActive: false est déjà la valeur par défaut.
        _host(
          stripeState: _stripeNotConfiguredState,
          initialCurrency: SupportedCurrency.xof,
        ),
      );

      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('payment-method-mobile-money')),
      );
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(
        find.text('Active d\'abord ton versement mobile money'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, 'Activer le versement'),
        findsOneWidget,
      );
    });

    testWidgets('devise XOF avec compte actif : bascule active, tap met le '
        'notifier à true (indépendant de l\'état Stripe)', (tester) async {
      final notifier = ValueNotifier<bool>(false);
      await _pump(
        tester,
        _host(
          stripeState: _stripeNotConfiguredState,
          initialCurrency: SupportedCurrency.xof,
          mobileMoneyAccountActive: true,
          mobileMoneyEnabledNotifier: notifier,
        ),
      );

      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('payment-method-mobile-money')),
      );
      expect(tile.onChanged, isNotNull);
      expect(find.text('Orange Money, Wave, MTN'), findsOneWidget);

      // Disposition "Stripe non configuré" plus haute (bannière
      // d'explication en plus) : la bascule est hors du viewport de test
      // par défaut, il faut la faire défiler avant de la taper.
      await tester.ensureVisible(
        find.byKey(const Key('payment-method-mobile-money')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('payment-method-mobile-money')));
      await tester.pump();

      expect(notifier.value, isTrue);
    });
  });
}
