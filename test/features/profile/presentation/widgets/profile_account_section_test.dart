import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _userWithPhoneAndEmail = UserModel(
  id: 'user-1',
  firstName: 'Amadou',
  lastName: 'Diallo',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
  phoneNumber: '+221701234567',
  email: 'amadou@example.com',
);

const _userWithNothing = UserModel(
  id: 'user-2',
  roles: ['SENDER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

Widget _app(UserModel user) =>
    MaterialApp(home: Scaffold(body: ProfileAccountSection(user: user)));

void main() {
  setUp(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));
  tearDown(() => setSmsAuthEnabled(kSmsAuthEnabledDefault));

  testWidgets(
    'masque la ligne TÉLÉPHONE tant que le SMS OTP backend n\'est pas confirmé',
    (tester) async {
      await tester.pumpWidget(_app(_userWithNothing));
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsNothing);
    },
  );

  testWidgets(
    'affiche la ligne TÉLÉPHONE (à ajouter) une fois le SMS OTP confirmé, si aucun numéro',
    (tester) async {
      setSmsAuthEnabled(true);

      await tester.pumpWidget(_app(_userWithNothing));
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsOneWidget);
      expect(find.text('Non ajouté'), findsWidgets);
    },
  );

  testWidgets(
    'masque la ligne TÉLÉPHONE une fois le numéro renseigné, même SMS OTP confirmé',
    (tester) async {
      setSmsAuthEnabled(true);

      await tester.pumpWidget(_app(_userWithPhoneAndEmail));
      await tester.pump();

      expect(find.text('TÉLÉPHONE'), findsNothing);
      expect(find.text('+221701234567'), findsNothing);
    },
  );

  testWidgets('affiche la ligne E-MAIL tant qu\'aucun email n\'est renseigné', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_userWithNothing));
    await tester.pump();

    expect(find.text('E-MAIL'), findsOneWidget);
    expect(find.text('Non ajouté'), findsOneWidget);
  });

  testWidgets('masque la ligne E-MAIL une fois l\'email renseigné', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_userWithPhoneAndEmail));
    await tester.pump();

    expect(find.text('E-MAIL'), findsNothing);
    expect(find.text('amadou@example.com'), findsNothing);
  });

  testWidgets('affiche « Documents d\'identité » tant que le KYC n\'est pas VERIFIED', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_userWithNothing));
    await tester.pump();

    expect(find.text('Documents d\'identité'), findsOneWidget);
  });

  testWidgets('masque « Documents d\'identité » une fois le KYC VERIFIED', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const UserModel(
          id: 'user-3',
          roles: ['SENDER'],
          kycStatus: 'VERIFIED',
          status: 'ACTIVE',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Documents d\'identité'), findsNothing);
  });

  testWidgets(
    'section « MON COMPTE » entièrement masquée quand KYC vérifié + email renseigné + '
    'téléphone renseigné (SMS OTP confirmé)',
    (tester) async {
      setSmsAuthEnabled(true);

      await tester.pumpWidget(
        _app(
          const UserModel(
            id: 'user-4',
            roles: ['SENDER'],
            kycStatus: 'VERIFIED',
            status: 'ACTIVE',
            phoneNumber: '+221701234567',
            email: 'amadou@example.com',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MON COMPTE'), findsNothing);
      expect(find.text('Documents d\'identité'), findsNothing);
      expect(find.text('TÉLÉPHONE'), findsNothing);
      expect(find.text('E-MAIL'), findsNothing);
    },
  );
}
