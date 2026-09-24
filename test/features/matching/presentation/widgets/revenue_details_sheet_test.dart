import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/revenue_details_cubit.dart';
import 'package:dony/features/matching/bloc/stats_period_cubit.dart';
import 'package:dony/features/matching/data/models/revenue_details_model.dart';
import 'package:dony/features/matching/presentation/widgets/revenue_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockRevenueDetailsCubit extends MockCubit<RevenueDetailsState>
    implements RevenueDetailsCubit {}

final _details = RevenueDetailsModel(
  period: '30d',
  deliveries: 3,
  groups: [
    RevenueGroupModel(
      currency: 'EUR',
      total: 810,
      deliveries: 2,
      items: [
        RevenueItemModel(
          tripId: 't1',
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          date: DateTime(2026, 9, 12),
          weightKg: 4,
          rail: RevenueRail.card,
          amount: 480,
        ),
        RevenueItemModel(
          tripId: 't2',
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          date: DateTime(2026, 9, 5),
          weightKg: 2.5,
          rail: RevenueRail.cash,
          amount: 330,
        ),
      ],
    ),
    RevenueGroupModel(
      currency: 'XOF',
      total: 120000,
      deliveries: 1,
      items: [
        RevenueItemModel(
          tripId: 't3',
          departureCity: 'Dakar',
          arrivalCity: 'Paris',
          date: DateTime(2026, 9, 9),
          rail: RevenueRail.mobileMoney,
          amount: 120000,
        ),
      ],
    ),
  ],
);

