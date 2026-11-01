// Harnais commun des tests des pièces de l'écran du trajet (gain, audience,
// étapes, routes) : vraies polices, blocs simulés, routeur qui note les
// écrans ouverts et sait revenir.
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

/// Écran ouvert depuis la carte : chemin complet et `extra`.
typedef PushedRoute = ({String location, Object? extra});

/// Vraies polices de l'app : la police de repli des tests fausserait la
/// mesure des textes à 360 dp.
Future<void> loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

AnnouncementModel tripFixture({
  String id = 'trip-1',
  String status = 'ACTIVE',
  int pendingBidCount = 0,
}) => AnnouncementModel(
  id: id,
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 12),
  availableKg: 20,
  totalKg: 20,
  pricePerKg: 7,
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
  pendingBidCount: pendingBidCount,
);

/// Monte [card] sous les blocs de l'écran ([bids], [announcement] : absents
/// quand `null`), dans une app localisée à l'échelle de texte [textScale].
/// Les écrans ouverts (`/demandes`, `/announcements/:id/bids`, `/bids/:id`)
/// sont notés dans la liste rendue et ont un bouton `back` qui revient.
Future<List<PushedRoute>> pumpTripCard(
  WidgetTester tester,
  Widget card, {
  BidBloc? bids,
  AnnouncementBloc? announcement,
  Locale locale = const Locale('fr'),
  double textScale = 1,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final pushed = <PushedRoute>[];

  Widget stub(BuildContext context, GoRouterState state) {
    pushed.add((location: state.uri.toString(), extra: state.extra));
    return Scaffold(
      body: TextButton(
        onPressed: () => context.pop(),
        child: const Text('back'),
      ),
    );
  }

  Widget screen(BuildContext context) {
    final body = Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DonySpacing.lg),
        child: card,
      ),
    );
    final providers = [
      if (bids != null) BlocProvider<BidBloc>.value(value: bids),
      if (announcement != null)
        BlocProvider<AnnouncementBloc>.value(value: announcement),
    ];
    return providers.isEmpty
        ? body
        : MultiBlocProvider(providers: providers, child: body);
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, _) => screen(context)),
      GoRoute(path: '/demandes', builder: stub),
      GoRoute(path: '/announcements/:id/bids', builder: stub),
      GoRoute(path: '/bids/:bidId', builder: stub),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  );
  // Laisse finir les fondus (`flutter_animate`) et leurs Timers.
  await tester.pump(const Duration(milliseconds: 400));
  return pushed;
}

/// Tailles d'écran et échelles de texte vérifiées pour chaque carte.
const kTripCardSmallPhone = Size(360, 1400);
