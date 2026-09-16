import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_confirm_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRefundRequestCubit extends MockCubit<WalletRefundRequestState>
    implements WalletRefundRequestCubit {}

void main() {
  late MockWalletRefundRequestCubit cubit;

  // `CurrencyFormatter` insère une espace insécable avant le symbole : on
  // construit l'attendu à partir du formateur réel plutôt que de deviner
  // le séparateur exact.
  final expectedButtonLabel =
      'Rembourser ${CurrencyFormatter.format(35, SupportedCurrency.eur)}';

  setUp(() {
    cubit = MockWalletRefundRequestCubit();
    when(() => cubit.state).thenReturn(const WalletRefundRequestState());
    when(() => cubit.submit(any(), any())).thenAnswer((_) async {});
  });

  Widget host({required double refundable, required double nonRefundable}) =>
      MaterialApp(
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
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

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
}
