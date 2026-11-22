import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_preview_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/sender_cancel_confirm_dialog.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 12, 4, 10);

final _bid = BidModel(
  id: 'bid-42',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 4,
  status: 'ACCEPTED',
  departureAt: _now.add(const Duration(days: 2)),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _withFee = CancellationFeePreviewModel(
  rate: 0.2,
  fee: 20,
  refundAmount: 80,
  currency: 'EUR',
);

const _noFee = CancellationFeePreviewModel(
  rate: 0,
  fee: 0,
  refundAmount: 100,
  currency: 'EUR',
);

const _bodyKey = Key('section-body');
const _noticeKey = Key('cancel-fee-notice');

Future<void> _pump(
  WidgetTester tester,
  CancellationFeePreviewState state, {
  bool scrollable = false,
  bool disableAnimations = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    locale: AppL10n.fr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: CancellationFeePreviewSection(
          state: state,
          bid: _bid,
          scrollable: scrollable,
          body: const Text('corps', key: _bodyKey),
        ),
      ),
    ),
  ),
);

AppLocalizations get _l => lookupAppLocalizations(AppL10n.fr);

void main() {
  testWidgets('lecture en cours ou aperçu illisible : le corps seul', (
    tester,
  ) async {
    await _pump(tester, const CancellationFeePreviewLoading());
    expect(find.byKey(_bodyKey), findsOneWidget);
    expect(find.byKey(_noticeKey), findsNothing);

    await _pump(tester, const CancellationFeePreviewUnavailable());
    expect(find.byKey(_bodyKey), findsOneWidget);
    expect(find.byKey(_noticeKey), findsNothing);
    expect(find.text(_l.cancelFeeRecheckFailed), findsNothing);
  });

  testWidgets('aucun frais : le corps seul', (tester) async {
    await _pump(tester, CancellationFeePreviewLoaded(_noFee, now: _now));
    expect(find.byKey(_bodyKey), findsOneWidget);
    expect(find.byKey(_noticeKey), findsNothing);
  });

  testWidgets('des frais : le bloc des frais sous le corps', (tester) async {
    await _pump(tester, CancellationFeePreviewLoaded(_withFee, now: _now));
    expect(find.byKey(_bodyKey), findsOneWidget);
    expect(find.byKey(_noticeKey), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(_noticeKey)).dy,
      greaterThan(tester.getBottomLeft(find.byKey(_bodyKey)).dy),
    );
    expect(find.text(_l.cancelFeeIncreased), findsNothing);
    expect(find.text(_l.cancelFeeRecheckFailed), findsNothing);
  });

  testWidgets('frais augmentés : l\'avertissement est dans le bloc', (
    tester,
  ) async {
    await _pump(
      tester,
      CancellationFeePreviewLoaded(_withFee, now: _now, increased: true),
    );
    expect(find.byKey(_noticeKey), findsOneWidget);
    expect(find.text(_l.cancelFeeIncreased), findsOneWidget);
  });

  testWidgets('relecture ratée avec frais : avertissement dans le bloc', (
    tester,
  ) async {
    await _pump(
      tester,
      CancellationFeePreviewLoaded(_withFee, now: _now, recheckFailed: true),
    );
    expect(find.byKey(_noticeKey), findsOneWidget);
    expect(find.text(_l.cancelFeeRecheckFailed), findsOneWidget);
  });

  testWidgets('relecture ratée sans frais : l\'avertissement seul', (
    tester,
  ) async {
    await _pump(
      tester,
      CancellationFeePreviewLoaded(_noFee, now: _now, recheckFailed: true),
    );
    expect(find.byKey(_noticeKey), findsNothing);
    expect(find.byType(CancellationFeeWarning), findsOneWidget);
    expect(find.text(_l.cancelFeeRecheckFailed), findsOneWidget);
  });

  testWidgets('scrollable : le corps est dans un SingleChildScrollView', (
    tester,
  ) async {
    await _pump(tester, const CancellationFeePreviewLoading());
    expect(find.byType(SingleChildScrollView), findsNothing);

    await _pump(
      tester,
      CancellationFeePreviewLoaded(_withFee, now: _now),
      scrollable: true,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(_noticeKey), findsOneWidget);
  });

  testWidgets('animation de 250 ms, aucune si le système les coupe', (
    tester,
  ) async {
    await _pump(tester, const CancellationFeePreviewLoading());
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      const Duration(milliseconds: 250),
    );
    await _pump(
      tester,
      const CancellationFeePreviewLoading(),
      disableAnimations: true,
    );
    expect(
      tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
      Duration.zero,
    );
  });
}
