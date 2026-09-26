import 'package:dony/features/matching/presentation/widgets/activity_tile.dart';
import 'package:dony/features/matching/presentation/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// La tuile principale pousse son bouton en bas avec un `Spacer` : dans le
/// hub, la rangée lui donne une hauteur bornée, le test fait de même.
Widget _wrapHero(Widget child) =>
    _wrap(Center(child: SizedBox(width: 180, height: 280, child: child)));

ActivityHeroTile _hero({
  int value = 6,
  bool isLoading = false,
  bool hasError = false,
  bool showNotificationDot = false,
  VoidCallback? onTap,
  VoidCallback? onCtaTap,
}) => ActivityHeroTile(
  iconName: 'plane',
  color: Colors.blue,
  value: value,
  label: 'Trajets actifs',
  subtitle: 'Vos voyages à venir',
  emptyLabel: 'Je voyage',
  emptySubtitle: 'Rentabilisez vos kilos libres',
  ctaLabel: 'Publier un trajet',
  ctaKey: const Key('cta'),
  isLoading: isLoading,
  hasError: hasError,
  showNotificationDot: showNotificationDot,
  onTap: onTap ?? () {},
  onCtaTap: onCtaTap ?? () {},
);

ActivityTile _tile({
  int value = 2,
  bool isLoading = false,
  bool hasError = false,
  String? emptyHint = 'Aucune pour l\'instant',
  VoidCallback? onTap,
}) => ActivityTile(
  iconName: 'bell',
  color: Colors.blue,
  value: value,
  label: 'Demandes reçues',
  subtitle: 'Des colis à transporter pour vous',
  emptyHint: emptyHint,
  isLoading: isLoading,
  hasError: hasError,
  onTap: onTap ?? () {},
);

/// Point rond peint avec la couleur d'erreur du thème courant (ici le thème
/// Material par défaut, pas celui de l'app).
Finder _redDot() => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final deco = w.decoration;
  return deco is BoxDecoration &&
      deco.shape == BoxShape.circle &&
      deco.color == ThemeData().colorScheme.error;
});

void main() {
  group('ActivityHeroTile', () {
    testWidgets('affiche le compteur, le titre, le sous-titre et le bouton', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapHero(_hero()));

      expect(find.text('6'), findsOneWidget);
      expect(find.text('Trajets actifs'), findsOneWidget);
      expect(find.text('Vos voyages à venir'), findsOneWidget);
      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    testWidgets('à zéro, devient une invitation sans compteur', (tester) async {
      await tester.pumpWidget(_wrapHero(_hero(value: 0)));

      // Un « 0 » nu ne dit rien à un nouvel utilisateur.
      expect(find.text('0'), findsNothing);
      expect(find.text('Trajets actifs'), findsNothing);
      expect(find.text('Je voyage'), findsOneWidget);
      expect(find.text('Rentabilisez vos kilos libres'), findsOneWidget);
      expect(find.text('Publier un trajet'), findsOneWidget);
    });

    testWidgets('à zéro sans invitation fournie, garde le titre et « 0 »', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapHero(
          ActivityHeroTile(
            iconName: 'plane',
            color: Colors.blue,
            value: 0,
            label: 'Trajets actifs',
            subtitle: 'Vos voyages à venir',
            ctaLabel: 'Publier',
            onTap: () {},
            onCtaTap: () {},
          ),
        ),
      );

      expect(find.text('Trajets actifs'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets(
      'en chargement, masque le compteur sans basculer en invitation',
      (tester) async {
        await tester.pumpWidget(_wrapHero(_hero(value: 0, isLoading: true)));

        expect(find.text('0'), findsNothing);
        // Pas d'invitation pendant un chargement : elle clignoterait à chaque
        // rechargement d'un utilisateur actif.
        expect(find.text('Trajets actifs'), findsOneWidget);
        expect(find.text('Je voyage'), findsNothing);
      },
    );

    testWidgets('en erreur, affiche un tiret court', (tester) async {
      await tester.pumpWidget(_wrapHero(_hero(hasError: true)));

      expect(find.text('-'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text('Trajets actifs'), findsOneWidget);
    });

    testWidgets('la carte ouvre la liste, le bouton lance la publication', (
      tester,
    ) async {
      var opened = 0;
      var published = 0;
      await tester.pumpWidget(
        _wrapHero(_hero(onTap: () => opened++, onCtaTap: () => published++)),
      );

      await tester.tap(find.text('Trajets actifs'));
      await tester.pump();
      expect(opened, 1);
      expect(published, 0);

      await tester.tap(find.byKey(const Key('cta')));
      await tester.pump();
      expect(published, 1);
      expect(opened, 1);
    });

    testWidgets('le point rouge n\'apparaît que sur demande', (tester) async {
      await tester.pumpWidget(_wrapHero(_hero()));
      expect(_redDot(), findsNothing);

      await tester.pumpWidget(_wrapHero(_hero(showNotificationDot: true)));
      expect(_redDot(), findsOneWidget);
    });
  });

  group('ActivityTile', () {
    testWidgets('au-dessus de zéro, pastille chiffrée et sous-titre', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_tile()));

      expect(find.byKey(const Key('activity-tile-badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(find.text('Des colis à transporter pour vous'), findsOneWidget);
      expect(find.text('Aucune pour l\'instant'), findsNothing);
    });

    testWidgets('à zéro, pas de pastille et l\'invite remplace le sous-titre', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_tile(value: 0)));

      expect(find.byKey(const Key('activity-tile-badge')), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.text('Aucune pour l\'instant'), findsOneWidget);
      expect(find.text('Des colis à transporter pour vous'), findsNothing);
    });

    testWidgets('à zéro sans invite, garde le sous-titre', (tester) async {
      await tester.pumpWidget(_wrap(_tile(value: 0, emptyHint: null)));

      expect(find.text('Des colis à transporter pour vous'), findsOneWidget);
    });

    testWidgets('en chargement, ni pastille ni valeur', (tester) async {
      await tester.pumpWidget(_wrap(_tile(isLoading: true)));

      expect(find.byKey(const Key('activity-tile-badge')), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('Demandes reçues'), findsOneWidget);
    });

    testWidgets('en erreur, affiche un tiret court et reste cliquable', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(_tile(hasError: true, onTap: () => tapped = true)),
      );

      expect(find.text('-'), findsOneWidget);
      expect(find.byKey(const Key('activity-tile-badge')), findsNothing);
      // Une erreur de compteur ne doit pas bloquer l'accès à l'écran cible :
      // c'est lui qui gère son propre état d'erreur.
      await tester.tap(find.text('Demandes reçues'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('déclenche onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(_tile(onTap: () => tapped = true)));

      await tester.tap(find.text('Demandes reçues'));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('StatTile', () {
    testWidgets('affiche le libellé et la valeur formatée', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: '152 €',
            color: Colors.blue,
          ),
        ),
      );

      expect(find.text('Revenus'), findsOneWidget);
      expect(find.text('152 €'), findsOneWidget);
    });

    testWidgets('en chargement, masque la valeur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatTile(
            iconName: 'euro',
            label: 'Revenus',
            value: '152 €',
            color: Colors.blue,
            isLoading: true,
          ),
        ),
      );

      expect(find.text('152 €'), findsNothing);
      expect(find.text('Revenus'), findsOneWidget);
    });
  });
}
