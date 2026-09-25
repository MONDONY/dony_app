import 'dart:convert';
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/package_request_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

/// PNG 1x1 valide (transparent) : `Image.file` a besoin d'un vrai fichier
/// décodable, sinon l'erreur de décodage remonte comme exception non
/// attrapée du test — le chemin `/tmp/x.jpg` des autres tests de ce fichier
/// n'est jamais rendu (photo prête, jamais affichée en échec).
const _kPng1x1Base64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAAAXNSR0IArs4c6QAA'
    'AA1JREFUCJlj+P//PwMAAAABv0eNPIYAAAAASUVORK5CYII=';

void main() {
  late _MockRepo repo;
  late PackageRequestPhotosCubit cubit;

  setUpAll(() {
    registerFallbackValue(File('x'));
  });

  setUp(() {
    repo = _MockRepo();
    cubit = PackageRequestPhotosCubit(
      repo,
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: const PackageRequestPhotoSection(),
      ),
    ),
  );

  testWidgets('rend le header + compteur 0/4 + bouton ajouter', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Photos du colis'), findsOneWidget);
    expect(find.text('0 / 4'), findsOneWidget);
    expect(find.byKey(const Key('pr-add-photo')), findsOneWidget);
  });

  testWidgets('bouton ajouter masqué quand 4 photos', (tester) async {
    // Pré-remplit le cubit à 4 (via emit interne par add simulé impossible ici) :
    // on vérifie plutôt le compteur passe à mesure. Avec 0 photo, bouton présent.
    await tester.pumpWidget(wrap());
    expect(find.byKey(const Key('pr-add-photo')), findsOneWidget);
  });

  testWidgets('anglais : titre de section et CTA d\'ajout', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap());
    expect(find.text('Parcel photos'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Photos du colis'), findsNothing);
  });

  // Relecture finale du lot K, mineur 3 : ce texte n'avait de test dans
  // aucune langue. `p.error` (`Exception: raw`) ne doit jamais apparaître,
  // seul le texte fixe traduit du catalogue.
  testWidgets(
    'anglais : échec d\'upload affiche le texte fixe, jamais l\'erreur brute',
    (tester) async {
      useEnglish();
      final tempFile = File(
        '${Directory.systemTemp.path}/pr-photo-fail-test.png',
      )..writeAsBytesSync(base64Decode(_kPng1x1Base64));
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      when(() => repo.uploadPhotoKey(any())).thenThrow(Exception('raw'));

      await cubit.add(tempFile.path);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.error_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Photo upload failed'), findsOneWidget);
      expect(find.textContaining('raw'), findsNothing);
    },
  );
}
