import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

AnnouncementModel _makeAnn({
  String departureCity = 'Paris',
  String arrivalCity = 'Dakar',
  String? departureFlag,
  String? arrivalFlag,
  bool kiloPro = false,
  bool isProAccount = false,
  bool kycVerified = false,
  DateTime? departureDate,
  List<String>? acceptedContentTypes,
}) =>
    AnnouncementModel(
      id: 'a1',
      travelerId: 't1',
      departureCity: departureCity,
      arrivalCity: arrivalCity,
      departureFlag: departureFlag,
      arrivalFlag: arrivalFlag,
      departureDate: departureDate ?? DateTime(2026, 6, 15),
      availableKg: 8,
      totalKg: 8,
      pricePerKg: 12,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      acceptedContentTypes: acceptedContentTypes,
      traveler: TravelerProfile(
        id: 't1',
        displayName: 'Mamadou Diallo',
        averageRating: 4.8,
        totalTrips: 5,
        kiloPro: kiloPro,
        isProAccount: isProAccount,
        kycVerified: kycVerified,
      ),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

/// Rend [child] contraint à [width], pour reproduire l'écart de largeur entre
/// la liste (large) et le carousel (étroit).
Widget _wrapAt(double width, Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  // Épingle le taux de commission : ces tests assertent des montants
  // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
  setUpAll(() => setDonyCommissionRate(0.12));
  tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  setUpAll(() => initializeDateFormatting('fr'));

  group('TravelerCard', () {
    testWidgets('shows traveler name and price', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Mamadou Diallo'), findsOneWidget);
      // Carte vue par l'expéditeur : prix au kilo affiché = net × 1,12
      // (12 €/kg net → 13,44 €/kg commission Dony incluse).
      expect(find.text('13.44 €/kg'), findsOneWidget);
    });

    testWidgets('shows KYC badge when kiloPro is true', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(kiloPro: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('KYC'), findsOneWidget);
    });

    testWidgets('shows PRO badge when isProAccount is true', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('PRO'), findsOneWidget);
    });

    testWidgets('does NOT show PRO badge when isProAccount is false',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: false),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('PRO'), findsNothing);
    });

    testWidgets('avatar shows gold verified badge when pro + kycVerified',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: true, kycVerified: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      final goldIcons = tester.widgetList<DonyIcon>(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check')).where(
        (icon) => icon.color == const Color(0xFFF0B829),
      );
      expect(goldIcons, isNotEmpty);
    });

    testWidgets('avatar shows blue verified badge when kycVerified but NOT pro',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(isProAccount: false, kycVerified: true),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      final blueIcons = tester.widgetList<DonyIcon>(find.byWidgetPredicate((w) => w is DonyIcon && w.name == 'badge-check')).where(
        (icon) => icon.color != const Color(0xFFF0B829),
      );
      expect(blueIcons, isNotEmpty);
    });

    testWidgets(
        'own card shows pill, chevron and is tappable when isOwnAnnouncement',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: true,
        onTap: () => tapped = true,
      )));
      await tester.pumpAndSettle();

      // Pill « Votre trajet » présent (key + texte).
      expect(find.byKey(const Key('own-trip-pill')), findsOneWidget);
      expect(find.text('Votre trajet'), findsOneWidget);

      // Chevron de cliquabilité sur le corridor.
      final chevrons = tester.widgetList<DonyIcon>(find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'chevron-right',
      ));
      expect(chevrons, isNotEmpty);

      // La carte propriétaire est désormais cliquable.
      await tester.tap(find.byType(TravelerCard));
      expect(tapped, isTrue);
    });

    testWidgets('does NOT show own-trip pill when isOwnAnnouncement is false',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('own-trip-pill')), findsNothing);
      expect(find.text('Votre trajet'), findsNothing);
      final chevrons = tester.widgetList<DonyIcon>(find.byWidgetPredicate(
        (w) => w is DonyIcon && w.name == 'chevron-right',
      ));
      expect(chevrons, isEmpty);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () => tapped = true,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TravelerCard));
      expect(tapped, isTrue);
    });
  });

  group('TravelerCard – trajet (route header)', () {
    testWidgets('affiche les villes départ et arrivée', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(departureCity: 'Lyon', arrivalCity: 'Abidjan'),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Abidjan'), findsOneWidget);
    });

    testWidgets('retombe sur cityFlag quand le drapeau backend est absent',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      // Paris → 🇫🇷, Dakar → 🇸🇳 via la map locale cityFlag().
      expect(find.text('🇫🇷'), findsOneWidget);
      expect(find.text('🇸🇳'), findsOneWidget);
    });

    testWidgets('privilégie le drapeau résolu par le backend', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(
          departureCity: 'Tombouctou-les-Bains', // inconnu de cityFlag
          departureFlag: '🇲🇱',
          arrivalFlag: '🇸🇳',
        ),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('🇲🇱'), findsOneWidget);
      expect(find.text('🇸🇳'), findsOneWidget);
    });

    testWidgets('appui réduit légèrement la carte (scale < 1)', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(TravelerCard)));
      await tester.pump(const Duration(milliseconds: 200));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('TravelerCard – distanceBadge', () {
    testWidgets('affiche le badge quand distanceBadge est fourni', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        distanceBadge: 'CDG · 8 km',
      )));
      await tester.pumpAndSettle();
      expect(find.text('CDG · 8 km'), findsOneWidget);
    });

    testWidgets('n\'affiche rien quand distanceBadge est null', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('CDG · 8 km'), findsNothing);
    });
  });

  group('TravelerCard – existingBidStatus', () {
    const chipKey = Key('traveler-card-existing-bid-chip');

    testWidgets('affiche le chip "Demande en attente" pour status PENDING',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'PENDING',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande en attente'), findsOneWidget);
    });

    testWidgets('affiche le chip "Demande acceptée" pour status ACCEPTED',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'ACCEPTED',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande acceptée'), findsOneWidget);
    });

    testWidgets(
        'PAYMENT_ESCROWED reste "Demande en attente" (paiement séquestré, non accepté)',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        existingBidStatus: 'PAYMENT_ESCROWED',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsOneWidget);
      expect(find.text('Demande en attente'), findsOneWidget);
      expect(find.text('Demande acceptée'), findsNothing);
    });

    testWidgets("n'affiche pas le chip quand existingBidStatus est null",
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(chipKey), findsNothing);
    });
  });

  // ── showFavorite ────────────────────────────────────────────────────────────

  group('TravelerCard – showFavorite', () {
    testWidgets(
        'showFavorite=false (défaut) : aucun FavoriteHeartButton affiché',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets(
        'showFavorite=true sans cubit dans l\'arbre : dégradation silencieuse (pas de crash)',
        (tester) async {
      // No FavoriteIdsCubit provided — defensive read must not crash.
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
        showFavorite: true,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets(
        'showFavorite=true avec cubit : FavoriteHeartButton affiché non-favori',
        (tester) async {
      final repo = _MockFavoriteRepository();
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TravelerCard(
            announcement: _makeAnn(),
            index: 0,
            isOwnAnnouncement: false,
            onTap: () {},
            showFavorite: true,
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      final icons = find.descendant(
        of: find.byType(FavoriteHeartButton),
        matching: find.byType(Icon),
      );
      final icon = tester.widget<Icon>(icons.first);
      expect(icon.icon, Icons.bookmark_border);
    });

    testWidgets(
        'showFavorite=true avec cubit seeded favori : signet rempli',
        (tester) async {
      final repo = _MockFavoriteRepository();
      // 'a1' is the id used in _makeAnn()
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {'a1'}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TravelerCard(
            announcement: _makeAnn(),
            index: 0,
            isOwnAnnouncement: false,
            onTap: () {},
            showFavorite: true,
          )),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      final icons = find.descendant(
        of: find.byType(FavoriteHeartButton),
        matching: find.byType(Icon),
      );
      final icon = tester.widget<Icon>(icons.first);
      expect(icon.icon, Icons.bookmark);
      expect(icon.color, DonyColors.primary);
    });

    testWidgets(
        'showFavorite=true : tap cœur appelle toggleTrip sur l\'id de l\'annonce',
        (tester) async {
      final repo = _MockFavoriteRepository();
      when(() => repo.add(any(), any())).thenAnswer((_) async {});

      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TravelerCard(
            announcement: _makeAnn(),
            index: 0,
            isOwnAnnouncement: false,
            onTap: () {},
            showFavorite: true,
          )),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump(const Duration(milliseconds: 500));

      // 'a1' is the announcement id from _makeAnn()
      expect(cubit.isTripFav('a1'), isTrue);
      verify(() => repo.add('trip', 'a1')).called(1);
    });

    testWidgets(
        'isOwnAnnouncement=true : même avec showFavorite=true (défense en amont), le cœur est rendu — owner guard est la responsabilité de l\'appelant',
        (tester) async {
      // The card itself has no owner guard; the caller must pass showFavorite:false
      // for own announcements. This test documents/verifies the card renders the
      // heart when showFavorite=true regardless of ownership.
      final repo = _MockFavoriteRepository();
      final cubit = FavoriteIdsCubit(repo)
        ..emitSeed(trips: {}, requests: {});

      await tester.pumpWidget(
        BlocProvider<FavoriteIdsCubit>.value(
          value: cubit,
          child: _wrap(TravelerCard(
            announcement: _makeAnn(),
            index: 0,
            isOwnAnnouncement: true,
            onTap: () {},
            showFavorite: true,
          )),
        ),
      );
      await tester.pumpAndSettle();

      // Card renders the heart — owner guard is caller's responsibility
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
    });
  });

  // ── Badge urgent ─────────────────────────────────────────────────────────

  group('TravelerCard – badge urgent', () {
    testWidgets('affiche le badge Urgent quand annonce.isUrgent', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(
          departureDate: DateTime.now().add(const Duration(days: 1)),
        ),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('🔥 Urgent'), findsOneWidget);
    });

    testWidgets('pas de badge Urgent si départ lointain', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(
          departureDate: DateTime.now().add(const Duration(days: 20)),
        ),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('🔥 Urgent'), findsNothing);
    });
  });

  group('TravelerCard — badges alignés liste/carousel', () {
    // Note, trajets et badges vivaient dans un seul Wrap : selon la largeur
    // (liste large vs carousel étroit), PRO et Urgent débordaient à des
    // endroits différents, donnant deux hauteurs de carte. Les badges vivent
    // désormais sur leur propre ligne, donc ils s'alignent quelle que soit la
    // largeur.
    Widget card() => TravelerCard(
          announcement: _makeAnn(
            isProAccount: true,
            departureDate: DateTime.now().add(const Duration(days: 2)),
          ),
          index: 0,
          isOwnAnnouncement: false,
          onTap: () {},
        );

    Future<void> expectBadgesSameRow(WidgetTester tester, double width) async {
      await tester.pumpWidget(_wrapAt(width, card()));
      await tester.pumpAndSettle();
      final pro = tester.getTopLeft(find.text('PRO')).dy;
      final urgent = tester.getTopLeft(find.text('🔥 Urgent')).dy;
      expect(urgent, pro,
          reason: 'PRO et Urgent doivent être sur la même ligne à '
              '\${width.toStringAsFixed(0)} px de large');
    }

    testWidgets('PRO et Urgent sur la même ligne, en large comme en étroit',
        (tester) async {
      await expectBadgesSameRow(tester, 430); // liste
      await expectBadgesSameRow(tester, 330); // carousel
    });
  });

  group('TravelerCard — catégories acceptées', () {
    // Les libellés du catalogue sont longs : au-delà d'un seul, chacun passait
    // à la ligne et la carte s'étirait sur trois rangées pour une information
    // secondaire.
    testWidgets('n\'affiche qu\'une catégorie, le reste dans « +N »',
        (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement: _makeAnn(acceptedContentTypes: const [
          'Vêtements & tissus',
          'Documents & administratif',
          'Médicaments traditionnels',
        ]),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Vêtements & tissus'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('Documents & administratif'), findsNothing);
      expect(find.text('Médicaments traditionnels'), findsNothing);
    });

    testWidgets('une seule catégorie : pas de pastille « +N »', (tester) async {
      await tester.pumpWidget(_wrap(TravelerCard(
        announcement:
            _makeAnn(acceptedContentTypes: const ['Vêtements & tissus']),
        index: 0,
        isOwnAnnouncement: false,
        onTap: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Vêtements & tissus'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
