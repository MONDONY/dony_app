import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_preview/cancellation_fee_preview_cubit.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../cancellation/cancellation_fee_test_support.dart';

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

/// Textes de l'expéditeur selon les frais d'annulation : la carte « Fenêtre de
/// remise dépassée » (A) et les sous-titres des annulations du menu ⋮ (B, C).
/// Non couvert (frais éteints, back antérieur, colis ancien, espèces) : le
/// texte d'aujourd'hui, mot pour mot ; couvert : le texte des frais.
BidModel _bid({
  String status = 'ACCEPTED',
  BidPaymentMethod method = BidPaymentMethod.stripe,
  DateTime? createdAt,
  DateTime? handoverDeadline,
  DateTime? departureAt,
}) => BidModel(
  id: 'bid-fee',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  weightKg: 4,
  status: status,
  paymentMethod: method,
  handoverDeadline: handoverDeadline,
  departureAt: departureAt,
  createdAt: createdAt ?? kCoveredCreatedAt,
  updatedAt: kCoveredCreatedAt,
);

/// Colis dont la date limite de dépôt est passée (carte A).
BidModel _windowExpired({
  BidPaymentMethod method = BidPaymentMethod.stripe,
  DateTime? createdAt,
}) => _bid(
  method: method,
  createdAt: createdAt,
  handoverDeadline: DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(NoShowConfirmRequested('x'));
  });

  late _MockCancellationBloc cancellationBloc;
  late _MockBidBloc bidBloc;
  late _MockConversationOpenBloc openBloc;

  setUp(() {
    cancellationBloc = _MockCancellationBloc();
    bidBloc = _MockBidBloc();
    openBloc = _MockConversationOpenBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => openBloc.state).thenReturn(const ConversationOpenInitial());
  });

  tearDown(getIt.reset);

  Widget app(Widget home, Locale locale) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<CancellationBloc>.value(value: cancellationBloc),
        BlocProvider<BidBloc>.value(value: bidBloc),
        BlocProvider<ConversationOpenBloc>.value(value: openBloc),
      ],
      child: Scaffold(body: home),
    ),
  );

  void phoneWidth(WidgetTester tester) {
    // 360 dp de large.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Sous-titre de la carte A, tel que l'écran le formate.
  String windowText(AppLocalizations l, BidModel bid, {required bool fee}) {
    final window = l.bidDetailUntil(
      DateFormat.MMMEd(l.localeName).format(bid.handoverDeadline!.toLocal()),
    );
    return fee
        ? l.bidDetailSenderWindowExpiredSubtitleWithFee(window)
        : l.bidDetailSenderWindowExpiredSubtitle(window);
  }

  Future<void> pumpHero(
    WidgetTester tester,
    BidModel bid,
    Locale locale,
  ) async {
    phoneWidth(tester);
    await tester.pumpWidget(app(SenderHeroCard(bid: bid), locale));
    await tester.pump();
  }

  Future<void> openOptions(
    WidgetTester tester,
    BidModel bid,
    Locale locale,
  ) async {
    phoneWidth(tester);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSenderOptionsSheet(context, bid),
            child: const Text('open-options'),
          ),
        ),
        locale,
      ),
    );
    await tester.tap(find.text('open-options'));
    await tester.pumpAndSettle();
  }

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    final l = lookupAppLocalizations(locale);
    final lang = locale.languageCode;

    group('[$lang] A · carte « Fenêtre de remise dépassée »', () {
      testWidgets('sans configuration : texte d\'aujourd\'hui', (tester) async {
        final bid = _windowExpired();
        await pumpHero(tester, bid, locale);
        expect(find.text(windowText(l, bid, fee: false)), findsOneWidget);
      });

      testWidgets('back antérieur (404) : texte d\'aujourd\'hui', (
        tester,
      ) async {
        await registerFeeConfig();
        final bid = _windowExpired();
        await pumpHero(tester, bid, locale);
        expect(find.text(windowText(l, bid, fee: false)), findsOneWidget);
      });

      testWidgets('frais allumés, colis couvert : texte des frais', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        final bid = _windowExpired();
        await pumpHero(tester, bid, locale);
        expect(find.text(windowText(l, bid, fee: true)), findsOneWidget);
        expect(find.text(windowText(l, bid, fee: false)), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('frais allumés, colis ancien ou en espèces : texte '
          'd\'aujourd\'hui', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        for (final bid in [
          _windowExpired(createdAt: DateTime.utc(2026, 12, 2)),
          _windowExpired(method: BidPaymentMethod.cash),
        ]) {
          await pumpHero(tester, bid, locale);
          expect(find.text(windowText(l, bid, fee: false)), findsOneWidget);
        }
      });
    });

    group('[$lang] B, C · sous-titres des annulations du menu ⋮', () {
      testWidgets('sans configuration : textes d\'aujourd\'hui', (
        tester,
      ) async {
        await openOptions(tester, _bid(), locale);
        expect(find.text(l.bidDetailCancelRefundAutoSubtitle), findsOneWidget);
        expect(
          find.text(l.bidDetailCancelRefundAutoSubtitleWithFee),
          findsNothing,
        );
      });

      testWidgets('back antérieur (404) : textes d\'aujourd\'hui', (
        tester,
      ) async {
        await registerFeeConfig();
        await openOptions(tester, _bid(), locale);
        expect(find.text(l.bidDetailCancelRefundAutoSubtitle), findsOneWidget);
      });

      testWidgets('C · couvert, ACCEPTED : remboursement moins les frais', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await openOptions(tester, _bid(), locale);
        expect(
          find.text(l.bidDetailCancelRefundAutoSubtitleWithFee),
          findsOneWidget,
        );
        expect(find.text(l.bidDetailCancelRefundAutoSubtitle), findsNothing);
        expect(tester.takeException(), isNull);
      });

      for (final status in ['PENDING', 'PAYMENT_ESCROWED']) {
        testWidgets('C · couvert, $status : aucun frais possible, texte '
            'd\'aujourd\'hui', (tester) async {
          await registerFeeConfig(config: kActiveFeeConfig);
          await openOptions(tester, _bid(status: status), locale);
          expect(
            find.text(l.bidDetailCancelRefundAutoSubtitle),
            findsOneWidget,
          );
          expect(
            find.text(l.bidDetailCancelRefundAutoSubtitleWithFee),
            findsNothing,
          );
        });
      }

      testWidgets('C · frais allumés, espèces : texte d\'aujourd\'hui', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await openOptions(tester, _bid(method: BidPaymentMethod.cash), locale);
        expect(find.text(l.bidDetailCancelRefundAutoSubtitle), findsOneWidget);
      });

      final future = DateTime.now().add(const Duration(days: 4));

      testWidgets('B · non couvert, après remise : texte d\'aujourd\'hui', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await openOptions(
          tester,
          _bid(
            status: 'HANDED_OVER',
            departureAt: future,
            createdAt: DateTime.utc(2026, 12, 2),
          ),
          locale,
        );
        expect(
          find.text(l.bidDetailCancelAfterHandoverOptionSubtitle),
          findsOneWidget,
        );
        expect(
          find.text(l.bidDetailCancelAfterHandoverOptionSubtitleWithFee),
          findsNothing,
        );
      });

      testWidgets('B · couvert mais parti : pas d\'annulation après remise', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await openOptions(
          tester,
          _bid(
            status: 'HANDED_OVER',
            departureAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          locale,
        );
        expect(
          find.text(l.bidDetailCancelAfterHandoverOptionSubtitleWithFee),
          findsNothing,
        );
      });

      testWidgets('B · couvert, après remise : frais d\'annulation possibles', (
        tester,
      ) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        await openOptions(
          tester,
          _bid(status: 'HANDED_OVER', departureAt: future),
          locale,
        );
        expect(
          find.text(l.bidDetailCancelAfterHandoverOptionSubtitleWithFee),
          findsOneWidget,
        );
        expect(
          find.text(l.bidDetailCancelAfterHandoverOptionSubtitle),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('[$lang] E · « Je confirme » depuis la carte de contestation', () {
      BidModel contested({DateTime? createdAt}) => BidModel(
        id: 'bid-fee',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        status: 'ACCEPTED',
        cancellationNoShowStatus: 'PENDING_CONFIRMATION',
        contestationDeadline: DateTime.now().add(const Duration(hours: 40)),
        createdAt: createdAt ?? kCoveredCreatedAt,
        updatedAt: kCoveredCreatedAt,
      );

      Future<void> confirmFromHero(WidgetTester tester, BidModel bid) async {
        await pumpHero(tester, bid, locale);
        await tester.tap(find.text(l.bidDetailSenderConfirmNoShowButton));
        await tester.pumpAndSettle();
      }

      Future<void> tapConfirmAndStop(WidgetTester tester) async {
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('donyBottomSheetFooter')),
            matching: find.text(l.bidDetailSenderConfirmSheetButton),
          ),
        );
        await tester.pumpAndSettle();
        verify(
          () => cancellationBloc.add(any(that: isA<NoShowConfirmRequested>())),
        ).called(1);
        // Arrête le compte à rebours de la carte.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }

      testWidgets('back antérieur (404) : feuille d\'aujourd\'hui', (
        tester,
      ) async {
        await registerFeeConfig();
        await confirmFromHero(tester, contested());
        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsOneWidget);
        await tapConfirmAndStop(tester);
      });

      testWidgets('couvert : texte des frais, aperçu indisponible sans '
          'blocage', (tester) async {
        await registerFeeConfig(config: kActiveFeeConfig);
        final previewRepository = MockFeeConfigRepository();
        when(
          () => previewRepository.getFeePreview('bid-fee'),
        ).thenThrow(feeConfigNotFound());
        final analytics = MockFeeConfigAnalytics();
        getIt.registerFactory<CancellationFeePreviewCubit>(
          () => CancellationFeePreviewCubit(previewRepository, analytics),
        );
        await confirmFromHero(tester, contested());
        expect(
          find.text(l.bidDetailSenderConfirmSheetBodyWithFee),
          findsOneWidget,
        );
        expect(find.text(l.bidDetailSenderConfirmSheetBody), findsNothing);
        await tapConfirmAndStop(tester);
        verify(() => previewRepository.getFeePreview('bid-fee')).called(1);
      });
    });
  }
}
