import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_change/recipient_change_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/recipient_change_sheet.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

const _warning =
    'Le code de retrait et le lien de suivi seront renouvelés. '
    "L'ancien destinataire n'y aura plus accès.";

BidModel _bid({String status = 'IN_TRANSIT'}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  recipientName: 'Fatou Sow',
  recipientPhone: '+221771234567',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

void main() {
  late _MockBidRepository repository;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(_FakeRecipientEvent());
  });

  setUp(() {
    repository = _MockBidRepository();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<RecipientChangeCubit>(
      () => RecipientChangeCubit(repository, analytics),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  void stubChange(Future<BidModel> Function() answer) {
    when(
      () => repository.changeRecipient(
        any(),
        recipientName: any(named: 'recipientName'),
        recipientPhone: any(named: 'recipientPhone'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> open(WidgetTester tester, {BidModel? bid}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openRecipientChangeSheet(context, bid ?? _bid()),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.byType(TextField).at(0);
  Finder phoneField() => find.byType(TextField).at(1);
  DonyButton saveButton(WidgetTester tester) =>
      tester.widget<DonyButton>(find.widgetWithText(DonyButton, 'Enregistrer'));

  testWidgets('pré-remplit nom et numéro, bouton inactif sans changement', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Modifier le destinataire'), findsOneWidget);
    expect(find.text('Fatou Sow'), findsOneWidget);
    expect(find.text('+221771234567'), findsOneWidget);
    expect(find.text(_warning), findsNothing);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets(
    'nom seul modifié : pas d\'avertissement, enregistre et recharge le bid',
    (tester) async {
      stubChange(() async => _bid());
      await open(tester);

      await tester.enterText(nameField(), 'Fatou Diop');
      await tester.pump();

      expect(find.text(_warning), findsNothing);
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      verify(
        () => repository.changeRecipient(
          'bid-1',
          recipientName: 'Fatou Diop',
          recipientPhone: '+221771234567',
        ),
      ).called(1);
      expect(find.text('Modifier le destinataire'), findsNothing);
      expect(find.text('Nom du destinataire modifié.'), findsOneWidget);
      verify(
        () => bidBloc.add(
          any(
            that: isA<BidDetailRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid-1',
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('même numéro écrit avec espaces : pas d\'avertissement', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(phoneField(), '+221 77 123 45 67');
    await tester.pump();

    expect(find.text(_warning), findsNothing);
    // Rien n'a vraiment changé.
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets(
    'nouveau numéro : avertissement, puis snackbar du nouveau lien de suivi',
    (tester) async {
      stubChange(() async => _bid());
      await open(tester);

      await tester.enterText(phoneField(), '+221 78 111 22 33');
      await tester.pump();

      expect(find.text(_warning), findsOneWidget);

      await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
      await tester.pumpAndSettle();

      verify(
        () => repository.changeRecipient(
          'bid-1',
          recipientName: 'Fatou Sow',
          recipientPhone: '+221781112233',
        ),
      ).called(1);
      expect(
        find.text(
          'Destinataire modifié. Envoyez-lui le nouveau lien de suivi.',
        ),
        findsOneWidget,
      );
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
    },
  );

  testWidgets(
    'numéro invalide : bouton inactif, erreur affichée à la perte de focus',
    (tester) async {
      await open(tester);

      await tester.enterText(phoneField(), '77123');
      await tester.pump();

      expect(saveButton(tester).onPressed, isNull);
      expect(find.text('Format E.164 (+221…)'), findsNothing);

      // Le focus passe au champ nom : le téléphone est validé.
      await tester.tap(nameField());
      await tester.pump();

      expect(find.text('Format E.164 (+221…)'), findsOneWidget);
    },
  );

  testWidgets('nom vidé : bouton inactif', (tester) async {
    await open(tester);

    await tester.enterText(nameField(), '   ');
    await tester.enterText(phoneField(), '+221781112233');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('409 : ferme la feuille, explique et recharge', (tester) async {
    stubChange(
      () async => throw const ConflictException('recipient-change-not-allowed'),
    );
    await open(tester);

    await tester.enterText(phoneField(), '+221781112233');
    await tester.pump();
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le destinataire'), findsNothing);
    expect(
      find.text(
        'Le colis a déjà été remis, le destinataire ne peut plus changer.',
      ),
      findsOneWidget,
    );
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('autre erreur : la feuille reste ouverte, bouton réactivé', (
    tester,
  ) async {
    stubChange(() async => throw const ServerException('boom'));
    await open(tester);

    await tester.enterText(phoneField(), '+221781112233');
    await tester.pump();
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le destinataire'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
    verifyNever(() => bidBloc.add(any()));
  });

  testWidgets('« Choisir dans mon carnet » remplit les champs', (tester) async {
    const awa = Recipient(
      id: 'r-1',
      fullName: 'Awa Ndiaye',
      phoneE164: '+221781112233',
      city: 'Dakar',
      country: 'SN',
    );
    final pickerBloc = _MockRecipientBloc();
    when(() => pickerBloc.state).thenReturn(
      const RecipientState(status: RecipientStatus.success, recipients: [awa]),
    );
    getIt.registerFactory<RecipientBloc>(() => pickerBloc);
    await open(tester);

    await tester.tap(find.text('Choisir dans mon carnet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer ce destinataire'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Awa Ndiaye',
    );
    expect(
      tester.widget<TextField>(phoneField()).controller!.text,
      '+221781112233',
    );
    expect(find.text(_warning), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('sans BidBloc au-dessus : snackbar sans rechargement', (
    tester,
  ) async {
    stubChange(() async => _bid());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openRecipientChangeSheet(context, _bid()),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Fatou Diop');
    await tester.pump();
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Nom du destinataire modifié.'), findsOneWidget);
  });
}
