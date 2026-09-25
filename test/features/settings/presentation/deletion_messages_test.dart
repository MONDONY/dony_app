import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/deletion_eligibility_cubit.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:dony/features/settings/presentation/deletion_labels.dart';
import 'package:dony/features/settings/presentation/widgets/delete_account_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class MockAccountDeletionBloc
    extends MockBloc<AccountDeletionEvent, AccountDeletionState>
    implements AccountDeletionBloc {}

class MockDeletionEligibilityCubit extends MockCubit<DeletionEligibilityState>
    implements DeletionEligibilityCubit {}

WalletSettlement _rail({
  required String currency,
  required double net,
  double forfeited = 0,
}) => WalletSettlement(
  currency: currency,
  refundableAmount: net,
  forfeitedAmount: forfeited,
  inFlightAmount: 0,
  rail: 'STRIPE',
  feeAmount: 0,
  netAmount: net,
);

String _fmt(double amount, String currency) => CurrencyFormatter.format(
  amount,
  SupportedCurrency.fromCodeOrDefault(currency),
);

Future<void> _open(WidgetTester tester, DeletionEligibilityState state) async {
  final bloc = MockAccountDeletionBloc();
  when(() => bloc.state).thenReturn(const AccountDeletionInitial());
  final cubit = MockDeletionEligibilityCubit();
  when(() => cubit.state).thenReturn(state);
  when(() => cubit.check()).thenAnswer((_) async {});

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AccountDeletionBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => DeleteAccountBottomSheet.show(
                context,
                eligibilityCubit: cubit,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  // ── _SettlementBanner : un montant ──────────────────────────────────────

  group('_SettlementBanner — un montant', () {
    testWidgets('fr : identique à l\'ancien texte, sans bonus perdu', (
      tester,
    ) async {
      final eur = _fmt(35, 'EUR');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [_rail(currency: 'EUR', net: 35)],
        ),
      );

      expect(
        find.textContaining('$eur seront remboursés dès la demande.'),
        findsOneWidget,
      );
      expect(find.textContaining('de bonus'), findsNothing);
    });

    testWidgets('fr : avec bonus perdu, deux phrases complètes', (
      tester,
    ) async {
      final eur = _fmt(35, 'EUR');
      final bonus = _fmt(5, 'EUR');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [_rail(currency: 'EUR', net: 35, forfeited: 5)],
        ),
      );

      expect(
        find.textContaining(
          '$eur seront remboursés dès la demande. $bonus de bonus seront '
          'perdus définitivement à la suppression.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('en : un montant, sans bonus perdu', (tester) async {
      useEnglish();
      final eur = _fmt(35, 'EUR');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [_rail(currency: 'EUR', net: 35)],
        ),
      );

      expect(
        find.textContaining('$eur will be refunded as soon as you request it.'),
        findsOneWidget,
      );
    });

    testWidgets('en : avec bonus perdu, deux phrases complètes', (
      tester,
    ) async {
      useEnglish();
      final eur = _fmt(35, 'EUR');
      final bonus = _fmt(5, 'EUR');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [_rail(currency: 'EUR', net: 35, forfeited: 5)],
        ),
      );

      expect(
        find.textContaining(
          '$eur will be refunded as soon as you request it. $bonus in bonus '
          'will be permanently lost when the account is deleted.',
        ),
        findsOneWidget,
      );
    });
  });

  // ── _SettlementBanner : deux montants ───────────────────────────────────

  group('_SettlementBanner — deux montants', () {
    testWidgets('fr : joints par « et »', (tester) async {
      final eur = _fmt(35, 'EUR');
      final xof = _fmt(10000, 'XOF');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [
            _rail(currency: 'EUR', net: 35),
            _rail(currency: 'XOF', net: 10000),
          ],
        ),
      );

      expect(
        find.textContaining('$eur et $xof seront remboursés dès la demande.'),
        findsOneWidget,
      );
    });

    testWidgets('en : joints par « and »', (tester) async {
      useEnglish();
      final eur = _fmt(35, 'EUR');
      final xof = _fmt(10000, 'XOF');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [
            _rail(currency: 'EUR', net: 35),
            _rail(currency: 'XOF', net: 10000),
          ],
        ),
      );

      expect(
        find.textContaining(
          '$eur and $xof will be refunded as soon as you request it.',
        ),
        findsOneWidget,
      );
    });
  });

  // ── _SettlementBanner : trois montants ──────────────────────────────────

  group('_SettlementBanner — trois montants', () {
    testWidgets(
      'fr : tête jointe par des virgules puis « et » pour le dernier, avec '
      'bonus perdu sur une des devises',
      (tester) async {
        final eur = _fmt(35, 'EUR');
        final xof = _fmt(10000, 'XOF');
        final cad = _fmt(20, 'CAD');
        final bonus = _fmt(5, 'EUR');
        await _open(
          tester,
          DeletionEligibilityState(
            isLoading: false,
            hasWalletBalance: true,
            walletSettlement: [
              _rail(currency: 'EUR', net: 35, forfeited: 5),
              _rail(currency: 'XOF', net: 10000),
              _rail(currency: 'CAD', net: 20),
            ],
          ),
        );

        expect(
          find.textContaining(
            '$eur, $xof et $cad seront remboursés dès la demande. $bonus de '
            'bonus seront perdus définitivement à la suppression.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('en : trois montants, sans bonus perdu', (tester) async {
      useEnglish();
      final eur = _fmt(35, 'EUR');
      final xof = _fmt(10000, 'XOF');
      final cad = _fmt(20, 'CAD');
      await _open(
        tester,
        DeletionEligibilityState(
          isLoading: false,
          hasWalletBalance: true,
          walletSettlement: [
            _rail(currency: 'EUR', net: 35),
            _rail(currency: 'XOF', net: 10000),
            _rail(currency: 'CAD', net: 20),
          ],
        ),
      );

      expect(
        find.textContaining(
          '$eur, $xof, and $cad will be refunded as soon as you request it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('in bonus'), findsNothing);
    });
  });

  // ── deletionBlockedMessage ───────────────────────────────────────────────

  group('deletionBlockedMessage', () {
    test('active-transactions → message dédié (fr)', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        deletionBlockedMessage(l, 'active-transactions'),
        'Vous avez un envoi en cours de livraison, avec des fonds bloqués en '
        'séquestre. Vous pourrez supprimer votre compte dès que la livraison '
        'sera confirmée.',
      );
    });

    test('code inconnu → repli générique (fr)', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        deletionBlockedMessage(l, 'some-new-backend-code'),
        "La suppression n'est pas possible pour l'instant.",
      );
    });

    test('code absent (null) → repli générique (fr)', () {
      final l = lookupAppLocalizations(AppL10n.fr);
      expect(
        deletionBlockedMessage(l, null),
        "La suppression n'est pas possible pour l'instant.",
      );
    });

    test('active-transactions → message dédié (en)', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(
        deletionBlockedMessage(l, 'active-transactions'),
        'You have a shipment being delivered, with funds on hold. You can '
        'delete your account once the delivery is confirmed.',
      );
    });

    test('code inconnu → repli générique (en)', () {
      final l = lookupAppLocalizations(AppL10n.en);
      expect(
        deletionBlockedMessage(l, 'some-new-backend-code'),
        "Deletion isn't possible right now.",
      );
    });
  });

  // ── Motif de suppression : valeur de donnée envoyée au serveur ──────────

  group('DeleteAccountBottomSheet — motif de suppression', () {
    testWidgets('en anglais : le libellé est traduit mais la valeur envoyée au '
        'serveur reste le texte français', (tester) async {
      useEnglish();
      await _open(tester, const DeletionEligibilityState(isLoading: false));

      expect(find.text('I no longer use the service'), findsOneWidget);

      final group = tester.widget<DonyRadioGroup<String>>(
        find.byType(DonyRadioGroup<String>),
      );
      final notUsing = group.options.firstWhere(
        (o) => o.label == 'I no longer use the service',
      );
      expect(notUsing.value, "Je n'utilise plus le service");
    });
  });
}
