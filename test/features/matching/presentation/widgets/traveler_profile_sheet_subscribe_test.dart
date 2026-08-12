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
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class MockTravelerSubscribeBloc
    extends MockBloc<TravelerSubscribeEvent, TravelerSubscribeState>
    implements TravelerSubscribeBloc {}

const _traveler = TravelerProfile(id: 't1', displayName: 'Ibrahima Diallo');

const _ratingsLoaded = UserRatingsLoaded(
  averageRating: 4.7,
  ratingCount: 0,
  distribution: {},
  ratings: [],
  page: 0,
  totalPages: 1,
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTravelerProfileSheet(context, _traveler),
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
        initialState: _ratingsLoaded);

    getIt.registerFactory<RatingBloc>(() => ratingBloc);
    getIt.registerFactory<TravelerSubscribeBloc>(() => subscribeBloc);
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets('affiche le bouton « S\'abonner » pour un non-abonné',
      (tester) async {
    whenListen(
      subscribeBloc,
      const Stream<TravelerSubscribeState>.empty(),
      initialState: const TravelerSubscribeState(
        status: TravelerSubscribeStatus.ready,
        subscribed: false,
      ),
    );

    await _openSheet(tester);

    expect(find.text("S'abonner à ce voyageur"), findsOneWidget);
  });

  testWidgets('un tap sur « S\'abonner » dispatch SubscribePressed',
      (tester) async {
    whenListen(
      subscribeBloc,
      const Stream<TravelerSubscribeState>.empty(),
      initialState: const TravelerSubscribeState(
        status: TravelerSubscribeStatus.ready,
        subscribed: false,
      ),
    );

    await _openSheet(tester);
    await tester.tap(find.text("S'abonner à ce voyageur"));
    await tester.pump();

    verify(() => subscribeBloc.add(const SubscribePressed())).called(1);
  });

  testWidgets('affiche « Abonné ✓ » et la cloche pour un abonné',
      (tester) async {
    whenListen(
      subscribeBloc,
      const Stream<TravelerSubscribeState>.empty(),
      initialState: const TravelerSubscribeState(
        status: TravelerSubscribeStatus.ready,
        subscribed: true,
        pushEnabled: true,
      ),
    );

    await _openSheet(tester);

    expect(find.text('Abonné ✓'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell'), findsWidgets);
  });

  testWidgets('la barre est masquée tant que le statut n\'est pas chargé',
      (tester) async {
    whenListen(
      subscribeBloc,
      const Stream<TravelerSubscribeState>.empty(),
      initialState: const TravelerSubscribeState(
        status: TravelerSubscribeStatus.loading,
      ),
    );

    await _openSheet(tester);

    expect(find.text("S'abonner à ce voyageur"), findsNothing);
    expect(find.text('Abonné ✓'), findsNothing);
  });
}
