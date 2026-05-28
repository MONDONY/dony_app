import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_profile_sheet.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_bloc.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_event.dart';
import 'package:dony/features/subscriptions/bloc/traveler_subscribe_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class MockTravelerSubscribeBloc
    extends MockBloc<TravelerSubscribeEvent, TravelerSubscribeState>
    implements TravelerSubscribeBloc {}

const _travelerFull = TravelerProfile(
  id: 't1',
  displayName: 'Amadou Maïga',
  phoneNumber: '+33612345678',
  averageRating: 4.8,
  totalTrips: 12,
  kycVerified: true,
  isProAccount: true,
);

const _travelerMinimal = TravelerProfile(
  id: 't2',
  displayName: 'Fatou D.',
);

const _ratingsEmpty = UserRatingsLoaded(
  averageRating: 0,
  ratingCount: 0,
  distribution: {},
  ratings: [],
  page: 0,
  totalPages: 1,
);

Future<void> _openSheet(WidgetTester tester, TravelerProfile traveler) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTravelerProfileSheet(context, traveler),
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
  late MockTravelerSubscribeBloc subscribeBloc;

  setUp(() {
    ratingBloc = MockRatingBloc();
    subscribeBloc = MockTravelerSubscribeBloc();
    whenListen(ratingBloc, const Stream<RatingState>.empty(),
        initialState: _ratingsEmpty);
    whenListen(
      subscribeBloc,
      const Stream<TravelerSubscribeState>.empty(),
      initialState: const TravelerSubscribeState(
        status: TravelerSubscribeStatus.loading,
      ),
    );
    getIt.registerFactory<RatingBloc>(() => ratingBloc);
    getIt.registerFactory<TravelerSubscribeBloc>(() => subscribeBloc);
  });

  tearDown(() => getIt.reset());

  group('Header — nom, téléphone, badges', () {
    testWidgets('affiche le nom abrégé', (tester) async {
      await _openSheet(tester, _travelerFull);
      // 'Amadou Maïga' → 'Amadou M.'
      expect(find.text('Amadou M.'), findsOneWidget);
    });

    testWidgets('affiche le numéro de téléphone', (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('+33612345678'), findsOneWidget);
    });

    testWidgets('affiche le badge Compte PRO quand isProAccount = true',
        (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('Compte PRO'), findsOneWidget);
    });

    testWidgets('affiche le badge Identité vérifiée quand kycVerified = true',
        (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('Identité vérifiée'), findsOneWidget);
    });

    testWidgets('affiche le texte masqué si phoneNumber est null',
        (tester) async {
      await _openSheet(tester, _travelerMinimal);
      expect(find.text('Numéro révélé après acceptation'), findsOneWidget);
    });
  });

  group('Stat cards', () {
    testWidgets('affiche les 3 labels', (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Trajets'), findsOneWidget);
      expect(find.text('Livraison'), findsOneWidget);
    });

    testWidgets('affiche la note du voyageur', (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('4.8'), findsOneWidget);
    });

    testWidgets('affiche le nombre de trajets', (tester) async {
      await _openSheet(tester, _travelerFull);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('affiche « – » quand averageRating et totalTrips sont null',
        (tester) async {
      await _openSheet(tester, _travelerMinimal);
      // note=null → '–', trajets=null → '–', livraison toujours '–' → exactement 3
      expect(find.text('–'), findsNWidgets(3));
    });
  });
}
