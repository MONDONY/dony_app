import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

class _MockImagePicker extends Mock implements ImagePicker {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

final _senderUser = UserModel(
  id: 'user-sender',
  avatarUrl: 'https://cdn.example.com/avatar.jpg',
  firstName: 'Ibrahima',
  lastName: 'Diallo',
  email: 'ibra@test.com',
  phoneNumber: '+221701234567',
  city: 'Paris',
  bio: 'Expéditeur depuis 2022.',
  birthDate: DateTime(1990, 6, 15),
  roles: const ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

const _travelerUser = UserModel(
  id: 'user-traveler',
  firstName: 'Moussa',
  lastName: 'Koné',
  email: 'moussa@test.com',
  city: 'Lyon',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  languages: ['Français', 'Wolof'],
  transportMode: 'AVION',
);

// ── Test harness ──────────────────────────────────────────────────────────────

Widget _wrap(Widget child, MockAuthBloc authBloc) {
  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, _) => child),
          GoRoute(
            path: '/profile/edit/email',
            builder: (context, _) =>
                const Scaffold(body: Text('EditEmailScreen')),
          ),
          GoRoute(
            path: '/profile/edit/phone',
            builder: (context, _) =>
                const Scaffold(body: Text('EditPhoneScreen')),
          ),
        ],
      ),
    ),
  );
}

