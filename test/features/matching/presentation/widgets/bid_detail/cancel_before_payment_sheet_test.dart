import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/cancel_before_payment_sheet.dart';
import 'package:dony/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid(BidPaymentMethod method) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'AWAITING_PAYMENT',
  paymentMethod: method,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Ouvre la feuille depuis un bouton et range son résultat dans [results].
Widget _host(
  BidModel bid,
  List<bool> results, {
  Locale locale = const Locale('fr'),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await CancelBeforePaymentSheet.show(context, bid: bid),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('confirmer rend true', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(_host(_bid(BidPaymentMethod.stripe), results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Annuler la demande ?'), findsOneWidget);
    expect(
      find.text(
        'La carte ne sera pas débitée. Si le voyageur avait vu votre demande, il sera prévenu.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancel-before-payment-confirm')));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('garder la demande rend false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(_host(_bid(BidPaymentMethod.stripe), results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-before-payment-keep')));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('fermer la feuille sans choisir rend false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(_host(_bid(BidPaymentMethod.stripe), results));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('en anglais, libellés traduits', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _host(
        _bid(BidPaymentMethod.mobileMoney),
        results,
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel the request?'), findsOneWidget);
    expect(
      find.text(
        'No payment will be taken. The traveler will be notified and the kilos freed up.',
      ),
      findsOneWidget,
    );
    expect(find.text('Yes, cancel the request'), findsOneWidget);
    expect(find.text('Keep the request'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('grand texte ×$scale : aucun débordement, boutons visibles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final results = <bool>[];
      await tester.pumpWidget(
        _host(_bid(BidPaymentMethod.mobileMoney), results, textScale: scale),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('cancel-before-payment-confirm')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cancel-before-payment-keep')).hitTestable(),
        findsOneWidget,
      );
    });
  }
}
