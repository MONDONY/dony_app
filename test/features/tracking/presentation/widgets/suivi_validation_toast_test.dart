import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validation_toast.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCubit extends MockCubit<SuiviValidationState>
    implements SuiviValidationCubit {}

PendingValidation _deposit({String? photoPath = '/tmp/depot.jpg'}) =>
    PendingValidation(
      id: 1,
      bidId: 'bid-1',
      step: 'DEPART',
      parcelLabel: 'Madou',
      method: ScanMethod.qr,
      deadline: DateTime(2026, 11, 15, 12),
      photoPath: photoPath,
      deposit: true,
    );

void main() {
  late _MockCubit cubit;

  setUp(() {
    cubit = _MockCubit();
    when(() => cubit.delay).thenReturn(const Duration(seconds: 5));
  });

  Future<void> pump(
    WidgetTester tester,
    SuiviValidationState state, {
    Locale locale = AppL10n.fr,
  }) async {
    whenListen(
      cubit,
      const Stream<SuiviValidationState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SuiviValidationCubit>.value(
            value: cubit,
            child: const SuiviPendingValidations(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Recette bateau : une fois le délai d'annulation écoulé, l'envoi de la
  // photo de dépôt ne montrait rien.
  testWidgets('envoi en cours : bandeau avec indicateur, sans « Annuler »', (
    tester,
  ) async {
    await pump(tester, SuiviValidationState(sending: [_deposit()]));

    expect(find.byKey(const Key('suivi-sending-bid-1')), findsOneWidget);
    expect(find.text('Envoi de la photo de Madou…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('suivi-undo-1')), findsNothing);
  });

  testWidgets('sans photo, le bandeau parle de l\'étape (anglais)', (
    tester,
  ) async {
    await pump(
      tester,
      SuiviValidationState(sending: [_deposit(photoPath: null)]),
      locale: AppL10n.en,
    );

    expect(find.text('Sending the step for Madou…'), findsOneWidget);
  });

  testWidgets('rien en attente ni en envoi : aucun bandeau', (tester) async {
    await pump(tester, const SuiviValidationState());

    expect(find.byKey(const Key('suivi-sending-bid-1')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
