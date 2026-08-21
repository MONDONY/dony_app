import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/presentation/widgets/wallet_refund_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRefundRequestCubit extends MockCubit<WalletRefundRequestState>
    implements WalletRefundRequestCubit {}

class _MockWalletEligibleTopupsCubit
    extends MockCubit<WalletEligibleTopupsState>
    implements WalletEligibleTopupsCubit {}

late _MockWalletEligibleTopupsCubit _currentTopupsCubit;

Widget _buildHarness(WalletRefundRequestCubit refundCubit) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider<WalletRefundRequestCubit>.value(
        value: refundCubit,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                WalletRefundSelectionSheet.show(context, currency: 'EUR'),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(
  WidgetTester tester,
  WalletRefundRequestCubit refundCubit,
) async {
  await tester.pumpWidget(_buildHarness(refundCubit));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  late _MockWalletRefundRequestCubit refundCubit;

  final topups = [
    WalletEligibleTopupModel(
      id: 'tx-1',
      amount: 30.00,
      paymentRef: 'pi_111',
      createdAt: DateTime(2026, 8, 20, 10, 30),
    ),
    WalletEligibleTopupModel(
      id: 'tx-2',
      amount: 20.00,
      paymentRef: 'pi_222',
      createdAt: DateTime(2026, 8, 21, 9),
    ),
  ];

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    if (!getIt.isRegistered<WalletEligibleTopupsCubit>()) {
      getIt.registerFactory<WalletEligibleTopupsCubit>(
        () => _currentTopupsCubit,
      );
    }
  });

  setUp(() {
    refundCubit = _MockWalletRefundRequestCubit();
    when(() => refundCubit.state).thenReturn(const WalletRefundRequestState());
    when(() => refundCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => refundCubit.close()).thenAnswer((_) async {});
    when(() => refundCubit.submit(any(), any())).thenAnswer((_) async {});

    _currentTopupsCubit = _MockWalletEligibleTopupsCubit();
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(const WalletEligibleTopupsState());
    when(
      () => _currentTopupsCubit.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => _currentTopupsCubit.close()).thenAnswer((_) async {});
    when(() => _currentTopupsCubit.load(any())).thenAnswer((_) async {});
  });

  testWidgets('affiche un spinner pendant le chargement', (tester) async {
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(const WalletEligibleTopupsState());

    // Pas de pumpAndSettle : le CircularProgressIndicator tourne en boucle
    // infinie tant que isLoading=true, pumpAndSettle ne se terminerait jamais.
    await tester.pumpWidget(_buildHarness(refundCubit));
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche les recharges éligibles avec montant et date', (
    tester,
  ) async {
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(WalletEligibleTopupsState(isLoading: false, topups: topups));

    await _openSheet(tester, refundCubit);

    expect(find.textContaining('30,00'), findsOneWidget);
    expect(find.textContaining('20,00'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets(
    'aucune recharge éligible affiche le message "Aucune recharge disponible"',
    (tester) async {
      when(
        () => _currentTopupsCubit.state,
      ).thenReturn(const WalletEligibleTopupsState(isLoading: false));

      await _openSheet(tester, refundCubit);

      expect(find.textContaining('Aucune recharge disponible'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets(
    'le bouton Rembourser reste désactivé tant qu\'aucune recharge n\'est cochée',
    (tester) async {
      when(
        () => _currentTopupsCubit.state,
      ).thenReturn(WalletEligibleTopupsState(isLoading: false, topups: topups));

      await _openSheet(tester, refundCubit);

      expect(find.text('Sélectionnez une recharge'), findsOneWidget);
      await tester.tap(find.text('Sélectionnez une recharge'));
      await tester.pump();

      verifyNever(() => refundCubit.submit(any(), any()));
    },
  );

  testWidgets(
    'cocher une recharge puis tap sur Rembourser soumet la sélection',
    (tester) async {
      when(
        () => _currentTopupsCubit.state,
      ).thenReturn(WalletEligibleTopupsState(isLoading: false, topups: topups));

      await _openSheet(tester, refundCubit);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(find.text('Rembourser (1)'), findsOneWidget);

      await tester.tap(find.text('Rembourser (1)'));
      await tester.pump();

      verify(() => refundCubit.submit('EUR', ['tx-1'])).called(1);
    },
  );

  testWidgets('la sheet se ferme (pop true) quand la demande aboutit', (
    tester,
  ) async {
    when(
      () => _currentTopupsCubit.state,
    ).thenReturn(WalletEligibleTopupsState(isLoading: false, topups: topups));
    final stateStream = Stream.fromIterable([
      WalletRefundRequestState(
        result: WalletRefundRequestModel(
          id: 'req-1',
          currency: 'EUR',
          amount: 30.00,
          channel: 'AUTOMATIC_STRIPE',
          status: 'PROCESSING',
          requestedAt: DateTime(2026, 8, 21),
        ),
      ),
    ]);
    when(() => refundCubit.stream).thenAnswer((_) => stateStream);

    bool? sheetResult;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BlocProvider<WalletRefundRequestCubit>.value(
            value: refundCubit,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  sheetResult = await WalletRefundSelectionSheet.show(
                    context,
                    currency: 'EUR',
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    // Le stream émet le résultat dès l'ouverture (Stream.fromIterable) : la
    // sheet se ferme dans le même pumpAndSettle que son animation d'entrée.
    await tester.pumpAndSettle();

    expect(find.text('Choisir une recharge'), findsNothing);
    expect(sheetResult, isTrue);
  });
}
