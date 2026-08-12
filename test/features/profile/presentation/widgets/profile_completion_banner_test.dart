import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _empty = UserModel(
  id: 'u1',
  roles: [],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

Widget _app(UserModel user, {VoidCallback? onTap}) => MaterialApp(
  home: Scaffold(
    body: ProfileCompletionBanner(user: user, onTap: onTap ?? () {}),
  ),
);

/// Couleur de percent-text/icônes affichée pour un [user] donné — lit
/// directement le thème résolu au lieu de dupliquer la logique de palier
/// (`profileCompletionTierColor`) dans le test.
Color _renderedTierColor(WidgetTester tester) {
  final context = tester.element(find.byType(ProfileCompletionBanner));
  final cs = Theme.of(context).colorScheme;
  final pctText = tester.widget<Text>(find.textContaining('% complété'));
  final color = pctText.style!.color!;
  // Egalité de couleur exacte : le tier retourne toujours l'une de ces 3
  // constantes du thème, jamais une teinte interpolée.
  if (color == cs.error) return cs.error;
  if (color == cs.warning) return cs.warning;
  return cs.info;
}

void main() {
  // Le SMS OTP backend confirmé est l'état par défaut de ces tests (8
  // champs, téléphone inclus) : le groupe dédié plus bas couvre le cas
  // désactivé (7 champs) séparément.
  setUp(() => setSmsAuthEnabled(true));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets('0/8 champs → 0 %, les 8 chips manquants affichés', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_empty));
    await tester.pump();

    expect(find.text('0% complété · Compléter maintenant'), findsOneWidget);
    for (final label in const [
      'Photo',
      'Prénom',
      'Nom',
      'Email',
      'Téléphone',
      'Date de naissance',
      'Ville',
      'À propos',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('8/8 champs → 100 %, aucun chip manquant', (tester) async {
    final user = _empty.copyWith(
      avatarUrl: 'https://cdn.example.com/avatar.jpg',
      firstName: 'Amadou',
      lastName: 'Diallo',
      email: 'amadou@example.com',
      phoneNumber: '+221701234567',
      city: 'Dakar',
      bio: 'Voyageur régulier.',
      birthDate: DateTime(1995, 3, 12),
    );
    await tester.pumpWidget(_app(user));
    await tester.pump();

    expect(find.text('100% complété · Compléter maintenant'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('À propos'), findsNothing);
  });

  testWidgets('tap déclenche le callback onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(_empty, onTap: () => tapped = true));
    await tester.tap(find.byType(ProfileCompletionBanner));
    await tester.pump();

    expect(tapped, isTrue);
  });

  group('palier de couleur selon le pourcentage', () {
    testWidgets('0/8 (0 %, < 1/3) → rouge (cs.error)', (tester) async {
      await tester.pumpWidget(_app(_empty));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(_renderedTierColor(tester), cs.error);
    });

    testWidgets('3/8 (37,5 %, entre 1/3 et 2/3) → orange (cs.warning)', (
      tester,
    ) async {
      final user = _empty.copyWith(
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@example.com',
      );
      await tester.pumpWidget(_app(user));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(find.text('38% complété · Compléter maintenant'), findsOneWidget);
      expect(_renderedTierColor(tester), cs.warning);
    });

    testWidgets('7/8 (87,5 %, >= 2/3) → bleu (cs.info)', (tester) async {
      final user = _empty.copyWith(
        avatarUrl: 'https://cdn.example.com/avatar.jpg',
        firstName: 'Amadou',
        lastName: 'Diallo',
        email: 'amadou@example.com',
        phoneNumber: '+221701234567',
        city: 'Dakar',
        bio: 'Voyageur régulier.',
      );
      await tester.pumpWidget(_app(user));
      await tester.pump();

      final context = tester.element(find.byType(ProfileCompletionBanner));
      final cs = Theme.of(context).colorScheme;
      expect(find.text('88% complété · Compléter maintenant'), findsOneWidget);
      expect(_renderedTierColor(tester), cs.info);
    });
  });

  group('SMS OTP backend non confirmé (kSmsAuthEnabledDefault)', () {
    setUp(() => setSmsAuthEnabled(false));

    testWidgets(
      '0/7 champs → 0 %, la croix Téléphone est absente (rien à réclamer)',
      (tester) async {
        await tester.pumpWidget(_app(_empty));
        await tester.pump();

        expect(find.text('0% complété · Compléter maintenant'), findsOneWidget);
        expect(find.text('Téléphone'), findsNothing);
        for (final label in const [
          'Photo',
          'Prénom',
          'Nom',
          'Email',
          'Date de naissance',
          'Ville',
          'À propos',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
      },
    );

    testWidgets(
      '7/7 champs (sans téléphone) → 100 %, la bannière disparaît côté '
      'ProfileScreen (isProfileComplete atteint sans numéro)',
      (tester) async {
        final user = _empty.copyWith(
          avatarUrl: 'https://cdn.example.com/avatar.jpg',
          firstName: 'Amadou',
          lastName: 'Diallo',
          email: 'amadou@example.com',
          city: 'Dakar',
          bio: 'Voyageur régulier.',
          birthDate: DateTime(1995, 3, 12),
        );
        await tester.pumpWidget(_app(user));
        await tester.pump();

        expect(user.phoneNumber, isNull);
        expect(user.isProfileComplete(countPhone: false), isTrue);
        expect(
          find.text('100% complété · Compléter maintenant'),
          findsOneWidget,
        );
      },
    );
  });
}
