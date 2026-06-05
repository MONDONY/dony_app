import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/traveler_announcement_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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
    status: 'ACTIVE',
    traveler: TravelerProfile(
      id: 't1',
      displayName: displayName,
      averageRating: rating,
      totalTrips: totalTrips,
      kycVerified: kycVerified,
    ),
    createdAt: now,
    updatedAt: now,
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
  when(() => authBloc.state).thenReturn(
    authState ?? AuthAuthenticated(_userWithKyc('VERIFIED')),
  );
  when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

  // showTravelerAnnouncementSheet lit BidBloc depuis l'arbre (context.read)
  // pour détecter un colis existant + rafraîchir la liste parente après bid.
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(bidState ?? BidInitial());
  when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<BidBloc>.value(value: bidBloc),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showTravelerAnnouncementSheet(ctx, announcement: announcement),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() => initializeDateFormatting('fr'));


  // ── Tests existants (comportement inchangé) ────────────────────────────────

  testWidgets('affiche le titre, le voyageur et le bouton Faire une demande',
      (tester) async {
    final a = _buildAnnouncement(
      kycVerified: true,
      totalTrips: 5,
      rating: 4.8,
    );
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Détail du trajet'), findsOneWidget);
    expect(find.text('Ibrahima Diallo'), findsOneWidget);
    expect(find.text('Faire une demande'), findsOneWidget);
  });

  testWidgets('affiche le badge KYC quand le voyageur est vérifié',
      (tester) async {
    final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('traveler-kyc-badge')), findsOneWidget);
  });

  testWidgets("n'affiche pas le badge KYC quand le voyageur n'est pas vérifié",
      (tester) async {
    final a = _buildAnnouncement(kycVerified: false);
    await tester.pumpWidget(_harness(announcement: a));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('traveler-kyc-badge')), findsNothing);
  });

  testWidgets('affiche toujours le nombre de trajets, même à 0',
      (tester) async {
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

  testWidgets('le bloc voyageur est tappable pour ouvrir son profil',
      (tester) async {
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

    testWidgets(
        'colis ACCEPTED sur ce trajet → message + « Voir mon colis », '
        'pas de « Faire une demande »', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded([acceptedBidOn('a1')]), // a1 = id de l'annonce
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Vous avez déjà un colis sur ce trajet'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
      expect(find.text('Voir mon colis'), findsOneWidget);
      expect(find.text('Faire une demande'), findsNothing);
    });

    testWidgets(
        'colis EN ROUTE (IN_TRANSIT) sur ce trajet → grisé + « Voir mon colis »',
        (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded([bidOn('a1', 'IN_TRANSIT')]),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Vous avez déjà un colis sur ce trajet'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
      expect(find.text('Faire une demande'), findsNothing);
    });

    testWidgets(
        'colis LIVRÉ (COMPLETED) sur ce trajet → grisé + « Voir mon colis »',
        (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded([bidOn('a1', 'COMPLETED')]),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Vous avez déjà un colis sur ce trajet'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsOneWidget);
      expect(find.text('Faire une demande'), findsNothing);
    });

    testWidgets('colis ANNULÉ (CANCELLED) → « Faire une demande » dispo',
        (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded([bidOn('a1', 'CANCELLED')]),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsNothing);
    });

    testWidgets('aucun colis (liste chargée vide) → « Faire une demande »',
        (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded(const []),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Faire une demande'), findsOneWidget);
      expect(find.byKey(const Key('see-my-parcel-btn')), findsNothing);
      expect(find.text('Vous avez déjà un colis sur ce trajet'), findsNothing);
    });

    testWidgets('colis sur un AUTRE trajet → « Faire une demande » ici',
        (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        bidState: BidListLoaded([acceptedBidOn('autre-trajet')]),
      ));
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

    setUp(() {
      GetIt.I.reset();

      mockKycBloc = _MockKycBloc();
      when(() => mockKycBloc.stream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockKycBloc.state).thenReturn(const KycInitial());

      mockBidBloc = _MockBidBloc();
      when(() => mockBidBloc.stream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockBidBloc.state).thenReturn(BidInitial());

      mockPaymentBloc = _MockPaymentBloc();
      when(() => mockPaymentBloc.stream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPaymentBloc.state).thenReturn(const PaymentInitial());

      mockWalletBloc = _MockWalletBloc();
      when(() => mockWalletBloc.stream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockWalletBloc.state).thenReturn(WalletInitial());

      GetIt.I.registerFactory<KycBloc>(() => mockKycBloc);
      GetIt.I.registerFactory<BidBloc>(() => mockBidBloc);
      GetIt.I.registerFactory<PaymentBloc>(() => mockPaymentBloc);
      GetIt.I.registerFactory<WalletBloc>(() => mockWalletBloc);
    });

    tearDown(() => GetIt.I.reset());

    testWidgets(
        'expéditeur NOT_STARTED : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        authState: AuthAuthenticated(_userWithKyc('NOT_STARTED')),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.text('Envoyer un colis'), findsNothing);
    });

    testWidgets(
        'expéditeur PENDING : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        authState: AuthAuthenticated(_userWithKyc('PENDING')),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.text('Envoyer un colis'), findsNothing);
    });

    testWidgets(
        'expéditeur REJECTED : ouvre KycStatusBottomSheet '
        '(titre "Vérification d\'identité")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        authState: AuthAuthenticated(_userWithKyc('REJECTED')),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(find.text('Envoyer un colis'), findsNothing);
    });

    testWidgets(
        'expéditeur VÉRIFIÉ : ouvre CreateBidBottomSheet '
        '(titre "Envoyer un colis")', (tester) async {
      final a = _buildAnnouncement(kycVerified: true, totalTrips: 3);
      await tester.pumpWidget(_harness(
        announcement: a,
        authState: AuthAuthenticated(_userWithKyc('VERIFIED')),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faire une demande'));
      await tester.pumpAndSettle();

      expect(find.text('Envoyer un colis'), findsOneWidget);
      expect(find.text("Vérification d'identité"), findsNothing);
    });
  });
}
