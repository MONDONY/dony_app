import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/parcel_refusal/parcel_refusal_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_refusal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidRepository extends Mock implements BidRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidModel _bid({
  String status = 'ACCEPTED',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  weightKg: 1,
  contentCategory: 'Vêtements',
  description: 'Deux chemises',
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _contentMismatch = 'Contenu différent de la déclaration';
const _submit = 'Refuser le colis';

void main() {
  late _MockBidRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(ImageSource.camera);
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repository = _MockBidRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenAnswer((_) async => XFile('/tmp/refus-introuvable.jpg'));
    when(
      () => repository.uploadRefusalPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/refus.jpg');
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<ParcelRefusalCubit>(
      () => ParcelRefusalCubit(repository, media, analytics),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  void stubRefuse(Future<BidModel> Function() answer) => when(
    () => repository.refuseParcel(
      any(),
      reason: any(named: 'reason'),
      photoKey: any(named: 'photoKey'),
    ),
  ).thenAnswer((_) => answer());

  Future<void> open(WidgetTester tester, {BidModel? bid}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BlocProvider<BidBloc>.value(
          value: bidBloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openParcelRefusalSheet(context, bid ?? _bid()),
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

  DonyButton submitButton(WidgetTester tester) =>
      tester.widget<DonyButton>(find.widgetWithText(DonyButton, _submit));

  Future<void> fillForm(WidgetTester tester) async {
    await tester.tap(find.text(_contentMismatch));
    await tester.pump();
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'rappelle la déclaration, bouton inactif tant que le formulaire est vide',
    (tester) async {
      await open(tester);

      expect(find.text('Déclaré par l\'expéditeur'), findsOneWidget);
      expect(find.text('Poids : 1 kg · Vêtements'), findsOneWidget);
      expect(find.text('Deux chemises'), findsOneWidget);
      expect(
        find.text(
          "L'expéditeur est prévenu et remboursé intégralement. "
          'Des refus répétés suspendent son compte.',
        ),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'motif + photo : refuse, ferme la feuille, recharge le colis et confirme',
    (tester) async {
      stubRefuse(() async => _bid(status: 'PARCEL_REFUSED'));
      await open(tester);

      await tester.tap(find.text(_contentMismatch));
      await tester.pump();
      expect(submitButton(tester).onPressed, isNull, reason: 'photo manquante');

      await tester.tap(find.text('Prendre une photo'));
      await tester.pumpAndSettle();
      expect(find.text('Reprendre la photo'), findsOneWidget);
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), 'Un téléphone');
      await tester.tap(find.widgetWithText(DonyButton, _submit));
      await tester.pumpAndSettle();

      verify(
        () => repository.refuseParcel(
          'bid-1',
          reason: '$_contentMismatch : Un téléphone',
          photoKey: 'tracking/bid-1/refus.jpg',
        ),
      ).called(1);
      expect(find.text(_submit), findsNothing);
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
      expect(
        find.text('Colis refusé. L\'expéditeur est prévenu et remboursé.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('« Autre raison » exige des précisions', (tester) async {
    await open(tester);

    await tester.tap(find.text('Autre raison'));
    await tester.pump();
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(find.text('Expliquez ce que vous avez constaté'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Colis ouvert');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('retirer la photo désactive de nouveau le bouton', (
    tester,
  ) async {
    await open(tester);
    await fillForm(tester);

    await tester.tap(find.byTooltip('Retirer la photo'));
    await tester.pump();

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('espèces : encart dédié et confirmation sans remboursement', (
    tester,
  ) async {
    stubRefuse(() async => _bid(status: 'PARCEL_REFUSED'));
    await open(tester, bid: _bid(paymentMethod: BidPaymentMethod.cash));

    expect(
      find.textContaining('Les frais de service Yadony déjà réglés'),
      findsOneWidget,
    );
    await fillForm(tester);
    await tester.tap(find.widgetWithText(DonyButton, _submit));
    await tester.pumpAndSettle();

    expect(
      find.text('Colis refusé. L\'expéditeur est prévenu.'),
      findsOneWidget,
    );
  });

  testWidgets('colis déjà scanné : rappel de le rendre sur place', (
    tester,
  ) async {
    await open(tester, bid: _bid(status: 'HANDED_OVER'));

    expect(
      find.text(
        'Vous avez déjà scanné ce colis : rendez-le à l\'expéditeur sur place.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('échec du refus : la feuille reste ouverte, rien ne recharge', (
    tester,
  ) async {
    stubRefuse(() async => throw const OfflineException());
    await open(tester);
    await fillForm(tester);

    await tester.tap(find.widgetWithText(DonyButton, _submit));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(DonyButton, _submit), findsOneWidget);
    verifyNever(() => bidBloc.add(any()));
  });

  testWidgets('trajet parti (409) : la feuille se ferme et le colis recharge', (
    tester,
  ) async {
    stubRefuse(
      () async =>
          throw const ConflictException('parti', code: 'parcel-refusal-locked'),
    );
    await open(tester, bid: _bid(status: 'HANDED_OVER'));
    await fillForm(tester);

    await tester.tap(find.widgetWithText(DonyButton, _submit));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(DonyButton, _submit), findsNothing);
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('photo : aucun DonyButton dans le contenu de la feuille', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Prendre une photo'), findsNothing);
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre la photo'), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Reprendre la photo'), findsNothing);
    await tester.tap(find.text('Reprendre la photo'));
    await tester.pumpAndSettle();
    verify(() => media.pick(source: any(named: 'source'))).called(2);
  });

  testWidgets('photo illisible : message d\'erreur', (tester) async {
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenThrow(const UnsupportedMediaTypeException('video.mp4'));
    await open(tester);

    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cette photo n\'a pas pu être lue. Réessayez.'),
      findsOneWidget,
    );
  });
}
