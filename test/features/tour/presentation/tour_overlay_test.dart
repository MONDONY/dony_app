import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/tour/bloc/tour_cubit.dart';
import 'package:dony/features/tour/data/tour_progress_store.dart';
import 'package:dony/features/tour/presentation/tour_anchors.dart';
import 'package:dony/features/tour/presentation/tour_overlay.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _delay = Duration(milliseconds: 200);

void main() {
  late TourCubit cubit;
  late AssistantBubbleBlockers blockers;
  final stored = <String, dynamic>{};

  setUp(() {
    stored.clear();
    final box = _MockBox();
    when(
      () => box.get(any()),
    ).thenAnswer((inv) => stored[inv.positionalArguments.first as String]);
    when(() => box.put(any(), any())).thenAnswer((inv) async {
      stored[inv.positionalArguments[0] as String] = inv.positionalArguments[1];
    });
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = TourCubit(TourProgressStore(box), analytics)..sync('uid-1');
    blockers = AssistantBubbleBlockers();
  });

  tearDown(() => cubit.close());

  Future<void> pump(
    WidgetTester tester, {
    int tabIndex = 0,
    bool signedIn = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: BlocProvider<TourCubit>.value(
          value: cubit,
          child: Scaffold(
            body: Stack(
              children: [
                const Align(
                  alignment: Alignment.topRight,
                  child: TourAnchor(
                    step: TourStep.plus,
                    child: SizedBox(width: 48, height: 48),
                  ),
                ),
                const Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: TourAnchor(
                      step: TourStep.modeTrips,
                      child: SizedBox(width: 150, height: 44),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: TourAnchor(
                      step: TourStep.modeParcels,
                      child: SizedBox(width: 150, height: 44),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: TourAnchor(
                    step: TourStep.activities,
                    child: SizedBox(width: 72, height: 60),
                  ),
                ),
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 140),
                    child: TourAnchor(
                      step: TourStep.urgent,
                      child: SizedBox(width: 80, height: 32),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.topLeft,
                  child: TourAnchor(
                    step: TourStep.favorites,
                    child: SizedBox(width: 48, height: 48),
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 200),
                    child: TourAnchor(
                      step: TourStep.support,
                      child: SizedBox(width: 72, height: 60),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: TourOverlay(
                    tabIndex: tabIndex,
                    blockers: blockers,
                    hasRealSession: () => signedIn,
                    armDelay: _delay,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('rien avant le délai, puis la bulle du bouton +', (tester) async {
    await pump(tester);
    expect(find.text('Le bouton +'), findsNothing);

    await tester.pump(_delay + const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.text('Le bouton +'), findsOneWidget);
    expect(find.text('1 sur 8'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Passer le tour'), findsOneWidget);
  });

  testWidgets('« Suivant » enchaîne les quatre bulles puis disparaît', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(_delay + const Duration(milliseconds: 50));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 sur 8'), findsOneWidget);
    expect(find.text('J\'envoie un colis'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Je voyage'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Activités'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pump();
    expect(cubit.state.step, isNull);
    expect(find.text('4 sur 8'), findsNothing);
    expect(stored['${TourProgressStore.seenPrefix}uid-1'], 15);
  });

  testWidgets('« Passer le tour » ferme tout', (tester) async {
    await pump(tester);
    await tester.pump(_delay + const Duration(milliseconds: 50));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tour-skip')));
    await tester.pump();
    expect(cubit.state.step, isNull);
    expect(find.text('Le bouton +'), findsNothing);
  });

  testWidgets(
    'une feuille ouverte masque la bulle, qui revient après le délai',
    (tester) async {
      await pump(tester);
      await tester.pump(_delay + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Le bouton +'), findsOneWidget);

      blockers.acquire();
      await tester.pump();
      await tester.pump();
      expect(find.text('Le bouton +'), findsNothing);

      blockers.release();
      await tester.pump();
      expect(find.text('Le bouton +'), findsNothing);
      await tester.pump(_delay + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Le bouton +'), findsOneWidget);
    },
  );

  testWidgets('hors de l\'onglet Rechercher, rien n\'est montré', (
    tester,
  ) async {
    await pump(tester, tabIndex: 1);
    await tester.pump(_delay * 2);
    await tester.pump();
    expect(find.text('Le bouton +'), findsNothing);
  });

  testWidgets('un invité ne voit pas le tour', (tester) async {
    await pump(tester, signedIn: false);
    await tester.pump(_delay * 2);
    await tester.pump();
    expect(find.text('Le bouton +'), findsNothing);
  });

  testWidgets('la bulle de la barre d\'onglets se pose au-dessus du bouton', (
    tester,
  ) async {
    stored['${TourProgressStore.seenPrefix}uid-1'] = 7;
    cubit.sync('uid-2');
    cubit.sync('uid-1');
    await pump(tester);
    await tester.pump(_delay + const Duration(milliseconds: 50));
    await tester.pump();

    final bubble = tester.getRect(find.text('Activités'));
    final target = tester.getRect(find.byType(TourAnchor).last);
    expect(bubble.bottom, lessThan(target.top));
  });

  group('bulles au moment utile', () {
    int bit(TourStep s) => 1 << s.index;
    final tourMask = TourStep.sequential.map(bit).reduce((a, b) => a | b);

    void tourFini() {
      stored['${TourProgressStore.seenPrefix}uid-1'] = tourMask;
      stored['${TourProgressStore.doneAtPrefix}uid-1'] =
          DateTime.now().millisecondsSinceEpoch;
      cubit.sync('uid-2');
      cubit.sync('uid-1');
    }

    testWidgets('le filtre touché fait venir la bulle Urgent', (tester) async {
      tourFini();
      await pump(tester);
      await tester.pump(_delay * 2);
      expect(find.text('Urgent'), findsNothing);

      cubit.trigger(TourStep.urgent);
      await tester.pump();
      await tester.pump();
      await tester.pump(_delay + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('5 sur 8'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);
      expect(find.byKey(const Key('tour-skip')), findsNothing);
    });

    testWidgets('« Compris » ferme la bulle pour de bon', (tester) async {
      tourFini();
      await pump(tester);
      cubit.trigger(TourStep.favorites);
      await tester.pump();
      await tester.pump();
      await tester.pump(_delay + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Mes favoris'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pump();
      expect(find.text('Mes favoris'), findsNothing);
      expect(
        stored['${TourProgressStore.seenPrefix}uid-1'],
        tourMask | bit(TourStep.favorites),
      );
    });

    testWidgets('le support se pose au-dessus de l\'onglet Messages', (
      tester,
    ) async {
      stored['${TourProgressStore.seenPrefix}uid-1'] = tourMask;
      stored['${TourProgressStore.doneAtPrefix}uid-1'] = DateTime.now()
          .subtract(const Duration(days: 4))
          .millisecondsSinceEpoch;
      cubit.sync('uid-2');
      cubit.sync('uid-1');
      await pump(tester);
      await tester.pump(_delay + const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text('Besoin d\'aide ?'), findsOneWidget);
      final bubble = tester.getRect(find.text('Besoin d\'aide ?'));
      final target = tester.getRect(find.byType(TourAnchor).last);
      expect(bubble.bottom, lessThan(target.top));
    });
  });
}
