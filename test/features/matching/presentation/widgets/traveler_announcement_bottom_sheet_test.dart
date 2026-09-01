import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/favorites/bloc/favorite_ids_cubit.dart';
import 'package:dony/features/favorites/data/repositories/favorite_repository.dart';
import 'package:dony/features/favorites/presentation/widgets/favorite_heart_button.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _MockExternalUrlLauncher extends Mock implements ExternalUrlLauncher {}

class _MockFavoriteRepository extends Mock implements FavoriteRepository {}

class _FakeUri extends Fake implements Uri {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

UserModel _userWithKyc(String kycStatus) => UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: kycStatus,
  status: 'ACTIVE',
);

AnnouncementModel _buildAnnouncement({
  bool kycVerified = false,
  int? totalTrips,
  double? rating,
  String displayName = 'Ibrahima Diallo',
  DateTime? handoverDeadline,
  bool acceptsUnverified = false,
  bool isProAccount = false,
  String currency = 'EUR',
  bool negotiable = false,
  String pricingMode = 'PER_KG',
  List<AnnouncementGridItemModel> priceGridItems = const [],
  AddressData? pickupAddress,
  AddressData? deliveryAddress,
  String? departureTime,
  String? arrivalTime,
  String? arrivalInstructions,
  Set<BidPaymentMethod> acceptedPaymentMethods = const {
    BidPaymentMethod.stripe,
  },
}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(now.year, now.month + 1, 15),
    departureTime: departureTime,
    arrivalTime: arrivalTime,
    availableKg: 12,
    totalKg: 20,
    pricePerKg: 8,
    currency: currency,
    status: 'ACTIVE',
    negotiable: negotiable,
    pricingMode: pricingMode,
    priceGridItems: priceGridItems,
    pickupAddress: pickupAddress,
    deliveryAddress: deliveryAddress,
    arrivalInstructions: arrivalInstructions,
    acceptedPaymentMethods: acceptedPaymentMethods,
    traveler: TravelerProfile(
      id: 't1',
      displayName: displayName,
      averageRating: rating,
      totalTrips: totalTrips,
      kycVerified: kycVerified,
      acceptsUnverified: acceptsUnverified,
      isProAccount: isProAccount,
    ),
    createdAt: now,
    updatedAt: now,
    handoverDeadline: handoverDeadline,
  );
}

