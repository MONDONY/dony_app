// Tests de CurrencySelectionBanner — bandeau de sélection de la devise de
// publication, étape "Trajet" du formulaire de création d'annonce.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/currency_selection_banner.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

Widget _host(SupportedCurrency currency, {StripeAccountState? stripeState}) {
  final stripe = _MockStripeAccountBloc();
  when(
    () => stripe.state,
  ).thenReturn(stripeState ?? const StripeAccountInitial());
  when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
  return MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<StripeAccountBloc>.value(
      value: stripe,
      child: Scaffold(
        body: CurrencySelectionBanner(
          currencyNotifier: ValueNotifier<SupportedCurrency>(currency),
        ),
      ),
    ),
  );
}

const _stripeReady = StripeAccountReady(
  ConnectAccountStatus(status: 'ONBOARDING_COMPLETE'),
);
const _stripeMissing = StripeAccountReady(
  ConnectAccountStatus(status: 'NOT_CREATED'),
);

Future<void> _openSelector(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('trip-currency-selector-row')));
  await tester.pumpAndSettle();
}

void main() {
  group('CurrencySelectionBanner', () {
    testWidgets('affiche "Publié en Euro (EUR)" et le bouton "Changer"', (
      tester,
    ) async {
      await tester.pumpWidget(_host(SupportedCurrency.eur));
      expect(find.text('Publié en Euro (EUR)'), findsOneWidget);
      expect(find.text('Changer'), findsOneWidget);
    });

    // YADONY-FLUTTER-PROD-19 : un trajet en francs CFA s'annonçait
    // « Espèces uniquement » alors que le mobile money est possible.
    testWidgets('en XOF, le sélecteur annonce mobile money et espèces', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(SupportedCurrency.xof, stripeState: _stripeMissing),
      );
      await _openSelector(tester);

      expect(
        find.text('Mobile money et espèces disponibles en XOF'),
        findsOneWidget,
      );
      expect(find.text('Espèces uniquement en XOF'), findsNothing);
      // Sous-titre des deux devises CFA dans la liste.
      expect(find.text('Mobile money et espèces'), findsNWidgets(2));
      expect(
        find.textContaining('ait activé un compte de versement'),
        findsOneWidget,
      );
      expect(
        find.textContaining("La carte n'est pas proposée en francs CFA"),
        findsOneWidget,
      );
    });

    testWidgets('en XAF avec Stripe prêt, toujours sans carte', (tester) async {
      await tester.pumpWidget(
        _host(SupportedCurrency.xaf, stripeState: _stripeReady),
      );
      await _openSelector(tester);

      expect(
        find.text('Mobile money et espèces disponibles en XAF'),
        findsOneWidget,
      );
      expect(find.text('Carte et espèces disponibles en XAF'), findsNothing);
    });

    testWidgets('en EUR avec Stripe prêt, carte et espèces', (tester) async {
      await tester.pumpWidget(
        _host(SupportedCurrency.eur, stripeState: _stripeReady),
      );
      await _openSelector(tester);

      expect(find.text('Carte et espèces disponibles en EUR'), findsOneWidget);
      expect(find.text('Espèces uniquement en EUR'), findsNothing);
    });

    testWidgets('en EUR sans Stripe, espèces uniquement avec le pourquoi', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(SupportedCurrency.eur, stripeState: _stripeMissing),
      );
      await _openSelector(tester);

      expect(find.text('Espèces uniquement en EUR'), findsOneWidget);
      expect(find.text('Carte et espèces disponibles en EUR'), findsNothing);
      expect(
        find.textContaining("le voyageur n'a pas activé les paiements Yadony"),
        findsOneWidget,
      );
    });
  });

  // ── Group: English (i18n) ─────────────────────────────────────────────────

  group('CurrencySelectionBanner — English', () {
    testWidgets('affiche "Posted in Euro (EUR)" et le bouton "Change"', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(_host(SupportedCurrency.eur));
      expect(find.text('Posted in Euro (EUR)'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('en XOF, mobile money et espèces en anglais', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _host(SupportedCurrency.xof, stripeState: _stripeMissing),
      );
      await _openSelector(tester);

      expect(find.textContaining('Mobile money'), findsWidgets);
      expect(find.text('Cash only in XOF'), findsNothing);
      expect(
        find.textContaining("Card payment isn't offered in CFA francs"),
        findsOneWidget,
      );
    });
  });
}
