// Harnais des tests du pied collant et du menu ⋮ de l'écran du trajet :
// trajet et colis de test, écran simulé sous les blocs de la route, routeur
// qui note les écrans ouverts et sait revenir.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'trip_card_harness.dart';

export 'trip_card_harness.dart'
    show MockAnnouncementBloc, MockBidBloc, PushedRoute, loadAppFonts;

/// Statuts du trajet couverts par les tables : les six de l'app, celui posé
/// par la modération et un statut que l'app ne connaît pas.
const kTripStatuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
  'SOMETHING_NEW',
];

AnnouncementModel ownerTrip({
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  int? bidsCount,
  int confirmedParcelCount = 0,
  int? remainingReschedules,
  String? arrivalInstructions,
  String? tripGroupId,
  Set<BidPaymentMethod> methods = const {BidPaymentMethod.stripe},
  bool trackingActive = false,
  TripParcelsSummary? parcelsSummary,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 12),
  availableKg: 20,
  totalKg: 20,
  pricePerKg: 7,
  status: status,
  bidsCount: bidsCount,
  pendingBidCount: pendingBidCount,
  confirmedParcelCount: confirmedParcelCount,
  remainingReschedules: remainingReschedules,
  arrivalInstructions: arrivalInstructions,
  tripGroupId: tripGroupId,
  acceptedPaymentMethods: methods,
  trackingActive: trackingActive,
  parcelsSummary: parcelsSummary,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Colis de test. Par défaut payé par carte : une demande `PENDING` y est
/// une carte pas encore payée par l'expéditeur (pas une action « À
/// traiter »), `PAYMENT_ESCROWED` une demande à traiter.
BidModel ownerBid(
  String id,
  String status, {
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  bool voyageurConfirmed = false,
  DateTime? departureDate,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: 'Awa Diop',
  weightKg: 3,
  status: status,
  paymentMethod: paymentMethod,
  voyageurConfirmed: voyageurConfirmed,
  departureDate: departureDate,
  recipientName: 'Fatou',
  recipientPhone: '+221770000000',
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Monte [child] (pied collant en `bottomNavigationBar`, ou bouton qui ouvre
/// le menu) sous les blocs de l'écran du trajet. Les écrans ouverts sont
/// notés dans la liste rendue et ont un bouton `back` qui revient.
Future<List<PushedRoute>> pumpTripOwnerScreen(
  WidgetTester tester, {
  Widget? bottomBar,
  Widget Function(BuildContext context)? body,
  PreferredSizeWidget? appBar,
  AnnouncementBloc? announcement,
  BidBloc? bids,
  CancellationBloc? cancellation,
  TripGroupCubit? group,
  Locale locale = const Locale('fr'),
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
    final page = Scaffold(
      appBar: appBar,
      body: Builder(
        builder: (context) => body?.call(context) ?? const SizedBox.expand(),
      ),
      bottomNavigationBar: bottomBar,
    );
    final providers = [
      if (announcement != null)
        BlocProvider<AnnouncementBloc>.value(value: announcement),
      if (bids != null) BlocProvider<BidBloc>.value(value: bids),
      if (cancellation != null)
        BlocProvider<CancellationBloc>.value(value: cancellation),
      if (group != null) BlocProvider<TripGroupCubit>.value(value: group),
    ];
    return providers.isEmpty
        ? page
        : MultiBlocProvider(providers: providers, child: page);
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, _) => screen(context)),
      GoRoute(path: '/demandes', builder: stub),
      GoRoute(path: '/trips/create', builder: stub),
      GoRoute(path: '/announcements/:id/affiche', builder: stub),
      GoRoute(path: '/bids/:bidId', builder: stub),
      GoRoute(path: '/tracking/validate', builder: stub),
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
  await tester.pump(const Duration(milliseconds: 400));
  return pushed;
}

/// Nom de route de la feuille qui contient [finder] (`/sheet/<analyticsName>`
/// d'un `DonyBottomSheet` nommé).
String? sheetRouteName(WidgetTester tester, Finder finder) =>
    ModalRoute.of(tester.element(finder))?.settings.name;
