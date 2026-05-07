import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeTrackingEvent());
  });

  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('affiche le champ de recherche et le bouton', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => TrackingSearchBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro de suivi'), findsOneWidget);
    expect(find.text('Rechercher'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('envoie TrackingSearchRequested avec le numéro normalisé',
      (tester) async {
    final trackingBloc = _MockTrackingBloc();
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(() => trackingBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => trackingBloc.add(any())).thenReturn(null);

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: trackingBloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => TrackingSearchBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    await tester.enterText(textField, '481234');
    await tester.tap(find.text('Rechercher'));
    await tester.pumpAndSettle();

    verify(() => trackingBloc.add(any(
        that: isA<TrackingSearchRequested>().having(
          (e) => e.number,
          'number',
          'DON-481234',
        )))).called(1);
  });

  testWidgets('accepte le numéro avec ou sans préfixe DON-',
      (tester) async {
    final trackingBloc = _MockTrackingBloc();
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(() => trackingBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => trackingBloc.add(any())).thenReturn(null);

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: trackingBloc,
        child: Builder(builder: (ctx) => TextButton(
          onPressed: () => TrackingSearchBottomSheet.show(ctx),
          child: const Text('Ouvrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'DON-481234');
    await tester.tap(find.text('Rechercher'));
    await tester.pumpAndSettle();

    verify(() => trackingBloc.add(any(
        that: isA<TrackingSearchRequested>().having(
          (e) => e.number,
          'number',
          'DON-481234',
        )))).called(1);
  });

}
