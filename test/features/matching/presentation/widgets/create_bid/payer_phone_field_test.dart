import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  Widget wrap({required bool hasProfilePhone}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: PayerPhoneField(
        controller: controller,
        hasProfilePhone: hasProfilePhone,
      ),
    ),
  );

  testWidgets(
    'hasProfilePhone à vrai affiche le texte d\'aide du pré-remplissage',
    (tester) async {
      await tester.pumpWidget(wrap(hasProfilePhone: true));

      expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
      expect(
        find.textContaining('Par défaut, ton numéro Yadony'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'hasProfilePhone à faux affiche le texte d\'aide du compte sans numéro',
    (tester) async {
      await tester.pumpWidget(wrap(hasProfilePhone: false));

      expect(find.byKey(const Key('payer-phone-field')), findsOneWidget);
      expect(
        find.textContaining('Ton compte n\'a pas de numéro'),
        findsOneWidget,
      );
    },
  );
}
