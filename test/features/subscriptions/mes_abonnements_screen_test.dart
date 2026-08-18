import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_skeleton.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/mes_abonnements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSubscriptionsBloc
    extends MockBloc<SubscriptionsEvent, SubscriptionsState>
    implements SubscriptionsBloc {}

SubscriptionItem _item(String name, {bool hasNew = false, bool push = false}) =>
    SubscriptionItem(
      travelerId: 't-$name',
      travelerName: name,
      isProAccount: false,
      averageRating: 4.8,
      ongoingTripsCount: 2,
      pushEnabled: push,
      hasNew: hasNew,
      lastAnnouncement: null,
    );

SubscriptionItem _itemWithNew(String name) => SubscriptionItem(
  travelerId: 't-$name',
  travelerName: name,
  isProAccount: false,
  averageRating: 4.8,
  ongoingTripsCount: 1,
  pushEnabled: false,
  hasNew: true,
  lastAnnouncement: LastAnnouncement(
    announcementId: 'ann-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    pricePerKg: 8.0,
    publishedAt: DateTime(2026, 6),
  ),
);

void main() {
  late MockSubscriptionsBloc bloc;

  setUp(() {
    bloc = MockSubscriptionsBloc();
    registerFallbackValue(const LoadSubscriptions());
    registerFallbackValue(const ToggleSubscriptionPush('', false));
  });

  Widget pump() => MaterialApp(
    home: BlocProvider<SubscriptionsBloc>.value(
      value: bloc,
      child: const MesAbonnementsScreen(),
    ),
  );

  testWidgets('liste les abonnements', (tester) async {
    when(() => bloc.state).thenReturn(
      SubscriptionsState(
        status: SubscriptionsStatus.success,
        items: [_item('Awa'), _item('Moussa')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Moussa'), findsOneWidget);
  });

  testWidgets('état vide affiche le message', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const SubscriptionsState(status: SubscriptionsStatus.success));
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Aucun abonnement'), findsOneWidget);
  });

  testWidgets('recherche filtre par nom', (tester) async {
    when(() => bloc.state).thenReturn(
      SubscriptionsState(
        status: SubscriptionsStatus.success,
        items: [_item('Awa'), _item('Moussa')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pump();
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Moussa'), findsNothing);
  });

  // ─── Loading state ────────────────────────────────────────────────────────────

  testWidgets('état loading → skeleton', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const SubscriptionsState(status: SubscriptionsStatus.loading));
    await tester.pumpWidget(pump());
    // No pump(600ms) here — we want to catch the loading indicator before items arrive.
    await tester.pump();
    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  // ─── Error state ──────────────────────────────────────────────────────────────

  testWidgets(
    'état error → affiche "Erreur de chargement" + bouton Réessayer',
    (tester) async {
      when(() => bloc.state).thenReturn(
        const SubscriptionsState(
          status: SubscriptionsStatus.error,
          error: 'Échec réseau',
        ),
      );
      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Erreur de chargement'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    },
  );

  testWidgets('tap Réessayer → bloc.add(LoadSubscriptions)', (tester) async {
    when(() => bloc.state).thenReturn(
      const SubscriptionsState(
        status: SubscriptionsStatus.error,
        error: 'Échec réseau',
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(
      () => bloc.add(const LoadSubscriptions()),
    ).called(greaterThanOrEqualTo(1));
  });

  // ─── Bell toggle ──────────────────────────────────────────────────────────────

  testWidgets('tap cloche → bloc.add(ToggleSubscriptionPush)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => bloc.state).thenReturn(
      SubscriptionsState(
        status: SubscriptionsStatus.success,
        items: [_item('Awa')],
      ),
    );
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    // The bell icon button is inside SubscriptionTile (DonyIcon 'bell-off')
    final bellFinder = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'bell-off',
    );
    expect(bellFinder, findsOneWidget);
    await tester.tap(bellFinder);
    await tester.pump();

    // ToggleSubscriptionPush doesn't implement ==, use captureAny to verify the type.
    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(
      captured.any((e) => e is ToggleSubscriptionPush),
      isTrue,
      reason: 'Expected a ToggleSubscriptionPush event to be added',
    );
  });

  // ─── hasNew section ───────────────────────────────────────────────────────────

  testWidgets(
    'item hasNew:true + lastAnnouncement → section "ONT PUBLIÉ RÉCEMMENT" + story avatar accessible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => bloc.state).thenReturn(
        SubscriptionsState(
          status: SubscriptionsStatus.success,
          items: [_itemWithNew('Ibou')],
        ),
      );
      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      // The section label is uppercased
      expect(
        find.textContaining('ONT PUBLIÉ RÉCEMMENT', findRichText: true),
        findsOneWidget,
      );
      // La story-row remplace le badge texte "NOUVEAU" par un Semantics
      // label sur l'avatar (a11y — cf. lib/core/design/CLAUDE.md règle
      // "Semantics sur icônes sans label").
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Nouveau trajet publié par Ibou',
        ),
        findsOneWidget,
      );
      expect(find.text('Ibou'), findsOneWidget);
    },
  );
}
