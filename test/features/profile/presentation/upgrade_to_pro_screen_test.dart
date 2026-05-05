import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:dony/features/profile/presentation/screens/upgrade_to_pro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

Widget _wrap() {
  return MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const UpgradeToProScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Scaffold(body: Text('Profile')),
        ),
      ],
    ),
  );
}

/// Duration long enough to let all flutter_animate delays complete.
/// The screen has delays up to 260ms.
const _kSettle = Duration(milliseconds: 600);

/// Finds the submit button (works even when animations cause duplicates).
Finder get _submitBtn => find.text('Activer le compte PRO').last;

void main() {
  late MockProfileRepository mockRepo;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    mockRepo = MockProfileRepository();
    // Reset getIt and register the mock
    if (getIt.isRegistered<ProfileRepository>()) {
      getIt.unregister<ProfileRepository>();
    }
    getIt.registerLazySingleton<ProfileRepository>(() => mockRepo);
  });

  tearDown(() {
    if (getIt.isRegistered<ProfileRepository>()) {
      getIt.unregister<ProfileRepository>();
    }
  });

  group('UpgradeToProScreen', () {
    testWidgets('renders form with companyName and siret fields',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      expect(find.text('Compte PRO'), findsOneWidget);
      expect(find.text('Passe en PRO'), findsOneWidget);
      expect(find.text('Activer le compte PRO'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text("Le nom de l'entreprise est requis"),
        findsOneWidget,
      );
      expect(find.text('Le numéro SIRET est requis'), findsOneWidget);
    });

    testWidgets('shows SIRET validation error for wrong length',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      // Fill company name but wrong SIRET
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '123', // wrong length
      );
      // Let any animation triggered by state changes settle
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Le SIRET doit contenir exactement 14 chiffres'),
        findsOneWidget,
      );
    });

    testWidgets('shows confirmation dialog on valid form submission',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirmer le passage en PRO'), findsOneWidget);
    });

    testWidgets('calls upgradeToPro and shows success snackbar on confirm',
        (tester) async {
      when(() => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Tap Confirmer in dialog
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.upgradeToPro(
            companyName: 'Ma Société SAS',
            siret: '12345678901234',
          )).called(1);

      expect(find.text('Compte PRO activé'), findsOneWidget);
    });

    testWidgets('does NOT call upgradeToPro when dialog is cancelled',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(_kSettle);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Ma Société SAS',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '12345678901234',
      );
      await tester.pump(_kSettle);

      await tester.ensureVisible(_submitBtn);
      await tester.tap(_submitBtn);
      await tester.pumpAndSettle();

      // Tap Annuler
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepo.upgradeToPro(
            companyName: any(named: 'companyName'),
            siret: any(named: 'siret'),
          ));
    });
  });
}
