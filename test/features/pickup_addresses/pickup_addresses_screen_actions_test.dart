import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_bloc.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_event.dart';
import 'package:dony/features/delivery_addresses/bloc/delivery_address_state.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/features/pickup_addresses/presentation/screens/pickup_addresses_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Actions de l'écran « Mes adresses » : ajout, ouverture, menu contextuel
/// des deux onglets (remise et livraison), et rechargement du bon BLoC
/// selon le résultat de l'éditeur. Les états de base de l'onglet Remise sont
/// couverts par `pickup_addresses_screen_test.dart`.

class MockPickupAddressBloc
    extends MockBloc<PickupAddressEvent, PickupAddressState>
    implements PickupAddressBloc {}

class MockDeliveryAddressBloc
    extends MockBloc<DeliveryAddressEvent, DeliveryAddressState>
    implements DeliveryAddressBloc {}

class _FakePickupEvent extends Fake implements PickupAddressEvent {}

const _home = PickupAddress(
  id: 'p-1',
  label: 'Maison',
  street: '12 rue de la Paix',
  postalCode: '75001',
  city: 'Paris',
  country: 'France',
  floorApartment: '3e étage, porte B',
  isDefault: true,
);

const _office = PickupAddress(
  id: 'p-2',
  label: 'Bureau',
  street: '5 avenue Montaigne',
  postalCode: '75008',
  city: 'Paris',
  country: 'France',
  isDefault: false,
);

const _family = DeliveryAddress(
  id: 'd-1',
  label: 'Famille',
  street: 'Rue 10, Médina',
  city: 'Dakar',
  country: 'Sénégal',
  instructions: 'Demander Awa',
  isDefault: true,
);

const _market = DeliveryAddress(
  id: 'd-2',
  label: 'Marché',
  city: 'Abidjan',
  country: 'Côte d\'Ivoire',
  isDefault: false,
);

/// Page d'éditeur factice : affiche son chemin et se ferme avec `true`
/// (« save ») ou `false` (« discard »).
Widget _editor(BuildContext context, GoRouterState state) => Scaffold(
  body: Column(
    children: [
      Text('editor ${state.uri.path}'),
      TextButton(onPressed: () => context.pop(true), child: const Text('save')),
      TextButton(
        onPressed: () => context.pop(false),
        child: const Text('discard'),
      ),
    ],
  ),
);