// _harness fournit toujours un AuthBloc et un BidBloc (par défaut : user vérifié).
// Les tests existants passent authState: null → AuthAuthenticated(VERIFIED).
// IMPORTANT: showTravelerAnnouncementSheet doit lire AuthBloc et BidBloc depuis
// le context original (avant DonyBottomSheet.show), pas depuis innerCtx — sinon
// useRootNavigator:true sort du BlocProvider et provoque un ProviderNotFoundException.
Widget _harness({
  required AnnouncementModel announcement,
  AuthState? authState,
  BidState? bidState,
  FavoriteIdsCubit? favorites,
}) {
  final authBloc = _MockAuthBloc();
  when(
    () => authBloc.state,
  ).thenReturn(authState ?? AuthAuthenticated(_userWithKyc('VERIFIED')));
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

  // showTravelerAnnouncementSheet lit BidBloc depuis l'arbre (context.read)
  // pour détecter un colis existant + rafraîchir la liste parente après bid.
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

  // Depuis 06a9a2bc (PR #126), CreateBidBottomSheet.show() délègue à
  // context.push('/bids/new') : le harness fournit donc un GoRouter avec la
  // route CreateBidScreen — miroir de l'enregistrement réel de router.dart.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showTravelerAnnouncementSheet(
                ctx,
                announcement: announcement,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/bids/new',
        builder: (_, state) => CreateBidScreen(
          announcement: (state.extra! as CreateBidArgs).announcement,
          negotiation: (state.extra! as CreateBidArgs).negotiation,
        ),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Bid détail'))),
      ),
      GoRoute(
        path: '/settings/report-incident',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Scaffold(
            body: Text(
              'Reported: ${extra?['targetType']}/${extra?['targetId']}',
            ),
          );
        },
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
      // Optionnel : la feuille se passe du cœur quand le cubit est absent de
      // l'arbre — c'est le cas de plusieurs points d'entrée réels.
      if (favorites != null)
        BlocProvider<FavoriteIdsCubit>.value(value: favorites),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    initializeDateFormatting('fr');
    registerFallbackValue(_FakeUri());
  });

  // ── Tests existants (comportement inchangé) ────────────────────────────────

  testWidgets('affiche la date limite de dépôt quand elle est définie', (
    tester,
  ) async {
    final now = DateTime.now();
    final a = _buildAnnouncement(
      kycVerified: true,
      handoverDeadline: DateTime(now.year, now.month + 1, 14, 18),
    );
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Redesign « Corridor héro » : la date limite vit dans une stat card
    // dédiée, plus dans une ligne « Dépôt des colis … ».
    expect(find.text('date limite de dépôt'), findsOneWidget);
  });

  testWidgets('masque la fenêtre de remise quand absente (annonce legacy)', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('date limite de dépôt'), findsNothing);
  });

  testWidgets('affiche le prix dans la devise du trajet, pas toujours en EUR', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true, currency: 'CAD');
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('CA\$'), findsOneWidget);
    expect(find.textContaining('€/kg'), findsNothing);
  });

  testWidgets('affiche le titre, le voyageur et le bouton Faire une demande', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 5, rating: 4.8);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Détail du trajet'), findsOneWidget);
    expect(find.text('Ibrahima Diallo'), findsOneWidget);
    expect(find.text('Faire une demande'), findsOneWidget);
  });

  testWidgets('affiche le badge KYC quand le voyageur est vérifié', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('traveler-kyc-badge')), findsOneWidget);
  });

  testWidgets(
    "n'affiche pas le badge KYC quand le voyageur n'est pas vérifié",
    (tester) async {
      final a = _buildAnnouncement();
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('traveler-kyc-badge')), findsNothing);
    },
  );

  testWidgets('affiche toujours le nombre de trajets, même à 0', (
    tester,
  ) async {
    final a = _buildAnnouncement(totalTrips: 0);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 trajet'), findsOneWidget);
  });

  testWidgets('affiche le pluriel quand totalTrips > 1', (tester) async {
    final a = _buildAnnouncement(totalTrips: 7);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7 trajets'), findsOneWidget);
  });

  testWidgets('le bloc voyageur est tappable pour ouvrir son profil', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 4);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final block = find.byKey(const Key('traveler-block'));
    expect(block, findsOneWidget);
    final inkWell = tester.widget<InkWell>(block);
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets(
    'Signaler ce trajet navigue vers report-incident avec la cible ANNOUNCEMENT, '
    'sans exiger de candidature',
    (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report-announcement-link')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('report-announcement-link')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-announcement-link')));
      await tester.pumpAndSettle();

      expect(
        find.text('Reported: IncidentTargetType.announcement/a1'),
        findsOneWidget,
      );
    },
  );

  // ── Colis existant sur le trajet (existingBid) ─────────────────────────────

  group('colis existant sur le trajet', () {
    BidModel acceptedBidOn(String announcementId) => BidModel(
      id: 'bid-1',
      announcementId: announcementId,
      senderId: 'u1',
      status: 'ACCEPTED',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    BidModel bidOn(String announcementId, String status) => BidModel(
      id: 'bid-1',
      announcementId: announcementId,
      senderId: 'u1',
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    testWidgets('colis ACCEPTED sur ce trajet → message + « Voir mon colis », '
        'pas de « Faire une demande »', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          bidState: BidListLoaded([
            acceptedBidOn('a1'),
          ]), // a1 = id de l'annonce
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(
        find.text('Vous avez déjà un colis sur ce trajet'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
      expect(find.text('Voir mon colis'), findsOneWidget);
      expect(find.text('Faire une demande'), findsNothing);
    });

    testWidgets(
      'colis EN ROUTE (IN_TRANSIT) sur ce trajet → grisé + « Voir mon colis »',
      (tester) async {
        final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
        await tester.pumpWidget(
          _harness(
            announcement: a,
            bidState: BidListLoaded([bidOn('a1', 'IN_TRANSIT')]),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        expect(
          find.text('Vous avez déjà un colis sur ce trajet'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
        expect(find.text('Faire une demande'), findsNothing);
      },
    );

    testWidgets(
      'colis LIVRÉ (COMPLETED) sur ce trajet → grisé + « Voir mon colis »',
      (tester) async {
        final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
        await tester.pumpWidget(
          _harness(
            announcement: a,
            bidState: BidListLoaded([bidOn('a1', 'COMPLETED')]),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        expect(
          find.text('Vous avez déjà un colis sur ce trajet'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
        expect(find.text('Faire une demande'), findsNothing);
      },
    );

    testWidgets('colis ANNULÉ (CANCELLED) → « Faire une demande » dispo', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          bidState: BidListLoaded([bidOn('a1', 'CANCELLED')]),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsNothing);
    });

    testWidgets('aucun colis (liste chargée vide) → « Faire une demande »', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(announcement: a, bidState: BidListLoaded(const [])),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsNothing);
      expect(find.text('Vous avez déjà un colis sur ce trajet'), findsNothing);
    });

    testWidgets('colis sur un AUTRE trajet → « Faire une demande » ici', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          bidState: BidListLoaded([acceptedBidOn('autre-trajet')]),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsNothing);
    });
  });

  // ── KYC Gate (nouveaux tests) ──────────────────────────────────────────────

  group('KYC gate — bouton Faire une demande', () {
    late _MockKycBloc mockKycBloc;
    late _MockBidBloc mockBidBloc;
    late _MockPaymentBloc mockPaymentBloc;
    late _MockWalletBloc mockWalletBloc;
    late _MockBidPhotosCubit mockPhotosCubit;
    late _MockRecipientBloc mockRecipientBloc;

    setUp(() {
      GetIt.I.reset();

      mockKycBloc = _MockKycBloc();
      when(() => mockKycBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockKycBloc.state).thenReturn(const KycInitial());

      mockBidBloc = _MockBidBloc();
      when(() => mockBidBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockBidBloc.state).thenReturn(BidInitial());

      mockPaymentBloc = _MockPaymentBloc();
      when(
        () => mockPaymentBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockPaymentBloc.state).thenReturn(const PaymentInitial());

      mockWalletBloc = _MockWalletBloc();
      when(() => mockWalletBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockWalletBloc.state).thenReturn(WalletInitial());

      mockPhotosCubit = _MockBidPhotosCubit();
      when(
        () => mockPhotosCubit.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockPhotosCubit.state).thenReturn(const <BidPhotoUpload>[]);
      when(() => mockPhotosCubit.close()).thenAnswer((_) async {});
      when(() => mockPhotosCubit.readyKeys).thenReturn(const <String>[]);

      // Depuis 57ce4308 (PR #130), la RecipientSection de CreateBidScreen
      // résout getIt<RecipientBloc>() dans initState.
      mockRecipientBloc = _MockRecipientBloc();
      when(
        () => mockRecipientBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockRecipientBloc.state).thenReturn(const RecipientState());
      when(() => mockRecipientBloc.close()).thenAnswer((_) async {});

      GetIt.I.registerFactory<KycBloc>(() => mockKycBloc);
      GetIt.I.registerFactory<BidBloc>(() => mockBidBloc);
      GetIt.I.registerFactory<PaymentBloc>(() => mockPaymentBloc);
      GetIt.I.registerFactory<WalletBloc>(() => mockWalletBloc);
      GetIt.I.registerFactory<BidPhotosCubit>(() => mockPhotosCubit);
      GetIt.I.registerFactory<RecipientBloc>(() => mockRecipientBloc);
      // Depuis 8b164c47 (PR #139, catalogue unifié), CreateBidScreen charge
      // le catalogue via getIt<IContentCategoryRepository>().
      GetIt.I.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
      );
    });

    tearDown(() => GetIt.I.reset());

    testWidgets('expéditeur NOT_STARTED : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(_userWithKyc('NOT_STARTED')),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.byKey(const Key('bid-submit-btn')), findsNothing);
    });

    testWidgets('expéditeur PENDING : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(_userWithKyc('PENDING')),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.byKey(const Key('bid-submit-btn')), findsNothing);
    });

    testWidgets('expéditeur REJECTED : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(_userWithKyc('REJECTED')),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.byKey(const Key('bid-submit-btn')), findsNothing);
    });

    testWidgets('expéditeur VÉRIFIÉ : ouvre CreateBidBottomSheet '
        '(titre "Publier un colis")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(_userWithKyc('VERIFIED')),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bid-submit-btn')), findsOneWidget);
      expect(find.text("Vérification d'identité"), findsNothing);
    });

    testWidgets('expéditeur NON vérifié + voyageur ouvert aux non vérifiés : '
        'ouvre le formulaire de demande', (tester) async {
      // Le voyageur a désactivé « profils vérifiés uniquement ». Sans cette
      // exception, son réglage resterait sans effet : le client barrait la route
      // avant même d'appeler le serveur.
      final a = _buildAnnouncement(kycVerified: true, acceptsUnverified: true);
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(_userWithKyc('PENDING')),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bid-submit-btn')), findsOneWidget);
      expect(find.text("Vérification d'identité"), findsNothing);
    });

    testWidgets(
      'expéditeur NON vérifié + voyageur exigeant des profils vérifiés : '
      "renvoie vers la vérification d'identité",
      (tester) async {
        final a = _buildAnnouncement(kycVerified: true);
        await tester.pumpWidget(
          _harness(
            announcement: a,
            authState: AuthAuthenticated(_userWithKyc('PENDING')),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Faire une demande'));
        await tester.pumpAndSettle();

        expect(find.text("Vérification d'identité"), findsOneWidget);
        expect(find.byKey(const Key('bid-submit-btn')), findsNothing);
      },
    );
  });

  // ── Lieux de remise / récupération ─────────────────────────────────────────

  group('lieux de remise et récupération', () {
    const pickup = AddressData(label: 'Marseille, France', lat: 43.3, lng: 5.4);
    const delivery = AddressData(
      label: "Abobo, Abidjan, Côte d'Ivoire",
      lat: 5.4,
      lng: -4.0,
    );

    testWidgets('adresses présentes → card Lieux avec les deux libellés', (
      tester,
    ) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        pickupAddress: pickup,
        deliveryAddress: delivery,
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Remise du colis'), findsOneWidget);
      expect(find.text('Récupération'), findsOneWidget);
      expect(find.text('Marseille, France'), findsOneWidget);
      expect(find.text("Abobo, Abidjan, Côte d'Ivoire"), findsOneWidget);
    });

    testWidgets('une seule adresse → seule sa ligne apparaît', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, pickupAddress: pickup);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Remise du colis'), findsOneWidget);
      expect(find.text('Récupération'), findsNothing);
    });

    testWidgets('tap sur une adresse → ouvre la carte native (launcher)', (
      tester,
    ) async {
      final launcher = _MockExternalUrlLauncher();
      when(() => launcher.open(any())).thenAnswer((_) async => true);
      if (getIt.isRegistered<ExternalUrlLauncher>()) {
        getIt.unregister<ExternalUrlLauncher>();
      }
      getIt.registerSingleton<ExternalUrlLauncher>(launcher);
      addTearDown(() => getIt.unregister<ExternalUrlLauncher>());

      final a = _buildAnnouncement(kycVerified: true, pickupAddress: pickup);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('location-pickup')));
      await tester.pump();

      final captured = verify(() => launcher.open(captureAny())).captured;
      expect(captured, isNotEmpty);
      final uri = captured.single as Uri;
      expect(uri.scheme, 'https');
      // Les coordonnées de la remise sont dans la requête (Plans ou Maps).
      expect(uri.query, contains('43.3'));
    });

    testWidgets('aucune adresse (annonce legacy) → pas de card Lieux', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Remise du colis'), findsNothing);
      expect(find.text('Récupération'), findsNothing);
    });
  });

  // ── Enrichissements (heures, paiements, instructions) ──────────────────────

  group('enrichissements', () {
    testWidgets('heures départ→arrivée présentes → chip 08:00 → 22:00', (
      tester,
    ) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        departureTime: '08:00',
        arrivalTime: '22:00',
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('08:00 → 22:00'), findsOneWidget);
    });

    testWidgets('une seule heure connue → pas de chip horaire', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, departureTime: '08:00');
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('→'), findsNothing);
    });

    testWidgets('paiements acceptés → chips Espèces + Carte', (tester) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        acceptedPaymentMethods: const {
          BidPaymentMethod.cash,
          BidPaymentMethod.stripe,
        },
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Paiements acceptés'), findsOneWidget);
      expect(find.text('Espèces'), findsOneWidget);
      expect(find.text('Carte'), findsOneWidget);
    });

    testWidgets('instructions renseignées → encart affiché', (tester) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        arrivalInstructions: 'Récupération possible après 18h.',
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Instructions du voyageur'), findsOneWidget);
      expect(find.text('Récupération possible après 18h.'), findsOneWidget);
    });

    testWidgets('instructions vides → pas d\'encart', (tester) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        arrivalInstructions: '   ',
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Instructions du voyageur'), findsNothing);
    });
  });

  // ── Redesign « Corridor héro » ─────────────────────────────────────────────

  group('redesign corridor héro', () {
    List<AnnouncementGridItemModel> gridItems(int count) => List.generate(
      count,
      (i) => AnnouncementGridItemModel(
        id: 'g$i',
        label: 'Article ${i + 1}',
        unitPriceDisplay: 5.0 + i,
      ),
    );

    testWidgets('affiche la carte héro corridor et le prix par kilo', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('TRAJET'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Dakar'), findsOneWidget);
      expect(find.text('par kilo'), findsOneWidget);
    });

    testWidgets('trajet négociable → mention et lien « Proposer un prix »', (
      tester,
    ) async {
      final a = _buildAnnouncement(kycVerified: true, negotiable: true);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trajet négociable'), findsOneWidget);
      expect(find.text('Proposer un prix'), findsOneWidget);
      expect(find.byKey(const Key('negotiate-price-btn')), findsOneWidget);
    });

    testWidgets('prix ferme → aucune mention de négociation', (tester) async {
      final a = _buildAnnouncement(kycVerified: true);
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Trajet négociable'), findsNothing);
      expect(find.text('Proposer un prix'), findsNothing);
    });

    testWidgets('grille 6 articles → 4 lignes visibles + « Voir tous les '
        'tarifs (6) »', (tester) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        pricingMode: 'MIXED',
        priceGridItems: gridItems(6),
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Grille tarifaire'), findsOneWidget);
      expect(find.textContaining('dès '), findsOneWidget);
      expect(find.text('Article 1'), findsOneWidget);
      expect(find.text('Article 4'), findsOneWidget);
      expect(find.text('Article 5'), findsNothing);
      expect(find.text('Voir tous les tarifs (6)'), findsOneWidget);
    });

    testWidgets('« Voir tous les tarifs » déplie le reste de la grille', (
      tester,
    ) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        pricingMode: 'MIXED',
        priceGridItems: gridItems(6),
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('price-grid-expand')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('price-grid-expand')));
      await tester.pumpAndSettle();

      expect(find.text('Article 5'), findsOneWidget);
      expect(find.text('Article 6'), findsOneWidget);
      expect(find.text('Voir tous les tarifs (6)'), findsNothing);
    });

    testWidgets('grille de 3 articles → liste entière, pas de dépliant', (
      tester,
    ) async {
      final a = _buildAnnouncement(
        kycVerified: true,
        pricingMode: 'MIXED',
        priceGridItems: gridItems(3),
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Article 3'), findsOneWidget);
      expect(find.textContaining('Voir tous les tarifs'), findsNothing);
    });
  });

  // ─── Reports de l'écran « Détail annonce » supprimé ────────────────────────
  //
  // Ces comportements n'existaient que sur l'écran plein, remplacé par cette
  // feuille. Ils sont testés ici pour que la suppression n'emporte pas leur
  // couverture avec elle.

  group('avertissement paiement en espèces', () {
    testWidgets('trajet en espèces uniquement → avertissement de séquestre', (
      tester,
    ) async {
      final a = _buildAnnouncement(
        acceptedPaymentMethods: {BidPaymentMethod.cash},
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Le message est un TextSpan composé : sans findRichText, le finder ne
      // regarde que les widgets Text simples et ne voit rien.
      expect(
        find.textContaining(
          'Trajet en espèces uniquement.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Yadony ne séquestre pas votre argent et ne peut pas '
          'le rembourser automatiquement en cas de litige.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('carte acceptée → aucun avertissement', (tester) async {
      final a = _buildAnnouncement(
        acceptedPaymentMethods: {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      await tester.pumpWidget(_harness(announcement: a));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Le séquestre s'applique dès qu'un paiement par carte est possible.
      expect(
        find.textContaining(
          'Trajet en espèces uniquement.',
          findRichText: true,
        ),
        findsNothing,
      );
    });
  });

  group('marqueur PRO du voyageur', () {
    testWidgets('compte PRO → avatar marqué', (tester) async {
      await tester.pumpWidget(
        _harness(announcement: _buildAnnouncement(isProAccount: true)),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      final avatar = tester.widget<DonyAvatar>(find.byType(DonyAvatar).first);
      expect(avatar.pro, isTrue);
    });

    testWidgets('compte ordinaire → avatar non marqué', (tester) async {
      await tester.pumpWidget(_harness(announcement: _buildAnnouncement()));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      final avatar = tester.widget<DonyAvatar>(find.byType(DonyAvatar).first);
      expect(avatar.pro, isFalse);
    });
  });

  group('cœur des favoris', () {
    late FavoriteIdsCubit cubit;
    late _MockFavoriteRepository repo;

    setUp(() {
      repo = _MockFavoriteRepository();
      cubit = FavoriteIdsCubit(repo);
    });
    tearDown(() => cubit.close());

    Future<void> ouvrir(WidgetTester tester, AnnouncementModel a) async {
      await tester.pumpWidget(_harness(announcement: a, favorites: cubit));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('ajout → message de confirmation', (tester) async {
      final a = _buildAnnouncement();
      when(() => repo.add('trip', a.id)).thenAnswer((_) async {});

      await ouvrir(tester, a);
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trajet ajouté aux favoris'), findsOneWidget);
    });

    testWidgets('retrait → message de confirmation', (tester) async {
      final a = _buildAnnouncement();
      cubit.emitSeed(trips: {a.id}, requests: {});
      when(() => repo.remove('trip', a.id)).thenAnswer((_) async {});

      await ouvrir(tester, a);
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Trajet retiré des favoris'), findsOneWidget);
    });

    testWidgets('échec réseau → message d\'erreur', (tester) async {
      final a = _buildAnnouncement();
      when(() => repo.add('trip', a.id)).thenThrow(Exception('réseau'));

      await ouvrir(tester, a);
      await tester.tap(find.byType(FavoriteHeartButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Impossible de modifier les favoris'), findsOneWidget);
    });

    testWidgets('sans cubit dans l\'arbre, aucun cœur et aucune erreur', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(announcement: _buildAnnouncement()));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byType(FavoriteHeartButton), findsNothing);
      expect(find.text('Détail du trajet'), findsOneWidget);
    });
  });

  // ─── Blocage, reporté de l'écran supprimé (PR #301) ───────────────────────

  group('blocage du voyageur', () {
    testWidgets('trajet d\'un tiers → « Bloquer ce voyageur »', (tester) async {
      await tester.pumpWidget(_harness(announcement: _buildAnnouncement()));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('block-traveler-link')), findsOneWidget);
      expect(find.text('Bloquer ce voyageur'), findsOneWidget);
    });

    testWidgets('son propre trajet → aucune entrée de blocage', (tester) async {
      final a = _buildAnnouncement();
      // Le lecteur est le voyageur de l'annonce : on ne se bloque pas soi-même.
      await tester.pumpWidget(
        _harness(
          announcement: a,
          authState: AuthAuthenticated(
            UserModel(
              id: a.travelerId,
              roles: const [],
              kycStatus: 'VERIFIED',
              status: 'ACTIVE',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('block-traveler-link')), findsNothing);
    });
  });
}
