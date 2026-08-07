import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = UserModel(
  id: 'user-1',
  firstName: 'Amadou',
  lastName: 'Diallo',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  phoneNumber: '+221701234567',
  email: 'amadou@example.com',
);

Widget _app(UserModel user) =>
    MaterialApp(home: Scaffold(body: ProfileAccountSection(user: user)));

void main() {
  setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets(
    'masque la ligne TÉLÉPHONE tant que le SMS OTP backend n\'est pas confirmé',
    (tester) async {
      await tester.pumpWidget(_app(_user));
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsNothing);
      expect(find.text('+221701234567'), findsNothing);
      expect(find.text('E-MAIL'), findsOneWidget);
    },
  );

  testWidgets(
    'affiche la ligne TÉLÉPHONE une fois le SMS OTP confirmé par le backend',
    (tester) async {
      setSmsAuthEnabled(true);

      await tester.pumpWidget(_app(_user));
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsOneWidget);
      expect(find.text('+221701234567'), findsOneWidget);
      expect(find.text('E-MAIL'), findsOneWidget);
    },
  );

  testWidgets(
    'la ligne E-MAIL reste seule visible même sans email renseigné quand le SMS est désactivé',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const UserModel(
            id: 'user-2',
            roles: ['SENDER'],
            kycStatus: 'NOT_STARTED',
            status: 'ACTIVE',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsNothing);
      expect(find.text('E-MAIL'), findsOneWidget);
      expect(find.text('Non ajouté'), findsOneWidget);
    },
  );
}
