// Tests de TripRecurrenceEditScreen — garde « pas de prix au kilo » (constat
// #3) : cet écran n'a pas de champ prix éditable, une récurrence issue d'un
// modèle « grille seule » ne doit donc jamais pouvoir être créée avec un prix
// à 0.

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_recurrence_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:dony/features/trip_templates/presentation/screens/trip_recurrence_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTripRecurrenceBloc
    extends MockBloc<TripRecurrenceEvent, TripRecurrenceState>
    implements TripRecurrenceBloc {}

class _MockAutocompleteService extends Mock
    implements AddressAutocompleteService {}

class _MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

/// Écran monté avec un compte Stripe Connect [status] (FLUTTER-FT).
Widget _wrapWithStripe(
  Widget child,
  TripRecurrenceBloc bloc, {
  String status = 'ONBOARDING_COMPLETE',
}) {
  final stripe = _MockStripeAccountBloc();
  when(
    () => stripe.state,
  ).thenReturn(StripeAccountReady(ConnectAccountStatus(status: status)));
  when(() => stripe.stream).thenAnswer((_) => const Stream.empty());
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TripRecurrenceBloc>.value(value: bloc),
          BlocProvider<StripeAccountBloc>.value(value: stripe),
        ],
        child: child,
      ),
    ),
    theme: AppTheme.light(),
  );
}

const _address = AddressData(label: 'Gare de Lyon', lat: 48.84, lng: 2.37);

/// Remplit le minimum exigé (un jour, deux adresses) puis publie, et rend les
/// données envoyées au BLoC.
Future<Map<String, dynamic>> _fillAndSubmit(
  WidgetTester tester,
  TripRecurrenceBloc bloc,
) async {
  await tester.ensureVisible(find.text('L'));
  await tester.pump();
  await tester.tap(find.text('L'));
  for (final field in tester.widgetList<AddressPickerField>(
    find.byType(AddressPickerField),
  )) {
    field.onChanged!(_address);
  }
  await tester.pump();
  final button = find.widgetWithText(DonyButton, 'Activer la récurrence');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  final event =
      verify(() => bloc.add(captureAny())).captured.single
          as TripRecurrenceCreated;
  return event.data;
}

Widget _wrap(Widget child, TripRecurrenceBloc bloc) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: BlocProvider<TripRecurrenceBloc>.value(value: bloc, child: child),
  ),
  theme: AppTheme.light(),
);

TripTemplate _template({
  required double? pricePerKg,
  bool cashAccepted = false,
  String? currency,
}) => TripTemplate(
  id: 't1',
  label: 'Paris → Dakar',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  transportMode: 'PLANE',
  capacityUnit: 'SUITCASE_23KG',
  availableKg: 23,
  pricePerKg: pricePerKg,
  acceptedCategories: const ['Vêtements'],
  cashAccepted: cashAccepted,
  currency: currency,
);