Widget _harness(RevenueDetailsCubit cubit, {String? approximateTotal}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider<RevenueDetailsCubit>.value(
        value: cubit,
        child: SingleChildScrollView(
          child: RevenueDetailsSheet(
            period: StatsPeriod.thirtyDays,
            approximateTotal: approximateTotal,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockRevenueDetailsCubit cubit;

  setUpAll(() {
    registerFallbackValue(StatsPeriod.thirtyDays);
    initializeDateFormatting('fr');
  });

  setUp(() {
    cubit = _MockRevenueDetailsCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  testWidgets('chargement : squelettes, aucun montant', (tester) async {
    whenListen(
      cubit,
      const Stream<RevenueDetailsState>.empty(),
      initialState: const RevenueDetailsState(
        status: RevenueDetailsStatus.loading,
      ),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pump();

    expect(find.textContaining('€'), findsNothing);
    expect(find.byKey(const Key('revenue-group-EUR')), findsNothing);
  });

  testWidgets(
    'chargé : un groupe par devise, sous-totaux et lignes dans leur devise',
    (tester) async {
      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: _details,
        ),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.text('3 livraisons'), findsOneWidget);
      expect(find.byKey(const Key('revenue-group-EUR')), findsOneWidget);
      expect(find.byKey(const Key('revenue-group-XOF')), findsOneWidget);
      expect(find.text('Euro'), findsOneWidget);
      expect(find.text('2 livraisons'), findsOneWidget);
      expect(find.textContaining('810,00'), findsOneWidget);
      // `NumberFormat.currency('fr_SN')` sépare les milliers par une espace fine
      // insécable (U+202F), pas une espace ordinaire : cf. rapport de tâche.
      expect(find.textContaining('120 000'), findsAtLeastNWidgets(1));
      expect(find.text('Paris → Dakar'), findsOneWidget);
      expect(find.textContaining('4 kg · Carte'), findsOneWidget);
      expect(find.textContaining('2,5 kg · Espèces'), findsOneWidget);
      expect(find.textContaining('Mobile money'), findsOneWidget);
      // Sans rappel de conversion tant que la tuile n'en porte pas.
      expect(find.textContaining('total converti'), findsNothing);
    },
  );

  testWidgets(
    "un en-tête de groupe est un bouton dépliable actionnable au lecteur d'écran",
    (tester) async {
      final handle = tester.ensureSemantics();
      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: _details,
        ),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      final header = find.byKey(const Key('revenue-group-EUR'));
      var node = tester.getSemantics(header);
      expect(
        node,
        isSemantics(
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      expect(node.label, contains('Euro'));

      // L'action tap sémantique (celle que déclenche VoiceOver/TalkBack)
      // plie bien le groupe, pas seulement le doigt sur l'InkWell.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      node = tester.getSemantics(header);
      expect(
        node,
        isSemantics(
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('revenue-group-EUR-items'))).height,
        0,
      );
      handle.dispose();
    },
  );

  testWidgets('un en-tête de groupe plie puis déplie ses lignes', (
    tester,
  ) async {
    whenListen(
      cubit,
      const Stream<RevenueDetailsState>.empty(),
      initialState: RevenueDetailsState(
        status: RevenueDetailsStatus.loaded,
        details: _details,
      ),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();
    // Le contenu reste monté (ClipRect/Align à heightFactor) pour glisser :
    // sa hauteur rendue, pas sa présence dans l'arbre, dit s'il est visible.
    expect(
      tester.getSize(find.byKey(const Key('revenue-group-EUR-items'))).height,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const Key('revenue-group-EUR')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('revenue-group-EUR-items'))).height,
      0,
    );
    // L'autre groupe ne bouge pas : pliage indépendant.
    expect(
      tester.getSize(find.byKey(const Key('revenue-group-XOF-items'))).height,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const Key('revenue-group-EUR')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('revenue-group-EUR-items'))).height,
      greaterThan(0),
    );
  });

  testWidgets(
    'devise inconnue : pastille garde le code, « Euro » ne se dédouble pas',
    (tester) async {
      final detailsWithUnknownCurrency = RevenueDetailsModel(
        period: '30d',
        deliveries: 2,
        groups: [
          RevenueGroupModel(
            currency: 'EUR',
            total: 100,
            deliveries: 1,
            items: [
              RevenueItemModel(
                departureCity: 'Paris',
                arrivalCity: 'Dakar',
                date: DateTime(2026, 9),
                rail: RevenueRail.card,
                amount: 100,
              ),
            ],
          ),
          RevenueGroupModel(
            currency: 'ZZZ',
            total: 50,
            deliveries: 1,
            items: [
              RevenueItemModel(
                departureCity: 'Lyon',
                arrivalCity: 'Bamako',
                date: DateTime(2026, 9, 2),
                rail: RevenueRail.cash,
                amount: 50,
              ),
            ],
          ),
        ],
      );

      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: detailsWithUnknownCurrency,
        ),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('revenue-group-ZZZ')), findsOneWidget);
      // Pastille et nom du groupe inconnu portent tous deux le code brut.
      expect(find.textContaining('ZZZ'), findsAtLeastNWidgets(2));
      // Un seul « Euro » : le groupe ZZZ ne s'affiche jamais comme un euro.
      expect(find.text('Euro'), findsOneWidget);
    },
  );

  testWidgets(
    'le rappel de conversion n\'apparaît qu\'avec un total approximatif',
    (tester) async {
      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: _details,
        ),
      );

      await tester.pumpWidget(_harness(cubit, approximateTotal: '≈ 1 419 €'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('« ≈ 1 419 € » est un total converti'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'poids arrondi : 2,04 kg affiche « 2 kg », 2,46 kg affiche « 2,5 kg »',
    (tester) async {
      final weightDetails = RevenueDetailsModel(
        period: '30d',
        deliveries: 2,
        groups: [
          RevenueGroupModel(
            currency: 'EUR',
            total: 200,
            deliveries: 2,
            items: [
              RevenueItemModel(
                departureCity: 'Paris',
                arrivalCity: 'Dakar',
                date: DateTime(2026, 9),
                weightKg: 2.04,
                rail: RevenueRail.card,
                amount: 100,
              ),
              RevenueItemModel(
                departureCity: 'Lyon',
                arrivalCity: 'Abidjan',
                date: DateTime(2026, 9, 2),
                weightKg: 2.46,
                rail: RevenueRail.card,
                amount: 100,
              ),
            ],
          ),
        ],
      );

      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: RevenueDetailsState(
          status: RevenueDetailsStatus.loaded,
          details: weightDetails,
        ),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 kg ·'), findsOneWidget);
      expect(find.textContaining('2,5 kg ·'), findsOneWidget);
    },
  );

  testWidgets('aucune livraison : état vide', (tester) async {
    whenListen(
      cubit,
      const Stream<RevenueDetailsState>.empty(),
      initialState: const RevenueDetailsState(
        status: RevenueDetailsStatus.loaded,
        details: RevenueDetailsModel(period: '30d', deliveries: 0, groups: []),
      ),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Aucune livraison sur la période'), findsOneWidget);
  });

  testWidgets('en anglais, les textes de la feuille sont traduits', (
    tester,
  ) async {
    await initializeDateFormatting('en');
    useEnglish();
    whenListen(
      cubit,
      const Stream<RevenueDetailsState>.empty(),
      initialState: RevenueDetailsState(
        status: RevenueDetailsStatus.loaded,
        details: _details,
      ),
    );

    await tester.pumpWidget(_harness(cubit));
    await tester.pumpAndSettle();

    expect(find.text('3 deliveries'), findsOneWidget);
    expect(find.text('2 deliveries'), findsOneWidget);
    expect(find.textContaining('4 kg · Card'), findsOneWidget);
    // `_kg` garde une virgule décimale quelle que soit la langue (même bug
    // que `formatWeightKg`, confié au lot E des paiements par la Ruling R30
    // de progress.md) : non corrigé ici, hors périmètre de cette tâche.
    expect(find.textContaining('2,5 kg · Cash'), findsOneWidget);
  });

  testWidgets(
    'erreur : « Détail indisponible » et « Réessayer » recharge la période',
    (tester) async {
      whenListen(
        cubit,
        const Stream<RevenueDetailsState>.empty(),
        initialState: const RevenueDetailsState(
          status: RevenueDetailsStatus.error,
        ),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Détail indisponible'), findsOneWidget);
      await tester.tap(find.byKey(const Key('revenue-retry')));
      await tester.pump();

      verify(() => cubit.load(StatsPeriod.thirtyDays)).called(1);
    },
  );
}
