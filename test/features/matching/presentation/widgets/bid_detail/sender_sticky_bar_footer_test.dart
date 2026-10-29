import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Footer de la fiche colis (expéditeur) : un seul bouton, ou deux boutons sur
/// la même ligne (secondaire à gauche = 1/3, principal à droite = 2/3), sans
/// badge, sans phrase d'aide. Complète `sender_sticky_bar_test.dart`.
class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({
  String status = 'AWAITING_PAYMENT',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-footer-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PaymentModel _payment() => const PaymentModel(
  id: 'pay-1',
  bidId: 'bid-footer-1',
  amount: 182,
  commissionAmount: 21.84,
  status: PaymentStatus.escrow,
);

/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et tout libellé paraît rétréci.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late _MockBidBloc bloc;

  setUpAll(_loadAppFonts);

  setUp(() {
    bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
  });

  Future<void> pumpBar(
    WidgetTester tester,
    BidModel bid, {
    bool paymentLoaded = true,
    PaymentModel? existingPayment,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
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
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => BlocProvider<BidBloc>.value(
                value: bloc,
                child: Scaffold(
                  bottomNavigationBar: SenderStickyBar(
                    bid: bid,
                    isLoading: false,
                    paymentLoaded: paymentLoaded,
                    existingPayment: existingPayment,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // flutter_animate laisse des Timers : plusieurs pas courts.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  final cancelFinder = find.byKey(const Key('sender-cancel-before-payment'));

  group('ligne [Annuler | Payer] (AWAITING_PAYMENT)', () {
    for (final (name, bid, payLabel) in [
      (
        'mobile money',
        _bid(paymentMethod: BidPaymentMethod.mobileMoney),
        'Payer par mobile money',
      ),
      ('stripe', _bid(), 'Payer mon envoi'),
    ]) {
      testWidgets('$name : deux boutons sur une seule ligne, Annuler à gauche '
          'en 1/3, principal à droite en 2/3', (tester) async {
        await pumpBar(tester, bid);

        expect(find.byType(DonyButton), findsNWidgets(2));
        final cancel = find.widgetWithText(DonyButton, 'Annuler');
        final pay = find.widgetWithText(DonyButton, payLabel);
        expect(cancel, findsOneWidget);
        expect(pay, findsOneWidget);
        expect(cancelFinder, findsOneWidget);

        final cancelRect = tester.getRect(cancel);
        final payRect = tester.getRect(pay);
        // Même ligne
        expect(cancelRect.top, payRect.top);
        expect(cancelRect.height, 52);
        expect(payRect.height, 52);
        // Annuler à gauche, principal à droite
        expect(cancelRect.right, lessThan(payRect.left));
        // 1/3 – 2/3 : le principal fait le double d'Annuler
        expect(payRect.width, closeTo(cancelRect.width * 2, 0.5));
        // Aucune phrase d'aide ni badge au-dessus
        expect(find.textContaining('Paiement sécurisé'), findsNothing);
      });
    }

    testWidgets('tap sur Annuler ouvre la feuille de confirmation', (
      tester,
    ) async {
      await pumpBar(tester, _bid());

      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();

      expect(find.text('Annuler la demande ?'), findsOneWidget);
      expect(find.text('Oui, annuler la demande'), findsOneWidget);
    });
  });

  group('pas de badge « Paiement sécurisé »', () {
    for (final status in ['PENDING', 'ACCEPTED']) {
      testWidgets('$status avec un paiement séquestré : aucun badge', (
        tester,
      ) async {
        await pumpBar(
          tester,
          _bid(status: status),
          existingPayment: _payment(),
        );

        expect(find.textContaining('sécurisé'), findsNothing);
        expect(find.textContaining('Voyageur payé'), findsNothing);
      });
    }
  });

  testWidgets('hauteur du bouton de chargement = hauteur du bouton réel '
      '(aucun saut de mise en page)', (tester) async {
    await pumpBar(tester, _bid(status: 'PENDING'), paymentLoaded: false);
    final loadingHeight = tester.getSize(find.byType(SenderStickyBar)).height;
    expect(tester.getSize(find.byType(DonyButton)).height, 52);

    await pumpBar(tester, _bid(status: 'PENDING'));
    final loadedHeight = tester.getSize(find.byType(SenderStickyBar)).height;
    expect(loadedHeight, loadingHeight);
  });

  group('libellés à taille nominale (360 dp)', () {
    /// Rapport entre la largeur rendue du libellé dans le `FittedBox` du
    /// `DonyButton` et sa largeur naturelle : 1 = aucune réduction.
    double labelScale(WidgetTester tester, Finder button, String label) {
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    // « Annuler » (1/3 de 360 dp) tient à taille nominale dans les deux langues,
    // y compris à 1,3 en anglais.
    for (final (locale, scale) in const [
      (Locale('en'), 1.3),
      (Locale('fr'), 1.0),
    ]) {
      final l = lookupAppLocalizations(locale);
      for (final (name, bid) in [
        ('mobile money', _bid(paymentMethod: BidPaymentMethod.mobileMoney)),
        ('stripe', _bid()),
      ]) {
        testWidgets(
          '${locale.languageCode} x$scale ($name) : « ${l.commonCancel} » '
          'tient sans réduction',
          (tester) async {
            await pumpBar(tester, bid, locale: locale, textScale: scale);

            expect(tester.takeException(), isNull);
            expect(
              labelScale(tester, cancelFinder, l.commonCancel),
              closeTo(1, 0.001),
            );
          },
        );
      }
    }

    // Le principal (2/3 de 360 dp, sans icône dans la ligne) tient à taille
    // nominale, en français comme en anglais, à ×1,0.
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      for (final (name, bid, label) in [
        (
          'mobile money',
          _bid(paymentMethod: BidPaymentMethod.mobileMoney),
          l.bidDetailPayByMobileMoney,
        ),
        ('stripe', _bid(), l.bidDetailPayMyShipment),
      ]) {
        testWidgets(
          '${locale.languageCode} x1.0 ($name) : « $label » et « ${l.commonCancel} » '
          'tiennent à taille nominale',
          (tester) async {
            await pumpBar(tester, bid, locale: locale);

            expect(tester.takeException(), isNull);
            expect(
              labelScale(tester, cancelFinder, l.commonCancel),
              closeTo(1, 0.001),
              reason: l.commonCancel,
            );
            expect(
              labelScale(tester, find.widgetWithText(DonyButton, label), label),
              closeTo(1, 0.001),
              reason: label,
            );
          },
        );
      }
    }

    // ×1,3 (très grand texte) : LIMITE ACCEPTÉE, pas la règle. Les libellés
    // principaux rétrécissent dans le `FittedBox` du `DonyButton` ; le
    // garde-fou empêche seulement qu'ils deviennent illisibles. La règle
    // « taille nominale » est celle des tests à ×1,0 ci-dessus.
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);
      for (final (name, bid, label) in [
        (
          'mobile money',
          _bid(paymentMethod: BidPaymentMethod.mobileMoney),
          l.bidDetailPayByMobileMoney,
        ),
        ('stripe', _bid(), l.bidDetailPayMyShipment),
      ]) {
        testWidgets(
          '${locale.languageCode} x1.3 ($name) : « $label » reste lisible '
          '(réduction bornée)',
          (tester) async {
            await pumpBar(tester, bid, locale: locale, textScale: 1.3);

            expect(tester.takeException(), isNull);
            expect(
              labelScale(tester, find.widgetWithText(DonyButton, label), label),
              greaterThan(0.75),
            );
          },
        );
      }
    }
  });
}