void main() {
  late _MockTripRecurrenceBloc bloc;

  setUpAll(() {
    registerFallbackValue(const TripRecurrenceCreated(<String, dynamic>{}));
    if (!getIt.isRegistered<AddressAutocompleteService>()) {
      getIt.registerSingleton<AddressAutocompleteService>(
        _MockAutocompleteService(),
      );
    }
  });

  setUp(() {
    bloc = _MockTripRecurrenceBloc();
    when(() => bloc.state).thenReturn(const TripRecurrenceState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('modèle sans prix au kilo : message affiché et CTA désactivé', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: null)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Ce modèle n'a pas de prix au kilo"), findsOneWidget);
    final button = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Activer la récurrence'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('modèle avec prix au kilo : pas de message de garde', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Ce modèle n'a pas de prix au kilo"), findsNothing);
  });

  testWidgets('anglais : titre et avertissement traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: null)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Recurring trip'), findsOneWidget);
    expect(find.text('This template has no price per kg'), findsOneWidget);
  });

  testWidgets('anglais : bouton et bloc actif traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Make it a recurring trip'), findsOneWidget);
    expect(find.text('Recurring trip on'), findsOneWidget);
    expect(find.text('Automatically posts upcoming trips'), findsOneWidget);
  });

  /// `_weekdayLabels` (initiales des jours, lundi → dimanche) est calculé via
  /// `DateFormat.EEEEE(locale)` : ce test fige le rendu français (identique à
  /// l'ancien motif codé en dur `['L', 'M', 'M', 'J', 'V', 'S', 'D']`).
  testWidgets('initiales des jours en français : L, M, M, J, V, S, D', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final letters = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.length == 1)
        .toList();

    expect(letters, ['L', 'M', 'M', 'J', 'V', 'S', 'D']);
  });

  testWidgets('initiales des jours en anglais : M, T, W, T, F, S, S', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
        bloc,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final letters = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.length == 1)
        .toList();

    expect(letters, ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
  });

  testWidgets(
    'en anglais : erreur réseau affiche le texte du catalogue, jamais le '
    'message brut',
    (tester) async {
      useEnglish();
      whenListen<TripRecurrenceState>(
        bloc,
        Stream.value(
          const TripRecurrenceState(
            status: TripRecurrenceStatus.error,
            error: NetworkException('raw technical detail'),
          ),
        ),
        initialState: const TripRecurrenceState(),
      );

      await tester.pumpWidget(
        _wrap(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('raw technical detail'), findsNothing);
    },
  );

  // Le bug : l'écran n'envoyait aucune devise, le serveur retenait l'euro même
  // pour un modèle en franc CFA.
  group('devise du modèle', () {
    testWidgets('modèle XOF : devise envoyée, prix affiché en F CFA, carte '
        'indisponible donc non envoyée', (tester) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(
            template: _template(pricePerKg: 5000, currency: 'XOF'),
          ),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('F CFA'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);

      final data = await _fillAndSubmit(tester, bloc);
      expect(data['currency'], 'XOF');
      expect(data['pricePerKg'], 5000);
      expect(data.containsKey('cardAccepted'), isFalse);
      expect(data['cashAccepted'], isTrue);
    });

    testWidgets('modèle XAF en minuscules : code normalisé', (tester) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(
            template: _template(pricePerKg: 4000, currency: 'xaf'),
          ),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final data = await _fillAndSubmit(tester, bloc);
      expect(data['currency'], 'XAF');
    });

    testWidgets('modèle sans devise : devise active, sinon euro', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final data = await _fillAndSubmit(tester, bloc);
      expect(data['currency'], 'EUR');
      expect(data['cardAccepted'], isTrue);
    });
  });

  group('FLUTTER-FT : carte décochable', () {
    testWidgets('Stripe prêt : carte cochée par défaut, envoyée acceptée', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final card = tester.widget<SwitchListTile>(
        find.byKey(const Key('recurrence-payment-card')),
      );
      expect(card.value, isTrue);
      expect(find.byKey(const Key('recurrence-card-off-help')), findsNothing);

      final data = await _fillAndSubmit(tester, bloc);
      expect(data['cardAccepted'], isTrue);
      expect(data['cashAccepted'], isFalse);
    });

    testWidgets(
      'carte décochée : texte d\'aide du trajet simple, espèces imposées',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithStripe(
            TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
            bloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        final card = find.byKey(const Key('recurrence-payment-card'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('recurrence-card-off-help')),
          findsOneWidget,
        );
        expect(
          find.text(
            "Sans carte, ce trajet n'aura pas de paiement protégé en ligne : "
            "l'argent n'est plus séquestré jusqu'à la livraison.",
          ),
          findsOneWidget,
        );
        final cash = tester.widget<SwitchListTile>(
          find.byKey(const Key('recurrence-payment-cash')),
        );
        expect(cash.value, isTrue);

        final data = await _fillAndSubmit(tester, bloc);
        expect(data['cardAccepted'], isFalse);
        expect(data['cashAccepted'], isTrue);
        // Laisse expirer le rappel « au moins un moyen de paiement ».
        await tester.pump(const Duration(seconds: 10));
      },
    );

    testWidgets('espèces verrouillées sans carte : un toucher explique', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final card = find.byKey(const Key('recurrence-payment-card'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 300));

      final cash = find.byKey(const Key('recurrence-payment-cash'));
      await tester.ensureVisible(cash);
      await tester.tap(cash);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('les espèces restent toujours acceptées'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(cash).value, isTrue);
    });

    testWidgets('espèces du modèle décochables tant que la carte reste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(
            template: _template(pricePerKg: 8.0, cashAccepted: true),
          ),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final cash = find.byKey(const Key('recurrence-payment-cash'));
      await tester.ensureVisible(cash);
      await tester.tap(cash);
      await tester.pump(const Duration(milliseconds: 300));

      final data = await _fillAndSubmit(tester, bloc);
      expect(data['cardAccepted'], isTrue);
      expect(data['cashAccepted'], isFalse);
    });

    testWidgets('Stripe non configuré : choix non envoyé, espèces imposées', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
          status: 'ONBOARDING_INCOMPLETE',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('recurrence-payment-card')),
            )
            .value,
        isFalse,
      );
      expect(
        find.text('Non configuré, activez pour proposer le paiement sécurisé'),
        findsOneWidget,
      );

      final data = await _fillAndSubmit(tester, bloc);
      expect(data.containsKey('cardAccepted'), isFalse);
      expect(data['cashAccepted'], isTrue);
    });

    testWidgets('anglais : section paiement traduite', (tester) async {
      useEnglish();
      await tester.pumpWidget(
        _wrapWithStripe(
          TripRecurrenceEditScreen(template: _template(pricePerKg: 8.0)),
          bloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Accepted payment methods'), findsOneWidget);
      expect(find.text('Card payment (Stripe)'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });
  });
}
