import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/presentation/widgets/payout_account_label.dart';
import 'package:dony/features/payments/presentation/widgets/payout_account_sheets.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _orange = MobileMoneyOperator(
  code: 'ORANGE_CIV',
  label: 'Orange Money',
  brand: 'ORANGE',
);

const _account = MobileMoneyPayoutAccount(
  id: 'a1',
  provider: 'ORANGE_CIV',
  providerLabel: 'Orange Money',
  brand: 'ORANGE',
  country: 'CI',
  currency: 'XOF',
  msisdnMasked: '+225 •••• 56',
);

/// Ouvre une feuille depuis un bouton et range son résultat dans [results].
Widget _host(
  Future<Object?> Function(BuildContext context) open,
  List<Object?> results, {
  Locale locale = AppL10n.fr,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => results.add(await open(context)),
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('PayoutNumberReviewSheet', () {
    Future<Object?> review(BuildContext context) =>
        PayoutNumberReviewSheet.show(
          context,
          operator: _orange,
          countryCode: 'CI',
          e164: '+2250748840856',
        );

    testWidgets('titre, texte, numéro groupé, opérateur et pays', (
      tester,
    ) async {
      await tester.pumpWidget(_host(review, []));
      await _open(tester);

      expect(find.text("C'est bien votre numéro ?"), findsOneWidget);
      expect(
        find.text(
          'Vos gains seront envoyés ici. Un chiffre faux et l\'argent part '
          'chez quelqu\'un d\'autre.',
        ),
        findsOneWidget,
      );
      expect(find.byType(DonyBrandMark), findsOneWidget);
      expect(find.text('+225 07 48 84 08 56'), findsOneWidget);
      expect(find.text("Orange Money · Côte d'Ivoire"), findsOneWidget);
      expect(find.text("Oui, c'est mon numéro"), findsOneWidget);
      expect(find.text('Corriger'), findsOneWidget);
    });

    testWidgets('« Oui » rend true', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(_host(review, results));
      await _open(tester);

      await tester.tap(find.byKey(const Key('payout-review-confirm')));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('« Corriger » rend false', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(_host(review, results));
      await _open(tester);

      await tester.tap(find.byKey(const Key('payout-review-edit')));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('anglais', (tester) async {
      await tester.pumpWidget(_host(review, [], locale: AppL10n.en));
      await _open(tester);

      expect(find.text('Is this your number?'), findsOneWidget);
      expect(find.text("Yes, it's my number"), findsOneWidget);
      expect(find.text("Orange Money · Côte d'Ivoire"), findsOneWidget);
    });

    testWidgets('thème sombre, 360 px : aucun débordement', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(review, [], theme: AppTheme.dark()));
      await _open(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('PayoutAccountRemoveSheet', () {
    testWidgets('textes, « Retirer ce compte » rend true', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        _host(
          (c) => PayoutAccountRemoveSheet.show(c, account: _account),
          results,
        ),
      );
      await _open(tester);

      expect(find.text('Retirer Orange Money ?'), findsOneWidget);
      expect(
        find.text(
          'Les expéditeurs ne pourront plus vous payer avec Orange '
          'Money.',
        ),
        findsOneWidget,
      );
      final confirm = tester.widget<DonyButton>(
        find.byKey(const Key('payout-remove-confirm')),
      );
      expect(confirm.variant, DonyButtonVariant.destructive);
      await tester.tap(find.byKey(const Key('payout-remove-confirm')));
      await tester.pumpAndSettle();

      expect(results, [true]);
    });

    testWidgets('« Annuler » rend false', (tester) async {
      final results = <Object?>[];
      await tester.pumpWidget(
        _host(
          (c) => PayoutAccountRemoveSheet.show(c, account: _account),
          results,
        ),
      );
      await _open(tester);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(results, [false]);
    });

    testWidgets('libellé distinct (« Orange CI ») quand il est fourni', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => PayoutAccountRemoveSheet.show(
            c,
            account: _account,
            label: 'Orange CI',
          ),
          [],
        ),
      );
      await _open(tester);

      expect(find.text('Retirer Orange CI ?'), findsOneWidget);
    });
  });

  group('PayoutAccountLockedSheet', () {
    testWidgets('pluriel : « 2 colis attendent… »', (tester) async {
      await tester.pumpWidget(
        _host((c) => PayoutAccountLockedSheet.show(c, pendingPayouts: 2), []),
      );
      await _open(tester);

      expect(
        find.text('2 colis attendent encore leur versement sur ce compte.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Vous pourrez le retirer ou changer de numéro une fois le versement '
          'reçu.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      expect(find.text('Compris'), findsNothing);
    });

    testWidgets('singulier : « 1 colis attend… »', (tester) async {
      await tester.pumpWidget(
        _host((c) => PayoutAccountLockedSheet.show(c, pendingPayouts: 1), []),
      );
      await _open(tester);

      expect(
        find.text('1 colis attend encore son versement sur ce compte.'),
        findsOneWidget,
      );
    });

    testWidgets('anglais', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => PayoutAccountLockedSheet.show(c, pendingPayouts: 2),
          [],
          locale: AppL10n.en,
        ),
      );
      await _open(tester);

      expect(
        find.text(
          '2 parcels are still waiting for their payout on this account.',
        ),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsOneWidget);
    });
  });

  group('presentPayoutAccountFailure', () {
    testWidgets('409 verrouillé : feuille bloquée, au moins 1 colis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          (c) => presentPayoutAccountFailure(
            c,
            const ConflictException('x', code: 'mobile-money-account-locked'),
            pendingPayouts: 0,
          ),
          [],
        ),
      );
      await _open(tester);

      expect(
        find.text('1 colis attend encore son versement sur ce compte.'),
        findsOneWidget,
      );
    });

    testWidgets('autre erreur : message d\'erreur', (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => presentPayoutAccountFailure(
            c,
            const NetworkException('offline'),
            pendingPayouts: 2,
          ),
          [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('colis attend'), findsNothing);
    });
  });

  group('outils', () {
    test('isPayoutAccountLocked', () {
      expect(
        isPayoutAccountLocked(
          const ConflictException('x', code: 'mobile-money-account-locked'),
        ),
        isTrue,
      );
      expect(
        isPayoutAccountLocked(const ConflictException('x', code: 'other')),
        isFalse,
      );
      expect(isPayoutAccountLocked(const NetworkException('x')), isFalse);
      expect(isPayoutAccountLocked(null), isFalse);
    });

    test('groupPayoutNumber : paires, Sénégal, impair, inconnu', () {
      expect(groupPayoutNumber('CI', '+2250748840856'), '+225 07 48 84 08 56');
      expect(groupPayoutNumber('sn', '+221771234567'), '+221 77 123 45 67');
      expect(groupPayoutNumber('CM', '+237671234567'), '+237 671 23 45 67');
      expect(groupPayoutNumber('BJ', '+22961234567'), '+229 61 23 45 67');
      // Indicatif d'un autre pays, ou pays inconnu : rendu tel quel.
      expect(groupPayoutNumber('CI', '+221771234567'), '+221771234567');
      expect(groupPayoutNumber('ZZ', '+2250748840856'), '+2250748840856');
      expect(groupPayoutNumber('CI', '+225'), '+225');
      expect(groupPayoutNumber('CI', '+225123'), '+225 123');
    });

    test('payoutAccountLabel : marque et pays seulement en doublon', () {
      const sn = MobileMoneyPayoutAccount(
        id: 'a3',
        provider: 'ORANGE_SEN',
        providerLabel: 'Orange Money',
        brand: 'ORANGE',
        country: 'SN',
        currency: 'XOF',
        msisdnMasked: '',
      );
      const mtn = MobileMoneyPayoutAccount(
        id: 'a2',
        provider: 'MTN_MOMO_CIV',
        providerLabel: 'MTN MoMo',
        brand: 'MTN',
        country: 'CI',
        currency: 'XOF',
        msisdnMasked: '',
      );
      expect(
        payoutAccountLabel(_account, const [_account, mtn]),
        'Orange Money',
      );
      expect(payoutAccountLabel(_account, const [_account, sn]), 'Orange CI');
      expect(payoutAccountLabel(sn, const [_account, sn]), 'Orange SN');
      expect(payoutAccountLabel(mtn, const [_account, sn, mtn]), 'MTN MoMo');
      expect(brandDisplayName('MTN'), 'MTN');
      expect(brandDisplayName('moov'), 'Moov');
    });
  });
}
