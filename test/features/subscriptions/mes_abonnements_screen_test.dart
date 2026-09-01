import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
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

SubscriptionItem _item(
  String name, {
  bool hasNew = false,
  bool push = false,
  LastAnnouncement? last,
}) => SubscriptionItem(
  travelerId: 't-$name',
  travelerName: name,
  isProAccount: false,
  averageRating: 4.8,
  ongoingTripsCount: 2,
  pushEnabled: push,
  hasNew: hasNew,
  lastAnnouncement: last,
);

LastAnnouncement _last({
  String from = 'Paris',
  String to = 'Dakar',
  double price = 8.0,
  String currency = 'EUR',
  DateTime? at,
}) => LastAnnouncement(
  announcementId: 'ann-$from$to',
  departureCity: from,
  arrivalCity: to,
  pricePerKg: price,
  currency: currency,
  publishedAt: at ?? DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  late MockSubscriptionsBloc bloc;

  setUp(() {
    bloc = MockSubscriptionsBloc();
    // Sans ça, un message identique émis par un test précédent est avalé par la
    // déduplication et l'assertion suivante ne trouve rien.
    DonySnackbar.clearDedup();
    registerFallbackValue(const LoadSubscriptions());
    registerFallbackValue(const ToggleSubscriptionPush('', false));
  });

  Widget pump() => MaterialApp(
    home: BlocProvider<SubscriptionsBloc>.value(
      value: bloc,
      child: const MesAbonnementsScreen(),
    ),
  );

  void givenItems(List<SubscriptionItem> items) {
    when(() => bloc.state).thenReturn(
      SubscriptionsState(status: SubscriptionsStatus.success, items: items),
    );
  }

  testWidgets('liste les abonnements', (tester) async {
    givenItems([_item('Awa'), _item('Moussa')]);
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

  // ─── Recherche conditionnelle ───────────────────────────────────────────────

  testWidgets('moins de 6 abonnements → pas de champ de recherche', (
    tester,
  ) async {
    givenItems([_item('Awa'), _item('Moussa')]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('à partir de 6 abonnements → recherche affichée et filtrante', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([
      _item('Awa'),
      _item('Moussa'),
      _item('Fatou'),
      _item('Ibou'),
      _item('Karim'),
      _item('Sophie'),
    ]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('Moussa'), findsNothing);
  });

  testWidgets('recherche sans résultat → message dédié', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([
      _item('Awa'),
      _item('Moussa'),
      _item('Fatou'),
      _item('Ibou'),
      _item('Karim'),
      _item('Sophie'),
    ]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Aucun voyageur ne correspond à cette recherche.'),
      findsOneWidget,
    );
  });

  // ─── Loading state ────────────────────────────────────────────────────────────

  testWidgets('état loading → skeleton', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(const SubscriptionsState(status: SubscriptionsStatus.loading));
    await tester.pump();
    await tester.pumpWidget(pump());
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

  // ─── Bascule des alertes push ──────────────────────────────────────────────

  testWidgets('tap cloche → événement + message qui dit ce qui est coupé', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([_item('Awa', push: true)]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    final bellFinder = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'bell',
    );
    expect(bellFinder, findsOneWidget);
    await tester.tap(bellFinder);
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.any((e) => e is ToggleSubscriptionPush), isTrue);

    // Le message dit explicitement que la notification, elle, reste : c'est le
    // mensonge que portait l'ancien libellé « Couper les notifications ».
    expect(
      find.textContaining('resteront visibles dans vos notifications'),
      findsOneWidget,
    );
  });

  // ─── Voyageurs ayant publié ────────────────────────────────────────────────

  testWidgets(
    'un voyageur ayant publié reste dans la liste, avec son dernier trajet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      givenItems([_item('Ibou', hasNew: true, last: _last())]);
      await tester.pumpWidget(pump());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Ibou'), findsOneWidget);
      expect(find.textContaining('Paris → Dakar'), findsOneWidget);
      // Il garde sa cloche et son balayage : la rangée de « stories » les lui
      // retirait en le sortant de la liste.
      expect(
        find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'bell-off'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Nouveau trajet publié par Ibou',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('les voyageurs ayant publié passent devant les autres', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([
      _item('Awa', last: _last(from: 'Lyon', to: 'Bamako')),
      _item('Ibou', hasNew: true, last: _last()),
    ]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    final awa = tester.getTopLeft(find.text('Awa')).dy;
    final ibou = tester.getTopLeft(find.text('Ibou')).dy;
    expect(ibou, lessThan(awa));
  });

  testWidgets('compteur annonce le total et les nouveaux', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([_item('Awa'), _item('Ibou', hasNew: true, last: _last())]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('2 voyageurs suivis'), findsOneWidget);
    expect(
      find.text('1 a publié depuis votre dernière visite'),
      findsOneWidget,
    );
  });

  // ─── Tout marquer comme vu ─────────────────────────────────────────────────

  testWidgets('aucune pastille → pas d\'action "tout marquer comme vu"', (
    tester,
  ) async {
    givenItems([_item('Awa')]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'check-check'),
      findsNothing,
    );
  });

  testWidgets('tap "tout marquer comme vu" → MarkAllSubscriptionsSeen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([_item('Ibou', hasNew: true, last: _last())]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    final action = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'check-check',
    );
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.any((e) => e is MarkAllSubscriptionsSeen), isTrue);
  });

  // ─── Désabonnement ─────────────────────────────────────────────────────────

  testWidgets('balayer puis Désabonner demande confirmation avant d\'agir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    givenItems([_item('Awa')]);
    await tester.pumpWidget(pump());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.drag(find.text('Awa'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Désabonner'));
    await tester.pumpAndSettle();

    // Le dialogue s'ouvre, et rien n'est encore parti au serveur.
    expect(find.text('Ne plus suivre Awa ?'), findsOneWidget);
    final avant = verify(() => bloc.add(captureAny())).captured;
    expect(avant.any((e) => e is UnsubscribeTraveler), isFalse);

    await tester.tap(find.text('Se désabonner'));
    await tester.pumpAndSettle();

    final apres = verify(() => bloc.add(captureAny())).captured;
    expect(apres.any((e) => e is UnsubscribeTraveler), isTrue);
  });
}
