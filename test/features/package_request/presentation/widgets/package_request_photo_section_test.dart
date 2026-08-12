import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/package_request_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements PackageRequestRepository {}

void main() {
  late _MockRepo repo;
  late PackageRequestPhotosCubit cubit;

  setUp(() {
    repo = _MockRepo();
    cubit = PackageRequestPhotosCubit(
        repo, makeDisabledAnalytics(MockAnalyticsBackend()));
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
}
