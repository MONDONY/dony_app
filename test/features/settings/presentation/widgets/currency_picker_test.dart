import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/currency_test_doubles.dart';

void main() {
  late MockBusinessPrefsBloc bloc;

  setUpAll(() {
    registerFallbackValue(const CurrencyChanged('EUR'));
  });

  setUp(() {
    bloc = stubBusinessPrefsBloc();
  });

  Widget wrap(void Function(BuildContext) onTrigger) =>
      BlocProvider<BusinessPrefsBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => onTrigger(context),
                      child: const Text('Trigger'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  group('CurrencyPicker.show', () {
    testWidgets('liste toutes les devises du catalogue', (tester) async {
      await tester.pumpWidget(wrap(CurrencyPicker.show));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Devise d\'affichage'), findsOneWidget);
      expect(find.text('Euro (EUR)'), findsOneWidget);
      expect(find.text('Franc CFA Ouest (XOF)'), findsOneWidget);
      expect(find.text('Franc CFA Centre (XAF)'), findsOneWidget);
    });

    testWidgets('taper la devise déjà active ferme le picker sans dialogue', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(CurrencyPicker.show));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Euro (EUR)'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de devise'), findsNothing);
      verifyNever(() => bloc.changeCurrency(any()));
    });

    testWidgets(
      'taper une devise différente puis confirmer envoie CurrencyChanged',
      (tester) async {
        await tester.pumpWidget(wrap(CurrencyPicker.show));
        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Franc CFA Centre (XAF)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Changer pour XAF'));
        await tester.pumpAndSettle();

        verify(() => bloc.changeCurrency('XAF')).called(1);
      },
    );

    testWidgets('annuler le dialogue n\'envoie jamais CurrencyChanged', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(CurrencyPicker.show));
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Franc CFA Centre (XAF)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.changeCurrency(any()));
    });
  });

  group('CurrencyPicker.switchTo', () {
    testWidgets('cible = devise active : aucun dialogue, aucun événement', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap((c) => CurrencyPicker.switchTo(c, SupportedCurrency.eur)),
      );
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Changer de devise'), findsNothing);
      verifyNever(() => bloc.changeCurrency(any()));
    });

    testWidgets(
      'cible différente : dialogue de confirmation puis CurrencyChanged',
      (tester) async {
        await tester.pumpWidget(
          wrap((c) => CurrencyPicker.switchTo(c, SupportedCurrency.xaf)),
        );
        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(find.text('Changer de devise'), findsOneWidget);
        await tester.tap(find.text('Changer pour XAF'));
        await tester.pumpAndSettle();

        verify(() => bloc.changeCurrency('XAF')).called(1);
      },
    );

    testWidgets('annuler ne dispatch rien', (tester) async {
      await tester.pumpWidget(
        wrap((c) => CurrencyPicker.switchTo(c, SupportedCurrency.xaf)),
      );
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.changeCurrency(any()));
    });
  });
}