/// Bascule l'écran en mode édition — tap sur le bouton du bas quand il dit
/// encore « Modifier ».
Future<void> _enterEditMode(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(DonyButton, 'Modifier'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(ImageSource.gallery);
  });

  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    setSmsAuthEnabled(kSmsAuthEnabledDefault);
  });

  tearDown(() {
    mockAuthBloc.close();
    setSmsAuthEnabled(kSmsAuthEnabledDefault);
  });

  // ── Mode vue (par défaut à l'ouverture) ───────────────────────────────────

  group('mode vue (par défaut)', () {
    testWidgets('affiche les infos en lecture et le bouton "Modifier"', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_senderUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le profil'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Modifier'), findsOneWidget);
      expect(find.widgetWithText(DonyButton, 'Enregistrer'), findsNothing);

      // Nom affiché comme titre, pas de champ de saisie.
      expect(find.text('Ibrahima Diallo'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);

      // Email en lecture, pas de badge "Modifier"/"Ajouter" hors édition.
      expect(find.text('ibra@test.com'), findsOneWidget);
      expect(
        find.text('Modifier'),
        findsOneWidget,
      ); // le seul, sur le bouton sticky
    });

    testWidgets('affiche bio, ville et date de naissance en texte simple', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_senderUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Expéditeur depuis 2022.'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('15/06/1990'), findsOneWidget);
    });

    testWidgets('voyageur voit langues et transport en texte simple', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(_travelerUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('PRÉFÉRENCES'), findsOneWidget);
      expect(find.text('Français, Wolof'), findsOneWidget);
      expect(find.text('Avion'), findsOneWidget);
      // Pas de chips sélectionnables hors édition.
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('non-voyageur ne voit pas la section Préférences', (
      tester,
    ) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_senderUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('PRÉFÉRENCES'), findsNothing);
    });

    testWidgets(
      'masque la ligne TÉLÉPHONE tant que le SMS OTP backend n\'est pas confirmé',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: AuthAuthenticated(_senderUser),
        );

        await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
        await tester.pumpAndSettle();

        expect(find.text('TÉLÉPHONE'), findsNothing);
      },
    );
  });

  // ── Bascule vue → édition ─────────────────────────────────────────────────

  group('bascule vue → édition', () {
    testWidgets(
      'tap "Modifier" affiche les champs et le bouton "Enregistrer"',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: AuthAuthenticated(_senderUser),
        );

        await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
        await tester.pumpAndSettle();
        await _enterEditMode(tester);

        expect(find.widgetWithText(DonyButton, 'Enregistrer'), findsOneWidget);
        expect(find.widgetWithText(DonyButton, 'Modifier'), findsNothing);
        // Le nom devient deux champs de saisie.
        expect(find.text('Ibrahima Diallo'), findsNothing);

        final editableTexts = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .map((e) => e.controller.text)
            .toList();
        expect(editableTexts, contains('Ibrahima'));
        expect(editableTexts, contains('Diallo'));
        expect(editableTexts, contains('Paris'));
        expect(editableTexts, contains('Expéditeur depuis 2022.'));
        // L'email n'est JAMAIS un champ de saisie, même en édition.
        expect(editableTexts, isNot(contains('ibra@test.com')));
      },
    );

    testWidgets(
      'voyageur voit les chips langues + sélecteur transport en édition',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: const AuthAuthenticated(_travelerUser),
        );

        await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
        await tester.pumpAndSettle();
        await _enterEditMode(tester);

        expect(find.byType(FilterChip), findsWidgets);
        final chip = tester.widget<FilterChip>(
          find.ancestor(
            of: find.text('Français'),
            matching: find.byType(FilterChip),
          ),
        );
        expect(chip.selected, isTrue);
      },
    );
  });

  // ── Email et téléphone : toujours à part, jamais de saisie directe ────────

  group('email et téléphone — écran OTP dédié', () {
    testWidgets(
      'ligne EMAIL en édition affiche un badge "Modifier" et pousse vers /profile/edit/email',
      (tester) async {
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: AuthAuthenticated(_senderUser),
        );

        await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
        await tester.pumpAndSettle();
        await _enterEditMode(tester);

        expect(find.text('ibra@test.com'), findsOneWidget);
        expect(
          find.text('Modifier'),
          findsWidgets,
        ); // badge email (+ éventuellement autre)

        await tester.ensureVisible(find.text('ibra@test.com'));
        await tester.tap(find.text('ibra@test.com'));
        await tester.pumpAndSettle();

        expect(find.text('EditEmailScreen'), findsOneWidget);
      },
    );

    testWidgets(
      'ligne TÉLÉPHONE visible en édition seulement si le SMS OTP est actif, pousse vers /profile/edit/phone',
      (tester) async {
        setSmsAuthEnabled(true);
        final userWithPhone = _senderUser.copyWith(
          phoneNumber: '+221701234567',
        );
        whenListen<AuthState>(
          mockAuthBloc,
          const Stream.empty(),
          initialState: AuthAuthenticated(userWithPhone),
        );

        await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
        await tester.pumpAndSettle();
        await _enterEditMode(tester);

        expect(find.text('TÉLÉPHONE'), findsOneWidget);
        expect(find.text('+221701234567'), findsOneWidget);

        await tester.ensureVisible(find.text('+221701234567'));
        await tester.tap(find.text('+221701234567'));
        await tester.pumpAndSettle();

        expect(find.text('EditPhoneScreen'), findsOneWidget);
      },
    );

    testWidgets('badge "Ajouter" (pas "Modifier") quand l\'email est absent', (
      tester,
    ) async {
      final userNoEmail = UserModel(
        id: 'u-no-email',
        firstName: 'Ibrahima',
        lastName: 'Diallo',
        roles: const ['SENDER'],
        kycStatus: 'NOT_STARTED',
        status: 'ACTIVE',
      );
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(userNoEmail),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();
      await _enterEditMode(tester);

      expect(find.text('Non ajouté'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);
    });
  });

  // ── Test : dispatche AuthUpdateProfileRequested au tap Enregistrer ────────

  testWidgets('dispatche AuthUpdateProfileRequested au tap sur Enregistrer', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();
    await _enterEditMode(tester);

    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pump();

    verify(
      () => mockAuthBloc.add(any(that: isA<AuthUpdateProfileRequested>())),
    ).called(1);
  });

  // ── AuthProfileUpdated seul (sans save) ne pop PAS ────────────────────────
  //
  // Avatar upload also produces AuthProfileUpdated. The screen must stay open.

  testWidgets('ne pop PAS sur AuthProfileUpdated sans save (avatar upload)', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      Stream.value(AuthProfileUpdated(_senderUser)),
      initialState: AuthAuthenticated(_senderUser),
    );

    // Navigate to /edit on top of /, so there is something to pop back to.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/edit',
          builder: (context, _) => BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const EditProfileScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/edit'));
    await tester.pumpAndSettle();

    // AuthProfileUpdated was received but _saving is false (no save tap) →
    // the screen must remain open.
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  // ── pop(true) sur AuthProfileUpdated après un save ────────────────────────

  testWidgets('pops (retourne) après AuthProfileUpdated suite à un save', (
    tester,
  ) async {
    // We need a controller so we can push AuthProfileUpdated after the tap.
    final controller = StreamController<AuthState>();

    whenListen<AuthState>(
      mockAuthBloc,
      controller.stream,
      initialState: AuthAuthenticated(_senderUser),
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/edit',
          builder: (context, _) => BlocProvider<AuthBloc>.value(
            value: mockAuthBloc,
            child: const EditProfileScreen(),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/edit'));
    await tester.pumpAndSettle();

    // Bascule en édition, puis tap "Enregistrer" — sets _saving = true.
    await _enterEditMode(tester);
    await tester.tap(find.widgetWithText(DonyButton, 'Enregistrer'));
    await tester.pump();

    // Now emit AuthProfileUpdated → listener should pop because _saving is true.
    controller.add(AuthProfileUpdated(_senderUser));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);

    await controller.close();
  });

  // ── AuthLoading hors sauvegarde (upload photo) ────────────────────────────

  testWidgets(
    'pendant un AuthLoading hors save (upload photo), le bouton est désactivé sans spinner',
    (tester) async {
      // A bare AuthLoading on this screen = avatar upload in progress (_saving=false).
      // The save button must NOT spin (the avatar overlay shows the spinner), but it
      // stays disabled to avoid racing the in-flight upload with a save.
      whenListen<AuthState>(
        mockAuthBloc,
        Stream.value(const AuthLoading()),
        initialState: AuthAuthenticated(_senderUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final buttons = tester.widgetList<DonyButton>(find.byType(DonyButton));
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        expect(button.isLoading, isFalse); // avatar overlay owns the spinner
        expect(button.onPressed, isNull); // still disabled during the upload
      }
    },
  );

  // ── Tap avatar dispatche AuthAvatarUploadRequested ────────────────────────

  testWidgets(
    'tap sur l\'avatar dispatche AuthAvatarUploadRequested avec le path du fichier',
    (tester) async {
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(_senderUser),
      );

      // Write a small temp file (4 bytes) so XFile.length() succeeds ≤ 10 MB.
      final tmpPath =
          '${Directory.systemTemp.path}/dony_test_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(tmpPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);

      // Use the mediaService seam — inject a DonyMediaService with a mock
      // ImagePicker that returns the test file without hitting platform channels.
      final mockPicker = _MockImagePicker();
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile(tmpPath));

      final fakeMediaService = DonyMediaService(
        imagePicker: mockPicker,
        // Pass-through compressor: avoids FlutterImageCompress platform channel.
        compressor: (f) async => f,
      );

      final screen = EditProfileScreen(mediaService: fakeMediaService);
      await tester.pumpWidget(_wrap(screen, mockAuthBloc));
      await tester.pumpAndSettle();

      // Ensure the avatar is on screen (top of scroll view, should already be).
      await tester.ensureVisible(
        find.byKey(const ValueKey('avatar_pick_gesture')),
      );
      await tester.pump();

      // Tap then allow all async work (pick → length() → dispatch) to complete.
      await tester.tap(find.byKey(const ValueKey('avatar_pick_gesture')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      verify(
        () => mockAuthBloc.add(any(that: isA<AuthAvatarUploadRequested>())),
      ).called(1);
    },
  );

  // ── Jauge de complétion ───────────────────────────────────────────────────

  testWidgets('masque la jauge de complétion quand les 8 champs sont remplis', (
    tester,
  ) async {
    whenListen<AuthState>(
      mockAuthBloc,
      const Stream.empty(),
      initialState: AuthAuthenticated(_senderUser),
    );

    await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
    await tester.pumpAndSettle();

    expect(find.text('Profil complet'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'affiche la jauge avec le bon pourcentage quand le profil est incomplet',
    (tester) async {
      const incompleteUser = UserModel(
        id: 'user-incomplete',
        firstName: 'Ibrahima',
        roles: ['SENDER'],
        kycStatus: 'NOT_STARTED',
        status: 'ACTIVE',
      );
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: const AuthAuthenticated(incompleteUser),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      // SMS OTP non confirmé par défaut dans ces tests (setUp) : total = 7
      // champs (téléphone exclu). 1 champ sur 7 (prénom) : 1/7 ≈ 14,3 % →
      // arrondi à 14 %.
      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('14%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'SMS OTP confirmé (flag actif) : le téléphone manquant compte dans le '
    'total de 8, la jauge reste visible même avec les 7 autres champs remplis',
    (tester) async {
      setSmsAuthEnabled(true);
      // _senderUser a déjà les 8 champs (avatar/nom/prénom/email/téléphone/
      // ville/bio/date de naissance) — on retire seulement le téléphone
      // pour isoler l'effet du flag.
      final userWithoutPhone = UserModel(
        id: _senderUser.id,
        avatarUrl: _senderUser.avatarUrl,
        firstName: _senderUser.firstName,
        lastName: _senderUser.lastName,
        email: _senderUser.email,
        city: _senderUser.city,
        bio: _senderUser.bio,
        birthDate: _senderUser.birthDate,
        roles: _senderUser.roles,
        kycStatus: _senderUser.kycStatus,
        status: _senderUser.status,
      );
      whenListen<AuthState>(
        mockAuthBloc,
        const Stream.empty(),
        initialState: AuthAuthenticated(userWithoutPhone),
      );

      await tester.pumpWidget(_wrap(const EditProfileScreen(), mockAuthBloc));
      await tester.pumpAndSettle();

      // 7 champs sur 8 (téléphone manquant, désormais compté) : 7/8 = 87,5 %
      // → arrondi à 88 %.
      expect(find.text('Profil complet'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
    },
  );
}
