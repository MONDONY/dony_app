import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/sender_profile_sheet.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class MockContactRevealBloc
    extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

const _ratingsEmpty = UserRatingsLoaded(
  averageRating: 0,
  ratingCount: 0,
  distribution: {},
  ratings: [],
  page: 0,
  totalPages: 1,
);

BidModel _bid({
  String? senderName,
  bool senderPhoneAvailable = false,
  bool senderKycVerified = false,
  bool senderIsProAccount = false,
  int? senderTotalShipments,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  status: 'PENDING',
  senderName: senderName,
  senderPhoneAvailable: senderPhoneAvailable,
  senderKycVerified: senderKycVerified,
  senderIsProAccount: senderIsProAccount,
  senderTotalShipments: senderTotalShipments,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Future<void> _openSheet(WidgetTester tester, BidModel bid) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSenderProfileSheet(context, bid),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late MockRatingBloc ratingBloc;
  late MockContactRevealBloc contactRevealBloc;

  setUp(() {
    ratingBloc = MockRatingBloc();
    contactRevealBloc = MockContactRevealBloc();
    whenListen(
      ratingBloc,
      const Stream<RatingState>.empty(),
      initialState: _ratingsEmpty,
    );
    whenListen(
      contactRevealBloc,
      const Stream<ContactRevealState>.empty(),
      initialState: const ContactRevealInitial(),
    );
    getIt.registerFactory<RatingBloc>(() => ratingBloc);
    getIt.registerFactory<ContactRevealBloc>(() => contactRevealBloc);
  });

  tearDown(() => getIt.reset());

  testWidgets('repli traduit quand l expediteur n a pas de nom', (
    tester,
  ) async {
    await _openSheet(tester, _bid());

    expect(find.text('Expéditeur'), findsOneWidget);
  });

  testWidgets('numéro masqué avant acceptation', (tester) async {
    await _openSheet(tester, _bid(senderName: 'Fatou S.'));

    expect(find.text('📞 Numéro révélé après acceptation'), findsOneWidget);
  });

  testWidgets('badges Compte PRO et Identité vérifiée', (tester) async {
    await _openSheet(
      tester,
      _bid(
        senderName: 'Fatou S.',
        senderIsProAccount: true,
        senderKycVerified: true,
      ),
    );

    expect(find.text('Compte PRO'), findsOneWidget);
    expect(find.text('Identité vérifiée'), findsOneWidget);
  });

  testWidgets('libellé Envois de la stat', (tester) async {
    await _openSheet(
      tester,
      _bid(senderName: 'Fatou S.', senderTotalShipments: 7),
    );

    expect(find.text('Envois'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('en anglais : repli, numéro masqué et badges traduits', (
    tester,
  ) async {
    useEnglish();
    await _openSheet(
      tester,
      _bid(senderIsProAccount: true, senderKycVerified: true),
    );

    expect(find.text('Sender'), findsOneWidget);
    expect(find.text('📞 Number revealed after acceptance'), findsOneWidget);
    expect(find.text('PRO account'), findsOneWidget);
    expect(find.text('Verified identity'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
  });
}
