import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/same_address_announcements_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

Widget _wrap(Widget child, {FavoriteIdsCubit? favCubit}) {
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
  final inner = BlocProvider<BidBloc>.value(
    value: bidBloc,
    child: MaterialApp(home: Scaffold(body: child)),
  );
  if (favCubit != null) {
    return BlocProvider<FavoriteIdsCubit>.value(
      value: favCubit,
      child: inner,
    );
  }
  return inner;
}

AnnouncementModel _ann(String id, String dep, String arr) => AnnouncementModel(
      id: id,
      travelerId: 't1',
      departureCity: dep,
      arrivalCity: arr,
      departureDate: DateTime(2026, 6, 15),
      availableKg: 8,
      totalKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      pickupAddress: const AddressData(label: 'Same', lat: 48.85, lng: 2.35),
      traveler: TravelerProfile(id: 't1', displayName: 'Sékou Ba', kiloPro: false),
    );

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('lists all announcements', (tester) async {
    final list = [_ann('a1', 'Paris', 'Dakar'), _ann('a2', 'Paris', 'Dakar')];
    await tester.pumpWidget(_wrap(SameAddressAnnouncementsSheet(
      addressLabel: '12 rue Hugo, Paris',
      announcements: list,
      onTap: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('12 rue Hugo, Paris'), findsOneWidget);
    expect(find.text('Sékou Ba'), findsNWidgets(2));
  });

  testWidgets('tap on item invokes onTap with that announcement', (tester) async {
    String? tappedId;
    final list = [_ann('a1', 'Paris', 'Dakar'), _ann('a2', 'Paris', 'Dakar')];
    await tester.pumpWidget(_wrap(SameAddressAnnouncementsSheet(
      addressLabel: 'X',
      announcements: list,
      onTap: (a) => tappedId = a.id,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sékou Ba').last);
    await tester.pumpAndSettle();
    expect(tappedId, 'a2');
  });

  testWidgets('isOwnAnnouncement: own card disables tap', (tester) async {
    String? tappedId;
    final list = [_ann('a1', 'Paris', 'Dakar')]; // travelerId == 't1'
    await tester.pumpWidget(_wrap(SameAddressAnnouncementsSheet(
      addressLabel: 'X',
      announcements: list,
      currentUserId: 't1', // matches the traveler — it's "own"
      onTap: (a) => tappedId = a.id,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Votre trajet'), findsOneWidget);
    await tester.tap(find.text('Sékou Ba'));
    await tester.pumpAndSettle();
    expect(tappedId, isNull);
  });

  // ── showFavorite gating ────────────────────────────────────────────────────

  testWidgets(
      'non-owned card shows FavoriteHeartButton when FavoriteIdsCubit is provided',
      (tester) async {
    final repo = _MockFavoriteRepository();
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    final list = [_ann('a1', 'Paris', 'Dakar')]; // travelerId == 't1'
    await tester.pumpWidget(_wrap(
      SameAddressAnnouncementsSheet(
        addressLabel: 'X',
        announcements: list,
        currentUserId: 'other-user', // not the owner → showFavorite: true
        onTap: (_) {},
      ),
      favCubit: cubit,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteHeartButton), findsOneWidget);
  });

  testWidgets(
      'owned card does NOT show FavoriteHeartButton even when FavoriteIdsCubit is provided',
      (tester) async {
    final repo = _MockFavoriteRepository();
    final cubit = FavoriteIdsCubit(repo)..emitSeed(trips: {}, requests: {});
    final list = [_ann('a1', 'Paris', 'Dakar')]; // travelerId == 't1'
    await tester.pumpWidget(_wrap(
      SameAddressAnnouncementsSheet(
        addressLabel: 'X',
        announcements: list,
        currentUserId: 't1', // matches travelerId → isOwn=true → showFavorite:false
        onTap: (_) {},
      ),
      favCubit: cubit,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FavoriteHeartButton), findsNothing);
  });
}
