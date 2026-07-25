import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class MockPrivacySettingsBloc
    extends MockBloc<PrivacySettingsEvent, PrivacySettingsState>
    implements PrivacySettingsBloc {}

class _MockHiveService extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

/// Minimal ValueListenable<Box> that does nothing — satisfies
/// `_AnalyticsConsentCard` which calls `ValueListenableBuilder` on it.
class _StubBoxListenable extends ValueNotifier<Box<dynamic>> {
  _StubBoxListenable(super.value);
}

Widget _wrap({
  required MockPrivacySettingsBloc mockBloc,
  PrivacySettingsState? state,
}) {
  final effectiveState =
      state ?? const PrivacySettingsLoaded(contactKycOnly: false);
  when(() => mockBloc.state).thenReturn(effectiveState);

  return MaterialApp(
    home: BlocProvider<PrivacySettingsBloc>.value(
      value: mockBloc,
      child: const PrivacySettingsScreen(),
    ),
  );
}

void main() {
  group('PrivacySettingsScreen', () {
    late MockPrivacySettingsBloc mockBloc;

    setUpAll(() {
      // Register HiveService and AnalyticsService in GetIt for _AnalyticsConsentCard
      if (!getIt.isRegistered<HiveService>()) {
        final hive = _MockHiveService();
        final box = _MockBox();
        final stubListenable = _StubBoxListenable(box);
        when(() => hive.userPrefs).thenReturn(box);
        when(() => hive.listenUserPrefs(keys: any(named: 'keys')))
            .thenReturn(stubListenable);
        when(() => box.get(HiveService.kAnalyticsConsent)).thenReturn(false);
        getIt.registerSingleton<HiveService>(hive);
        final backend = MockAnalyticsBackend();
        final analytics = makeDisabledAnalytics(backend);
        analytics.onConfigured();
        getIt.registerSingleton<AnalyticsService>(analytics);
      }
    });

    tearDownAll(() {
      GetIt.instance.reset();
    });

    setUp(() {
      mockBloc = MockPrivacySettingsBloc();
    });

    testWidgets('affiche le titre "Confidentialité"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Confidentialité'), findsOneWidget);
    });

    testWidgets('affiche le bandeau de protection du numéro', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Ton numéro est protégé'), findsOneWidget);
    });

    testWidgets('affiche la section QUI PEUT ME CONTACTER', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('QUI PEUT ME CONTACTER'), findsOneWidget);
    });

    testWidgets('affiche la tuile "Profils vérifiés uniquement"',
        (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Profils vérifiés uniquement'), findsOneWidget);
    });

    testWidgets('affiche la section BLOCAGE', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('BLOCAGE'), findsOneWidget);
    });

    testWidgets('affiche la tuile "Utilisateurs bloqués"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Utilisateurs bloqués'), findsOneWidget);
    });

    testWidgets('Switch est off quand contactKycOnly == false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: false),
        ),
      );
      await tester.pumpAndSettle();

      // First Switch is the KYC toggle; second is the analytics consent toggle.
      expect(find.byType(Switch), findsWidgets);
      final sw = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(sw.value, isFalse);
    });

    testWidgets('Switch est on quand contactKycOnly == true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: true),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(sw.value, isTrue);
    });

    testWidgets('Switch désactivé pendant PrivacySettingsLoading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoading(),
        ),
      );
      await tester.pumpAndSettle();

      final sw = tester.widgetList<Switch>(find.byType(Switch)).first;
      expect(sw.onChanged, isNull);
    });

    testWidgets(
        'tapper le Switch envoie ContactKycOnlyToggled(true) quand valeur false',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the first Switch (KYC toggle)
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const ContactKycOnlyToggled(true))).called(1);
    });

    // ── Masquage du numéro ───────────────────────────────────────────────────

    testWidgets('affiche la tuile "Masquer mon numéro"', (tester) async {
      await tester.pumpWidget(_wrap(mockBloc: mockBloc));
      await tester.pumpAndSettle();

      expect(find.text('Masquer mon numéro'), findsOneWidget);
    });

    testWidgets('le Switch de masquage reflète hidePhoneNumber', (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(
              contactKycOnly: false, hidePhoneNumber: true),
        ),
      );
      await tester.pumpAndSettle();

      // Ordre des interrupteurs : KYC, masquage du numéro, puis analytics.
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[1].value, isTrue);
    });

    testWidgets('tapper le Switch de masquage envoie HidePhoneNumberToggled(true)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(contactKycOnly: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      verify(() => mockBloc.add(const HidePhoneNumberToggled(true))).called(1);
    });

    testWidgets('le bandeau annonce le masquage quand la préférence est active',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          mockBloc: mockBloc,
          state: const PrivacySettingsLoaded(
              contactKycOnly: false, hidePhoneNumber: true),
        ),
      );
      await tester.pumpAndSettle();

      // Le bandeau ne doit plus promettre un échange de numéros à quelqu'un qui
      // vient justement de le refuser.
      expect(find.text('Ton numéro reste masqué'), findsOneWidget);
      expect(find.text('Ton numéro est protégé'), findsNothing);
    });

    testWidgets('le Switch de masquage est désactivé pendant le chargement',
        (tester) async {
      await tester.pumpWidget(
        _wrap(mockBloc: mockBloc, state: const PrivacySettingsLoading()),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[1].onChanged, isNull);
    });
  });
}
