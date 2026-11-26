import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/kyc/bloc/kyc_bloc.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/publish_gate/bloc/publish_kyc_gate_cubit.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockKycBloc extends MockBloc<KycEvent, KycState> implements KycBloc {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

UserModel _user(String kycStatus) => UserModel(
  id: 'u1',
  roles: const [],
  kycStatus: kycStatus,
  status: 'ACTIVE',
);

/// Trajet en espèces seulement : le bouton final crée la demande
/// (`BidCreateRequested`). [acceptsUnverified] : réglage du voyageur.
AnnouncementModel _announcement({
  bool acceptsUnverified = false,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.cash},
}) => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  acceptedPaymentMethods: methods,
  traveler: TravelerProfile(id: 'trav-1', acceptsUnverified: acceptsUnverified),
);

final RegExp _cashCta = RegExp(r'^Confirmer .* en espèces$');

void main() {
  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockBidPhotosCubit photos;
  late _MockRecipientBloc recipients;
  late _MockAuthBloc authBloc;
  late _MockKycBloc kycBloc;
  late _MockAuthRepository authRepository;
  late _MockAnalytics analytics;
  late StreamController<KycState> kycStates;
  late StreamController<BidState> bidStates;
  late List<String> kycLocations;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(_FakeRecipientEvent());
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(const KycReset());
    registerFallbackValue(
      BidCreateRequested(
        announcementId: '',
        weightKg: 0,
        description: '',
        contentCategory: '',
        recipientName: '',
        recipientPhone: '',
      ),
    );
  });

  setUp(() async {
    await getIt.reset();
    DonySnackbar.clearDedup();
    bidStates = StreamController<BidState>.broadcast();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => bidStates.stream);
    when(() => bidBloc.close()).thenAnswer((_) async {});

    paymentBloc = _MockPaymentBloc();
    when(() => paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => paymentBloc.close()).thenAnswer((_) async {});

    photos = _MockBidPhotosCubit();
    when(() => photos.state).thenReturn(const <BidPhotoUpload>[]);
    when(() => photos.stream).thenAnswer((_) => const Stream.empty());
    when(() => photos.close()).thenAnswer((_) async {});
    when(() => photos.readyKeys).thenReturn(const <String>['bids/p.jpg']);

    recipients = _MockRecipientBloc();
    when(() => recipients.state).thenReturn(const RecipientState());
    when(() => recipients.stream).thenAnswer((_) => const Stream.empty());
    when(() => recipients.close()).thenAnswer((_) async {});
    when(() => recipients.add(any())).thenReturn(null);

    authBloc = _MockAuthBloc();
    when(() => authBloc.isClosed).thenReturn(false);

    kycStates = StreamController<KycState>.broadcast();
    kycBloc = _MockKycBloc();
    whenListen(kycBloc, kycStates.stream, initialState: const KycInitial());

    authRepository = _MockAuthRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    getIt
      ..registerFactory<BidBloc>(() => bidBloc)
      ..registerFactory<PaymentBloc>(() => paymentBloc)
      ..registerFactory<BidPhotosCubit>(() => photos)
      ..registerFactory<RecipientBloc>(() => recipients)
      ..registerFactory<IContentCategoryRepository>(
        _FakeContentCategoryRepository.new,
      )
      ..registerSingleton<AuthRepository>(authRepository)
      ..registerFactoryParam<PublishKycGateCubit, KycGateSubject, bool>(
        (subject, resumed) => PublishKycGateCubit(
          subject: subject,
          analytics: analytics,
          resumedFromGate: resumed,
        ),
      );
    kycLocations = [];
  });

  tearDown(() async {
    await kycStates.close();
    await bidStates.close();
    await getIt.reset();
  });

  void serverStatus(String status) => when(
    () => authRepository.getProfile(),
  ).thenAnswer((_) async => _user(status));

  Future<void> open(
    WidgetTester tester, {
    required AnnouncementModel announcement,
    String cachedStatus = 'NOT_STARTED',
    Locale locale = AppL10n.fr,
  }) async {
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(_user(cachedStatus)),
    );
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (inner) => TextButton(
                onPressed: () => CreateBidBottomSheet.show(
                  inner,
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
          ),
        ),
        // Vérification ouverte par-dessus le formulaire (`back=1`) : la page
        // du fournisseur (extra = URL) puis l'écran de statut (sans extra).
        GoRoute(
          path: '/kyc/verify',
          builder: (ctx, state) {
            kycLocations.add(state.uri.toString());
            final provider = state.extra is String;
            return Scaffold(
              body: Column(
                children: [
                  if (provider) ...[
                    TextButton(
                      onPressed: () => ctx.pop(true),
                      child: const Text('Parcours terminé'),
                    ),
                    TextButton(
                      onPressed: () => ctx.pop(),
                      child: const Text('Fermer la page'),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => ctx.pop(),
                      child: const Text('Quitter le statut'),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<KycBloc>.value(value: kycBloc),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  /// Remplit le formulaire puis passe à l'étape du paiement.
  Future<void> fillAndContinue(WidgetTester tester) async {
    tester.widget<Slider>(find.byType(Slider)).onChanged!(5);
    await tester.pump();
    await tester.tap(find.byKey(const Key('bid-content-field')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('bid-content-item-Vêtements & tissus')),
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Médicaments');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), 'Amadou Diallo');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(3), '+221 77 000 00 00');
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
  }

  /// Après un envoi : le bouton tourne sans fin (aucune réponse simulée),
  /// `pumpAndSettle` ne rendrait jamais la main.
  Future<void> settleSending(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Matcher createWith({String? description, String? recipientName}) =>
      predicate<BidEvent>(
        (e) =>
            e is BidCreateRequested &&
            (description == null || e.description == description) &&
            (recipientName == null || e.recipientName == recipientName),
      );

  const gateTitle = 'Dernière étape : vérifiez votre identité';
  const gateBody =
      'Votre demande est prête. Vérifiez votre identité (environ 2 minutes) '
      'puis envoyez-la.';

  testWidgets('non vérifié : le formulaire s\'ouvre, la feuille ne vient '
      'qu\'à l\'envoi, sans rien envoyer', (tester) async {
    serverStatus('NOT_STARTED');
    await open(tester, announcement: _announcement());
    expect(find.byKey(const Key('bid-submit-btn')), findsOne);
    expect(find.text(gateTitle), findsNothing);

    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pumpAndSettle();

    expect(find.text(gateTitle), findsOne);
    expect(find.text(gateBody), findsOne);
    verify(() => authRepository.getProfile()).called(1);
    verifyNever(() => bidBloc.add(any(that: isA<BidCreateRequested>())));
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateShown,
        properties: {'role': 'sender_bid', 'kyc_status': 'not_started'},
      ),
    ).called(1);

    // « Plus tard » : retour au formulaire, toujours rempli.
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_cashCta), findsOne);
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('bid-submit-btn')),
    );
    expect(button.isLoading, isFalse);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('vérification par-dessus le formulaire puis retour vérifié : '
      'la demande part avec la saisie, sans ressaisie', (tester) async {
    serverStatus('NOT_STARTED');
    await open(tester, announcement: _announcement());
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vérifier mon identité'));
    await tester.pump();
    verify(() => kycBloc.add(const KycSessionRequested())).called(1);
    kycStates.add(
      const KycSessionCreated(
        stripeUrl: 'https://verify.didit.me/x',
        sessionId: 's1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parcours terminé'), findsOne);
    expect(Uri.parse(kycLocations.last).queryParameters[kycBackParam], '1');

    serverStatus('VERIFIED');
    await tester.tap(find.text('Parcours terminé'));
    await tester.pumpAndSettle();
    // L'écran de statut s'ouvre à son tour, toujours par-dessus.
    expect(find.text('Quitter le statut'), findsOne);
    await tester.tap(find.text('Quitter le statut'));
    await settleSending(tester);

    verify(
      () => bidBloc.add(
        any(
          that: createWith(
            description: 'Médicaments',
            recipientName: 'Amadou Diallo',
          ),
        ),
      ),
    ).called(1);
    expect(
      find.text('Identité vérifiée : nous envoyons votre demande.'),
      findsOne,
    );

    // Demande créée : publish_kyc_gate_resumed, une fois.
    bidStates.add(BidCreated(BidModel.skeleton('bid-1')));
    await tester.pumpAndSettle();
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.publishKycGateResumed,
        properties: {'role': 'sender_bid'},
      ),
    ).called(1);
  });

  testWidgets('page du fournisseur fermée sans finir : rien ne part, le '
      'bouton revient', (tester) async {
    serverStatus('NOT_STARTED');
    await open(tester, announcement: _announcement());
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier mon identité'));
    await tester.pump();
    kycStates.add(
      const KycSessionCreated(
        stripeUrl: 'https://verify.didit.me/x',
        sessionId: 's1',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer la page'));
    await tester.pumpAndSettle();

    expect(find.text('Quitter le statut'), findsNothing);
    verifyNever(() => bidBloc.add(any(that: isA<BidCreateRequested>())));
    final button = tester.widget<DonyButton>(
      find.byKey(const Key('bid-submit-btn')),
    );
    expect(button.isLoading, isFalse);
  });

  testWidgets('retour avec une décision en attente : feuille « Vérification '
      'en cours », la demande reste prête', (tester) async {
    serverStatus('NOT_STARTED');
    await open(tester, announcement: _announcement());
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vérifier mon identité'));
    await tester.pump();
    kycStates.add(
      const KycSessionCreated(
        stripeUrl: 'https://verify.didit.me/x',
        sessionId: 's1',
      ),
    );
    await tester.pumpAndSettle();
    serverStatus('PENDING');
    await tester.tap(find.text('Parcours terminé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter le statut'));
    await tester.pumpAndSettle();

    expect(find.text('Vérification en cours'), findsOne);
    expect(find.textContaining('Votre demande reste prête'), findsOne);
    verifyNever(() => bidBloc.add(any(that: isA<BidCreateRequested>())));
  });

  testWidgets('PENDING dès l\'envoi : feuille « Vérification en cours »', (
    tester,
  ) async {
    serverStatus('PENDING');
    await open(tester, announcement: _announcement(), cachedStatus: 'PENDING');
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pumpAndSettle();
    expect(find.text('Vérification en cours'), findsOne);
    verifyNever(() => bidBloc.add(any(that: isA<BidCreateRequested>())));
  });

  testWidgets('identité validée hors de l\'app (cache périmé) : la relecture '
      'du serveur laisse partir la demande', (tester) async {
    serverStatus('VERIFIED');
    await open(tester, announcement: _announcement());
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await settleSending(tester);
    expect(find.text(gateTitle), findsNothing);
    verify(() => bidBloc.add(any(that: createWith()))).called(1);
  });

  testWidgets('voyageur ouvert aux profils non vérifiés : envoi direct, '
      'sans relecture ni feuille', (tester) async {
    serverStatus('NOT_STARTED');
    await open(tester, announcement: _announcement(acceptsUnverified: true));
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await settleSending(tester);
    expect(find.text(gateTitle), findsNothing);
    verifyNever(() => authRepository.getProfile());
    verify(() => bidBloc.add(any(that: createWith()))).called(1);
  });

  testWidgets('expéditeur vérifié : envoi direct', (tester) async {
    await open(tester, announcement: _announcement(), cachedStatus: 'VERIFIED');
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await settleSending(tester);
    verifyNever(() => authRepository.getProfile());
    verify(() => bidBloc.add(any(that: createWith()))).called(1);
  });

  testWidgets('403 contact-kyc-required malgré le cache : la feuille de '
      'vérification, pas d\'erreur brute', (tester) async {
    serverStatus('NOT_STARTED');
    // Le cache dit vérifié : la demande part, le serveur la refuse.
    await open(tester, announcement: _announcement(), cachedStatus: 'VERIFIED');
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pump();
    bidStates.add(
      BidError(
        const ForbiddenException(
          'Ce voyageur accepte uniquement les profils vérifiés',
          'contact-kyc-required',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(gateTitle), findsOne);
    expect(find.textContaining('uniquement les profils'), findsNothing);
  });

  testWidgets('403 contact-kyc-required alors que le serveur dit vérifié : '
      'l\'erreur s\'affiche', (tester) async {
    serverStatus('VERIFIED');
    await open(tester, announcement: _announcement(), cachedStatus: 'VERIFIED');
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pump();
    bidStates.add(
      BidError(const ForbiddenException('refus', 'contact-kyc-required')),
    );
    await tester.pumpAndSettle();
    expect(find.text(gateTitle), findsNothing);
  });

  testWidgets('envoi en cours : chargement, un second appui ne crée rien', (
    tester,
  ) async {
    await open(tester, announcement: _announcement(), cachedStatus: 'VERIFIED');
    await fillAndContinue(tester);
    await tester.tap(find.textContaining(_cashCta));
    await tester.pump();

    final button = tester.widget<DonyButton>(
      find.byKey(const Key('bid-submit-btn')),
    );
    expect(button.isLoading, isTrue);
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const Key('bid-submit-btn')));
    await tester.pump();
    verify(() => bidBloc.add(any(that: isA<BidCreateRequested>()))).called(1);

    // Refus du serveur : le bouton revient pour réessayer.
    bidStates.add(BidError(const ServerException('panne')));
    await tester.pumpAndSettle();
    final after = tester.widget<DonyButton>(
      find.byKey(const Key('bid-submit-btn')),
    );
    expect(after.isLoading, isFalse);
    expect(after.onPressed, isNotNull);
  });
}
