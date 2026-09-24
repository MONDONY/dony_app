// Couvre les messages ajoutés à la tâche D1 (i18n) : les trois formats de
// date des cartes principales du détail d'offre (sender_hero_card.dart,
// traveler_hero_card.dart), et un test anglais par carte migrée (dont
// traveler_gain_card.dart).

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _FakeCancellationEvent extends Fake implements CancellationEvent {}

BidModel _bid({
  required String status,
  double? total = 48,
  DateTime? handoverDeadline,
  String? handoverLocation,
  String? travelerName,
  DateTime? departureDate,
  bool voyageurConfirmed = false,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  totalAmountEur: total,
  handoverDeadline: handoverDeadline,
  handoverLocation: handoverLocation,
  travelerName: travelerName,
  departureDate: departureDate,
  voyageurConfirmed: voyageurConfirmed,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pumpSender(WidgetTester tester, BidModel bid) async {
  final cancel = _MockCancelBloc();
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: BlocProvider<CancellationBloc>.value(
          value: cancel,
          child: SenderHeroCard(bid: bid),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpTraveler(WidgetTester tester, BidModel bid) async {
  final cancel = _MockCancelBloc();
  when(() => cancel.state).thenReturn(CancellationInitial());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: BlocProvider<CancellationBloc>.value(
          value: cancel,
          child: TravelerHeroCard(bid: bid),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    registerFallbackValue(_FakeCancellationEvent());
  });

  // Date fixe déjà vérifiée dans common-context (mar. 6 oct. / 14:05).
  final fixedDate = DateTime(2026, 10, 6, 14, 5);

  group('Formats de date (bidDetailUntil, commonDateAtTime)', () {
    testWidgets(
      'bidDetailUntil avec DateFormat.MMMEd(fr) — égalité avec l\'ancien motif "EEE d MMM"',
      (tester) async {
        await _pumpSender(
          tester,
          _bid(status: 'ACCEPTED', handoverDeadline: fixedDate),
        );

        expect(find.textContaining("jusqu'au mar. 6 oct."), findsOneWidget);
      },
    );

    test(
      'DateFormat.Md(fr) (repli de bidDetailUntil) — égalité avec l\'ancien motif "dd/MM"',
      () {
        // Le repli n'est atteint que quand les données de locale manquent
        // (isolat de test) : impossible à déclencher depuis un widget test
        // normal (déjà vrai avant cette tâche). On protège directement
        // l'équivalence du squelette utilisé dans le catch.
        expect(DateFormat.Md('fr').format(fixedDate), '06/10');
      },
    );

    testWidgets(
      'commonDateAtTime avec MMMEd + jm(fr) — égalité avec l\'ancien motif "EEE d MMM à HH:mm"',
      (tester) async {
        await _pumpSender(
          tester,
          _bid(
            status: 'HANDED_OVER',
            travelerName: 'Mamadou',
            departureDate: fixedDate,
          ),
        );

        expect(
          find.textContaining('Embarquement prévu le mar. 6 oct. à 14:05.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Anglais — un test par carte migrée', () {
    testWidgets('sender_hero_card.dart — PENDING en anglais', (tester) async {
      useEnglish();
      await _pumpSender(tester, _bid(status: 'PENDING'));

      expect(find.textContaining('Waiting for the traveler'), findsOneWidget);
      expect(
        find.textContaining("You'll be notified as soon as they reply."),
        findsOneWidget,
      );
    });

    testWidgets('traveler_hero_card.dart — PENDING en anglais', (tester) async {
      useEnglish();
      await _pumpTraveler(tester, _bid(status: 'PENDING'));

      expect(find.textContaining('New shipment request'), findsOneWidget);
      expect(find.textContaining('Potential earnings: '), findsOneWidget);
      expect(
        find.textContaining('Accept or decline the request.'),
        findsOneWidget,
      );
    });

    testWidgets('traveler_gain_card.dart — ACCEPTED carte en anglais', (
      tester,
    ) async {
      useEnglish();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TravelerGainCard(bid: _bid(status: 'ACCEPTED')),
          ),
        ),
      );

      expect(find.text('YOU RECEIVE'), findsOneWidget);
      expect(find.textContaining('on hold'), findsOneWidget);
    });
  });
}
