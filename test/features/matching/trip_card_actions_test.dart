import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/firebase_session_probe.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/likes/bloc/trip_likes_cubit.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';
import 'package:dony/features/likes/data/repositories/trip_like_repository.dart';
import 'package:dony/features/likes/presentation/widgets/trip_like_button.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card_actions.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockLikeRepo extends Mock implements TripLikeRepository {}

class _MockFavoriteRepo extends Mock implements FavoriteRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _Probe implements FirebaseSessionProbe {
  const _Probe({required this.real});

  final bool real;

  @override
  bool get hasSession => true;
  @override
  bool get isAnonymous => !real;
  @override
  bool get hasRealSession => real;
}

AnnouncementModel _trip({
  String id = 'trip-1',
  String status = 'ACTIVE',
  int likeCount = 0,
  bool likedByMe = false,
  bool hidden = false,
}) => AnnouncementModel(
  id: id,
  travelerId: 'tv1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime.now().add(const Duration(days: 5)),
  availableKg: 15,
  totalKg: 20,
  pricePerKg: 8,
  status: status,
  createdAt: DateTime(2026, 3),
  updatedAt: DateTime(2026, 3),
  likeCount: likeCount,
  likedByMe: likedByMe,
  hidden: hidden,
  traveler: const TravelerProfile(
    id: 'tv1',
    displayName: 'Moustapha H.',
    averageRating: 4.6,
    totalTrips: 3,
  ),
);

const _likeButton = Key('trip-like-button');
const _likeCount = Key('trip-like-count');
const _readOnlyLikes = Key('trip-like-count-readonly');
const _shareButton = Key('trip-card-share-button');
const _actions = Key('trip-card-actions');

