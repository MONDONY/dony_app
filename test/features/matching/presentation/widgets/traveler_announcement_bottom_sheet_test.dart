import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
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
  DateTime? handoverStart,
  DateTime? handoverEnd,
  bool acceptsUnverified = false,
  String currency = 'EUR',
}) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'a1',
    travelerId: 't1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(now.year, now.month + 1, 15),
    availableKg: 12,
    totalKg: 20,
    pricePerKg: 8,
    currency: currency,
    status: 'ACTIVE',
    traveler: TravelerProfile(
      id: 't1',
      displayName: displayName,
      averageRating: rating,
      totalTrips: totalTrips,
      kycVerified: kycVerified,
      acceptsUnverified: acceptsUnverified,
    ),
    createdAt: now,
    updatedAt: now,
    handoverWindowStart: handoverStart,
    handoverWindowEnd: handoverEnd,
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
        builder: (_, state) =>
            CreateBidScreen(announcement: state.extra as AnnouncementModel),
      ),
      GoRoute(
        path: '/bids/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Bid détail'))),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
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
  setUpAll(() => initializeDateFormatting('fr'));

  // ── Tests existants (comportement inchangé) ────────────────────────────────

  testWidgets('affiche la fenêtre de remise quand elle est définie', (
    tester,
  ) async {
    final now = DateTime.now();
    final a = _buildAnnouncement(
      kycVerified: true,
      handoverStart: DateTime(now.year, now.month + 1, 14, 16),
      handoverEnd: DateTime(now.year, now.month + 1, 14, 18),
    );
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Remise :'), findsOneWidget);
  });

  testWidgets('masque la fenêtre de remise quand absente (annonce legacy)', (
    tester,
  ) async {
    final a = _buildAnnouncement(kycVerified: true);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Remise :'), findsNothing);
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
      final a = _buildAnnouncement(kycVerified: false);
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

  // ── Colis existant sur le trajet (existingBid) ─────────────────────────────

  group('colis existant sur le trajet', () {
    BidModel acceptedBidOn(String announcementId) => BidModel(
      id: 'bid-1',
      announcementId: announcementId,
      senderId: 'u1',
      status: 'ACCEPTED',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    BidModel bidOn(String announcementId, String status) => BidModel(
      id: 'bid-1',
      announcementId: announcementId,
      senderId: 'u1',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
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
      expect(find.text('Publier un colis'), findsNothing);
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
      expect(find.text('Publier un colis'), findsNothing);
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
      expect(find.text('Publier un colis'), findsNothing);
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

      expect(find.text('Publier un colis'), findsOneWidget);
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

      expect(find.text('Publier un colis'), findsOneWidget);
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
        expect(find.text('Publier un colis'), findsNothing);
      },
    );
  });
}
