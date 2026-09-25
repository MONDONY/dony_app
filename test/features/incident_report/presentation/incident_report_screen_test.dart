import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/incident_report/bloc/incident_photos_cubit.dart';
import 'package:dony/features/incident_report/bloc/incident_report_cubit.dart';
import 'package:dony/features/incident_report/data/report_reasons.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/incident_report/presentation/report_reason_labels.dart';
import 'package:dony/features/incident_report/presentation/screens/incident_report_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements IncidentReportRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(IncidentTargetType.app);
  });

  late _MockRepo repo;
  late IncidentReportCubit reportCubit;
  late IncidentPhotosCubit photosCubit;

  setUp(() {
    repo = _MockRepo();
    final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
    reportCubit = IncidentReportCubit(repo, analytics);
    photosCubit = IncidentPhotosCubit(repo, analytics);
  });

  tearDown(() async {
    await reportCubit.close();
    await photosCubit.close();
  });

  Widget wrap() => MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: reportCubit),
          BlocProvider.value(value: photosCubit),
        ],
        child: const IncidentReportScreen(),
      ),
    ),
  );

  testWidgets(
    'affiche motifs, description, photos et bouton désactivé sans motif',
    (tester) async {
      await tester.pumpWidget(wrap());

      expect(find.text('Signaler un problème'), findsOneWidget);
      for (final reason in reportReasonsFor(IncidentTargetType.app)) {
        expect(find.text(reason.label(AppL10n.current)), findsOneWidget);
      }
      expect(find.text('Description'), findsOneWidget);

      final button = tester.widget<DonyButton>(find.byType(DonyButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('sélection d\'un motif active le bouton', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Bug de l\'application'));
    await tester.pump();

    final button = tester.widget<DonyButton>(find.byType(DonyButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submit envoie motif + description et affiche le succès', (
    tester,
  ) async {
    when(
      () => repo.submit(
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
      ),
    ).thenAnswer((_) async => 'r-9');

    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Problème de paiement'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Double débit');
    await tester.ensureVisible(find.byType(DonyButton));
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();

    verify(
      () => repo.submit(
        targetType: IncidentTargetType.app,
        reason: 'PAYMENT_ISSUE',
        description: 'Double débit',
      ),
    ).called(1);
  });

  testWidgets('erreur du cubit affichée en snackbar', (tester) async {
    when(
      () => repo.submit(
        targetType: any(named: 'targetType'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        description: any(named: 'description'),
        photoKeys: any(named: 'photoKeys'),
      ),
    ).thenThrow(Exception('boom'));

    await tester.pumpWidget(wrap());
    await tester.tap(find.text('Autre'));
    await tester.pump();
    await tester.ensureVisible(find.byType(DonyButton));
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Impossible d\'envoyer'), findsOneWidget);
  });

  testWidgets(
    'erreur typée (AppException) : passe par ErrorPresenter, pas le message brut',
    (tester) async {
      when(
        () => repo.submit(
          targetType: any(named: 'targetType'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          description: any(named: 'description'),
          photoKeys: any(named: 'photoKeys'),
        ),
      ).thenThrow(const ValidationException('Le motif est obligatoire'));

      await tester.pumpWidget(wrap());
      await tester.tap(find.text('Autre'));
      await tester.pump();
      await tester.ensureVisible(find.byType(DonyButton));
      await tester.tap(find.text('Envoyer le signalement'));
      await tester.pumpAndSettle();

      // Le message serveur brut n'est plus affiché : ErrorPresenter résout
      // via ErrorCatalog un message générique de validation.
      expect(find.text('Le motif est obligatoire'), findsNothing);
      expect(
        find.text('Vérifie les informations saisies puis réessaie.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('anglais : titre, motif et bouton traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap());

    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.text('App bug'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Send report'), findsOneWidget);
  });
}
