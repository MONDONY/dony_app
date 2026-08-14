import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid/photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockRepo extends Mock implements BidRepository {}

void main() {
  late BidPhotosCubit cubit;

  setUp(() {
    cubit = BidPhotosCubit(
      _MockRepo(),
      makeDisabledAnalytics(MockAnalyticsBackend()),
    );
  });

  Widget wrap() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: BlocProvider.value(value: cubit, child: const PhotoSection()),
    ),
  );

  testWidgets('affiche le CTA plein largeur et le compteur quand vide', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.text('0 / 4'), findsOneWidget);
    expect(find.text('Ajouter une photo'), findsOneWidget);
    expect(find.byKey(const Key('bid-add-photo')), findsOneWidget);

    // Le CTA occupe toute la largeur : c'est ce qui le rend visible, une case
    // de 64 px se ratait au défilement.
    final width = tester.getSize(find.byKey(const Key('bid-add-photo'))).width;
    expect(width, greaterThan(300));
  });
}
