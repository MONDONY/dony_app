import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

void main() {
  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  tearDown(() {
    bloc.close();
  });

  testWidgets('affiche la liste des scans en attente', (tester) async {
    final items = [
      OfflineScanItem(
        donNumber: 'DON-4821',
        eventType: 'Prise en charge',
        timestamp: DateTime.now(),
      ),
      OfflineScanItem(
        donNumber: 'DON-4819',
        eventType: 'En transit',
        timestamp: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => OfflineQueueBottomSheet.show(ctx, items: items),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('DON-4821'), findsOneWidget);
    expect(find.text('DON-4819'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
  });

  testWidgets('affiche le bon titre avec le nombre de scans', (tester) async {
    final items = [
      OfflineScanItem(
        donNumber: 'DON-0001',
        eventType: 'Collecte',
        timestamp: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => OfflineQueueBottomSheet.show(ctx, items: items),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('1 scan hors-ligne'), findsOneWidget);
    expect(find.text('En attente de synchronisation'), findsOneWidget);
  });

  testWidgets('affiche le pluriel correct pour plusieurs scans', (tester) async {
    final items = [
      OfflineScanItem(
        donNumber: 'DON-0001',
        eventType: 'Collecte',
        timestamp: DateTime.now(),
      ),
      OfflineScanItem(
        donNumber: 'DON-0002',
        eventType: 'Livraison',
        timestamp: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<TrackingBloc>.value(
        value: bloc,
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => OfflineQueueBottomSheet.show(ctx, items: items),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('2 scans hors-ligne'), findsOneWidget);
  });
}
