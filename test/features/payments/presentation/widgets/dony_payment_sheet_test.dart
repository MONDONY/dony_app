import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentSheetBloc
    extends MockBloc<PaymentSheetEvent, PaymentSheetState>
    implements PaymentSheetBloc {
  MockPaymentSheetBloc(this.config);

  @override
  final PaymentSheetConfig config;
}

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

  /// [settle] : false pour les états qui animent en continu (spinner du
  /// bouton Carte) — pumpAndSettle ne convergerait jamais, on borne les pumps.
  Future<void> openSheet(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      MaterialApp(
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
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
  }

  group('Vue principale — boutons conditionnels', () {
    testWidgets('sans wallet ni PayPal : seul le bouton Carte', (tester) async {
      when(() => bloc.state).thenReturn(
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: false,
        ),
      );

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetWalletButton')), findsNothing);
      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsNothing);
      expect(find.byKey(const Key('paymentSheetCardButton')), findsOneWidget);
      expect(find.text('Carte'), findsOneWidget);
    });

    testWidgets('avec PayPal disponible : bouton PayPal affiché', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: true,
        ),
      );

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetPayPalButton')), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      expect(find.byKey(const Key('paymentSheetCardButton')), findsOneWidget);
    });

    testWidgets('plus de section « Cartes enregistrées » ni de saisie inline', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: false,
        ),
      );

      await openSheet(tester);

      expect(find.text('Cartes enregistrées'), findsNothing);
      expect(find.text('Nouvelle carte'), findsNothing);
      expect(find.byKey(const Key('paymentSheetCardFormField')), findsNothing);
    });
  });

  group('Bouton Carte', () {
    testWidgets('tap dispatch PaymentSheetCardPressed', (tester) async {
      when(() => bloc.state).thenReturn(
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: false,
        ),
      );

      await openSheet(tester);
      await tester.tap(find.byKey(const Key('paymentSheetCardButton')));

      verify(() => bloc.add(const PaymentSheetCardPressed())).called(1);
    });

    testWidgets('désactivé pendant le traitement d\'un autre moyen', (
      tester,
    ) async {
      const ready = PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: true,
      );
      when(() => bloc.state).thenReturn(
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.paypal,
        ),
      );

      await openSheet(tester);

      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('paymentSheetCardButton')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
      // Le spinner n'apparaît que quand c'est le flux carte qui tourne.
      expect(
        find.byKey(const Key('paymentSheetCardButtonSpinner')),
        findsNothing,
      );
    });

    testWidgets('spinner + désactivé pendant le vol du flux carte', (
      tester,
    ) async {
      const ready = PaymentSheetResolved(
        walletAvailable: false,
        paypalAvailable: false,
      );
      when(() => bloc.state).thenReturn(
        const PaymentSheetProcessing(
          ready: ready,
          method: PaymentMethodKind.card,
        ),
      );

      await openSheet(tester, settle: false);

      expect(
        find.byKey(const Key('paymentSheetCardButtonSpinner')),
        findsOneWidget,
      );
      expect(find.text('Carte'), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const Key('paymentSheetCardButton')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Sticky bottom — plus de bouton « Payer »', () {
    testWidgets('aucun bouton Payer générique, uniquement la note sécurité', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        const PaymentSheetResolved(
          walletAvailable: false,
          paypalAvailable: false,
        ),
      );

      await openSheet(tester);

      expect(find.byKey(const Key('paymentSheetPayButton')), findsNothing);
      expect(find.text('Paiement sécurisé par Stripe'), findsOneWidget);
    });
  });

  group('Vue succès', () {
    testWidgets('affiche l\'encart escrow et le bouton de sortie', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(const PaymentSheetSuccess(method: PaymentMethodKind.card));

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
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Paiement refusé'), findsOneWidget);
    });
  });
}
