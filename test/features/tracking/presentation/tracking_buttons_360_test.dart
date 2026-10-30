// Règle « libellé de bouton sur une ligne » (CLAUDE.md racine) pour les
// boutons du suivi approximatif du voyageur : à 360 dp, en FR et en EN, à
// l'échelle de texte 1.0 et 1.3, le libellé ne passe ni sur deux lignes, ni
// en débordement, ni rétréci par le FittedBox(scaleDown) de DonyButton, et le
// bouton garde la hauteur d'un bouton à libellé court.
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/trip_depart_button.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_consent_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockDepart extends MockCubit<TripDepartState>
    implements TripDepartCubit {}

class _Metrics {
  _Metrics(
    this.label,
    this.buttonHeight,
    this.textWidth,
    this.boxWidth,
    this.paragraphHeight,
    this.fontSize,
  );
  final String label;
  final double buttonHeight;
  final double textWidth;
  final double boxWidth;
  final double paragraphHeight;
  final double fontSize;
  @override
  String toString() =>
      '"$label" bouton ${buttonHeight}dp, texte ${textWidth.toStringAsFixed(1)}'
      ' / boîte ${boxWidth.toStringAsFixed(1)}, ligne '
      '${paragraphHeight.toStringAsFixed(1)} (police ${fontSize}px)';
}

/// Mesures du DonyButton [button] : le texte est-il rétréci par le FittedBox ?
_Metrics _measure(WidgetTester tester, Finder button) {
  final fitted = find.descendant(of: button, matching: find.byType(FittedBox));
  expect(fitted, findsOneWidget, reason: 'FittedBox du label introuvable');
  final rf = tester.renderObject<RenderFittedBox>(fitted);
  final text = find.descendant(of: fitted, matching: find.byType(Text));
  final rp = tester.renderObject<RenderParagraph>(text);
  final style = tester.widget<Text>(text);
  final fontSize =
      DefaultTextStyle.of(tester.element(text)).style.fontSize ?? 14;
  // Un seul rendu de ligne : getBoxesForSelection compte les lignes.
  final lines = rp
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: style.data!.length),
      )
      .map((b) => b.top)
      .toSet()
      .length;
  expect(lines, 1, reason: 'le libellé "${style.data}" est sur $lines lignes');
  return _Metrics(
    style.data!,
    tester.getSize(button.first).height,
    rf.child!.size.width,
    rf.size.width,
    rp.size.height,
    fontSize,
  );
}

/// Polices embarquées de l'app : sans elles les tests rendent en Ahem (1 em
/// par caractère), ce qui fausserait la mesure des libellés.
Future<void> _loadAppFonts() async {
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

void main() {
  setUpAll(_loadAppFonts);

  const locales = [AppL10n.fr, AppL10n.en];
  const scales = [1.0, 1.3];

  Widget app(Widget home, Locale locale, double scale) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  void phone360(WidgetTester tester) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Bouton de référence (libellé court) du même type, même échelle.
  Future<double> referenceHeight(
    WidgetTester tester,
    Locale locale,
    double scale, {
    DonyButtonVariant variant = DonyButtonVariant.primary,
  }) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DonyButton(label: 'OK', variant: variant, onPressed: () {}),
          ),
        ),
        locale,
        scale,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return tester.getSize(find.byType(DonyButton)).height;
  }

  void expectRule(_Metrics m, double refHeight) {
    expect(
      m.textWidth,
      lessThanOrEqualTo(m.boxWidth + 0.01),
      reason: 'libellé rétréci par le FittedBox : $m',
    );
    expect(
      m.buttonHeight,
      refHeight,
      reason: 'hauteur différente du bouton court : $m',
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  for (final locale in locales) {
    for (final scale in scales) {
      final tag = '${locale.languageCode} x$scale';

      group('360 dp, $tag', () {
        testWidgets('feuille de consentement : Autoriser et Pas maintenant', (
          tester,
        ) async {
          phone360(tester);
          final ref = await referenceHeight(tester, locale, scale);
          final refSecondary = await referenceHeight(
            tester,
            locale,
            scale,
            variant: DonyButtonVariant.secondary,
          );
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => TrackingConsentSheet.show(context),
                    child: const Text('ouvrir'),
                  ),
                ),
              ),
              locale,
              scale,
            ),
          );
          await tester.tap(find.text('ouvrir'));
          await settle(tester);

          final accept = _measure(
            tester,
            find.byKey(const Key('tracking-consent-accept')),
          );
          final decline = _measure(
            tester,
            find.byKey(const Key('tracking-consent-decline')),
          );
          expectRule(accept, ref);
          expectRule(decline, refSecondary);
          expect(tester.takeException(), isNull);
          debugPrint('[$tag] $accept | $decline');
        });

        testWidgets('Je pars / I\'m leaving', (tester) async {
          phone360(tester);
          final ref = await referenceHeight(tester, locale, scale);
          final cubit = _MockDepart();
          whenListen(
            cubit,
            const Stream<TripDepartState>.empty(),
            initialState: const TripDepartState(),
          );
          await tester.pumpWidget(
            app(
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  // Pied du sheet « Je pars », sur le cubit de l'écran.
                  child: BlocProvider<TripDepartCubit>.value(
                    value: cubit,
                    child: const TripDepartAction(),
                  ),
                ),
              ),
              locale,
              scale,
            ),
          );
          await settle(tester);
          final m = _measure(
            tester,
            find.byKey(const Key('trip-depart-button')),
          );
          expectRule(m, ref);
          expect(tester.takeException(), isNull);
          debugPrint('[$tag] $m');
        });

        // Le « lien » vers la frise est en réalité un DonyButton secondaire
        // dans le stickyBottom du sheet Suivi (sender_tile_sheets.dart) : on
        // monte le même bouton, même libellé, dans un vrai DonyBottomSheet.
        testWidgets('Voir toutes les étapes et photos', (tester) async {
          phone360(tester);
          final ref = await referenceHeight(
            tester,
            locale,
            scale,
            variant: DonyButtonVariant.secondary,
          );
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => DonyBottomSheet.show<void>(
                      context,
                      title: 'Suivi',
                      stickyBottom: DonyButton(
                        key: const Key('timeline-button'),
                        label: context.l10n.travelerTrackingOpenTimeline,
                        variant: DonyButtonVariant.secondary,
                        onPressed: () {},
                      ),
                      child: const SizedBox(height: 40),
                    ),
                    child: const Text('ouvrir'),
                  ),
                ),
              ),
              locale,
              scale,
            ),
          );
          await tester.tap(find.text('ouvrir'));
          await settle(tester);
          final m = _measure(tester, find.byKey(const Key('timeline-button')));
          expectRule(m, ref);
          expect(tester.takeException(), isNull);
          debugPrint('[$tag] $m');
        });
      });
    }
  }
}
