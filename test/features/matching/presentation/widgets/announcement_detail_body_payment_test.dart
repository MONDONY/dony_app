import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../../helpers/stripe_account_test_doubles.dart';

AnnouncementModel _announcement({
  required Set<BidPaymentMethod> acceptedPaymentMethods,
}) {
  final now = DateTime(2026, 7, 20);
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: now.add(const Duration(days: 10)),
    availableKg: 20,
    totalKg: 20,
    pricePerKg: 10,
    status: 'PUBLISHED',
    createdAt: now,
    updatedAt: now,
    acceptedPaymentMethods: acceptedPaymentMethods,
  );
}

Widget _wrap(AnnouncementModel a, {StripeAccountState? stripeState}) {
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (context, state) => BlocProvider<StripeAccountBloc>.value(
          value: stripeState == null
              ? stubStripeAccountBloc()
              : stubStripeAccountBloc(state: stripeState),
          child: Scaffold(
            body: SingleChildScrollView(child: AnnouncementDetailBody(a: a)),
          ),
        ),
      ),
      GoRoute(
        path: '/connect/onboarding/intro',
        builder: (context, state) =>
            const Scaffold(body: Text('stripe-onboarding-intro')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  // AnnouncementDetailBody n'est utilisé que par TripOwnerDetailScreen (le
  // voyageur consultant SON PROPRE trajet). Le nudge cash-only s'adresse donc
  // au voyageur (pas à l'expéditeur — cf. traveler_profile_screen_payment_test.dart
  // pour la bannière D5 « pas de séquestre » côté expéditeur).
  group('AnnouncementDetailBody — nudge cash-only (vue voyageur)', () {
    testWidgets(
      'trajet cash-only — nudge affiché avec CTA vers activation carte',
      (tester) async {
        final a = _announcement(
          acceptedPaymentMethods: {BidPaymentMethod.cash},
        );

        await tester.pumpWidget(_wrap(a));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Beaucoup d\'expéditeurs préfèrent payer par carte',
          ),
          findsOneWidget,
        );
        expect(find.text('Activer les paiements par carte'), findsOneWidget);

        await tester.tap(find.byKey(const Key('activate-card-payments-cta')));
        await tester.pumpAndSettle();

        expect(find.text('stripe-onboarding-intro'), findsOneWidget);
      },
    );

    testWidgets('trajet avec carte acceptée — pas de nudge', (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {
          BidPaymentMethod.cash,
          BidPaymentMethod.stripe,
        },
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(find.text('Activer les paiements par carte'), findsNothing);
    });

    testWidgets('trajet carte uniquement — pas de nudge', (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {BidPaymentMethod.stripe},
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(find.text('Activer les paiements par carte'), findsNothing);
    });

    testWidgets('pays non couvert par Stripe — pas de nudge', (tester) async {
      // Trajet cash-only, donc le nudge s'afficherait normalement. Là où
      // Stripe n'ouvre pas de compte, tous les trajets le sont : la bannière
      // s'afficherait sur chacun, pour un reproche impossible à lever.
      final a = _announcement(acceptedPaymentMethods: {BidPaymentMethod.cash});

      await tester.pumpWidget(
        _wrap(a, stripeState: stripeCountryUnavailableState),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Beaucoup d\'expéditeurs préfèrent payer par carte',
        ),
        findsNothing,
      );
      expect(find.text('Activer les paiements par carte'), findsNothing);
    });
  });
}
