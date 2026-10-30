// Bottom sheet de la tuile « Supplément de prix » de la section « À traiter »
// (fiche colis, vue voyageur) : frais de service du supplément à valider sur
// un colis payé en espèces. Contenu sans cadre, boutons dans le pied, cubits
// du sheet, BidBloc de l'écran reposé, 3DS (succès, échec, abandon),
// fermeture une fois la demande traitée, erreurs visibles par-dessus le
// sheet, mesures et libellés à taille nominale en FR et EN à 360 dp × 1,3.
import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_commission_flow.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockRepository extends Mock implements BidSupplementRepository {}

BidSupplement _supplement(
  BidSupplementStatus status, {
  String? commissionStatus,
  String? clientSecret,
}) => BidSupplement(
  id: 'sup-1',
  status: status,
  rail: 'CASH',
  netAmount: 15,
  commissionAmount: 2,
  grossAmount: 17,
  reasonCode: 'EXTRA_WEIGHT',
  commissionStatus: commissionStatus,
  commissionClientSecret: clientSecret,
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 25)),
  blocksHandover: status.isOpen,
);

BidModel _bid([
  BidSupplementStatus status = BidSupplementStatus.commissionPending,
]) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: BidPaymentMethod.cash,
  supplement: _supplement(status),
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Vraies polices de l'app : la police de repli des tests donne un cadratin
/// par glyphe et fausserait la mesure des libellés.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  late MockAnalyticsBackend backend;
  late _MockBidBloc bidBloc;
  late StreamController<BidState> bidStates;
  late _MockRepository repository;
  late bool failAuth;
  late bool authorizeResult;
  late int authorizations;

  setUpAll(() async {
    registerFallbackValue(BidDetailRequested('fallback'));
    await _loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    bidStates = StreamController<BidState>.broadcast();
    addTearDown(bidStates.close);
    bidBloc = _MockBidBloc();
    whenListen(bidBloc, bidStates.stream, initialState: BidInitial());

    repository = _MockRepository();
    failAuth = false;
    authorizeResult = true;
    authorizations = 0;

    await getIt.reset();
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(repository, analytics),
      )
      ..registerFactory<SupplementCommissionCubit>(
        () => SupplementCommissionCubit(
          SupplementCommissionFlow(
            repository,
            analytics,
            nextAction: (_) async {
              if (failAuth) throw StateError('canceled');
            },
          ),
          analytics,
        ),
      );
    DonySnackbar.clearDedup();
  });

  tearDown(() async => getIt.reset());

  /// Ouvre la feuille depuis un `Builder` posé sous le `BidBloc` de l'écran,
  /// comme le fait le corps de la fiche.
  Future<void> openTodo(
    WidgetTester tester, {
    BidModel? bid,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
    bool withBloc = true,
    TodoSource source = TodoSource.tile,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final opener = Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => openTravelerTodoSheet(
            context,
            bid ?? _bid(),
            TravelerTodoTile.supplement,
            source: source,
            authorize: (_) async {
              authorizations++;
              return authorizeResult;
            },
          ),
          child: const Text('open-todo'),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: withBloc
            ? BlocProvider<BidBloc>.value(value: bidBloc, child: opener)
            : opener,
      ),
    );
    await tester.tap(find.text('open-todo'));
    await tester.pumpAndSettle();
  }

  Finder footer() => find.byKey(const Key('donyBottomSheetFooter'));
  Finder footerButtons() =>
      find.descendant(of: footer(), matching: find.byType(DonyButton));
  Finder confirmButton() =>
      find.byKey(const Key('supplement-commission-confirm-btn'));
  Finder withdrawButton() => find.byKey(const Key('supplement-withdraw-btn'));
  Finder sheetTitle() => find.text('Supplément de prix');
  Finder dialogWithdraw() => find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(FilledButton, 'Retirer la demande'),
  );

  group('contenu', () {
    testWidgets('titre, carte sans cadre, deux boutons empilés dans le pied', (
      tester,
    ) async {
      await openTodo(tester);

      expect(tester.takeException(), isNull);
      expect(sheetTitle(), findsOneWidget);
      expect(find.byType(SupplementTravelerCard), findsOneWidget);
      expect(find.byType(DetailCard), findsNothing);
      expect(find.text('Frais de service à valider'), findsOneWidget);
      expect(
        find.textContaining('Validez le paiement des frais de service'),
        findsOneWidget,
      );
      // Les deux boutons dans le pied, aucun dans le contenu défilant.
      expect(footerButtons(), findsNWidgets(2));
      expect(find.byType(DonyButton), findsNWidgets(2));
      expect(
        find.descendant(of: footer(), matching: confirmButton()),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer(), matching: withdrawButton()),
        findsOneWidget,
      );
      // Empilés en pleine largeur, « Valider le paiement » en haut.
      final confirm = tester.getRect(confirmButton());
      final withdraw = tester.getRect(withdrawButton());
      expect(confirm.bottom, lessThanOrEqualTo(withdraw.top));
      expect(confirm.width, withdraw.width);
    });

    testWidgets('le pied lit les cubits du sheet et le BidBloc de l\'écran', (
      tester,
    ) async {
      await openTodo(tester);

      final inFooter = tester.element(confirmButton());
      expect(inFooter.read<SupplementCommissionCubit>(), isNotNull);
      expect(inFooter.read<SupplementActionCubit>(), isNotNull);
      expect(inFooter.read<BidBloc>(), same(bidBloc));
    });

    testWidgets(
      'sans BidBloc à l\'écran : contenu et boutons de l\'ouverture',
      (tester) async {
        await openTodo(tester, withBloc: false);

        expect(tester.takeException(), isNull);
        expect(sheetTitle(), findsOneWidget);
        expect(footerButtons(), findsNWidgets(2));
      },
    );
  });

  group('« Valider le paiement »', () {
    testWidgets('frais prélevés : la feuille se ferme, confirme et relit le '
        'colis', (tester) async {
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => _supplement(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
      );
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(authorizations, 1);
      verify(() => repository.confirmCommission('bid-1', 'sup-1')).called(1);
      expect(sheetTitle(), findsNothing);
      expect(
        find
            .text("Frais de service payés : demande envoyée à l'expéditeur")
            .hitTestable(),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementCommissionResumed, {
          'outcome': 'proposed',
        }),
      ).called(1);
    });

    testWidgets('3DS demandée puis réussie : seconde confirmation, fermeture', (
      tester,
    ) async {
      var calls = 0;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer((
        _,
      ) async {
        calls++;
        return calls == 1
            ? _supplement(
                BidSupplementStatus.commissionPending,
                clientSecret: 'pi_secret',
              )
            : _supplement(
                BidSupplementStatus.proposed,
                commissionStatus: SupplementCommissionStatus.charged,
              );
      });
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(sheetTitle(), findsNothing);
      expect(
        find.text("Frais de service payés : demande envoyée à l'expéditeur"),
        findsOneWidget,
      );
    });

    testWidgets('Stripe traite encore : la feuille se ferme, message neutre et '
        'relecture', (tester) async {
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => _supplement(BidSupplementStatus.commissionPending),
      );
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(sheetTitle(), findsNothing);
      expect(
        find.text(
          'Demande enregistrée : paiement des frais de service en cours de '
          'validation',
        ),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    });

    testWidgets('vérification locale refusée : message par-dessus la feuille, '
        'rien n\'est confirmé', (tester) async {
      authorizeResult = false;
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Paiement non confirmé, réessayez').hitTestable(),
        findsOneWidget,
      );
      expect(sheetTitle(), findsOneWidget);
      verifyNever(() => repository.confirmCommission(any(), any()));
      expect(tester.widget<DonyButton>(confirmButton()).onPressed, isNotNull);
    });

    testWidgets('3DS abandonnée : message par-dessus la feuille, qui reste '
        'ouverte et réessayable, sans relecture', (tester) async {
      failAuth = true;
      when(() => repository.confirmCommission('bid-1', 'sup-1')).thenAnswer(
        (_) async => _supplement(
          BidSupplementStatus.commissionPending,
          clientSecret: 'pi_secret',
        ),
      );
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(
        find
            .text(
              "Validation bancaire interrompue : rien n'a été prélevé. "
              'Réessayez.',
            )
            .hitTestable(),
        findsOneWidget,
      );
      expect(sheetTitle(), findsOneWidget);
      verifyNever(() => bidBloc.add(any()));
      expect(tester.widget<DonyButton>(confirmButton()).onPressed, isNotNull);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementCommissionResumed, {
          'outcome': 'failed',
        }),
      ).called(1);
    });

    testWidgets('carte refusée : erreur par-dessus la feuille et relecture ; '
        'la demande annulée referme la feuille', (tester) async {
      const error = ValidationException(
        'd',
        code: 'supplement-commission-card-declined',
      );
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenThrow(error);
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      final presented = ErrorPresenter.resolve(
        error,
        l10n: lookupAppLocalizations(const Locale('fr')),
      );
      expect(find.text(presented.title).hitTestable(), findsWidgets);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);

      // La feuille reste ouverte ; le colis relu montre la demande annulée :
      // elle se ferme.
      expect(sheetTitle(), findsOneWidget);
      bidStates.add(BidDetailLoaded(_bid(BidSupplementStatus.cancelled)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(sheetTitle(), findsNothing);
    });

    testWidgets('pendant l\'appel : chargement, les deux boutons désactivés', (
      tester,
    ) async {
      final pending = Completer<BidSupplement>();
      when(
        () => repository.confirmCommission(any(), any()),
      ).thenAnswer((_) => pending.future);
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final confirm = tester.widget<DonyButton>(confirmButton());
      expect(confirm.isLoading, isTrue);
      expect(confirm.onPressed, isNull);
      expect(tester.widget<DonyButton>(withdrawButton()).onPressed, isNull);

      pending.complete(
        _supplement(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
      );
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
    });
  });

  // Sheet refermé de force pendant l'appel (glissement) : ses cubits sont
  // fermés avec la route, son écouteur n'est plus là. L'issue reste mesurée
  // et le bouton relit le colis à la réponse, pour que la tuile se mette à
  // jour sans attendre le relevé suivant.
  group('sheet fermé pendant l\'appel', () {
    Future<void> forceClose(WidgetTester tester) async {
      Navigator.of(
        tester.element(find.text('open-todo')),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
    }

    testWidgets('« Valider le paiement » : issue mesurée et colis relu à la '
        'réponse', (tester) async {
      final pending = Completer<BidSupplement>();
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenAnswer((_) => pending.future);
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pump();
      await forceClose(tester);
      verifyNever(() => bidBloc.add(any()));

      pending.complete(
        _supplement(
          BidSupplementStatus.proposed,
          commissionStatus: SupplementCommissionStatus.charged,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementCommissionResumed, {
          'outcome': 'proposed',
        }),
      ).called(1);
    });

    testWidgets('3DS abandonnée après fermeture : échec mesuré, colis relu', (
      tester,
    ) async {
      failAuth = true;
      final pending = Completer<BidSupplement>();
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenAnswer((_) => pending.future);
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pump();
      await forceClose(tester);
      pending.complete(
        _supplement(
          BidSupplementStatus.commissionPending,
          clientSecret: 'pi_secret',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementCommissionResumed, {
          'outcome': 'failed',
        }),
      ).called(1);
    });

    testWidgets('« Retirer la demande » : retrait mesuré et colis relu à la '
        'réponse', (tester) async {
      final pending = Completer<BidSupplement>();
      when(
        () => repository.withdraw('bid-1', 'sup-1'),
      ).thenAnswer((_) => pending.future);
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      await tester.tap(dialogWithdraw());
      await tester.pump();
      await forceClose(tester);
      verifyNever(() => bidBloc.add(any()));

      pending.complete(_supplement(BidSupplementStatus.withdrawn));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementWithdrawn, any()),
      ).called(1);
    });

    testWidgets('pendant l\'appel, le retour système ne ferme pas le sheet ; '
        'une fois la réponse arrivée, il le ferme', (tester) async {
      final pending = Completer<BidSupplement>();
      when(
        () => repository.confirmCommission('bid-1', 'sup-1'),
      ).thenAnswer((_) => pending.future);
      await openTodo(tester);

      await tester.tap(confirmButton());
      await tester.pump();
      // Le chargement tourne : pas de pumpAndSettle tant que l'appel dure.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sheetTitle(), findsOneWidget);

      // 3DS abandonnée : plus d'appel en cours, le retour ferme de nouveau.
      failAuth = true;
      pending.complete(
        _supplement(
          BidSupplementStatus.commissionPending,
          clientSecret: 'pi_secret',
        ),
      );
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
    });
  });

  group('« Retirer la demande »', () {
    testWidgets('confirme, retire, puis la feuille se ferme, confirme et '
        'relit le colis', (tester) async {
      when(
        () => repository.withdraw('bid-1', 'sup-1'),
      ).thenAnswer((_) async => _supplement(BidSupplementStatus.withdrawn));
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      expect(find.text('Retirer la demande ?'), findsOneWidget);
      verifyNever(() => repository.withdraw(any(), any()));

      await tester.tap(dialogWithdraw());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verify(() => repository.withdraw('bid-1', 'sup-1')).called(1);
      expect(sheetTitle(), findsNothing);
      expect(find.text('Demande retirée').hitTestable(), findsOneWidget);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementWithdrawn, any()),
      ).called(1);
    });

    testWidgets('confirmation refusée : rien n\'est envoyé', (tester) async {
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Annuler'),
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(() => repository.withdraw(any(), any()));
      expect(sheetTitle(), findsOneWidget);
    });

    testWidgets('retrait refusé (déjà traité) : erreur par-dessus la feuille, '
        'qui reste ouverte, et relecture', (tester) async {
      const error = ConflictException('d', code: 'supplement-not-pending');
      when(() => repository.withdraw('bid-1', 'sup-1')).thenThrow(error);
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      await tester.tap(dialogWithdraw());
      await tester.pumpAndSettle();

      final message = ErrorPresenter.resolve(
        error,
        l10n: lookupAppLocalizations(const Locale('fr')),
      ).message;
      expect(tester.takeException(), isNull);
      expect(find.text(message).hitTestable(), findsOneWidget);
      expect(sheetTitle(), findsOneWidget);
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
      verify(
        () => backend.capture(AnalyticsEvents.bidSupplementActionFailed, {
          'action': 'withdraw',
          'error_code': 'supplement-not-pending',
        }),
      ).called(1);
    });
  });

  group('suit le colis rechargé', () {
    testWidgets('frais validés ailleurs : la feuille se ferme', (tester) async {
      await openTodo(tester);

      bidStates.add(BidDetailLoaded(_bid(BidSupplementStatus.proposed)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(sheetTitle(), findsNothing);
    });

    // Le pied ne se vide pas pendant que le sheet se referme : il garde les
    // derniers boutons, désactivés (comme le contenu garde la dernière
    // demande connue), plutôt qu'une bande vide avec bordure et ombre.
    testWidgets('demande traitée ailleurs : le pied garde les boutons, '
        'désactivés, le temps de la fermeture', (tester) async {
      await openTodo(tester);

      bidStates.add(BidDetailLoaded(_bid(BidSupplementStatus.proposed)));
      // Colis relu, puis début de l'animation de sortie du sheet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(footerButtons(), findsNWidgets(2));
      expect(tester.widget<DonyButton>(confirmButton()).onPressed, isNull);
      expect(tester.widget<DonyButton>(withdrawButton()).onPressed, isNull);
      expect(find.text('Frais de service à valider'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(sheetTitle(), findsNothing);
    });

    testWidgets('confirmation ouverte quand la demande est traitée : les '
        'boutons du pied restent visibles, désactivés', (tester) async {
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      bidStates.add(BidDetailLoaded(_bid(BidSupplementStatus.proposed)));
      await tester.pumpAndSettle();

      expect(find.text('Retirer la demande ?'), findsOneWidget);
      expect(footerButtons(), findsNWidgets(2));
      expect(tester.widget<DonyButton>(confirmButton()).onPressed, isNull);
    });

    testWidgets('le colis rechargé d\'un autre envoi ne ferme rien', (
      tester,
    ) async {
      await openTodo(tester);

      bidStates.add(
        BidDetailLoaded(
          BidModel(
            id: 'bid-other',
            announcementId: 'ann-1',
            senderId: 'sender-1',
            status: 'COMPLETED',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sheetTitle(), findsOneWidget);
    });

    testWidgets('une confirmation ouverte n\'est pas refermée à sa place ; '
        'refusée, la feuille se ferme sans rien envoyer', (tester) async {
      await openTodo(tester);

      await tester.tap(withdrawButton());
      await tester.pumpAndSettle();
      bidStates.add(BidDetailLoaded(_bid(BidSupplementStatus.proposed)));
      await tester.pumpAndSettle();
      expect(find.text('Retirer la demande ?'), findsOneWidget);

      await tester.tap(dialogWithdraw());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      verifyNever(() => repository.withdraw(any(), any()));
      expect(sheetTitle(), findsNothing);
    });
  });

  group('mesures', () {
    testWidgets('bid_detail_tile_opened : tuile, rôle et source', (
      tester,
    ) async {
      await openTodo(tester);
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'supplement',
          'role': 'traveler',
          'source': 'tile',
        }),
      ).called(1);
    });

    testWidgets('source link (?action=supplement)', (tester) async {
      await openTodo(tester, source: TodoSource.link);
      verify(
        () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
          'tile': 'supplement',
          'role': 'traveler',
          'source': 'link',
        }),
      ).called(1);
    });

    testWidgets('pas de bid_supplement_viewed à l\'ouverture (la tuile le '
        'mesure)', (tester) async {
      await openTodo(tester);
      verifyNever(
        () => backend.capture(AnalyticsEvents.bidSupplementViewed, any()),
      );
    });
  });

  group('boutons à taille nominale', () {
    double labelScale(WidgetTester tester, Finder button, String label) {
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} à 360 dp, TextScaler 1.3', (
        tester,
      ) async {
        final l = lookupAppLocalizations(locale);
        await openTodo(
          tester,
          locale: locale,
          textScale: 1.3,
          size: const Size(360, 800),
        );

        expect(tester.takeException(), isNull);
        for (final (button, label) in [
          (confirmButton(), l.supplementCommissionConfirm),
          (withdrawButton(), l.supplementWithdraw),
        ]) {
          expect(tester.getSize(button).height, 52, reason: label);
          expect(labelScale(tester, button, label), closeTo(1, 0.001));
        }
      });
    }
  });
}
