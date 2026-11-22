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
import 'package:dony/features/cancellation/presentation/widgets/sender_cancel_confirm_dialog.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements CancellationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _now = DateTime.utc(2026, 12, 4, 10);

BidModel _bid({DateTime? departureAt, String currency = 'EUR'}) => BidModel(
  id: 'bid-42',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 4,
  status: 'ACCEPTED',
  currency: currency,
  departureAt: departureAt,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

CancellationFeePreviewModel _fee({
  double rate = 0.2,
  double fee = 20,
  double refund = 80,
  String? currency = 'EUR',
  DateTime? nextTierAt,
  bool? capped,
}) => CancellationFeePreviewModel(
  rate: rate,
  fee: fee,
  refundAmount: refund,
  currency: currency,
  nextTierAt: nextTierAt,
  capped: capped,
);

String _eur(double v) => CurrencyFormatter.format(v, SupportedCurrency.eur);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late int confirmed;
  late DateTime now;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    confirmed = 0;
    now = _now;
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerFactory<CancellationFeePreviewCubit>(
      () => CancellationFeePreviewCubit(repo, analytics, clock: () => now),
    );
  });

  tearDown(getIt.reset);

  /// Ouvre le dialogue tel que l'app l'ouvre : après remise par défaut (corps
  /// avec frais et corps « frais inconnus »), ou avant remise
  /// (`afterHandover: false`, corps unique qui ne promet aucun remboursement).
  Future<AppLocalizations> open(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    BidModel? bid,
    bool afterHandover = true,
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = lookupAppLocalizations(locale);
    final target = bid ?? _bid(departureAt: _now.add(const Duration(days: 2)));
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => afterHandover
                        ? showSenderCancelConfirmDialog(
                            context,
                            bid: target,
                            title: l.bidDetailCancelAfterHandoverTitle,
                            body: l.bidDetailCancelAfterHandoverBody,
                            bodyWithFee:
                                l.bidDetailCancelAfterHandoverBodyWithFee,
                            bodyUnknownFee:
                                l.bidDetailCancelAfterHandoverBodyUnknownFee,
                            onConfirmed: () => confirmed++,
                          )
                        : showSenderCancelConfirmDialog(
                            context,
                            bid: target,
                            title: l.bidDetailCancelRequestLabel,
                            body: l.bidDetailCancelConfirmBody,
                            onConfirmed: () => confirmed++,
                          ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return l;
  }

  Future<void> tapConfirm(WidgetTester tester) async {
    await tester.tap(find.byKey(SenderCancelConfirmDialog.confirmButtonKey));
    await tester.pumpAndSettle();
  }

  /// Libellé du bouton de confirmation sur une ligne, à la taille du thème.
  void expectConfirmOnOneLine(WidgetTester tester, AppLocalizations l) {
    expect(tester.takeException(), isNull);
    final label = find.text(l.bidDetailConfirmCancelButton);
    expect(label, findsOneWidget);
    final style = tester.widget<Text>(label).style;
    final fontSize = style?.fontSize ?? 14;
    expect(tester.getSize(label).height, lessThan(fontSize * 2));
    final button = tester.getSize(
      find.byKey(SenderCancelConfirmDialog.confirmButtonKey),
    );
    expect(button.height, lessThan(60));
  }

  void expectNoFeeBlock(WidgetTester tester, AppLocalizations l) {
    expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
    expect(find.text(l.cancelFeeLaterCostsMore), findsNothing);
    expect(find.text(l.bidDetailNo), findsOneWidget);
    expectConfirmOnOneLine(tester, l);
  }

  /// Après remise, aucun frais : le dialogue d'aujourd'hui, mot pour mot.
  void expectAfterHandoverToday(WidgetTester tester, AppLocalizations l) {
    expect(find.text(l.bidDetailCancelAfterHandoverTitle), findsOneWidget);
    expect(find.text(l.bidDetailCancelAfterHandoverBody), findsOneWidget);
    expect(find.text(l.bidDetailCancelAfterHandoverBodyWithFee), findsNothing);
    expect(
      find.text(l.bidDetailCancelAfterHandoverBodyUnknownFee),
      findsNothing,
    );
    expectNoFeeBlock(tester, l);
  }

  /// Après remise, frais inconnus : plus de « intégralement remboursé ».
  void expectAfterHandoverUnknownFee(WidgetTester tester, AppLocalizations l) {
    expect(find.text(l.bidDetailCancelAfterHandoverTitle), findsOneWidget);
    expect(
      find.text(l.bidDetailCancelAfterHandoverBodyUnknownFee),
      findsOneWidget,
    );
    expect(find.text(l.bidDetailCancelAfterHandoverBody), findsNothing);
    expect(find.text(l.bidDetailCancelAfterHandoverBodyWithFee), findsNothing);
    expectNoFeeBlock(tester, l);
  }

  /// Avant remise : son corps ne promet aucun remboursement, il ne change pas.
  void expectBeforeHandoverToday(WidgetTester tester, AppLocalizations l) {
    expect(find.text(l.bidDetailCancelRequestLabel), findsOneWidget);
    expect(find.text(l.bidDetailCancelConfirmBody), findsOneWidget);
    expectNoFeeBlock(tester, l);
  }

  DioException notFound() => DioException(
    requestOptions: RequestOptions(path: '/x'),
    error: const NotFoundException(),
  );

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    final code = locale.languageCode;

    group('[$code] frais > 0', () {
      testWidgets('bloc des frais avec les montants formatés, puis confirme', (
        tester,
      ) async {
        when(() => repo.getFeePreview('bid-42')).thenAnswer(
          (_) async => _fee(nextTierAt: _now.add(const Duration(hours: 5))),
        );
        final l = await open(tester, locale: locale);

        expect(find.byKey(const Key('cancel-fee-notice')), findsOneWidget);
        expect(
          find.text(l.bidDetailCancelAfterHandoverBodyWithFee),
          findsOneWidget,
        );
        expect(find.text(l.bidDetailCancelAfterHandoverBody), findsNothing);
        expect(find.text(l.cancelFeeRetained(_eur(20))), findsOneWidget);
        expect(find.text(l.cancelFeeRefunded(_eur(80))), findsOneWidget);
        expect(find.text(l.cancelFeeReasonDays(2, 20)), findsOneWidget);
        expect(find.text(l.cancelFeeLaterCostsMore), findsOneWidget);
        expect(find.text(l.cancelFeeIncreased), findsNothing);
        expect(find.text(l.cancelFeeRecheckFailed), findsNothing);
        expectConfirmOnOneLine(tester, l);

        await tapConfirm(tester);

        expect(confirmed, 1);
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('palier le plus cher : pas de mention de hausse', (
        tester,
      ) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee(rate: 0.3, fee: 30, refund: 70));
        final l = await open(
          tester,
          locale: locale,
          bid: _bid(departureAt: _now.add(const Duration(hours: 5))),
        );

        expect(find.text(l.cancelFeeRetained(_eur(30))), findsOneWidget);
        expect(find.text(l.cancelFeeReasonHours(5, 30)), findsOneWidget);
        expect(find.text(l.cancelFeeLaterCostsMore), findsNothing);
        expectConfirmOnOneLine(tester, l);
      });

      testWidgets('plafond : 200 € à 20 %, frais de 30 € plafonnés, pas de '
          '« 20 % du montant payé »', (tester) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee(fee: 30, refund: 170));
        final l = await open(tester, locale: locale);

        expect(find.text(l.cancelFeeRetained(_eur(30))), findsOneWidget);
        expect(find.text(l.cancelFeeRefunded(_eur(170))), findsOneWidget);
        expect(
          find.text(
            '${l.cancelFeeLeavesInDays(2)} ${l.cancelFeeCapped(_eur(30))}',
          ),
          findsOneWidget,
        );
        expect(find.text(l.cancelFeeReasonDays(2, 20)), findsNothing);
        expectConfirmOnOneLine(tester, l);
      });

      testWidgets('`capped: true` du serveur : même texte plafonné', (
        tester,
      ) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee(fee: 30, refund: 170, capped: true));
        final l = await open(tester, locale: locale);

        expect(
          find.text(
            '${l.cancelFeeLeavesInDays(2)} ${l.cancelFeeCapped(_eur(30))}',
          ),
          findsOneWidget,
        );
        expect(find.text(l.cancelFeeReasonDays(2, 20)), findsNothing);
      });

      testWidgets('`capped: false` du serveur : « 20 % du montant payé »', (
        tester,
      ) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee(fee: 30, refund: 170, capped: false));
        final l = await open(tester, locale: locale);

        expect(find.text(l.cancelFeeReasonDays(2, 20)), findsOneWidget);
        expect(find.text(l.cancelFeeCapped(_eur(30))), findsNothing);
      });

      testWidgets('« Non » ferme sans annuler', (tester) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee());
        final l = await open(tester, locale: locale);
        await tester.tap(find.text(l.bidDetailNo));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(confirmed, 0);
      });

      testWidgets('palier passé, relecture ratée : avertissement, puis le '
          'second appui annule', (tester) async {
        final next = _now.add(const Duration(minutes: 10));
        var calls = 0;
        when(() => repo.getFeePreview('bid-42')).thenAnswer((_) async {
          calls++;
          if (calls == 1) return _fee(nextTierAt: next);
          throw const OfflineException();
        });
        final l = await open(tester, locale: locale);
        expect(find.text(l.cancelFeeRecheckFailed), findsNothing);

        now = next.add(const Duration(seconds: 1));
        await tapConfirm(tester);

        expect(confirmed, 0);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(l.cancelFeeRecheckFailed), findsOneWidget);
        expect(find.text(l.cancelFeeRetained(_eur(20))), findsOneWidget);
        expectConfirmOnOneLine(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
        expect(calls, 2);
      });

      testWidgets('téléphone en retard (palier dans 1 minute) : montant relu, '
          'hausse montrée avant d\'annuler', (tester) async {
        final next = _now.add(const Duration(minutes: 10));
        var calls = 0;
        when(() => repo.getFeePreview('bid-42')).thenAnswer((_) async {
          calls++;
          return calls == 1
              ? _fee(nextTierAt: next)
              : _fee(rate: 0.3, fee: 30, refund: 70);
        });
        final l = await open(tester, locale: locale);

        now = next.subtract(const Duration(minutes: 1));
        await tapConfirm(tester);

        expect(calls, 2);
        expect(confirmed, 0);
        expect(find.text(l.cancelFeeIncreased), findsOneWidget);
        expect(find.text(l.cancelFeeRetained(_eur(30))), findsOneWidget);
        expectConfirmOnOneLine(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
      });
    });

    group('[$code] aucun frais ou frais inconnus', () {
      testWidgets('aucun frais (fonction éteinte) : dialogue d\'aujourd\'hui', (
        tester,
      ) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenAnswer((_) async => _fee(rate: 0, fee: 0, refund: 100));
        final l = await open(tester, locale: locale);
        expectAfterHandoverToday(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
      });

      testWidgets('fenêtre gratuite : 0 € avec une hausse annoncée', (
        tester,
      ) async {
        when(() => repo.getFeePreview('bid-42')).thenAnswer(
          (_) async => _fee(
            rate: 0,
            fee: 0,
            refund: 100,
            nextTierAt: _now.add(const Duration(days: 1)),
          ),
        );
        final l = await open(tester, locale: locale);
        expectAfterHandoverToday(tester, l);
      });

      testWidgets('après remise, back antérieur (404) : « moins d\'éventuels '
          'frais », annulation possible', (tester) async {
        when(() => repo.getFeePreview('bid-42')).thenThrow(notFound());
        final l = await open(tester, locale: locale);
        expectAfterHandoverUnknownFee(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
      });

      testWidgets(
        'après remise, erreur réseau : « moins d\'éventuels frais »',
        (tester) async {
          when(
            () => repo.getFeePreview('bid-42'),
          ).thenThrow(const OfflineException());
          final l = await open(tester, locale: locale);
          expectAfterHandoverUnknownFee(tester, l);
        },
      );

      testWidgets('avant remise, back antérieur (404) : dialogue '
          'd\'aujourd\'hui, annulation possible', (tester) async {
        when(() => repo.getFeePreview('bid-42')).thenThrow(notFound());
        final l = await open(tester, locale: locale, afterHandover: false);
        expectBeforeHandoverToday(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
      });

      testWidgets('avant remise, erreur réseau : dialogue d\'aujourd\'hui', (
        tester,
      ) async {
        when(
          () => repo.getFeePreview('bid-42'),
        ).thenThrow(const OfflineException());
        final l = await open(tester, locale: locale, afterHandover: false);
        expectBeforeHandoverToday(tester, l);
      });

      testWidgets('fenêtre gratuite, palier passé, relecture ratée : corps '
          '« frais inconnus » et avertissement, puis annulation', (
        tester,
      ) async {
        final next = _now.add(const Duration(minutes: 10));
        var calls = 0;
        when(() => repo.getFeePreview('bid-42')).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return _fee(rate: 0, fee: 0, refund: 100, nextTierAt: next);
          }
          throw const OfflineException();
        });
        final l = await open(tester, locale: locale);
        expectAfterHandoverToday(tester, l);

        now = next.add(const Duration(seconds: 1));
        await tapConfirm(tester);

        expect(confirmed, 0);
        expect(
          find.text(l.bidDetailCancelAfterHandoverBodyUnknownFee),
          findsOneWidget,
        );
        expect(find.text(l.cancelFeeRecheckFailed), findsOneWidget);
        expect(find.byKey(const Key('cancel-fee-notice')), findsNothing);
        expectConfirmOnOneLine(tester, l);

        await tapConfirm(tester);
        expect(confirmed, 1);
      });
    });
  }

  testWidgets('lecture en cours : bouton en attente, puis libre', (
    tester,
  ) async {
    final completer = Completer<CancellationFeePreviewModel>();
    when(
      () => repo.getFeePreview('bid-42'),
    ).thenAnswer((_) => completer.future);
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = lookupAppLocalizations(AppL10n.fr);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showSenderCancelConfirmDialog(
                      context,
                      bid: _bid(),
                      title: l.bidDetailCancelRequestLabel,
                      body: l.bidDetailCancelConfirmBody,
                      onConfirmed: () => confirmed++,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Le libellé reste en place (largeur du bouton, lecteur d'écran).
    expect(find.text(l.bidDetailConfirmCancelButton), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(SenderCancelConfirmDialog.confirmButtonKey),
    );
    expect(button.onPressed, isNull);
    expect(find.text(l.bidDetailCancelConfirmBody), findsOneWidget);

    completer.complete(_fee());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(SenderCancelConfirmDialog.confirmButtonKey),
          )
          .onPressed,
      isNotNull,
    );
    // Sans corps « avec frais », le corps d'origine reste au-dessus du bloc.
    expect(find.text(l.bidDetailCancelConfirmBody), findsOneWidget);
    expect(find.byKey(const Key('cancel-fee-notice')), findsOneWidget);
  });

  testWidgets(
    'palier passé pendant que le dialogue est ouvert : nouveau montant, '
    'seconde confirmation',
    (tester) async {
      final next = _now.add(const Duration(minutes: 10));
      var calls = 0;
      when(() => repo.getFeePreview('bid-42')).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _fee(nextTierAt: next)
            : _fee(rate: 0.3, fee: 30, refund: 70);
      });
      final l = await open(
        tester,
        bid: _bid(departureAt: _now.add(const Duration(hours: 20))),
      );
      expect(find.text(l.cancelFeeRetained(_eur(20))), findsOneWidget);

      now = next.add(const Duration(seconds: 1));
      await tester.tap(find.byKey(SenderCancelConfirmDialog.confirmButtonKey));
      await tester.pumpAndSettle();

      expect(confirmed, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l.cancelFeeIncreased), findsOneWidget);
      expect(find.text(l.cancelFeeRetained(_eur(30))), findsOneWidget);
      expect(find.text(l.cancelFeeRefunded(_eur(70))), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(SenderCancelConfirmDialog.confirmButtonKey));
      await tester.pumpAndSettle();
      expect(confirmed, 1);
      expect(calls, 2);
    },
  );

  group('pourquoi ce taux', () {
    Future<AppLocalizations> openWith(
      WidgetTester tester,
      DateTime? departureAt,
    ) async {
      when(
        () => repo.getFeePreview('bid-42'),
      ).thenAnswer((_) async => _fee(rate: 0.3, fee: 30, refund: 70));
      return open(tester, bid: _bid(departureAt: departureAt));
    }

    testWidgets('départ dans 1 jour', (tester) async {
      final l = await openWith(
        tester,
        _now.add(const Duration(days: 1, hours: 3)),
      );
      expect(find.text(l.cancelFeeReasonDays(1, 30)), findsOneWidget);
    });

    testWidgets('départ dans moins d\'une heure', (tester) async {
      final l = await openWith(tester, _now.add(const Duration(minutes: 20)));
      expect(find.text(l.cancelFeeReasonSoon(30)), findsOneWidget);
    });

    testWidgets('départ passé : taux seul', (tester) async {
      final l = await openWith(tester, _now.subtract(const Duration(hours: 1)));
      expect(find.text(l.cancelFeeReasonRate(30)), findsOneWidget);
    });

    testWidgets('départ inconnu : taux seul', (tester) async {
      final l = await openWith(tester, null);
      expect(find.text(l.cancelFeeReasonRate(30)), findsOneWidget);
    });

    // 200 € payés à 30 % = 60 € ; frais de 30 € : plafond.
    Future<AppLocalizations> openCapped(
      WidgetTester tester,
      DateTime? departureAt,
    ) async {
      when(
        () => repo.getFeePreview('bid-42'),
      ).thenAnswer((_) async => _fee(rate: 0.3, fee: 30, refund: 170));
      return open(tester, bid: _bid(departureAt: departureAt));
    }

    testWidgets('plafond, départ dans moins d\'une heure', (tester) async {
      final l = await openCapped(tester, _now.add(const Duration(minutes: 20)));
      expect(
        find.text('${l.cancelFeeLeavesSoon} ${l.cancelFeeCapped(_eur(30))}'),
        findsOneWidget,
      );
    });

    testWidgets('plafond, départ inconnu : plafond seul', (tester) async {
      final l = await openCapped(tester, null);
      expect(find.text(l.cancelFeeCapped(_eur(30))), findsOneWidget);
      expect(find.text(l.cancelFeeReasonRate(30)), findsNothing);
    });
  });

  testWidgets('franc CFA, devise absente de l\'aperçu : devise du colis', (
    tester,
  ) async {
    when(() => repo.getFeePreview('bid-42')).thenAnswer(
      (_) async => _fee(rate: 0.3, fee: 19678, refund: 45922, currency: null),
    );
    final l = await open(
      tester,
      bid: _bid(
        currency: 'XOF',
        departureAt: _now.add(const Duration(hours: 3)),
      ),
    );
    String xof(double v) => CurrencyFormatter.format(v, SupportedCurrency.xof);
    expect(find.text(l.cancelFeeRetained(xof(19678))), findsOneWidget);
    expect(find.text(l.cancelFeeRefunded(xof(45922))), findsOneWidget);
    expect(xof(19678), isNot(contains(',')));
    // 65 600 F × 30 % = 19 680 F ; 19 678 F : le plafond de 30 € converti.
    expect(
      find.text(
        '${l.cancelFeeLeavesInHours(3)} ${l.cancelFeeCapped(xof(19678))}',
      ),
      findsOneWidget,
    );
    expect(find.text(l.cancelFeeReasonHours(3, 30)), findsNothing);
  });

  testWidgets('rien à rendre : pas de ligne « remboursé de 0 »', (
    tester,
  ) async {
    when(
      () => repo.getFeePreview('bid-42'),
    ).thenAnswer((_) async => _fee(refund: 0));
    final l = await open(tester);
    expect(find.text(l.cancelFeeRetained(_eur(20))), findsOneWidget);
    expect(find.text(l.cancelFeeRefunded(_eur(0))), findsNothing);
  });

  testWidgets('mode sombre : aucun débordement', (tester) async {
    when(() => repo.getFeePreview('bid-42')).thenAnswer(
      (_) async => _fee(nextTierAt: _now.add(const Duration(days: 1))),
    );
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final l = lookupAppLocalizations(AppL10n.en);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        locale: AppL10n.en,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showSenderCancelConfirmDialog(
                      context,
                      bid: _bid(departureAt: _now.add(const Duration(days: 3))),
                      title: l.bidDetailCancelRequestLabel,
                      body: l.bidDetailCancelConfirmBody,
                      onConfirmed: () => confirmed++,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-fee-notice')), findsOneWidget);
    expectConfirmOnOneLine(tester, l);
  });
}
