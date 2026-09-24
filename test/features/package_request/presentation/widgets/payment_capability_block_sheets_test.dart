import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_capability_block_sheets.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';

void main() {
  Widget wrap({required MockStripeAccountBloc bloc}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => Scaffold(
            body: BlocProvider<StripeAccountBloc>.value(
              value: bloc,
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showCardCapabilityRequiredSheet(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/connect/onboarding/intro',
          builder: (_, _) => const Scaffold(body: Text('ONBOARDING')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  testWidgets(
    'Stripe disponible dans le pays → titre, corps et bouton d\'activation',
    (tester) async {
      await tester.pumpWidget(wrap(bloc: stubStripeAccountBloc()));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Paiement carte requis'), findsOneWidget);
      expect(
        find.textContaining('Active les paiements par carte'),
        findsOneWidget,
      );
      expect(find.text('Activer le paiement carte'), findsOneWidget);

      await tester.tap(find.text('Activer le paiement carte'));
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING'), findsOneWidget);
    },
  );

  testWidgets(
    'Stripe indisponible dans le pays → titre et bouton de fermeture',
    (tester) async {
      await tester.pumpWidget(
        wrap(bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Colis indisponible'), findsOneWidget);
      expect(
        find.textContaining('ne permet pas encore d\'ouvrir un compte'),
        findsOneWidget,
      );
      expect(find.text('J\'ai compris'), findsOneWidget);

      await tester.tap(find.text('J\'ai compris'));
      await tester.pumpAndSettle();

      expect(find.text('Colis indisponible'), findsNothing);
    },
  );

  testWidgets('anglais : titre, corps et bouton traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap(bloc: stubStripeAccountBloc()));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Card payment required'), findsOneWidget);
    expect(find.textContaining('Activate card payments'), findsWidgets);
  });

  testWidgets(
    'anglais, Stripe indisponible : titre et bouton "Got it" traduits',
    (tester) async {
      useEnglish();
      await tester.pumpWidget(
        wrap(bloc: stubStripeAccountBloc(state: stripeCountryUnavailableState)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Parcel unavailable'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    },
  );
}