Widget _wrap(PickupAddressBloc pickup, DeliveryAddressBloc delivery) =>
    MultiBlocProvider(
      providers: [
        BlocProvider<PickupAddressBloc>.value(value: pickup),
        BlocProvider<DeliveryAddressBloc>.value(value: delivery),
      ],
      child: MaterialApp.router(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const PickupAddressesScreen(),
            ),
            GoRoute(path: '/profile/addresses/new', builder: _editor),
            GoRoute(path: '/profile/addresses/delivery/new', builder: _editor),
            GoRoute(path: '/profile/addresses/delivery/:id', builder: _editor),
            GoRoute(path: '/profile/addresses/:id', builder: _editor),
          ],
        ),
      ),
    );

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  late MockPickupAddressBloc pickup;
  late MockDeliveryAddressBloc delivery;

  setUpAll(() {
    registerFallbackValue(_FakePickupEvent());
    registerFallbackValue(const DeliveryAddressLoaded());
  });

  setUp(() {
    pickup = MockPickupAddressBloc();
    delivery = MockDeliveryAddressBloc();
    when(() => pickup.state).thenReturn(
      const PickupAddressState(
        status: PickupAddressStatus.success,
        addresses: [_home, _office],
      ),
    );
    when(() => delivery.state).thenReturn(
      const DeliveryAddressState(
        status: DeliveryAddressStatus.success,
        addresses: [_family, _market],
      ),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Police de test (Ahem) : chaque glyphe a la largeur de la taille de
    // police. Sans réduction, les libellés du menu contextuel débordent.
    tester.platformDispatcher.textScaleFactorTestValue = 0.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_wrap(pickup, delivery));
    await tester.pumpAndSettle();
  }

  Future<void> openDeliveryTab(WidgetTester tester) async {
    await tester.tap(find.text(fr.addressesTabDelivery));
    await tester.pumpAndSettle();
  }

  Future<void> openMenuOf(WidgetTester tester, String label) async {
    final card = find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );
    await tester.tap(
      find.descendant(
        of: card.first,
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Object?> pickupEvents() =>
      verify(() => pickup.add(captureAny())).captured;
  List<Object?> deliveryEvents() =>
      verify(() => delivery.add(captureAny())).captured;

  group('onglet Remise', () {
    testWidgets('carte : adresse complète, étage et badge par défaut', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('12 rue de la Paix, 75001, Paris'), findsOneWidget);
      expect(find.text('3e étage, porte B'), findsOneWidget);
      expect(find.text(fr.commonDefault), findsOneWidget);
    });

    testWidgets('« + » ouvre l\'éditeur de remise et recharge si enregistré', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip(fr.addressesAddPickupTooltip));
      await tester.pumpAndSettle();
      expect(find.text('editor /profile/addresses/new'), findsOneWidget);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(pickupEvents().single, isA<PickupAddressLoaded>());
      verifyNever(() => delivery.add(any()));
    });

    testWidgets('éditeur fermé sans enregistrer : aucun rechargement', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip(fr.addressesAddPickupTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('discard'));
      await tester.pumpAndSettle();

      verifyNever(() => pickup.add(any()));
    });

    testWidgets('tap sur une carte : éditeur de cette adresse', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text(_office.label));
      await tester.pumpAndSettle();
      expect(find.text('editor /profile/addresses/p-2'), findsOneWidget);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(pickupEvents().single, isA<PickupAddressLoaded>());
    });

    testWidgets('menu d\'une adresse par défaut : pas de « Définir par '
        'défaut »', (tester) async {
      await pumpScreen(tester);
      await openMenuOf(tester, _home.label);

      expect(find.text(fr.addressesSetDefaultLabel), findsNothing);
      expect(find.text(fr.commonEdit), findsOneWidget);
    });

    testWidgets('menu : « Définir par défaut » envoie SetDefault', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openMenuOf(tester, _office.label);
      await tester.tap(find.text(fr.addressesSetDefaultLabel));
      await tester.pumpAndSettle();

      final event = pickupEvents().single! as PickupAddressSetDefault;
      expect(event.id, _office.id);
    });

    testWidgets('menu : « Modifier » ouvre l\'éditeur puis recharge', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openMenuOf(tester, _office.label);
      await tester.tap(find.text(fr.commonEdit));
      await tester.pumpAndSettle();
      expect(find.text('editor /profile/addresses/p-2'), findsOneWidget);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(pickupEvents().single, isA<PickupAddressLoaded>());
    });

    testWidgets('menu : suppression confirmée envoie Deleted', (tester) async {
      await pumpScreen(tester);
      await openMenuOf(tester, _office.label);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();

      expect(find.text(fr.addressesDeleteTitle), findsOneWidget);
      expect(
        find.text(fr.addressesDeleteConfirmMessage(_office.label)),
        findsOneWidget,
      );
      await tester.tap(find.text(fr.commonDelete).last);
      await tester.pumpAndSettle();

      final event = pickupEvents().single! as PickupAddressDeleted;
      expect(event.id, _office.id);
    });

    testWidgets('menu : suppression annulée, rien n\'est envoyé', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openMenuOf(tester, _office.label);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => pickup.add(any()));
    });

    testWidgets('état vide : « Ajouter » ouvre l\'éditeur puis recharge', (
      tester,
    ) async {
      when(() => pickup.state).thenReturn(
        const PickupAddressState(status: PickupAddressStatus.success),
      );
      await pumpScreen(tester);
      await tester.tap(find.text(fr.addressesAddButtonLabel));
      await tester.pumpAndSettle();
      expect(find.text('editor /profile/addresses/new'), findsOneWidget);

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(pickupEvents().single, isA<PickupAddressLoaded>());
    });

    testWidgets('erreur sans détail : texte générique de repli', (
      tester,
    ) async {
      when(
        () => pickup.state,
      ).thenReturn(const PickupAddressState(status: PickupAddressStatus.error));
      await pumpScreen(tester);

      expect(find.text(fr.commonLoadError), findsOneWidget);
      expect(find.text(fr.commonSomethingWentWrongDot), findsOneWidget);
    });
  });

  group('onglet Livraison', () {
    testWidgets('carte : rue facultative, consignes et badge par défaut', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);

      expect(find.text('Rue 10, Médina, Dakar'), findsOneWidget);
      expect(find.text('Abidjan'), findsOneWidget);
      expect(find.text('Demander Awa'), findsOneWidget);
      expect(find.text(fr.commonDefault), findsOneWidget);
    });

    testWidgets('« + » ouvre l\'éditeur de livraison et recharge ce BLoC', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await tester.tap(find.byTooltip(fr.addressesAddDeliveryTooltip));
      await tester.pumpAndSettle();
      expect(
        find.text('editor /profile/addresses/delivery/new'),
        findsOneWidget,
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(deliveryEvents().single, isA<DeliveryAddressLoaded>());
      verifyNever(() => pickup.add(any()));
    });

    testWidgets('« + » puis abandon : aucun rechargement', (tester) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await tester.tap(find.byTooltip(fr.addressesAddDeliveryTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('discard'));
      await tester.pumpAndSettle();

      verifyNever(() => delivery.add(any()));
    });

    testWidgets('tap sur une carte : éditeur de cette adresse', (tester) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await tester.tap(find.text(_market.label));
      await tester.pumpAndSettle();
      expect(
        find.text('editor /profile/addresses/delivery/d-2'),
        findsOneWidget,
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(deliveryEvents().single, isA<DeliveryAddressLoaded>());
    });

    testWidgets('menu : « Définir par défaut » envoie SetDefault', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await openMenuOf(tester, _market.label);
      await tester.tap(find.text(fr.addressesSetDefaultLabel));
      await tester.pumpAndSettle();

      final event = deliveryEvents().single! as DeliveryAddressSetDefault;
      expect(event.id, _market.id);
    });

    testWidgets('menu d\'une adresse par défaut : pas de « Définir par '
        'défaut »', (tester) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await openMenuOf(tester, _family.label);

      expect(find.text(fr.addressesSetDefaultLabel), findsNothing);
    });

    testWidgets('menu : « Modifier » ouvre l\'éditeur puis recharge', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await openMenuOf(tester, _market.label);
      await tester.tap(find.text(fr.commonEdit));
      await tester.pumpAndSettle();
      expect(
        find.text('editor /profile/addresses/delivery/d-2'),
        findsOneWidget,
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(deliveryEvents().single, isA<DeliveryAddressLoaded>());
    });

    testWidgets('menu : suppression confirmée envoie Deleted', (tester) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await openMenuOf(tester, _market.label);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();
      expect(
        find.text(fr.addressesDeleteConfirmMessage(_market.label)),
        findsOneWidget,
      );
      await tester.tap(find.text(fr.commonDelete).last);
      await tester.pumpAndSettle();

      final event = deliveryEvents().single! as DeliveryAddressDeleted;
      expect(event.id, _market.id);
    });

    testWidgets('menu : suppression annulée, rien n\'est envoyé', (
      tester,
    ) async {
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      await openMenuOf(tester, _market.label);
      await tester.tap(find.text(fr.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => delivery.add(any()));
    });

    testWidgets('chargement sans adresse : ni liste ni état vide', (
      tester,
    ) async {
      when(() => delivery.state).thenReturn(
        const DeliveryAddressState(status: DeliveryAddressStatus.loading),
      );
      await tester.pumpWidget(_wrap(pickup, delivery));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fr.addressesTabDelivery));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(fr.addressesEmptyDeliveryTitle), findsNothing);
      expect(find.text(_family.label), findsNothing);
    });

    testWidgets('état vide : « Ajouter » ouvre l\'éditeur puis recharge', (
      tester,
    ) async {
      when(() => delivery.state).thenReturn(
        const DeliveryAddressState(status: DeliveryAddressStatus.success),
      );
      await pumpScreen(tester);
      await openDeliveryTab(tester);
      expect(find.text(fr.addressesEmptyDeliveryTitle), findsOneWidget);

      await tester.tap(find.text(fr.addressesAddButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
      expect(deliveryEvents().single, isA<DeliveryAddressLoaded>());
    });

    testWidgets('erreur sans détail : repli générique, Réessayer recharge', (
      tester,
    ) async {
      when(() => delivery.state).thenReturn(
        const DeliveryAddressState(status: DeliveryAddressStatus.error),
      );
      await pumpScreen(tester);
      await openDeliveryTab(tester);

      expect(find.text(fr.commonSomethingWentWrongDot), findsOneWidget);
      await tester.tap(find.text(fr.commonRetry));
      expect(deliveryEvents().single, isA<DeliveryAddressLoaded>());
    });
  });
}
