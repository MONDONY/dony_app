// `MainShell` monte trop de dépendances (GoRouter, getIt, une dizaine de
// BLoCs) pour être testé isolément ici — voir `_DonyBottomNav` dans
// `main_shell.dart`, privée à ce fichier. On vérifie donc la traduction des
// libellés d'onglets via `DonyNavItem`, l'unité qui les affiche réellement,
// alimentée par les mêmes clés `context.l10n.shellTab…` que `main_shell.dart`.
import 'package:dony/app/widgets/dony_nav_item.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/l10n_test_helpers.dart';

void main() {
  Widget buildTabs() => localizedApp(
    Builder(
      builder: (context) => Row(
        children: [
          DonyNavItem(
            iconAsset: 'search',
            label: context.l10n.shellTabSearch,
            index: 0,
            currentIndex: 0,
            onTap: () {},
          ),
          DonyNavItem(
            iconAsset: 'layout-grid',
            label: context.l10n.shellTabActivity,
            index: 1,
            currentIndex: 0,
            onTap: () {},
          ),
          DonyNavItem(
            iconAsset: 'message-circle',
            label: context.l10n.shellTabMessages,
            index: 2,
            currentIndex: 0,
            onTap: () {},
          ),
          DonyNavItem(
            iconAsset: 'user',
            label: context.l10n.shellTabProfile,
            index: 3,
            currentIndex: 0,
            onTap: () {},
          ),
        ],
      ),
    ),
    locale: AppL10n.en,
  );

  testWidgets('onglets de la barre de navigation traduits en anglais '
      '(Activity, Search, Messages, Profile)', (tester) async {
    await tester.pumpWidget(buildTabs());

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
