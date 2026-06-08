import 'package:dony/features/home/presentation/home_map_focus.dart';
import 'package:dony/features/home/presentation/widgets/home_focus_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche les 3 segments et notifie au tap', (tester) async {
    HomeMapFocus? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeFocusFilter(
            focus: HomeMapFocus.all,
            onChanged: (f) => picked = f,
          ),
        ),
      ),
    );

    expect(find.text('Tout'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
    expect(find.text('Trajets'), findsOneWidget);

    await tester.tap(find.text('Colis'));
    await tester.pump();
    expect(picked, HomeMapFocus.parcels);
  });

  testWidgets('tap sur Trajets notifie trips', (tester) async {
    HomeMapFocus? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeFocusFilter(
            focus: HomeMapFocus.all,
            onChanged: (f) => picked = f,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trajets'));
    await tester.pump();
    expect(picked, HomeMapFocus.trips);
  });

  testWidgets('tap sur Tout notifie all', (tester) async {
    HomeMapFocus? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeFocusFilter(
            focus: HomeMapFocus.parcels,
            onChanged: (f) => picked = f,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tout'));
    await tester.pump();
    expect(picked, HomeMapFocus.all);
  });
}
