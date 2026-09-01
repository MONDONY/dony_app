import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscription_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SubscriptionItem _item({
  String name = 'Awa',
  bool pro = false,
  double? rating = 4.8,
  int ongoing = 2,
  bool push = false,
  bool hasNew = false,
  LastAnnouncement? last,
}) => SubscriptionItem(
  travelerId: 't-1',
  travelerName: name,
  isProAccount: pro,
  averageRating: rating,
  ongoingTripsCount: ongoing,
  pushEnabled: push,
  hasNew: hasNew,
  lastAnnouncement: last,
);

void main() {
  final now = DateTime(2026, 9, 1, 12);

  Widget host(
    SubscriptionItem item, {
    VoidCallback? onTap,
    VoidCallback? onOpenLastTrip,
  }) => MaterialApp(
    home: Scaffold(
      body: SubscriptionTile(
        item: item,
        onTap: onTap ?? () {},
        onToggleBell: () {},
        onOpenLastTrip: onOpenLastTrip,
        now: now,
      ),
    ),
  );

  LastAnnouncement trajet() => LastAnnouncement(
    announcementId: 'a1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    pricePerKg: 8,
    publishedAt: now.subtract(const Duration(hours: 2)),
  );

  testWidgets('affiche le dernier trajet, son prix et son ancienneté', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        _item(
          last: LastAnnouncement(
            announcementId: 'a1',
            departureCity: 'Paris',
            arrivalCity: 'Dakar',
            pricePerKg: 8,
            publishedAt: now.subtract(const Duration(hours: 2)),
          ),
        ),
      ),
    );

    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.textContaining('/kg'), findsOneWidget);
    expect(find.text('il y a 2 h'), findsOneWidget);
  });

  testWidgets('le prix suit la devise de l\'annonce, pas l\'euro par défaut', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        _item(
          last: LastAnnouncement(
            announcementId: 'a1',
            departureCity: 'Lyon',
            arrivalCity: 'Bamako',
            pricePerKg: 4500,
            currency: 'XOF',
            publishedAt: now,
          ),
        ),
      ),
    );

    // Corridor et prix sont deux Text distincts : le prix ne doit jamais
    // s'abréger, c'est le corridor qui cède la place.
    expect(find.text('Lyon → Bamako'), findsOneWidget);
    final prix = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('/kg'),
      ),
    );
    expect(prix.data, contains('F CFA'));
    expect(prix.data, isNot(contains('€')));
  });

  testWidgets('sans trajet publié, la carte le dit au lieu de rester muette', (
    tester,
  ) async {
    await tester.pumpWidget(host(_item(ongoing: 0)));
    expect(find.text('Aucun trajet publié pour le moment'), findsOneWidget);
    expect(find.text('Aucun trajet en cours'), findsOneWidget);
  });

  testWidgets('note absente → aucune étoile plutôt qu\'un tiret', (
    tester,
  ) async {
    await tester.pumpWidget(host(_item(rating: null)));
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'star'),
      findsNothing,
    );
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('note présente → affichée à la française', (tester) async {
    await tester.pumpWidget(host(_item()));
    expect(find.text('4,8'), findsOneWidget);
  });

  testWidgets('singulier et pluriel des trajets en cours', (tester) async {
    await tester.pumpWidget(host(_item(ongoing: 1)));
    expect(find.text('1 trajet en cours'), findsOneWidget);

    await tester.pumpWidget(host(_item(ongoing: 3)));
    expect(find.text('3 trajets en cours'), findsOneWidget);
  });

  testWidgets('compte PRO → marqueur PRO', (tester) async {
    await tester.pumpWidget(host(_item(pro: true)));
    expect(find.text('PRO'), findsOneWidget);
  });

  testWidgets('la cloche annonce ce qu\'elle commande', (tester) async {
    await tester.pumpWidget(host(_item(push: true)));
    final bouton = tester.widget<IconButton>(find.byType(IconButton));
    expect(bouton.tooltip, 'Couper les alertes push');

    await tester.pumpWidget(host(_item()));
    final eteint = tester.widget<IconButton>(find.byType(IconButton));
    expect(eteint.tooltip, 'Activer les alertes push');
  });

  testWidgets('un nouveau trajet est annoncé aux lecteurs d\'écran', (
    tester,
  ) async {
    await tester.pumpWidget(host(_item(name: 'Ibou', hasNew: true)));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Nouveau trajet publié par Ibou',
      ),
      findsOneWidget,
    );
  });

  // ─── Deux zones de tap ─────────────────────────────────────────────────────

  testWidgets('tap sur la ligne du trajet ouvre le trajet, pas le profil', (
    tester,
  ) async {
    var profil = 0;
    var voyage = 0;
    await tester.pumpWidget(
      host(
        _item(last: trajet()),
        onTap: () => profil++,
        onOpenLastTrip: () => voyage++,
      ),
    );

    await tester.tap(find.textContaining('Paris → Dakar'));
    await tester.pump();

    expect(voyage, 1);
    expect(profil, 0, reason: 'la zone intérieure doit absorber le tap');
  });

  testWidgets('tap sur le nom ouvre le profil', (tester) async {
    var profil = 0;
    var voyage = 0;
    await tester.pumpWidget(
      host(
        _item(last: trajet()),
        onTap: () => profil++,
        onOpenLastTrip: () => voyage++,
      ),
    );

    await tester.tap(find.text('Awa'));
    await tester.pump();

    expect(profil, 1);
    expect(voyage, 0);
  });

  testWidgets('la zone trajet respecte la cible tactile de 44pt', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(_item(last: trajet()), onOpenLastTrip: () {}),
    );

    final zone = find.ancestor(
      of: find.textContaining('Paris → Dakar'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(zone.first).height, greaterThanOrEqualTo(44));
  });

  testWidgets('sans destination de trajet, aucun chevron ne le promet', (
    tester,
  ) async {
    await tester.pumpWidget(host(_item(last: trajet())));
    expect(
      find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'chevron-right'),
      findsNothing,
    );
  });

  // ─── Date affichée ─────────────────────────────────────────────────────────

  testWidgets('date de départ servie → elle prime sur l\'ancienneté', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        _item(
          last: LastAnnouncement(
            announcementId: 'a1',
            departureCity: 'Marseille',
            arrivalCity: 'Abidjan',
            pricePerKg: 7.7,
            departureDate: DateTime(2026, 9, 27),
            publishedAt: now.subtract(const Duration(days: 28)),
          ),
        ),
      ),
    );

    expect(find.text('Départ 27 sept.'), findsOneWidget);
    // La date de publication ne doit plus apparaître : c'est celle du départ
    // qui décide si l'expéditeur peut confier son colis.
    expect(find.text('4 août'), findsNothing);
  });

  testWidgets('date de départ absente → repli sur l\'ancienneté', (
    tester,
  ) async {
    await tester.pumpWidget(host(_item(last: trajet())));
    expect(find.text('il y a 2 h'), findsOneWidget);
    expect(find.textContaining('Départ'), findsNothing);
  });
}
