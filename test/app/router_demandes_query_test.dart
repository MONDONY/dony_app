// `/demandes` lit `?bid=`, `?filter=` et `?announcement=` : on appelle le
// `builder` de la route avec un `GoRouterState` synthétique (comme
// `router_legal_terms_title_test.dart`) et on inspecte l'écran construit,
// sans le pumper (il tirerait ses blocs de getIt).
import 'package:dony/app/router.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _trip = '11111111-2222-3333-4444-555555555555';

Future<DemandesScreen> _build(WidgetTester tester, String location) async {
  final route = appRouter.configuration.routes.whereType<GoRoute>().singleWhere(
    (r) => r.path == '/demandes',
  );
  late BuildContext ctx;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        ctx = context;
        return const SizedBox.shrink();
      },
    ),
  );
  final uri = Uri.parse(location);
  final state = GoRouterState(
    appRouter.configuration,
    uri: uri,
    matchedLocation: uri.path,
    fullPath: '/demandes',
    pathParameters: const {},
    pageKey: ValueKey(location),
  );
  return route.builder!(ctx, state) as DemandesScreen;
}

void main() {
  testWidgets('filtre et trajet lus depuis la requête', (tester) async {
    final screen = await _build(
      tester,
      '/demandes?filter=aTraiter&announcement=$_trip',
    );
    expect(screen.initialFilter, TravelerBidFilter.aTraiter);
    expect(screen.announcementId, _trip);
    expect(screen.focusBidId, isNull);
  });

  testWidgets('trajet non UUID et filtre inconnu ignorés', (tester) async {
    final screen = await _build(
      tester,
      '/demandes?filter=bidon&announcement=../admin',
    );
    expect(screen.initialFilter, isNull);
    expect(screen.announcementId, isNull);
  });

  testWidgets('sans paramètre : écran comme avant, ?bid= transmis', (
    tester,
  ) async {
    final plain = await _build(tester, '/demandes');
    expect(plain.initialFilter, isNull);
    expect(plain.announcementId, isNull);
    expect(plain.focusBidId, isNull);

    final focused = await _build(tester, '/demandes?bid=$_trip');
    expect(focused.focusBidId, _trip);
    expect(focused.initialFilter, isNull);
  });
}