void main() {
  late _MockLikeRepo likeRepo;
  late _MockFavoriteRepo favoriteRepo;
  late _MockAnalytics analytics;
  late TripLikesCubit likes;
  late FavoriteIdsCubit favorites;

  setUpAll(() {
    initializeDateFormatting('fr');
    initializeDateFormatting('en');
  });

  setUp(() {
    likeRepo = _MockLikeRepo();
    favoriteRepo = _MockFavoriteRepo();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    likes = TripLikesCubit(likeRepo, analytics);
    favorites = FavoriteIdsCubit(favoriteRepo)
      ..emitSeed(trips: {}, requests: {});
    DonySnackbar.clearDedup();
  });

  tearDown(() async {
    await likes.close();
    await favorites.close();
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      await getIt.unregister<FirebaseSessionProbe>();
    }
  });

  void useSession({required bool real}) {
    if (getIt.isRegistered<FirebaseSessionProbe>()) {
      getIt.unregister<FirebaseSessionProbe>();
    }
    getIt.registerSingleton<FirebaseSessionProbe>(_Probe(real: real));
  }

  /// Monte [child] sur un écran de [width] dp, texte agrandi à [textScale],
  /// avec les vraies traductions, GoRouter (affiche, connexion) et les deux
  /// cubits réels, sous le thème [theme] (clair par défaut).
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = AppL10n.fr,
    double width = 360,
    double textScale = 1,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = Size(width * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: child,
            ),
          ),
        ),
        GoRoute(
          path: '/announcements/:id/affiche',
          builder: (_, state) =>
              Scaffold(body: Text('poster ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/auth/method',
          builder: (_, _) => const Scaffold(body: Text('auth-method')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TripLikesCubit>.value(value: likes),
          BlocProvider<FavoriteIdsCubit>.value(value: favorites),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, routed) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: routed!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Icon heartIcon(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(of: find.byKey(_likeButton), matching: find.byType(Icon)),
  );

  group('TripCardActions', () {
    testWidgets('affiche_coeur_partage_et_signet_pour_un_autre_voyageur', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 3), isOwn: false),
      );

      expect(find.byKey(_likeButton), findsOneWidget);
      expect(find.byKey(_shareButton), findsOneWidget);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      // Ordre de la maquette : ♡ puis partage à gauche, signet à droite.
      final heart = tester.getCenter(find.byKey(_likeButton)).dx;
      final share = tester.getCenter(find.byKey(_shareButton)).dx;
      final bookmark = tester.getCenter(find.byType(FavoriteHeartButton)).dx;
      expect(heart, lessThan(share));
      expect(share, lessThan(bookmark));
      // Flèche courbe pour le partage.
      final icon = tester.widget<DonyIcon>(
        find.descendant(
          of: find.byKey(_shareButton),
          matching: find.byType(DonyIcon),
        ),
      );
      expect(icon.name, 'share-curved');
      // Chaque bouton a son nom (infobulle) et une cible de 44 px.
      expect(find.byTooltip("J'aime"), findsOneWidget);
      expect(find.byTooltip("Partager l'affiche"), findsOneWidget);
      expect(find.byTooltip('Ajouter aux favoris'), findsOneWidget);
      for (final f in [
        find.byKey(_likeButton),
        find.byKey(_shareButton),
        find.byType(FavoriteHeartButton),
      ]) {
        final size = tester.getSize(f);
        expect(size.width, greaterThanOrEqualTo(kDonyMinTapTarget));
        expect(size.height, greaterThanOrEqualTo(kDonyMinTapTarget));
      }
      // Rien de sélectionné : ♡ et signet au contour, couleur neutre.
      expect(heartIcon(tester).icon, Icons.favorite_border);
      expect(heartIcon(tester).color, isNot(DonyColors.primary));
    });

    testWidgets('compteur_masque_a_zero_et_visible_a_partir_de_1', (
      tester,
    ) async {
      useSession(real: true);
      final semantics = tester.ensureSemantics();
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));
      expect(find.byKey(_likeButton), findsOneWidget);
      expect(find.byKey(_likeCount), findsNothing);

      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 1), isOwn: false),
      );
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '1');
      // Le ♡ est un bouton à bascule actionnable au lecteur d'écran
      // (TalkBack ACTION_CLICK, Switch Access, Voice Access).
      expect(
        tester.getSemantics(find.byKey(_likeButton)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          hasToggledState: true,
          label: "J'aime",
          value: '1 personne aime ce trajet',
        ),
      );
      semantics.dispose();
    });

    testWidgets('lecteur d\'écran : l\'action du ♡ aime le trajet', (
      tester,
    ) async {
      useSession(real: true);
      final semantics = tester.ensureSemantics();
      when(() => likeRepo.like('trip-1')).thenAnswer(
        (_) async => const TripLikeStatus(likeCount: 3, likedByMe: true),
      );
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 2), isOwn: false),
      );

      // Action « toucher » du lecteur d'écran, pas un toucher à l'écran.
      tester.semantics.tap(find.semantics.byLabel("J'aime"));
      await tester.pumpAndSettle();

      verify(() => likeRepo.like('trip-1')).called(1);
      // Libellé constant, l'état passe par « activé » : TalkBack lit
      // « J'aime, activé », jamais « Je n'aime plus, activé ».
      expect(
        tester.getSemantics(find.byKey(_likeButton)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
          label: "J'aime",
          value: '3 personnes aiment ce trajet',
        ),
      );
      // L'infobulle visuelle, elle, dit le geste qui suit.
      expect(find.byTooltip("Je n'aime plus"), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('lecteur d\'écran : libellé constant en anglais aussi', (
      tester,
    ) async {
      useSession(real: true);
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        TripCardActions(
          announcement: _trip(likeCount: 2, likedByMe: true),
          isOwn: false,
        ),
        locale: AppL10n.en,
      );
      expect(
        tester.getSemantics(find.byKey(_likeButton)),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          hasToggledState: true,
          isToggled: true,
          label: 'Like',
          value: '2 people like this trip',
        ),
      );
      expect(find.byTooltip('Unlike'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('le ♡ a sa propre surface d\'encre dans la carte, sans '
        'changer sa cible de 44 px', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TravelerCard(
          announcement: _trip(likeCount: 2),
          index: 0,
          isOwnAnnouncement: false,
          compact: true,
          showActions: true,
          onTap: () {},
        ),
      );
      final ink = find.descendant(
        of: find.byKey(_likeButton),
        matching: find.byType(InkWell),
      );
      expect(ink, findsOneWidget);
      // Le fond de la carte (Container décoré) recouvrait l'encre du Material
      // de l'écran : ni éclaboussure ni focus visible. Le Material le plus
      // proche est maintenant transparent, posé dans le ♡ lui-même.
      final material = tester
          .element(ink)
          .findAncestorWidgetOfExactType<Material>();
      expect(material?.type, MaterialType.transparency);
      expect(
        find.descendant(
          of: find.byKey(_likeButton),
          matching: find.byWidget(material!),
        ),
        findsOneWidget,
      );
      final size = tester.getSize(find.byKey(_likeButton));
      expect(size.width, greaterThanOrEqualTo(kDonyMinTapTarget));
      expect(size.height, greaterThanOrEqualTo(kDonyMinTapTarget));
      expect(
        tester.getSize(ink).height,
        greaterThanOrEqualTo(kDonyMinTapTarget),
      );
    });

    testWidgets('lecteur d\'écran : le compteur de son trajet n\'a pas '
        'd\'action', (tester) async {
      useSession(real: true);
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 4), isOwn: true),
      );

      final node = tester.getSemantics(find.byKey(_readOnlyLikes));
      expect(node, matchesSemantics(label: '4 personnes aiment ce trajet'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });

    testWidgets('grands nombres abrégés à la langue', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 1250), isOwn: false),
        locale: AppL10n.en,
      );
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '1.25K');
    });

    testWidgets('toucher_le_coeur_passe_au_primaire_et_incremente', (
      tester,
    ) async {
      useSession(real: true);
      when(() => likeRepo.like('trip-1')).thenAnswer(
        (_) async => const TripLikeStatus(likeCount: 3, likedByMe: true),
      );
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 2), isOwn: false),
      );
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '2');

      await tester.tap(find.byKey(_likeButton));
      await tester.pumpAndSettle();

      expect(heartIcon(tester).icon, Icons.favorite);
      expect(heartIcon(tester).color, DonyColors.primary);
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '3');
      expect(find.byTooltip("Je n'aime plus"), findsOneWidget);
      verify(() => likeRepo.like('trip-1')).called(1);
      verify(() => analytics.logEvent(AnalyticsEvents.tripLiked)).called(1);
    });

    testWidgets('toucher un coeur déjà aimé retire le j\'aime', (tester) async {
      useSession(real: true);
      when(() => likeRepo.unlike('trip-1')).thenAnswer(
        (_) async => const TripLikeStatus(likeCount: 1, likedByMe: false),
      );
      await pump(
        tester,
        TripCardActions(
          announcement: _trip(likeCount: 2, likedByMe: true),
          isOwn: false,
        ),
      );
      expect(heartIcon(tester).icon, Icons.favorite);

      await tester.tap(find.byKey(_likeButton));
      await tester.pumpAndSettle();

      expect(heartIcon(tester).icon, Icons.favorite_border);
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '1');
      verify(() => likeRepo.unlike('trip-1')).called(1);
    });

    testWidgets('echec_du_j_aime_affiche_le_message_d_erreur', (tester) async {
      useSession(real: true);
      when(() => likeRepo.like('trip-1')).thenThrow(Exception('réseau'));
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 2), isOwn: false),
      );

      await tester.tap(find.byKey(_likeButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(AppL10n.current.listingRetryActionMessage),
        findsOneWidget,
      );
      // Retour à l'état d'avant.
      expect(heartIcon(tester).icon, Icons.favorite_border);
      expect(tester.widget<Text>(find.byKey(_likeCount)).data, '2');
    });

    testWidgets('toucher_le_signet_appelle_toggleTrip', (tester) async {
      useSession(real: true);
      when(() => favoriteRepo.add('trip', 'trip-1')).thenAnswer((_) async {});
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pumpAndSettle();

      expect(favorites.isTripFav('trip-1'), isTrue);
      verify(() => favoriteRepo.add('trip', 'trip-1')).called(1);
      final bookmark = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteHeartButton),
          matching: find.byType(Icon),
        ),
      );
      expect(bookmark.icon, Icons.bookmark);
      expect(bookmark.color, DonyColors.primary);
      // Les deux gestes sont indépendants.
      verifyNever(() => likeRepo.like(any()));
    });

    testWidgets('signet en échec : message d\'erreur', (tester) async {
      useSession(real: true);
      when(
        () => favoriteRepo.add('trip', 'trip-1'),
      ).thenThrow(Exception('réseau'));
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(AppL10n.current.listingRetryActionMessage),
        findsOneWidget,
      );
    });

    testWidgets(
      'voyageur_sur_son_trajet_voit_le_compteur_sans_coeur_ni_signet',
      (tester) async {
        useSession(real: true);
        await pump(
          tester,
          TripCardActions(announcement: _trip(likeCount: 4), isOwn: true),
        );

        expect(find.byKey(_likeButton), findsNothing);
        expect(find.byType(FavoriteHeartButton), findsNothing);
        expect(find.byKey(_readOnlyLikes), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(_readOnlyLikes),
            matching: find.text('4'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(_shareButton), findsOneWidget);
        // Cœur au contour, neutre : il ne se lit pas « j'ai aimé mon trajet ».
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(_readOnlyLikes),
            matching: find.byType(Icon),
          ),
        );
        final cs = Theme.of(
          tester.element(find.byKey(_readOnlyLikes)),
        ).colorScheme;
        expect(icon.icon, Icons.favorite_border);
        expect(icon.color, cs.onSurfaceVariant);
        // Lecture seule : toucher le compteur ne fait rien.
        await tester.tap(find.byKey(_readOnlyLikes));
        await tester.pumpAndSettle();
        verifyNever(() => likeRepo.like(any()));
        expect(find.text('Connexion requise'), findsNothing);
      },
    );

    testWidgets('son trajet sans j\'aime : partage seul', (tester) async {
      useSession(real: true);
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: true));
      expect(find.byKey(_readOnlyLikes), findsNothing);
      expect(find.byKey(_shareButton), findsOneWidget);
    });

    testWidgets('son trajet complet sans j\'aime : aucune ligne ni filet', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCardActions(announcement: _trip(status: 'FULL'), isOwn: true),
      );
      expect(find.byKey(_actions), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('son trajet complet aimé : compteur seul, la ligne suit les '
        'j\'aime reçus', (tester) async {
      useSession(real: true);
      final full = _trip(status: 'FULL', likeCount: 3);
      await pump(tester, TripCardActions(announcement: full, isOwn: true));
      expect(find.byKey(_actions), findsOneWidget);
      expect(find.byKey(_readOnlyLikes), findsOneWidget);
      expect(find.byKey(_shareButton), findsNothing);

      // Liste relue : plus aucun j'aime, la ligne et son filet disparaissent.
      likes.seed([_trip(status: 'FULL')]);
      expect(likes.state.byTrip['trip-1']?.likeCount, 0);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_actions), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets(
      'visiteur_touchant_le_coeur_ouvre_l_invitation_et_ne_change_rien',
      (tester) async {
        useSession(real: false);
        await pump(
          tester,
          TripCardActions(announcement: _trip(likeCount: 2), isOwn: false),
        );

        await tester.tap(find.byKey(_likeButton));
        await tester.pumpAndSettle();

        // L'invitation des visiteurs, avec son texte du j'aime.
        expect(find.text('Connexion requise'), findsOneWidget);
        expect(
          find.text('Connectez-vous pour aimer ce trajet.'),
          findsOneWidget,
        );
        expect(
          find.text(
            "Un j'aime est lié à votre compte : il montre au voyageur que "
            'son trajet intéresse.',
          ),
          findsOneWidget,
        );
        verify(
          () => analytics.logEvent(AnalyticsEvents.tripLikeLoginPrompted),
        ).called(1);
        verifyNever(() => likeRepo.like(any()));
        expect(likes.state.byTrip, isEmpty);

        // « Continuer à explorer » : rien n'a bougé sur la carte.
        await tester.tap(find.text('Continuer à explorer'));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(_likeCount)).data, '2');
        expect(heartIcon(tester).icon, Icons.favorite_border);
      },
    );

    testWidgets('visiteur : « Se connecter » mène à la connexion', (
      tester,
    ) async {
      useSession(real: false);
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));
      await tester.tap(find.byKey(_likeButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('auth-method'), findsOneWidget);
    });

    testWidgets('visiteur : le favori fonctionne comme avant', (tester) async {
      useSession(real: false);
      when(() => favoriteRepo.add('trip', 'trip-1')).thenAnswer((_) async {});
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));

      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pumpAndSettle();

      expect(favorites.isTripFav('trip-1'), isTrue);
      expect(find.text('Connexion requise'), findsNothing);
    });

    testWidgets('partage_absent_quand_canShareTripPoster_est_faux', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCardActions(
          announcement: _trip(status: 'FULL', likeCount: 2),
          isOwn: false,
        ),
      );
      expect(find.byKey(_shareButton), findsNothing);
      expect(find.byKey(_likeButton), findsOneWidget);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
    });

    testWidgets('partage : ouvre l\'affiche du trajet et le mesure', (
      tester,
    ) async {
      useSession(real: true);
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));

      await tester.tap(find.byKey(_shareButton));
      await tester.pumpAndSettle();

      expect(find.text('poster trip-1'), findsOneWidget);
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripCardShareTapped),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.tripLikeLoginPrompted),
      );
    });

    testWidgets('visiteur : le partage ouvre l\'invitation, pas l\'affiche', (
      tester,
    ) async {
      useSession(real: false);
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));

      await tester.tap(find.byKey(_shareButton));
      await tester.pumpAndSettle();

      expect(find.text('Connexion requise'), findsOneWidget);
      expect(
        find.text('Connectez-vous pour partager ce trajet.'),
        findsOneWidget,
      );
      expect(
        find.text(
          "Avec un compte Yadony, partagez l'affiche du trajet : image, "
          'lien et légende prêts à envoyer.',
        ),
        findsOneWidget,
      );
      // Le partage n'a pas eu lieu : invitation mesurée, pas de partage.
      verify(
        () => analytics.logEvent(AnalyticsEvents.tripLikeLoginPrompted),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(AnalyticsEvents.tripCardShareTapped),
      );

      // « Continuer à explorer » : toujours sur la carte, jamais l'affiche.
      await tester.tap(find.text('Continuer à explorer'));
      await tester.pumpAndSettle();
      expect(find.text('poster trip-1'), findsNothing);
      expect(find.byKey(_shareButton), findsOneWidget);
    });

    testWidgets('visiteur : invitation au partage en anglais', (tester) async {
      useSession(real: false);
      await pump(
        tester,
        TripCardActions(announcement: _trip(), isOwn: false),
        locale: AppL10n.en,
      );

      await tester.tap(find.byKey(_shareButton));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to share this trip.'), findsOneWidget);
      expect(
        find.text(
          'With a Yadony account, share the trip poster: image, link and '
          'caption ready to send.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('partage : primaire seulement pendant l\'appui', (
      tester,
    ) async {
      useSession(real: true);
      await pump(tester, TripCardActions(announcement: _trip(), isOwn: false));
      Color? shareColor() => tester
          .widget<DonyIcon>(
            find.descendant(
              of: find.byKey(_shareButton),
              matching: find.byType(DonyIcon),
            ),
          )
          .color;

      expect(shareColor(), isNot(DonyColors.primary));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_shareButton)),
      );
      // Appui reconnu à 100 ms, puis teinte du bouton animée (200 ms) ;
      // relevé avant l'appui long (500 ms) qui ouvrirait l'infobulle.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 250));
      expect(shareColor(), DonyColors.primary);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(shareColor(), isNot(DonyColors.primary));
    });

    // Le primaire du thème change avec le mode sombre et le contraste élevé
    // (bleu #0B5FFF ≈ 3,4:1 sur la surface sombre : échec AA).
    for (final (name, theme) in [
      ('sombre', AppTheme.dark()),
      (
        'contraste élevé',
        AppTheme.light(a11y: const A11yThemeOptions(highContrast: true)),
      ),
      (
        'sombre et contraste élevé',
        AppTheme.dark(a11y: const A11yThemeOptions(highContrast: true)),
      ),
    ]) {
      testWidgets('thème $name : ♡ aimé, compteur, signet et partage au '
          'primaire du thème', (tester) async {
        useSession(real: true);
        final primary = theme.colorScheme.primary;
        expect(primary, isNot(DonyColors.primary));
        favorites.emitSeed(trips: {'trip-1'}, requests: {});
        await pump(
          tester,
          TripCardActions(
            announcement: _trip(likeCount: 3, likedByMe: true),
            isOwn: false,
          ),
          theme: theme,
        );

        expect(heartIcon(tester).icon, Icons.favorite);
        expect(heartIcon(tester).color, primary);
        expect(
          tester.widget<Text>(find.byKey(_likeCount)).style?.color,
          primary,
        );
        final bookmark = tester.widget<Icon>(
          find.descendant(
            of: find.byType(FavoriteHeartButton),
            matching: find.byType(Icon),
          ),
        );
        expect(bookmark.icon, Icons.bookmark);
        expect(bookmark.color, primary);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(_shareButton)),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester
              .widget<DonyIcon>(
                find.descendant(
                  of: find.byKey(_shareButton),
                  matching: find.byType(DonyIcon),
                ),
              )
              .color,
          primary,
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
      });
    }

    testWidgets('sans cubits dans l\'arbre : partage seul, sans plantage', (
      tester,
    ) async {
      useSession(real: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripCardActions(announcement: _trip(), isOwn: false),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(_likeButton), findsNothing);
      expect(find.byType(FavoriteHeartButton), findsNothing);
      expect(find.byKey(_shareButton), findsOneWidget);
    });

    testWidgets('textes en anglais', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TripCardActions(announcement: _trip(likeCount: 2), isOwn: false),
        locale: AppL10n.en,
      );
      expect(find.byTooltip('Like'), findsOneWidget);
      expect(find.byTooltip('Share the poster'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
    });

    for (final locale in [AppL10n.fr, AppL10n.en]) {
      testWidgets('aucun_debordement_a_360dp_et_texte_200_pourcent '
          '(${locale.languageCode})', (tester) async {
        useSession(real: true);
        await pump(
          tester,
          Column(
            children: [
              TripCardActions(
                announcement: _trip(likeCount: 987),
                isOwn: false,
              ),
              TripCardActions(
                announcement: _trip(id: 'own', likeCount: 987),
                isOwn: true,
              ),
              TravelerCard(
                announcement: _trip(id: 'card', likeCount: 987),
                index: 0,
                isOwnAnnouncement: false,
                compact: true,
                showActions: true,
                onTap: () {},
              ),
              TripCard(
                announcement: _trip(id: 'fav', likeCount: 987),
                index: 0,
                showFavorite: true,
                onTap: () {},
              ),
            ],
          ),
          locale: locale,
          textScale: 2,
        );
        // Pastille de statut pulsée de TripCard : pas de pumpAndSettle.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        expect(tester.takeException(), isNull);
        final rows = find.byKey(_actions);
        expect(rows, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          expect(
            tester.getSize(rows.at(i)).height,
            greaterThanOrEqualTo(kDonyMinTapTarget),
          );
        }
        // Les boutons restent à leur taille : jamais rétrécis.
        for (final f in [
          find.byKey(_likeButton).first,
          find.byKey(_shareButton).first,
          find.byType(FavoriteHeartButton).first,
        ]) {
          expect(
            tester.getSize(f).height,
            greaterThanOrEqualTo(kDonyMinTapTarget),
          );
        }
      });
    }
  });

  group('TripLikeButton.canLike : même règle que le back', () {
    const expected = {
      'ACTIVE': true,
      'FULL': true,
      'DRAFT': false,
      'IN_PROGRESS': false,
      'COMPLETED': false,
      'CANCELLED': false,
      'REMOVED_BY_ADMIN': false,
      'SOMETHING_NEW': false,
    };
    for (final MapEntry(key: status, value: likeable) in expected.entries) {
      test(status, () {
        expect(TripLikeButton.canLike(_trip(status: status)), likeable);
        // Caché : jamais, quel que soit le statut.
        expect(
          TripLikeButton.canLike(_trip(status: status, hidden: true)),
          isFalse,
        );
      });
    }
  });

  group('TripCard', () {
    testWidgets('carte active d\'un autre voyageur : signet dans la ligne, '
        'plus dans l\'en-tête', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(
          announcement: _trip(likeCount: 2),
          index: 0,
          showFavorite: true,
          onTap: () {},
        ),
      );

      expect(find.byKey(_actions), findsOneWidget);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_actions),
          matching: find.byType(FavoriteHeartButton),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_likeButton), findsOneWidget);
    });

    testWidgets('carte sans showFavorite ni showOwnLikes : aucune ligne', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(announcement: _trip(), index: 0, onTap: () {}),
      );
      expect(find.byKey(_actions), findsNothing);
    });

    testWidgets('showOwnLikes : compteur en lecture seule, sans signet', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(
          announcement: _trip(likeCount: 5),
          index: 0,
          showOwnLikes: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_readOnlyLikes), findsOneWidget);
      expect(find.byKey(_likeButton), findsNothing);
      expect(find.byType(FavoriteHeartButton), findsNothing);
    });

    testWidgets('son trajet en favori : compteur en lecture seule et signet '
        'pour le retirer', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(
          announcement: _trip(likeCount: 5),
          index: 0,
          showFavorite: true,
          showOwnLikes: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_readOnlyLikes), findsOneWidget);
      expect(find.byKey(_likeButton), findsNothing);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
    });

    // Le back n'accepte un j'aime que sur un trajet ACTIVE ou FULL non caché :
    // ailleurs, chaque toucher donnait un 404 puis « Action impossible ».
    for (final (name, trip) in [
      ('en cours', _trip(status: 'IN_PROGRESS', likeCount: 3)),
      ('brouillon', _trip(status: 'DRAFT', likeCount: 3)),
      ('retiré par l\'équipe', _trip(status: 'REMOVED_BY_ADMIN', likeCount: 3)),
      ('caché', _trip(likeCount: 3, hidden: true)),
      ('complet et caché', _trip(status: 'FULL', likeCount: 3, hidden: true)),
    ]) {
      testWidgets('favori $name d\'un autre : ♡ en lecture seule, signet '
          'gardé', (tester) async {
        useSession(real: true);
        await pump(
          tester,
          TripCard(
            announcement: trip,
            index: 0,
            showFavorite: true,
            onTap: () {},
          ),
        );
        expect(find.byKey(_likeButton), findsNothing);
        expect(find.byKey(_readOnlyLikes), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(_readOnlyLikes),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        expect(find.byType(FavoriteHeartButton), findsOneWidget);

        await tester.tap(find.byKey(_readOnlyLikes));
        await tester.pump(const Duration(milliseconds: 300));
        verifyNever(() => likeRepo.like(any()));
        verifyNever(() => likeRepo.unlike(any()));
        expect(
          find.text(AppL10n.current.listingRetryActionMessage),
          findsNothing,
        );
      });
    }

    testWidgets('favori complet d\'un autre : ♡ actif', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(
          announcement: _trip(status: 'FULL', likeCount: 3),
          index: 0,
          showFavorite: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_likeButton), findsOneWidget);
      expect(find.byKey(_readOnlyLikes), findsNothing);
    });

    testWidgets('son trajet complet sans j\'aime : la carte garde sa marge '
        'du bas', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        Column(
          children: [
            TripCard(
              announcement: _trip(id: 'a', status: 'FULL'),
              index: 0,
              showOwnLikes: true,
              onTap: () {},
            ),
            TripCard(
              announcement: _trip(id: 'b', status: 'FULL'),
              index: 0,
              onTap: () {},
            ),
          ],
        ),
      );
      expect(find.byKey(_actions), findsNothing);
      final cards = find.byType(TripCard);
      expect(
        tester.getSize(cards.at(0)).height,
        tester.getSize(cards.at(1)).height,
      );
    });

    testWidgets('carte passée : inchangée, signet dans l\'en-tête', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TripCard(
          announcement: _trip(status: 'COMPLETED', likeCount: 2),
          index: 0,
          showFavorite: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_actions), findsNothing);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
    });
  });

  group('TravelerCard', () {
    testWidgets('showActions : ligne sous la carte de recherche', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TravelerCard(
          announcement: _trip(likeCount: 24),
          index: 0,
          isOwnAnnouncement: false,
          compact: true,
          showActions: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_actions), findsOneWidget);
      expect(find.byKey(_likeButton), findsOneWidget);
      expect(find.byKey(_shareButton), findsOneWidget);
      expect(find.byType(FavoriteHeartButton), findsOneWidget);
      // La ligne ferme la carte : sous le prix.
      expect(
        tester.getTopLeft(find.byKey(_actions)).dy,
        greaterThan(tester.getTopLeft(find.text('Moustapha H.')).dy),
      );
    });

    testWidgets('sans showActions (défaut) : carte inchangée', (tester) async {
      useSession(real: true);
      await pump(
        tester,
        TravelerCard(
          announcement: _trip(likeCount: 24),
          index: 0,
          isOwnAnnouncement: false,
          onTap: () {},
        ),
      );
      expect(find.byKey(_actions), findsNothing);
    });

    testWidgets('son trajet : compteur en lecture seule, ni coeur ni signet', (
      tester,
    ) async {
      useSession(real: true);
      await pump(
        tester,
        TravelerCard(
          announcement: _trip(likeCount: 24),
          index: 0,
          isOwnAnnouncement: true,
          compact: true,
          showActions: true,
          onTap: () {},
        ),
      );
      expect(find.byKey(_readOnlyLikes), findsOneWidget);
      expect(find.byKey(_likeButton), findsNothing);
      expect(find.byType(FavoriteHeartButton), findsNothing);
      expect(find.byKey(_shareButton), findsOneWidget);
    });

    for (final compact in [true, false]) {
      testWidgets('son trajet complet sans j\'aime : la carte garde sa marge '
          'du bas (compact: $compact)', (tester) async {
        useSession(real: true);
        TravelerCard card(String id, {required bool actions}) => TravelerCard(
          announcement: _trip(id: id, status: 'FULL'),
          index: 0,
          isOwnAnnouncement: true,
          compact: compact,
          showActions: actions,
          onTap: () {},
        );
        await pump(
          tester,
          Column(
            children: [card('a', actions: true), card('b', actions: false)],
          ),
        );
        expect(find.byKey(_actions), findsNothing);
        final cards = find.byType(TravelerCard);
        expect(
          tester.getSize(cards.at(0)).height,
          tester.getSize(cards.at(1)).height,
        );

        // Un j'aime arrive : la ligne s'affiche et la marge se resserre
        // (la zone de 44 px porte son propre blanc).
        likes.seed([_trip(id: 'a', status: 'FULL', likeCount: 2)]);
        await tester.pump();
        expect(find.byKey(_actions), findsOneWidget);
        // Boîte de la carte elle-même, sous la même translation d'entrée
        // (flutter_animate) que la ligne.
        final box = find.byKey(const Key('traveler-card-opacity')).first;
        expect(
          tester.getBottomLeft(find.byKey(_actions)).dy,
          moreOrLessEquals(
            tester.getBottomLeft(box).dy -
                TripCardActions.cardBottomPadding -
                1.5, // bordure de « Votre trajet »
            epsilon: 0.01,
          ),
        );
      });
    }

    testWidgets('toucher le coeur n\'ouvre pas le trajet', (tester) async {
      useSession(real: true);
      when(() => likeRepo.like('trip-1')).thenAnswer(
        (_) async => const TripLikeStatus(likeCount: 1, likedByMe: true),
      );
      var opened = 0;
      await pump(
        tester,
        TravelerCard(
          announcement: _trip(),
          index: 0,
          isOwnAnnouncement: false,
          compact: true,
          showActions: true,
          onTap: () => opened++,
        ),
      );
      await tester.tap(find.byKey(_likeButton));
      await tester.pumpAndSettle();
      expect(opened, 0);
      verify(() => likeRepo.like('trip-1')).called(1);
    });
  });
}
