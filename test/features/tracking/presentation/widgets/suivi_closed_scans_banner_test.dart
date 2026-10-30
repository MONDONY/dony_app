import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_closed_scans_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOfflineSyncService extends Mock implements OfflineSyncService {}

void main() {
  late _MockOfflineSyncService sync;
  late ValueNotifier<int> changes;
  late List<String> closed;

  setUp(() {
    sync = _MockOfflineSyncService();
    changes = ValueNotifier(0);
    closed = ['bid-1'];
    when(() => sync.closedScanChanges).thenReturn(changes);
    when(() => sync.closedScansFor(any())).thenAnswer((_) => List.of(closed));
    when(() => sync.dismissClosedScan(any())).thenAnswer((invocation) async {
      closed.remove(invocation.positionalArguments.single);
      changes.value++;
    });
  });

  tearDown(() => changes.dispose());

  Future<void> pump(WidgetTester tester, {Locale locale = AppL10n.fr}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SuiviClosedScansBanner(bidIds: const {'bid-1'}, sync: sync),
          ),
        ),
      );

  testWidgets('prévient que le colis a été clos avant la synchronisation', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text(
        'Ce colis a été clos avant la synchronisation de votre scan. '
        "L'équipe Yadony a été prévenue.",
      ),
      findsOneWidget,
    );
    verify(() => sync.closedScansFor({'bid-1'})).called(1);
  });

  testWidgets('en anglais', (tester) async {
    await pump(tester, locale: AppL10n.en);

    expect(
      find.text(
        'This parcel was closed before your scan synced. '
        'The Yadony team has been notified.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('le bouton de fermeture retire le message', (tester) async {
    await pump(tester);

    await tester.tap(
      find.byTooltip('Fermer le message sur le scan non synchronisé'),
    );
    await tester.pump();

    verify(() => sync.dismissClosedScan('bid-1')).called(1);
    expect(find.byKey(const Key('suivi-closed-scan-bid-1')), findsNothing);
  });

  testWidgets('rien quand aucun scan n\'a été refusé', (tester) async {
    closed = [];
    await pump(tester);

    expect(find.byType(IconButton), findsNothing);
  });
}
