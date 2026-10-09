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
/// PrixConditionsStep, avec un GoRouter réel : le lien « Activer le mobile
/// money » pousse `/payments/mobile-money/account`, dont la destination est
/// stubée (avec un bouton de retour pour éprouver le rechargement).
Widget _host({
  StripeAccountState? stripeState,
  SupportedCurrency initialCurrency = SupportedCurrency.eur,
  ValueNotifier<bool>? mobileMoneyEnabledNotifier,
  ValueNotifier<SupportedCurrency>? currencyNotifier,
  bool mobileMoneyAccountActive = false,
  SupportedCurrency? mobileMoneyCurrency,
  VoidCallback? onMobileMoneySetupReturned,
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
                mobileMoneyCurrency: mobileMoneyCurrency,
                onMobileMoneySetupReturned: onMobileMoneySetupReturned,
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
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              const Text('mobile-money-account-stub'),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('stub-back'),
              ),
            ],
          ),
        ),
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
          find.byKey(const Key('activate-mobile-money-cta')),
          findsNothing,
          reason: 'Rien à activer hors zone CFA',
        );
      },
    );

    testWidgets(
      'devise XOF sans compte actif : désactivée, encart explicatif, le '
      'lien pousse /payments/mobile-money/account',
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
          find.text('Non configuré, activez-le pour l\'accepter'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('activate-mobile-money-cta')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('activate-mobile-money-cta')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('activate-mobile-money-cta')));
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
        expect(find.text('Orange Money, MTN, Moov'), findsOneWidget);
        expect(
          find.byKey(const Key('activate-mobile-money-cta')),
          findsNothing,
          reason: 'Compte déjà actif : rien à activer',
        );

        // En XOF la carte est indisponible : son encart et celui des espèces
        // (forcées ON) repoussent la bascule hors du viewport de test.
        await tester.ensureVisible(
          find.byKey(const Key('payment-method-mobile-money')),
        );
        await tester.pump();
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
        expect(find.text('Orange Money, MTN, Moov'), findsOneWidget);
      },
    );
  });

  group('PrixConditionsStep — encart « mobile money non activé »', () {
    testWidgets('devise XOF sans compte actif : explique pourquoi et propose '
        'l\'activation', (tester) async {
      await _pump(tester, _host(initialCurrency: SupportedCurrency.xof));

      expect(
        find.byKey(const Key('mobile-money-setup-notice')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Le mobile money n\'est pas activé : vous ne pouvez pas encore '
          'l\'accepter sur ce trajet.',
        ),
        findsOneWidget,
      );
      expect(find.text('Activer le mobile money'), findsOneWidget);
    });

    testWidgets('hors zone CFA : aucun encart, le mobile money ne peut pas '
        's\'appliquer à ce trajet', (tester) async {
      await _pump(tester, _host());

      expect(find.byKey(const Key('mobile-money-setup-notice')), findsNothing);
      expect(find.byKey(const Key('activate-mobile-money-cta')), findsNothing);
    });

    testWidgets('compte actif : aucun encart', (tester) async {
      await _pump(
        tester,
        _host(
          initialCurrency: SupportedCurrency.xof,
          mobileMoneyAccountActive: true,
        ),
      );

      expect(find.byKey(const Key('mobile-money-setup-notice')), findsNothing);
    });

    testWidgets('au retour de l\'écran d\'activation, le parent est invité à '
        'recharger le compte mobile money', (tester) async {
      var reloads = 0;
      await _pump(
        tester,
        _host(
          initialCurrency: SupportedCurrency.xof,
          onMobileMoneySetupReturned: () => reloads++,
        ),
      );

      await tester.ensureVisible(
        find.byKey(const Key('activate-mobile-money-cta')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('activate-mobile-money-cta')));
      await tester.pumpAndSettle();
      expect(
        reloads,
        0,
        reason: 'Rien à recharger tant que l\'écran est ouvert',
      );

      await tester.tap(find.text('stub-back'));
      await tester.pumpAndSettle();

      expect(reloads, 1);
    });

    testWidgets('bascule jamais affichée activée quand le mobile money est '
        'inutilisable, même si la valeur héritée vaut true', (tester) async {
      await _pump(
        tester,
        _host(
          initialCurrency: SupportedCurrency.xof,
          mobileMoneyEnabledNotifier: ValueNotifier<bool>(true),
        ),
      );

      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('payment-method-mobile-money')),
      );
      expect(tile.value, isFalse);
    });
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
        find.text('Non configuré, activez-le pour l\'accepter'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('activate-mobile-money-cta')),
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
      expect(find.text('Orange Money, MTN, Moov'), findsOneWidget);

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

  // FLUTTER-55 : « j'ai fait la configuration de paiement par mobile mais je
  // n'arrive pas à le sélectionner quand je crée un trajet ». Compte activé,
  // trajet en EUR : l'option restait grisée sans dire pourquoi.
  group('compte mobile money activé, trajet dans une autre devise', () {
    testWidgets('encart explicatif et bouton « Publier en XOF »', (
      tester,
    ) async {
      final currency = ValueNotifier<SupportedCurrency>(SupportedCurrency.eur);
      await _pump(
        tester,
        _host(
          currencyNotifier: currency,
          mobileMoneyAccountActive: true,
          mobileMoneyCurrency: SupportedCurrency.xof,
        ),
      );

      expect(
        find.text(
          'Votre mobile money reçoit des XOF. Ce trajet est en EUR : '
          'publiez-le en XOF pour accepter le mobile money.',
        ),
        findsOneWidget,
      );

      final cta = find.byKey(const Key('switch-to-mobile-money-currency-cta'));
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      // FLUTTER-GK : confirmation explicite avant de basculer la devise.
      expect(currency.value.code, SupportedCurrency.eur.code);
      expect(
        find.text(
          'Tous les prix du voyage passent en F CFA et le paiement par carte '
          'ne sera plus proposé.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('currency-switch-confirm')));
      // Le changement de devise relance les animations d'apparition.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(currency.value.code, SupportedCurrency.xof.code);
      expect(
        find.byKey(const Key('mobile-money-currency-notice')),
        findsNothing,
      );
      final tile = tester.widget<SwitchListTile>(
        find.byKey(const Key('payment-method-mobile-money')),
      );
      expect(tile.onChanged, isNotNull);
      await tester.pumpAndSettle();
    });

    testWidgets('FLUTTER-GK : « Annuler » garde la devise du voyage', (
      tester,
    ) async {
      final currency = ValueNotifier<SupportedCurrency>(SupportedCurrency.eur);
      await _pump(
        tester,
        _host(
          currencyNotifier: currency,
          mobileMoneyAccountActive: true,
          mobileMoneyCurrency: SupportedCurrency.xof,
        ),
      );
      final cta = find.byKey(const Key('switch-to-mobile-money-currency-cta'));
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('currency-switch-cancel')));
      await tester.pumpAndSettle();

      expect(currency.value.code, SupportedCurrency.eur.code);
      expect(
        find.byKey(const Key('mobile-money-currency-notice')),
        findsOneWidget,
      );
    });

    testWidgets('devise du compte inconnue : encart générique sans bouton', (
      tester,
    ) async {
      await _pump(tester, _host(mobileMoneyAccountActive: true));

      expect(
        find.byKey(const Key('mobile-money-currency-notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('switch-to-mobile-money-currency-cta')),
        findsNothing,
      );
    });

    testWidgets('trajet déjà en XOF : aucun encart de devise', (tester) async {
      await _pump(
        tester,
        _host(
          initialCurrency: SupportedCurrency.xof,
          mobileMoneyAccountActive: true,
          mobileMoneyCurrency: SupportedCurrency.xof,
        ),
      );

      expect(
        find.byKey(const Key('mobile-money-currency-notice')),
        findsNothing,
      );
    });
  });
}
