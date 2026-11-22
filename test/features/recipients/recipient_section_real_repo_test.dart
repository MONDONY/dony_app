import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/recipients/bloc/designate_yadony_user_cubit.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/datasources/recipient_invitation_datasource.dart';
import 'package:dony/features/recipients/data/models/recipient_invitation.dart';
import 'package:dony/features/recipients/data/repositories/recipient_invitation_repository.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDatasource extends Mock implements RecipientInvitationDatasource {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockBloc extends Mock implements RecipientBloc {}

void main() {
  testWidgets('feuille refermée après un verdict « indisponible » : le choix '
      'Yadony disparaît (vrai dépôt)', (tester) async {
    final datasource = _MockDatasource();
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(() => datasource.lookupUsername(any())).thenAnswer(
      (_) async => const UsernameLookup(username: 'awa.diallo', initial: 'A'),
    );
    final repo = RecipientInvitationRepository(datasource);
    getIt
      ..registerSingleton<RecipientInvitationRepository>(repo)
      ..registerFactory<DesignateYadonyUserCubit>(
        () => DesignateYadonyUserCubit(repo, analytics),
      );
    addTearDown(getIt.reset);

    final controller = RecipientSectionController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    addTearDown(() {
      controller.dispose();
      nameCtrl.dispose();
      phoneCtrl.dispose();
    });
    final bloc = _MockBloc();
    when(() => bloc.state).thenReturn(const RecipientState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.close()).thenAnswer((_) async {});

    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipientSection(
              controller: controller,
              nameCtrl: nameCtrl,
              phoneCtrl: phoneCtrl,
              allowYadonyUser: true,
              createBloc: () => bloc,
              children: const [Text('champs manuels')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final choice = find.byKey(const Key('recipient-section-yadony-user'));
    expect(choice, findsOneWidget);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('designate-yadony-user-field')),
      'awa.diallo',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byKey(const Key('designate-yadony-user-field'))),
    ).pop();
    await tester.pumpAndSettle();

    expect(repo.parcelDesignationOffered, isFalse);
    expect(choice, findsNothing);
  });
}
