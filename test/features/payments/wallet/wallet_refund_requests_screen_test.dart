import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_requests_list_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/presentation/screens/wallet_refund_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRefundRequestsListCubit
    extends MockCubit<WalletRefundRequestsListState>
    implements WalletRefundRequestsListCubit {}

void main() {
  late MockWalletRefundRequestsListCubit cubit;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  setUp(() {
    cubit = MockWalletRefundRequestsListCubit();
    when(() => cubit.load()).thenAnswer((_) async {});
  });

  Widget host() => MaterialApp(
    home: BlocProvider<WalletRefundRequestsListCubit>.value(
      value: cubit,
      child: const WalletRefundRequestsScreen(),
    ),
  );

  void stub(WalletRefundRequestsListState state) {
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.stream).thenAnswer((_) => Stream.value(state));
  }

  testWidgets('affiche un indicateur de chargement', (tester) async {
    stub(const WalletRefundRequestsListState());

    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche le message vide sans demande', (tester) async {
    stub(const WalletRefundRequestsListState(isLoading: false));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Aucune demande de remboursement pour l\'instant.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ancien contrat (rail absent) : sous-titre limité à la date, aucun '
    'détail de frais',
    (tester) async {
      stub(
        WalletRefundRequestsListState(
          isLoading: false,
          requests: [
            WalletRefundRequestModel(
              id: 'req-1',
              currency: 'EUR',
              amount: 40,
              channel: 'AUTOMATIC_STRIPE',
              status: 'PROCESSING',
              requestedAt: DateTime(2026, 8, 20),
            ),
          ],
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('20 août 2026'), findsOneWidget);
      expect(find.textContaining('remboursables'), findsNothing);
      expect(find.textContaining('Mobile money'), findsNothing);
      expect(find.textContaining('Carte'), findsNothing);
    },
  );

  testWidgets('rail pawaPay en cours avec destination connue : phrase de repli '
      'affichée avec le texte figé', (tester) async {
    stub(
      WalletRefundRequestsListState(
        isLoading: false,
        requests: [
          WalletRefundRequestModel(
            id: 'req-2',
            currency: 'XOF',
            amount: 5000,
            channel: 'MANUAL',
            status: 'PROCESSING',
            requestedAt: DateTime(2026, 9, 10),
            rail: 'PAWAPAY',
            destinationMasked: '+225 07 ** ** 89',
          ),
        ],
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('Mobile money'), findsOneWidget);
    expect(find.textContaining('+225 07 ** ** 89'), findsWidgets);
    expect(
      find.text(
        'Le remboursement part vers +225 07 ** ** 89. En cas de refus de '
        'l\'opérateur, l\'argent est renvoyé par un versement sur le même '
        'numéro.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'rail pawaPay terminé : pas de phrase de repli même avec destination',
    (tester) async {
      stub(
        WalletRefundRequestsListState(
          isLoading: false,
          requests: [
            WalletRefundRequestModel(
              id: 'req-3',
              currency: 'XOF',
              amount: 5000,
              channel: 'MANUAL',
              status: 'REFUNDED',
              requestedAt: DateTime(2026, 9, 10),
              resolvedAt: DateTime(2026, 9, 11),
              rail: 'PAWAPAY',
              destinationMasked: '+225 07 ** ** 89',
            ),
          ],
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('En cas de refus de l\'opérateur'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'rail STRIPE : sous-titre "Carte", aucune phrase de repli mobile money',
    (tester) async {
      stub(
        WalletRefundRequestsListState(
          isLoading: false,
          requests: [
            WalletRefundRequestModel(
              id: 'req-4',
              currency: 'EUR',
              amount: 35,
              channel: 'AUTOMATIC_STRIPE',
              status: 'PROCESSING',
              requestedAt: DateTime(2026, 9, 12),
              rail: 'STRIPE',
            ),
          ],
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.textContaining('Carte'), findsOneWidget);
      expect(
        find.textContaining('En cas de refus de l\'opérateur'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'feeAmount > 0 : détail "brut remboursables, frais retenus" affiché',
    (tester) async {
      stub(
        WalletRefundRequestsListState(
          isLoading: false,
          requests: [
            WalletRefundRequestModel(
              id: 'req-5',
              currency: 'EUR',
              amount: 35,
              channel: 'MANUAL',
              status: 'PROCESSING',
              requestedAt: DateTime(2026, 9, 12),
              rail: 'PAWAPAY',
              destinationMasked: '+225 07 ** ** 89',
              feeAmount: 3,
              netAmount: 32,
            ),
          ],
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.textContaining('remboursables'), findsOneWidget);
      expect(find.textContaining('de frais retenus'), findsOneWidget);
    },
  );

  testWidgets('feeAmount == 0 : pas de détail de frais', (tester) async {
    stub(
      WalletRefundRequestsListState(
        isLoading: false,
        requests: [
          WalletRefundRequestModel(
            id: 'req-6',
            currency: 'EUR',
            amount: 35,
            channel: 'MANUAL',
            status: 'PROCESSING',
            requestedAt: DateTime(2026, 9, 12),
            rail: 'PAWAPAY',
            destinationMasked: '+225 07 ** ** 89',
            feeAmount: 0,
            netAmount: 35,
          ),
        ],
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.textContaining('de frais retenus'), findsNothing);
  });

  testWidgets(
    'IMPORTANT — le montant mis en avant est le NET promis par la sheet, le '
    'brut restant lisible dans le détail des frais',
    (tester) async {
      stub(
        WalletRefundRequestsListState(
          isLoading: false,
          requests: [
            WalletRefundRequestModel(
              id: 'req-7',
              currency: 'EUR',
              amount: 35,
              channel: 'MANUAL',
              status: 'PROCESSING',
              requestedAt: DateTime(2026, 9, 12),
              rail: 'PAWAPAY',
              destinationMasked: '+225 07 ** ** 89',
              feeAmount: 3,
              netAmount: 32,
            ),
          ],
        ),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final gross = CurrencyFormatter.format(35, SupportedCurrency.eur);
      final net = CurrencyFormatter.format(32, SupportedCurrency.eur);
      final fee = CurrencyFormatter.format(3, SupportedCurrency.eur);

      expect(find.text(net), findsOneWidget);
      expect(
        find.text(
          '$gross remboursables, $fee de frais retenus, vous '
          'recevez $net',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('ancien contrat (netAmount absent) : le brut reste affiché', (
    tester,
  ) async {
    stub(
      WalletRefundRequestsListState(
        isLoading: false,
        requests: [
          WalletRefundRequestModel(
            id: 'req-8',
            currency: 'EUR',
            amount: 35,
            channel: 'MANUAL',
            status: 'PROCESSING',
            requestedAt: DateTime(2026, 9, 12),
          ),
        ],
      ),
    );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text(CurrencyFormatter.format(35, SupportedCurrency.eur)),
      findsOneWidget,
    );
  });
}
