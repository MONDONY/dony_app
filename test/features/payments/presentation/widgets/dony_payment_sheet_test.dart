import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/saved_card_model.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentSheetBloc extends MockBloc<PaymentSheetEvent, PaymentSheetState>
    implements PaymentSheetBloc {
  MockPaymentSheetBloc(this.config);

  @override
  final PaymentSheetConfig config;
}

const _visa = SavedCardModel(
  id: 'pm_1',
  brand: 'visa',
  last4: '4242',
  expMonth: 8,
  expYear: 2027,
);

const _config = PaymentSheetConfig(
  clientSecret: 'pi_123_secret_abc',
  amountEur: 56.0,
  paymentMethodTypes: ['card', 'paypal'],
);

void main() {
  late MockPaymentSheetBloc bloc;

  setUp(() {
    bloc = MockPaymentSheetBloc(_config);
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => DonyPaymentSheet.show(
              ctx,
              config: _config,
              contextLabel: 'Envoi vers Dakar',
              onSuccess: () {},
              bloc: bloc,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  group('Vue principale — boutons conditionnels', () {
    testWidgets('sans wallet ni PayPal ni cartes : seule « Nouvelle carte »',
        (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [],
        saveCard: true,
      ));

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetWalletButton')), findsNothing);
      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsNothing);
      expect(find.byKey(const Key('paymentSheetNewCardTile')), findsOneWidget);
    });

    testWidgets('avec PayPal disponible : bouton PayPal affiché',
        (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: true,
        savedCards: [],
        saveCard: true,
      ));

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
    });

    testWidgets('avec cartes enregistrées : chaque carte listée',
        (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [_visa],
        saveCard: true,
      ));

      await openSheet(tester);

      expect(find.text('Visa •••• 4242'), findsOneWidget);
      expect(
          find.byKey(const Key('paymentSheetSavedCard_pm_1')), findsOneWidget);
    });

    testWidgets('sans cartes enregistrées : section masquée', (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [],
        saveCard: true,
      ));

      await openSheet(tester);

      expect(find.text('Cartes enregistrées'), findsNothing);
    });
  });

  group('Sélection de carte', () {
    testWidgets('tap sur une carte enregistrée dispatch le bon choix',
        (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [_visa],
        saveCard: true,
      ));

      await openSheet(tester);
      await tester.tap(find.byKey(const Key('paymentSheetSavedCard_pm_1')));

      verify(() => bloc.add(const PaymentSheetCardChoiceChanged(
          SavedCardChoice(_visa)))).called(1);
    });

    testWidgets('carte sélectionnée active le bouton payer', (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [_visa],
        cardChoice: SavedCardChoice(_visa),
        saveCard: true,
      ));

      await openSheet(tester);

      final button = tester
          .widget<DonyButton>(find.byKey(const Key('paymentSheetPayButton')));
      expect(button.onPressed, isNotNull);
      final amountLabel =
          NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(56.0);
      expect(find.text('Payer $amountLabel'), findsOneWidget);
    });

    testWidgets('aucun choix : bouton payer désactivé', (tester) async {
      when(() => bloc.state).thenReturn(const PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [_visa],
        saveCard: true,
      ));

      await openSheet(tester);

      final button = tester
          .widget<DonyButton>(find.byKey(const Key('paymentSheetPayButton')));
      expect(button.onPressed, isNull);
    });
  });

  group('Vue succès', () {
    testWidgets('affiche l\'encart escrow et le bouton de sortie',
        (tester) async {
      when(() => bloc.state)
          .thenReturn(const PaymentSheetSuccess(method: PaymentMethodKind.wallet));

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetEscrowNote')), findsOneWidget);
      expect(find.text('Paiement confirmé'), findsOneWidget);
      expect(find.byKey(const Key('paymentSheetDoneButton')), findsOneWidget);
    });
  });

  group('Échec', () {
    testWidgets('failure transitoire affiche une snackbar', (tester) async {
      const ready = PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
        savedCards: [],
        saveCard: true,
      );
      whenListen<PaymentSheetState>(
        bloc,
        Stream.fromIterable([
          const PaymentSheetFailure(message: 'Paiement refusé', ready: ready),
        ]),
        initialState: ready,
      );

      // pumpAndSettle avancerait le temps virtuel jusqu'à la disparition de la
      // snackbar (durée par défaut 4s) — on pompe image par image à la place.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => DonyPaymentSheet.show(
                ctx,
                config: _config,
                contextLabel: 'Envoi vers Dakar',
                onSuccess: () {},
                bloc: bloc,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Paiement refusé'), findsOneWidget);
    });
  });
}
