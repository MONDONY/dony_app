// Recette du 14/11 : un colis payé en espèces ne passe jamais par Yadony.
// Aucun texte ne lui promet de remboursement ; carte et mobile money gardent
// le leur. Les messages se lisent à la bonne personne (l'expéditeur qui
// annule lit « vous », jamais « l'expéditeur »).
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid(BidPaymentMethod method, {String status = 'CANCELLED'}) =>
    BidModel(
      id: 'bid-1',
      announcementId: 'a-1',
      senderId: 's-1',
      status: status,
      paymentMethod: method,
      rejectionReason: status == 'EXPIRED' ? 'HANDOVER_DEADLINE_PASSED' : null,
      weightKg: 5,
      createdAt: DateTime(2026, 11),
      updatedAt: DateTime(2026, 11),
    );

/// Promesse d'un remboursement à venir, en français ou en anglais.
final _refundPromise = RegExp(
  r'sera remboursé|serez remboursé|est remboursé|vous est remboursé'
  r'|will be refunded|is refunded|refunded to you|refunded automatically',
);

void main() {
  for (final locale in const [AppL10n.fr, AppL10n.en]) {
    final l = lookupAppLocalizations(locale);
    final lang = locale.languageCode;

    group('bidCancelledMessage $lang', () {
      test('expéditeur, espèces : aucune somme à rembourser par Yadony', () {
        final text = bidCancelledMessage(
          l,
          _bid(BidPaymentMethod.cash),
          viewerIsSender: true,
        );
        expect(text, l.bidDetailCancelledSenderCashSnackbar);
        expect(_refundPromise.hasMatch(text), isFalse, reason: text);
      });

      test(
        'expéditeur, carte ou mobile money : remboursé, à la 2e personne',
        () {
          for (final method in [
            BidPaymentMethod.stripe,
            BidPaymentMethod.mobileMoney,
          ]) {
            expect(
              bidCancelledMessage(l, _bid(method), viewerIsSender: true),
              l.bidDetailCancelledSenderSnackbar,
            );
          }
          // Jamais « l'expéditeur sera remboursé » lu par l'expéditeur.
          expect(
            l.bidDetailCancelledSenderSnackbar,
            isNot(l.bidDetailCancelledSnackbar),
          );
        },
      );

      test('voyageur : espèces sans remboursement, carte remboursée', () {
        final cash = bidCancelledMessage(
          l,
          _bid(BidPaymentMethod.cash),
          viewerIsSender: false,
        );
        expect(cash, l.bidDetailCancelledCashSnackbar);
        expect(_refundPromise.hasMatch(cash), isFalse, reason: cash);
        expect(
          bidCancelledMessage(
            l,
            _bid(BidPaymentMethod.stripe),
            viewerIsSender: false,
          ),
          l.bidDetailCancelledSnackbar,
        );
      });

      test('variantes espèces : aucune ne promet de remboursement', () {
        for (final text in [
          l.bidDetailCancelCashSubtitle,
          l.bidDetailCancelAfterHandoverCashOptionSubtitle,
          l.bidDetailCancelAfterHandoverCashBody,
          l.bidDetailRefuseParcelCashSubtitle,
          l.bidDetailCancelTransportAcceptedCashSubtitle,
          l.bidCancelAcceptedCashSubtitle,
          l.bidCancelWarningRefundNoteCash,
          l.bidDetailCancelledCashSnackbar,
          l.bidDetailCancelledSenderCashSnackbar,
          l.bidCreateHandoverCheckNoticeCash,
          l.bidRescheduleWithdrawConfirmCashMessage,
          l.bidRescheduleWithdrawConfirmReturnCashMessage,
          l.bidRescheduleWithdrawnCashSnackbar,
          l.ticketHandoverDeadlineExpiredSenderCash,
        ]) {
          expect(_refundPromise.hasMatch(text), isFalse, reason: text);
        }
      });
    });

    testWidgets('billet expéditeur $lang 360 dp, date limite passée en '
        'espèces : rien à rembourser', (tester) async {
      if (locale == AppL10n.en) useEnglish();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tracking = _MockTrackingBloc();
      final bids = _MockBidBloc();
      when(() => tracking.state).thenReturn(TrackingInitial());
      when(() => bids.state).thenReturn(BidInitial());
      Future<void> pump(BidPaymentMethod method) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider<TrackingBloc>.value(value: tracking),
                  BlocProvider<BidBloc>.value(value: bids),
                ],
                child: BilletTalon(
                  bid: _bid(method, status: 'EXPIRED'),
                  isSender: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }

      await pump(BidPaymentMethod.cash);
      expect(
        find.text(l.ticketHandoverDeadlineExpiredSenderCash),
        findsOneWidget,
      );
      expect(find.text(l.ticketHandoverDeadlineExpiredSender), findsNothing);
      expect(tester.takeException(), isNull);

      await pump(BidPaymentMethod.stripe);
      expect(find.text(l.ticketHandoverDeadlineExpiredSender), findsOneWidget);
    });
  }
}
