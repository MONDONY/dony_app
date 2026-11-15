import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_lost_photos_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOfflineSyncService extends Mock implements OfflineSyncService {}

const _depart = LostTrackingPhoto(bidId: 'bid-1', eventType: 'DEPART');

void main() {
  setUpAll(() {
    registerFallbackValue(_depart);
    registerFallbackValue(
      const DepositPhotoRetake(key: 0, bidId: '', eventType: ''),
    );
  });

  late _MockOfflineSyncService sync;
  late ValueNotifier<int> changes;
  late List<LostTrackingPhoto> lost;
  late List<DepositPhotoRetake> retakes;

  setUp(() {
    sync = _MockOfflineSyncService();
    changes = ValueNotifier(0);
    lost = [_depart];
    retakes = [];
    when(() => sync.queueChanges).thenReturn(changes);
    when(
      () => sync.depositRetakeFor(any()),
    ).thenAnswer((_) => List.of(retakes));
    when(() => sync.dismissDepositRetake(any())).thenAnswer((_) async {});
    when(() => sync.lostPhotoChanges).thenReturn(changes);
    when(() => sync.lostPhotosFor(any())).thenAnswer((_) => List.of(lost));
    when(() => sync.dismissLostPhoto(any())).thenAnswer((invocation) async {
      lost.remove(invocation.positionalArguments.single);
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
            body: SuiviLostPhotosBanner(bidIds: const {'bid-1'}, sync: sync),
          ),
        ),
      );

  testWidgets('prévient que la photo n\'est plus sur le téléphone', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text(
        'La photo de l\'étape « Récupération » n\'est plus disponible sur ce '
        'téléphone : l\'étape a été enregistrée sans photo.',
      ),
      findsOneWidget,
    );
    verify(() => sync.lostPhotosFor({'bid-1'})).called(1);
  });

  testWidgets('le bouton de fermeture retire le message', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Fermer le message sur la photo perdue'));
    await tester.pump();

    verify(() => sync.dismissLostPhoto(_depart)).called(1);
    expect(
      find.byKey(const Key('suivi-lost-photo-bid-1-DEPART')),
      findsNothing,
    );
  });

  testWidgets('rien quand aucune photo n\'est perdue', (tester) async {
    lost = [];
    await pump(tester);

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('dépôt resté en file faute de photo : « reprendre la photo », '
      'en français et en anglais', (tester) async {
    lost = [];
    retakes = [
      const DepositPhotoRetake(key: 3, bidId: 'bid-1', eventType: 'DEPART'),
    ];
    await pump(tester);
    expect(find.textContaining('Reprenez la photo du dépôt'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer le message sur la photo du dépôt'));
    verify(() => sync.dismissDepositRetake(retakes.single)).called(1);

    await pump(tester, locale: AppL10n.en);
    await tester.pumpAndSettle();
    expect(find.textContaining('Retake the deposit photo'), findsOneWidget);
  });
}
