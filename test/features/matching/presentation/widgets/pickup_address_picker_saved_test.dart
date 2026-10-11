import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/pickup_address_picker_sheet.dart';
import 'package:dony/features/pickup_addresses/bloc/pickup_address_bloc.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends MockBloc<PickupAddressEvent, PickupAddressState>
    implements PickupAddressBloc {}

class _MockAutocomplete extends Mock implements AddressAutocompleteService {}

final _l = lookupAppLocalizations(AppL10n.fr);

const _home = PickupAddress(
  id: 'a1',
  label: 'Maison',
  street: '12 rue de Paris',
  postalCode: '75011',
  city: 'Paris',
  country: 'FR',
  latitude: 48.85,
  longitude: 2.37,
  isDefault: true,
);

const _office = PickupAddress(
  id: 'a2',
  label: 'Bureau',
  street: '3 avenue Foch',
  postalCode: '',
  city: 'Lyon',
  country: 'FR',
  isDefault: false,
);

void main() {
  late _MockBloc bloc;
  late List<String> visited;

  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_saved_').path);
  });

  setUp(() async {
    bloc = _MockBloc();
    visited = [];
    whenListen(
      bloc,
      const Stream<PickupAddressState>.empty(),
      initialState: const PickupAddressState(
        status: PickupAddressStatus.success,
        addresses: [_home, _office],
      ),
    );
    getIt.registerLazySingleton<AddressAutocompleteService>(
      _MockAutocomplete.new,
    );
    await (await Hive.openBox(HiveService.userPrefsBox)).clear();
    getIt.registerLazySingleton<HiveService>(HiveService.new);
  });

  tearDown(() => getIt.reset());

  /// Ouvre le sheet depuis un bouton et rend la valeur renvoyée au `pop`.
  Future<List<AddressData?>> open(
    WidgetTester tester, {
    AddressData? current,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final results = <AddressData?>[];
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => results.add(
                    await showModalBottomSheet<AddressData>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => BlocProvider<PickupAddressBloc>.value(
                        value: bloc,
                        child: PickupAddressPickerSheet(current: current),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
            GoRoute(
              path: '/profile/addresses/new',
              builder: (_, _) {
                visited.add('/profile/addresses/new');
                return const Scaffold(body: Text('new address'));
              },
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('adresses enregistrées : en-tête, badge par défaut, détails', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(_l.addressSavedAddressesHeader), findsOneWidget);
    expect(find.text('Maison'), findsOneWidget);
    expect(find.text(_l.addressDefaultBadge), findsOneWidget);
    expect(find.text('12 rue de Paris, 75011, Paris'), findsOneWidget);
    // Code postal vide : omis du sous-titre.
    expect(find.text('3 avenue Foch, Lyon'), findsOneWidget);
  });

  testWidgets('sans choix, « Confirmer » renvoie la première adresse', (
    tester,
  ) async {
    final results = await open(tester);
    await tester.tap(find.text(_l.addressConfirmButton));
    await tester.pumpAndSettle();

    expect(results.single?.label, 'Maison, 12 rue de Paris, 75011, Paris');
    expect(results.single?.lat, 48.85);
  });

  testWidgets('adresse choisie puis confirmée (coordonnées absentes → 0)', (
    tester,
  ) async {
    final results = await open(tester);
    await tester.tap(find.text('Bureau'));
    await tester.pump();
    await tester.tap(find.text(_l.addressConfirmButton));
    await tester.pumpAndSettle();

    expect(results.single?.label, 'Bureau, 3 avenue Foch, Lyon');
    expect(results.single?.lat, 0.0);
    expect(results.single?.lng, 0.0);
  });

  testWidgets('adresse courante enregistrée : présélectionnée', (tester) async {
    final results = await open(
      tester,
      current: const AddressData(
        label: 'Bureau, 3 avenue Foch, Lyon',
        lat: 0,
        lng: 0,
      ),
    );
    await tester.tap(find.text(_l.addressConfirmButton));
    await tester.pumpAndSettle();
    expect(results.single?.label, 'Bureau, 3 avenue Foch, Lyon');
  });

  testWidgets('« Ajouter une adresse » ferme le sheet et navigue', (
    tester,
  ) async {
    final results = await open(tester);
    await tester.tap(find.text(_l.addressAddNewTitle));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(visited, ['/profile/addresses/new']);
  });
}
