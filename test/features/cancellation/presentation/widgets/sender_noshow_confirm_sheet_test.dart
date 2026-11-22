import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:dony/features/cancellation/presentation/widgets/sender_noshow_confirm_sheet.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../cancellation_fee_test_support.dart';

class _MockPreviewRepository extends Mock implements CancellationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ACCEPTED',
  BidPaymentMethod method = BidPaymentMethod.stripe,
  DateTime? createdAt,
}) => BidModel(
  id: 'bid-ns',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  paymentMethod: method,
  cancellationNoShowStatus: 'PENDING_CONFIRMATION',
  createdAt: createdAt ?? kCoveredCreatedAt,
  updatedAt: kCoveredCreatedAt,
);

void main() {
  late _MockPreviewRepository previewRepository;
  bool? result;

  setUp(() {
    result = null;
    previewRepository = _MockPreviewRepository();
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<CancellationFeePreviewCubit>(
      () => CancellationFeePreviewCubit(previewRepository, analytics),
    );
  });

  tearDown(getIt.reset);

  Future<void> open(
    WidgetTester tester,
    BidModel bid, {
    Locale locale = AppL10n.fr,
  }) async {
    // 360 dp de large.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSenderNoShowConfirmSheet(context, bid: bid);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder confirmButton(AppLocalizations l) => find.descendant(
    of: find.byKey(const Key('donyBottomSheetFooter')),
    matching: find.text(l.bidDetailSenderConfirmSheetButton),
  );

  /// Libellé du bouton sur une ligne, à sa taille, sans débordement.
  void expectButtonFits(WidgetTester tester, AppLocalizations l) {
    expect(tester.takeException(), isNull);
    final label = confirmButton(l);
    expect(label, findsOneWidget);
    final size = tester.getSize(label);
    final style = tester.widget<Text>(label).style;
    expect(size.height, lessThan((style?.fontSize ?? 15) * 2));
  }

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    final l = lookupAppLocalizations(locale);
    final lang = locale.languageCode;

    group('[$lang] colis non couvert : la feuille d\'avant', () {
      testWidgets('sans configuration (cubit absent) : texte d\'avant, aucun '
          'aperçu lu', (tester) async {
        await open(tester, _bid(), locale: locale);

        expect(find.text(l.bidDetailSenderConfirmSheetTitle), findsOneWidget);
        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsOneWidget);
        expect(
          find.text(l.bidDetailSenderConfirmSheetBodyWithFee),
          findsNothing,
        );
        expectButtonFits(tester, l);

        await tester.tap(confirmButton(l));
        await tester.pumpAndSettle();
        expect(result, isTrue);
        verifyNever(() => previewRepository.getFeePreview(any()));
      });

      testWidgets('back antérieur (404) : texte d\'avant', (tester) async {
        await registerFeeConfig();
        await open(tester, _bid(), locale: locale);

        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsOneWidget);
        expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
        verifyNever(() => previewRepository.getFeePreview(any()));
      });

      testWidgets('frais allumés, colis antérieur à la date d\'effet : texte '
          'd\'avant', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await open(
          tester,
          _bid(createdAt: DateTime.utc(2026, 12, 2)),
          locale: locale,
        );

        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsOneWidget);
        verifyNever(() => previewRepository.getFeePreview(any()));
      });

      testWidgets('frais allumés, espèces : texte d\'avant', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await open(tester, _bid(method: BidPaymentMethod.cash), locale: locale);

        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsOneWidget);
        verifyNever(() => previewRepository.getFeePreview(any()));
      });
    });

    group('[$lang] colis couvert', () {
      String eur(double v) =>
          CurrencyFormatter.format(v, SupportedCurrency.eur);

      testWidgets('frais > 0 : texte des frais et bloc de l\'aperçu, puis '
          'confirmation', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        when(() => previewRepository.getFeePreview('bid-ns')).thenAnswer(
          (_) async => const CancellationFeePreviewModel(
            rate: 0.2,
            fee: 9,
            refundAmount: 36,
            currency: 'EUR',
          ),
        );
        await open(tester, _bid(), locale: locale);

        expect(
          find.text(l.bidDetailSenderConfirmSheetBodyWithFee),
          findsOneWidget,
        );
        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsNothing);
        expect(find.byKey(const Key('cancel-fee-notice')), findsOneWidget);
        expect(find.text(l.cancelFeeRetained(eur(9))), findsOneWidget);
        expect(find.text(l.cancelFeeRefunded(eur(36))), findsOneWidget);
        expectButtonFits(tester, l);

        await tester.tap(confirmButton(l));
        await tester.pumpAndSettle();
        expect(result, isTrue);
        verify(() => previewRepository.getFeePreview('bid-ns')).called(1);
      });

      testWidgets('aperçu indisponible (404) : texte des frais seul, '
          'confirmation possible', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        when(() => previewRepository.getFeePreview('bid-ns')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/fee-preview'),
            error: const NotFoundException(),
          ),
        );
        await open(tester, _bid(), locale: locale);

        expect(
          find.text(l.bidDetailSenderConfirmSheetBodyWithFee),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);

        await tester.tap(confirmButton(l));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });

      testWidgets(
        'aucun frais (fenêtre gratuite) : texte des frais sans bloc',
        (tester) async {
          await registerFeeConfig(config: kActiveFeeConfig);
          when(() => previewRepository.getFeePreview('bid-ns')).thenAnswer(
            (_) async => const CancellationFeePreviewModel(
              rate: 0,
              fee: 0,
              refundAmount: 45,
              currency: 'EUR',
            ),
          );
          await open(tester, _bid(), locale: locale);

          expect(
            find.text(l.bidDetailSenderConfirmSheetBodyWithFee),
            findsOneWidget,
          );
          expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
        },
      );
    });
  }

  testWidgets('colis couvert mais pas accepté : texte des frais, aucun aperçu '
      'lu', (tester) async {
    final l = lookupAppLocalizations(AppL10n.fr);
    await registerFeeConfig(config: kActiveFeeConfig);
    await open(tester, _bid(status: 'HANDED_OVER'));

    expect(find.text(l.bidDetailSenderConfirmSheetBodyWithFee), findsOneWidget);
    await tester.tap(confirmButton(l));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    verifyNever(() => previewRepository.getFeePreview(any()));
  });

  testWidgets('lecture de l\'aperçu en cours : le bouton attend, puis '
      'confirme', (tester) async {
    final l = lookupAppLocalizations(AppL10n.fr);
    await registerFeeConfig(config: kActiveFeeConfig);
    final pending = Completer<CancellationFeePreviewModel>();
    when(
      () => previewRepository.getFeePreview('bid-ns'),
    ).thenAnswer((_) => pending.future);
    // pumpAndSettle ne rendrait jamais la main (indicateur de chargement).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSenderNoShowConfirmSheet(
                  context,
                  bid: _bid(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final button = tester.widget<DonyButton>(
      find.descendant(
        of: find.byKey(const Key('donyBottomSheetFooter')),
        matching: find.byType(DonyButton),
      ),
    );
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);

    pending.complete(
      const CancellationFeePreviewModel(
        rate: 0.3,
        fee: 13.5,
        refundAmount: 31.5,
        currency: 'EUR',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-fee-notice')), findsOneWidget);
    await tester.tap(confirmButton(l));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('feuille fermée sans confirmer : faux', (tester) async {
    await registerFeeConfig(config: kActiveFeeConfig);
    when(() => previewRepository.getFeePreview('bid-ns')).thenAnswer(
      (_) async => const CancellationFeePreviewModel(
        rate: 0.2,
        fee: 9,
        refundAmount: 36,
        currency: 'EUR',
      ),
    );
    await open(tester, _bid());

    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('palier passé, relecture ratée : avertissement, le second appui '
      'confirme', (tester) async {
    final l = lookupAppLocalizations(AppL10n.fr);
    await registerFeeConfig(config: kActiveFeeConfig);
    var calls = 0;
    when(() => previewRepository.getFeePreview('bid-ns')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        // Palier déjà passé : la confirmation relit l'aperçu.
        return CancellationFeePreviewModel(
          rate: 0.2,
          fee: 9,
          refundAmount: 36,
          currency: 'EUR',
          nextTierAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }
      throw const OfflineException();
    });
    await open(tester, _bid());

    await tester.tap(confirmButton(l));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'pas encore confirmé');
    expect(find.text(l.cancelFeeRecheckFailed), findsOneWidget);

    await tester.tap(confirmButton(l));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(calls, 2);
  });

  testWidgets('aucun frais, palier passé, relecture ratée : avertissement '
      'sans bloc des frais', (tester) async {
    final l = lookupAppLocalizations(AppL10n.fr);
    await registerFeeConfig(config: kActiveFeeConfig);
    var calls = 0;
    when(() => previewRepository.getFeePreview('bid-ns')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return CancellationFeePreviewModel(
          rate: 0,
          fee: 0,
          refundAmount: 45,
          currency: 'EUR',
          nextTierAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      }
      throw const OfflineException();
    });
    await open(tester, _bid());

    await tester.tap(confirmButton(l));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
    expect(find.text(l.cancelFeeRecheckFailed), findsOneWidget);
  });
}
