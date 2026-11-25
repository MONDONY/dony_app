import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/data/models/contact_phone_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/counterpart_call_launcher.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// « Appeler {prénom} » d'un colis : le numéro est demandé au serveur au
/// geste, mesuré par `parcel_call_tapped`, jamais avec le numéro.
class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockBidRepository repo;
  late _MockAnalytics analytics;

  setUp(() async {
    repo = _MockBidRepository();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    await getIt.reset();
    getIt
      ..registerFactory<ContactRevealBloc>(() => ContactRevealBloc(repo))
      ..registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(WidgetTester tester, {String? status}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: AppL10n.fr,
        home: Scaffold(
          body: CounterpartCallLauncher(
            bidId: 'bid-1',
            source: 'sender_footer',
            status: status,
            builder: (context, onPressed, isLoading) => DonyButton(
              key: const Key('call'),
              label: 'Appeler Mamadou',
              isLoading: isLoading,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  DonyButton button(WidgetTester tester) =>
      tester.widget<DonyButton>(find.byKey(const Key('call')));

  testWidgets('le geste mesure l\'appel puis demande le numéro au serveur', (
    tester,
  ) async {
    when(
      () => repo.getCounterpartyContact('bid-1'),
    ).thenAnswer((_) async => const ContactPhoneModel(phoneNumber: '+33600'));
    await pump(tester, status: 'ARRIVED');

    await tester.tap(find.byKey(const Key('call')));
    await tester.pump();

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.parcelCallTapped,
        properties: {'source': 'sender_footer', 'status': 'ARRIVED'},
      ),
    ).called(1);
    verify(() => repo.getCounterpartyContact('bid-1')).called(1);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('sans statut connu : seule la source est mesurée', (
    tester,
  ) async {
    when(
      () => repo.getCounterpartyContact('bid-1'),
    ).thenAnswer((_) async => const ContactPhoneModel());
    await pump(tester);

    await tester.tap(find.byKey(const Key('call')));
    await tester.pump();

    verify(
      () => analytics.logEvent(
        AnalyticsEvents.parcelCallTapped,
        properties: {'source': 'sender_footer'},
      ),
    ).called(1);
    // Compte sans numéro : le message le dit, aucun composeur vide.
    await tester.pump();
    expect(
      find.text('Aucun numéro disponible pour ce contact'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('pendant la demande : bouton en chargement, un seul appel', (
    tester,
  ) async {
    final pending = Completer<ContactPhoneModel>();
    when(
      () => repo.getCounterpartyContact('bid-1'),
    ).thenAnswer((_) => pending.future);
    await pump(tester);

    await tester.tap(find.byKey(const Key('call')));
    await tester.pump();

    expect(button(tester).isLoading, isTrue);
    expect(button(tester).onPressed, isNull);
    verify(() => repo.getCounterpartyContact('bid-1')).called(1);

    pending.complete(const ContactPhoneModel());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('refus du serveur : message d\'erreur, le bouton revient', (
    tester,
  ) async {
    when(
      () => repo.getCounterpartyContact('bid-1'),
    ).thenThrow(const ForbiddenException('x'));
    await pump(tester);

    await tester.tap(find.byKey(const Key('call')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(button(tester).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
