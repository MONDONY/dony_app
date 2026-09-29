import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/presentation/widgets/android_sms_code_retriever.dart';
import 'package:dony/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinput/pinput.dart';

/// Remplace l'API SMS Retriever : rend le code comme si Google avait remis le
/// SMS à l'app.
class _FakeSmsRetriever implements SmsRetriever {
  _FakeSmsRetriever(this.code);

  final String? code;
  var disposed = false;

  @override
  bool get listenForMultipleSms => false;

  @override
  Future<String?> getSmsCode() async => code;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Widget wrap({
    ValueChanged<String>? onCompleted,
    SmsRetriever? smsRetriever,
    bool readSms = false,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: OtpCodeField(
          controller: controller,
          onCompleted: onCompleted,
          readSms: readSms,
          smsRetriever: smsRetriever,
        ),
      ),
    ),
  );

  // Sans cet indice, le téléphone ne propose pas le code reçu par SMS au-dessus
  // du clavier : les testeurs allaient le chercher dans Messages, où iOS range
  // les expéditeurs inconnus hors de la liste principale.
  testWidgets('déclare le remplissage automatique d\'un code à usage unique', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(Pinput),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
  });

  // Les six anciennes cases acceptaient un chiffre chacune : un code collé ou
  // rempli d'un bloc était tronqué au premier chiffre.
  testWidgets('un code arrivé d\'un bloc remplit les six cases', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(wrap(onCompleted: (code) => completed = code));

    await tester.enterText(find.byType(Pinput), '482913');
    await tester.pump();

    expect(controller.text, '482913');
    expect(completed, '482913');
    for (final digit in '482913'.split('')) {
      expect(find.text(digit), findsOneWidget);
    }
  });

  testWidgets('ne rend la main qu\'aux six chiffres, et refuse les lettres', (
    tester,
  ) async {
    String? completed;
    await tester.pumpWidget(wrap(onCompleted: (code) => completed = code));

    await tester.enterText(find.byType(Pinput), '48a2');
    await tester.pump();

    expect(controller.text, isNot(contains('a')));
    expect(completed, isNull);
  });

  // Android : le SMS de connexion porte l'empreinte de l'app, Google le remet
  // directement, le code se remplit et la vérification part sans aucun geste.
  testWidgets('un code lu dans le SMS remplit le champ et termine la saisie', (
    tester,
  ) async {
    String? completed;
    final retriever = _FakeSmsRetriever('482913');
    await tester.pumpWidget(
      wrap(
        onCompleted: (code) => completed = code,
        smsRetriever: retriever,
        readSms: true,
      ),
    );
    await tester.pump();

    expect(controller.text, '482913');
    expect(completed, '482913');
  });

  testWidgets('libère l\'écoute du SMS quand le champ disparaît', (
    tester,
  ) async {
    final retriever = _FakeSmsRetriever(null);
    await tester.pumpWidget(wrap(smsRetriever: retriever, readSms: true));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(retriever.disposed, isTrue);
    expect(controller.text, isEmpty);
  });

  // Un code reçu par e-mail ne transite pas par SMS : rien à écouter.
  testWidgets('n\'écoute pas les SMS pour un code envoyé par e-mail', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    final pinput = tester.widget<Pinput>(find.byType(Pinput));
    expect(pinput.smsRetriever, isNull);
  });

  test('le motif ne retient que six chiffres isolés, pas une empreinte', () {
    final matcher = RegExp(AndroidSmsCodeRetriever.codeMatcher);
    const sms =
        'Ton code Yadony est : 482913. Valable 10 minutes.\nQR5XSgGkFEN';

    expect(matcher.firstMatch(sms)?.group(0), '482913');
    expect(matcher.hasMatch('QR5XSgGkFEN AB12345678CD'), isFalse);
  });
}
