import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/bloc/parcel_refusal/parcel_refusal_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_options_sheet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _FakeConversationOpenEvent extends Fake
    implements ConversationOpenEvent {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockSupplementRepository extends Mock
    implements BidSupplementRepository {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? token = 'tok',
  DateTime? departureAt,
  bool supplementRequestAllowed = false,
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'b1',
  supplementRequestAllowed: supplementRequestAllowed,
  paymentMethod: paymentMethod,
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  weightKg: 5,
  trackingToken: token,
  departureAt: departureAt,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

Widget _buildApp({
  required _MockBidBloc bidBloc,
  required _MockConvBloc conv,
  required BidModel bid,
  List<Object?>? transitExtras,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<ConversationOpenBloc>.value(value: conv),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showTravelerOptionsSheet(context, bid),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/tracking/scan/identify',
        builder: (_, state) {
          transitExtras?.add(state.extra);
          return const Scaffold(body: Text('identify-screen'));
        },
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
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  );
}

Future<_MockBidBloc> _open(
  WidgetTester tester,
  BidModel bid, {
  List<Object?>? transitExtras,
  Size? size,
  double textScale = 1.0,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final bidBloc = _MockBidBloc();
  final conv = _MockConvBloc();
  when(() => bidBloc.state).thenReturn(BidInitial());
  when(() => conv.state).thenReturn(const ConversationOpenInitial());
  await tester.pumpWidget(
    _buildApp(
      bidBloc: bidBloc,
      conv: conv,
      bid: bid,
      transitExtras: transitExtras,
      textScale: textScale,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return bidBloc;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeConversationOpenEvent());
    registerFallbackValue(_FakeBidEvent());
  });

  testWidgets(
    'ACCEPTED → contacter / détails / signaler / annuler sans partage suivi',
    (tester) async {
      await _open(tester, _bid());
      expect(find.text("Contacter l'expéditeur"), findsOneWidget);
      expect(find.text('Détails du colis'), findsOneWidget);
      expect(find.text('Partager le suivi'), findsNothing);
      expect(find.text("Signaler l'expéditeur"), findsOneWidget);
      expect(find.text('Annuler ce transport'), findsOneWidget);
      expect(find.text('Le colis ne correspond pas'), findsOneWidget);
      expect(find.text('Supprimer cette demande'), findsNothing);
    },
  );

  testWidgets("REJECTED → supprimer, pas d'annuler", (tester) async {
    await _open(tester, _bid(status: 'REJECTED', token: null));
    expect(find.text('Supprimer cette demande'), findsOneWidget);
    expect(find.text('Annuler ce transport'), findsNothing);
    expect(find.text('Le colis ne correspond pas'), findsNothing);
    expect(find.text('Partager le suivi'), findsNothing);
  });

  group('Supprimer cette demande (ex-footer)', () {
    testWidgets('REJECTED : confirmation puis BidTravelerDismissRequested', (
      tester,
    ) async {
      final bidBloc = await _open(
        tester,
        _bid(status: 'REJECTED', token: null),
      );
      await tester.ensureVisible(find.text('Supprimer cette demande'));
      await tester.tap(find.text('Supprimer cette demande'));
      await tester.pumpAndSettle();

      // Même boîte de confirmation que l'ancien bouton du footer.
      expect(
        find.text(
          'Cette demande refusée sera retirée définitivement de votre liste.',
        ),
        findsOneWidget,
      );
      verifyNever(() => bidBloc.add(any()));

      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final event = verify(() => bidBloc.add(captureAny())).captured.single;
      expect(event, isA<BidTravelerDismissRequested>());
      expect((event as BidTravelerDismissRequested).bidId, 'b1');
    });

    testWidgets('REJECTED : Annuler ferme la boîte sans événement', (
      tester,
    ) async {
      final bidBloc = await _open(
        tester,
        _bid(status: 'REJECTED', token: null),
      );
      await tester.ensureVisible(find.text('Supprimer cette demande'));
      await tester.tap(find.text('Supprimer cette demande'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => bidBloc.add(any()));
    });

    for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'PENDING']) {
      testWidgets('$status : pas d\'entrée Supprimer', (tester) async {
        await _open(tester, _bid(status: status, token: null));
        expect(find.text('Supprimer cette demande'), findsNothing);
      });
    }
  });

  group('Scanner le transit (ex-footer)', () {
    testWidgets('HANDED_OVER : entrée présente, ouvre le scan TRANSIT', (
      tester,
    ) async {
      final extras = <Object?>[];
      await _open(
        tester,
        _bid(status: 'HANDED_OVER', token: null),
        transitExtras: extras,
      );
      expect(find.text('Scanner le transit'), findsOneWidget);
      expect(find.textContaining('facultatif)'), findsNothing);

      await tester.ensureVisible(find.text('Scanner le transit'));
      await tester.tap(find.text('Scanner le transit'));
      await tester.pumpAndSettle();

      expect(find.text('identify-screen'), findsOneWidget);
      expect(extras.single, <String, dynamic>{
        'etape': 'TRANSIT',
        'focusNumber': false,
      });
    });

    for (final status in [
      'ACCEPTED',
      'IN_TRANSIT',
      'ARRIVED',
      'REJECTED',
      'PENDING',
    ]) {
      testWidgets('$status : pas d\'entrée Scanner le transit', (tester) async {
        await _open(tester, _bid(status: status, token: null));
        expect(find.text('Scanner le transit'), findsNothing);
      });
    }

    testWidgets('anglais : « Scan the transit »', (tester) async {
      useEnglish();
      await _open(tester, _bid(status: 'HANDED_OVER', token: null));
      expect(find.text('Scan the transit'), findsOneWidget);
    });
  });

  testWidgets('CANCELLED → supprimer présent, pas annuler', (tester) async {
    await _open(tester, _bid(status: 'CANCELLED', token: null));
    expect(find.text('Supprimer cette demande'), findsOneWidget);
    expect(find.text('Annuler ce transport'), findsNothing);
  });

  // CANCELLED reste supprimable par le voyageur (existant) : corps générique,
  // pas celui d'une « demande refusée », même événement.
  testWidgets('CANCELLED : corps générique puis BidTravelerDismissRequested', (
    tester,
  ) async {
    final bidBloc = await _open(tester, _bid(status: 'CANCELLED', token: null));
    await tester.ensureVisible(find.text('Supprimer cette demande'));
    await tester.tap(find.text('Supprimer cette demande'));
    await tester.pumpAndSettle();

    expect(
      find.text('Elle sera retirée définitivement de votre historique.'),
      findsOneWidget,
    );
    expect(find.textContaining('demande refusée'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    final event = verify(() => bidBloc.add(captureAny())).captured.single;
    expect(event, isA<BidTravelerDismissRequested>());
    expect((event as BidTravelerDismissRequested).bidId, 'b1');
  });

  testWidgets('IN_TRANSIT → annulation impossible (D3), pas supprimer', (
    tester,
  ) async {
    await _open(tester, _bid(status: 'IN_TRANSIT', token: null));
    expect(find.text('Annuler ce transport'), findsNothing);
    expect(find.text('Le colis ne correspond pas'), findsNothing);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets('HANDED_OVER avant départ → annuler présent, pas supprimer', (
    tester,
  ) async {
    await _open(
      tester,
      _bid(
        status: 'HANDED_OVER',
        token: null,
        departureAt: DateTime.now().add(const Duration(days: 2)),
      ),
    );
    expect(find.text('Annuler ce transport'), findsOneWidget);
    expect(find.text('Le colis ne correspond pas'), findsOneWidget);
    expect(find.text('Supprimer cette demande'), findsNothing);
  });

  testWidgets('HANDED_OVER après départ → annulation impossible (D3)', (
    tester,
  ) async {
    await _open(
      tester,
      _bid(
        status: 'HANDED_OVER',
        token: null,
        departureAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(find.text('Annuler ce transport'), findsNothing);
    expect(find.text('Le colis ne correspond pas'), findsNothing);
  });

  testWidgets('sans trackingToken → pas de Partager le suivi', (tester) async {
    await _open(tester, _bid(token: null));
    expect(find.text('Partager le suivi'), findsNothing);
  });

  testWidgets('tap Contacter → ConversationOpenRequested émis', (tester) async {
    final bidBloc = _MockBidBloc();
    final conv = _MockConvBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => conv.state).thenReturn(const ConversationOpenInitial());

    await tester.pumpWidget(
      _buildApp(bidBloc: bidBloc, conv: conv, bid: _bid()),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Contacter l'expéditeur"));
    await tester.pumpAndSettle();

    verify(
      () => conv.add(any(that: isA<ConversationOpenRequested>())),
    ).called(1);
  });

  testWidgets(
    'tap Signaler → navigue vers report-incident avec la cible USER/expéditeur',
    (tester) async {
      await _open(tester, _bid());
      await tester.tap(find.text("Signaler l'expéditeur"));
      await tester.pumpAndSettle();

      expect(find.text('Reported: IncidentTargetType.user/s1'), findsOneWidget);
    },
  );

  testWidgets('tap Détails du colis → sub-sheet apparaît', (tester) async {
    await _open(tester, _bid());
    await tester.tap(find.text('Détails du colis'));
    await tester.pumpAndSettle();
    // After tapping, the sub-sheet title 'Détails du colis' should appear
    expect(find.text('Détails du colis'), findsWidgets);
  });

  testWidgets('avec trackingToken → le voyageur ne voit pas le partage suivi', (
    tester,
  ) async {
    await _open(tester, _bid(token: 'abc123'));
    expect(find.text('Partager le suivi'), findsNothing);
  });

  testWidgets('tap Annuler ce transport → dialog affiché', (tester) async {
    await _open(tester, _bid(token: null));
    await tester.ensureVisible(find.text('Annuler ce transport'));
    await tester.tap(find.text('Annuler ce transport'));
    await tester.pumpAndSettle();
    // CancellationDialog shows a button text (Garder or Confirmer)
    expect(
      find.byType(AlertDialog).hitTestable().evaluate().isNotEmpty ||
          find.text('Garder').evaluate().isNotEmpty ||
          find.text('Annuler').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('tap Le colis ne correspond pas → feuille de refus ouverte', (
    tester,
  ) async {
    getIt.registerFactory<ParcelRefusalCubit>(
      () => ParcelRefusalCubit(
        _MockBidRepository(),
        _MockMediaService(),
        _MockAnalyticsService(),
      ),
    );
    addTearDown(getIt.reset);
    await _open(tester, _bid(token: null));

    await tester.tap(find.text('Le colis ne correspond pas'));
    await tester.pumpAndSettle();

    expect(find.text('Déclaré par l\'expéditeur'), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Refuser le colis'), findsOneWidget);
  });

  group('Demander un supplément', () {
    testWidgets('masqué tant que le serveur ne l\'autorise pas', (
      tester,
    ) async {
      await _open(tester, _bid());
      expect(find.text('Demander un supplément'), findsNothing);
    });

    testWidgets('autorisé : tuile avant « Le colis ne correspond pas »', (
      tester,
    ) async {
      await _open(tester, _bid(supplementRequestAllowed: true));

      final supplement = find.text('Demander un supplément');
      expect(supplement, findsOneWidget);
      expect(
        tester.getTopLeft(supplement).dy,
        lessThan(tester.getTopLeft(find.text('Le colis ne correspond pas')).dy),
      );
    });

    testWidgets('espèces : visible dès que le serveur l\'autorise (PR A4)', (
      tester,
    ) async {
      await _open(
        tester,
        _bid(
          supplementRequestAllowed: true,
          paymentMethod: BidPaymentMethod.cash,
        ),
      );
      expect(find.text('Demander un supplément'), findsOneWidget);
    });

    testWidgets('espèces non autorisé par le serveur : masqué', (tester) async {
      await _open(tester, _bid(paymentMethod: BidPaymentMethod.cash));
      expect(find.text('Demander un supplément'), findsNothing);
    });

    testWidgets('tap → feuille de demande ouverte', (tester) async {
      final repository = _MockSupplementRepository();
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      when(() => repository.options(any())).thenAnswer(
        (_) async =>
            const SupplementOptions(currency: 'EUR', minNet: 1, maxNet: 300),
      );
      getIt.registerFactory<SupplementRequestCubit>(
        () =>
            SupplementRequestCubit(repository, _MockMediaService(), analytics),
      );
      addTearDown(getIt.reset);
      await _open(tester, _bid(supplementRequestAllowed: true));

      await tester.tap(find.text('Demander un supplément'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(DonyButton, 'Envoyer la demande'),
        findsOneWidget,
      );
      verify(() => repository.options('b1')).called(1);
    });
  });

  testWidgets('anglais — tuiles traduites', (tester) async {
    useEnglish();
    await _open(tester, _bid());
    expect(find.text('Contact the sender'), findsOneWidget);
    expect(find.text('Parcel details'), findsOneWidget);
    expect(find.text('Report the sender'), findsOneWidget);
    expect(find.text('Cancel this transport'), findsOneWidget);
    expect(find.text("The parcel doesn't match"), findsOneWidget);
  });

  // ── Matrice du menu ⋮ : chaque statut, chaque entrée (inventaire B5) ──────
  group('entrées du menu par statut', () {
    const contact = "Contacter l'expéditeur";
    const details = 'Détails du colis';
    const report = "Signaler l'expéditeur";
    const supplement = 'Demander un supplément';
    const refuse = 'Le colis ne correspond pas';
    const cancel = 'Annuler ce transport';
    const transit = 'Scanner le transit';
    const delete = 'Supprimer cette demande';
    const all = [
      contact,
      details,
      report,
      supplement,
      refuse,
      cancel,
      transit,
      delete,
    ];
    const base = [contact, details, report];
    final soon = DateTime.now().add(const Duration(days: 2));
    final gone = DateTime.now().subtract(const Duration(hours: 2));

    final cases = <String, (BidModel, List<String>)>{
      'PENDING': (_bid(status: 'PENDING'), base),
      'PAYMENT_ESCROWED': (_bid(status: 'PAYMENT_ESCROWED'), base),
      'AWAITING_PAYMENT': (_bid(status: 'AWAITING_PAYMENT'), base),
      'ACCEPTED': (_bid(status: 'ACCEPTED'), [...base, refuse, cancel]),
      'HANDED_OVER avant le départ': (
        _bid(status: 'HANDED_OVER', departureAt: soon),
        [...base, refuse, cancel, transit],
      ),
      'HANDED_OVER départ passé': (
        _bid(status: 'HANDED_OVER', departureAt: gone),
        [...base, transit],
      ),
      'IN_TRANSIT': (_bid(status: 'IN_TRANSIT'), base),
      'ARRIVED': (_bid(status: 'ARRIVED'), base),
      'COMPLETED': (_bid(status: 'COMPLETED'), base),
      'DELIVERED': (_bid(status: 'DELIVERED'), base),
      'REJECTED': (_bid(status: 'REJECTED'), [...base, delete]),
      'CANCELLED': (_bid(status: 'CANCELLED'), [...base, delete]),
      // Le serveur ne laisse masquer que REJECTED et CANCELLED (409
      // invalid-bid-status sinon) : pas d'entrée pour les trois autres.
      'NO_SHOW': (_bid(status: 'NO_SHOW'), base),
      'EXPIRED': (_bid(status: 'EXPIRED'), base),
      'PARCEL_REFUSED': (_bid(status: 'PARCEL_REFUSED'), base),
    };

    for (final MapEntry(key: name, value: (bid, expected)) in cases.entries) {
      testWidgets('$name : exactement les entrées attendues', (tester) async {
        await _open(tester, bid);
        final present = [
          for (final label in all)
            if (find.text(label).evaluate().isNotEmpty) label,
        ];
        expect(present, unorderedEquals(expected));
        // Jamais de partage du suivi pour le voyageur.
        expect(find.text('Partager le suivi'), findsNothing);
      });
    }

    testWidgets('supplément autorisé par le serveur : il s\'ajoute, quel que '
        'soit le statut', (tester) async {
      for (final status in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT']) {
        await _open(
          tester,
          _bid(status: status, supplementRequestAllowed: true),
        );
        expect(find.text(supplement), findsOneWidget, reason: status);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    });
  });

  // ── Sept entrées : la feuille défile, la dernière est atteignable ────────
  group('sept entrées sur un petit écran', () {
    // HANDED_OVER avant le départ, supplément autorisé : contacter, détails,
    // signaler, supplément, le colis ne correspond pas, annuler, scanner le
    // transit.
    final sevenEntries = _bid(
      status: 'HANDED_OVER',
      token: null,
      supplementRequestAllowed: true,
      departureAt: DateTime.now().add(const Duration(days: 2)),
    );

    for (final (english, labels) in [
      (false, ['Scanner le transit', "Contacter l'expéditeur"]),
      (true, ['Scan the transit', 'Contact the sender']),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '360 × 640 dp, texte ×$scale, ${english ? 'EN' : 'FR'} : pas '
          'd\'exception, dernière entrée atteignable',
          (tester) async {
            if (english) useEnglish();
            final extras = <Object?>[];
            await _open(
              tester,
              sevenEntries,
              size: const Size(360, 640),
              textScale: scale,
              transitExtras: extras,
            );
            expect(tester.takeException(), isNull);

            final last = find.text(labels.first);
            final first = find.text(labels.last);
            expect(last, findsOneWidget);
            expect(first, findsOneWidget);

            // La feuille n'est plus bornée à 9/16 de l'écran : elle prend la
            // hauteur dont elle a besoin (comme celle de l'expéditeur).
            final sheet = tester.getSize(
              find.ancestor(
                of: first,
                matching: find.byType(SingleChildScrollView),
              ),
            );
            expect(sheet.height, greaterThan(640 * 9 / 16 + 1));

            // Le défilement amène la dernière entrée à l'écran, et un tap
            // l'atteint vraiment.
            await tester.scrollUntilVisible(
              last,
              120,
              scrollable: find.descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            expect(last.hitTestable(), findsOneWidget);
            expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(640));
            await tester.tap(last);
            await tester.pumpAndSettle();
            expect(find.text('identify-screen'), findsOneWidget);
            expect(extras.single, <String, dynamic>{
              'etape': 'TRANSIT',
              'focusNumber': false,
            });
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
