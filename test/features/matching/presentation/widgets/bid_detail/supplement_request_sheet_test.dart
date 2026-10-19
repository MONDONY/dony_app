import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_request_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_request_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockRepository extends Mock implements BidSupplementRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _FakeBidEvent extends Fake implements BidEvent {}

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

const _options = SupplementOptions(
  currency: 'EUR',
  minNet: 1,
  maxNet: 300,
  suggestions: [
    SupplementSuggestion(
      kind: SupplementSuggestion.kindGridItem,
      label: 'Téléphone',
      unitNet: 15,
    ),
    SupplementSuggestion(kind: SupplementSuggestion.kindKg, unitNet: 8),
  ],
);

const _submit = 'Envoyer la demande';

/// Texte affiché, espaces insécables du format monétaire lues comme des
/// espaces simples.
Finder _txt(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText())?.replaceAll(
            RegExp('[\u00A0\u202F]'),
            ' ',
          ) ==
          text,
);

Finder _btn(String label) =>
    find.ancestor(of: _txt(label), matching: find.byType(DonyButton)).first;

void main() {
  late _MockRepository repository;
  late _MockMediaService media;
  late _MockAnalyticsService analytics;
  late _MockBidBloc bidBloc;

  setUpAll(() {
    registerFallbackValue(_FakeBidEvent());
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(BidSupplementReason.other);
  });

  setUp(() {
    DonySnackbar.clearDedup();
    repository = _MockRepository();
    media = _MockMediaService();
    analytics = _MockAnalyticsService();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => repository.options(any())).thenAnswer((_) async => _options);
    when(() => repository.quote(any(), any())).thenAnswer(
      (inv) async => SupplementQuote(
        netAmount: inv.positionalArguments[1] as double,
        commissionAmount: 2,
        grossAmount: (inv.positionalArguments[1] as double) + 2,
        currency: 'EUR',
      ),
    );
    when(
      () => media.pick(source: any(named: 'source')),
    ).thenAnswer((_) async => XFile('/tmp/supplement-introuvable.jpg'));
    when(
      () => repository.uploadPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/supplement.jpg');
    getIt.registerFactory<SupplementRequestCubit>(
      () => SupplementRequestCubit(
        repository,
        media,
        analytics,
        quoteDebounce: Duration.zero,
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  void stubCreate(Future<BidSupplement> Function() answer) => when(
    () => repository.create(
      any(),
      netAmount: any(named: 'netAmount'),
      reason: any(named: 'reason'),
      reasonText: any(named: 'reasonText'),
      gridItemLabel: any(named: 'gridItemLabel'),
      photoKey: any(named: 'photoKey'),
    ),
  ).thenAnswer((_) => answer());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
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
                onPressed: () => openSupplementRequestSheet(context, _bid()),
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

  /// Bouton d'envoi du stickyBottom, quel que soit son libellé.
  DonyButton submitButton(WidgetTester tester) => tester.widget<DonyButton>(
    find.byWidgetPredicate(
      (w) =>
          w is DonyButton &&
          (w.label == _submit || w.label.startsWith('Demander ')),
    ),
  );

  Finder amountField() => find.byType(TextField).first;

  testWidgets(
    'bouton dans le stickyBottom, inactif tant que rien n\'est saisi',
    (tester) async {
      await open(tester);

      expect(_txt('+1 kg : 8 €'), findsOneWidget);
      expect(_txt('Téléphone : 15 €'), findsOneWidget);
      final sticky = find.widgetWithText(DonyButton, _submit);
      expect(sticky, findsOneWidget);
      expect(tester.widget<DonyButton>(sticky).onPressed, isNull);
      // Le bouton vit hors du contenu défilant de la feuille.
      expect(
        find.ancestor(of: sticky, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
    },
  );

  testWidgets('suggestion + photo : devis affiché, demande envoyée', (
    tester,
  ) async {
    stubCreate(
      () async => const BidSupplement(
        id: 'sup-1',
        status: BidSupplementStatus.proposed,
        grossAmount: 17,
      ),
    );
    await open(tester);

    await tester.tap(_txt('Téléphone : 15 €'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amountField()).controller!.text, '15,00');
    expect(find.text('Payé par l\'expéditeur'), findsOneWidget);
    expect(_txt('17 €'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull, reason: 'photo manquante');

    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(find.text('Reprendre la photo'), findsOneWidget);

    final send = _btn('Demander 17 €');
    expect(tester.widget<DonyButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        'bid-1',
        netAmount: 15,
        reason: BidSupplementReason.gridItem,
        gridItemLabel: 'Téléphone',
        photoKey: 'tracking/bid-1/supplement.jpg',
      ),
    ).called(1);
    expect(find.text('Demande envoyée à l\'expéditeur'), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('montant hors bornes : erreur sous le champ, bouton inactif', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(amountField(), '500');
    await tester.pumpAndSettle();

    expect(
      _txt('Le montant doit être compris entre 1 € et 300 €.'),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('« Autre » exige des précisions', (tester) async {
    await open(tester);
    await tester.enterText(amountField(), '12');
    await tester.tap(find.text('Autre'));
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    expect(find.text('Expliquez l\'écart à l\'expéditeur'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(1), 'Deux colis');
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.byTooltip('Retirer la photo'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('échec réseau : la feuille reste ouverte, rien ne recharge', (
    tester,
  ) async {
    stubCreate(() async => throw const OfflineException());
    await open(tester);
    await tester.tap(_txt('+1 kg : 8 €'));
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(_btn('Demander 10 €'), findsOneWidget);
    verifyNever(() => bidBloc.add(any()));
  });

  testWidgets('départ trop proche (409) : la feuille se ferme et recharge', (
    tester,
  ) async {
    stubCreate(
      () async => throw const ConflictException('x', code: 'supplement-locked'),
    );
    await open(tester);
    await tester.tap(_txt('+1 kg : 8 €'));
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    await tester.tap(_btn('Demander 10 €'));
    await tester.pumpAndSettle();

    expect(find.text('Demander un supplément'), findsNothing);
    verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).called(1);
  });

  testWidgets('options introuvables : message et Réessayer', (tester) async {
    var calls = 0;
    when(() => repository.options(any())).thenAnswer((_) async {
      if (calls++ == 0) throw const OfflineException();
      return _options;
    });
    await open(tester);

    expect(
      find.text('Impossible de charger les montants possibles.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(_txt('+1 kg : 8 €'), findsOneWidget);
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

  testWidgets('anglais : textes traduits', (tester) async {
    useEnglish();
    await open(tester);

    expect(find.text('Request an extra charge'), findsOneWidget);
    expect(_txt('+1 kg: 8 €'), findsOneWidget);
    expect(find.widgetWithText(DonyButton, 'Send the request'), findsOneWidget);
  });
}
