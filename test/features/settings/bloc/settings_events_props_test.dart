// Tests covering the props() getters on event/state classes to hit
// the abstract base class overrides that are otherwise uncovered.
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataExportEvent props', () {
    test('DataExportRequested == DataExportRequested (calls props)', () {
      const a = DataExportRequested();
      const b = DataExportRequested();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });
  });

  group('DiagnosticsEvent props', () {
    test('DiagnosticsLoadRequested == DiagnosticsLoadRequested (calls props)',
        () {
      const a = DiagnosticsLoadRequested();
      const b = DiagnosticsLoadRequested();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('ApiPingRequested == ApiPingRequested (calls props)', () {
      const a = ApiPingRequested();
      const b = ApiPingRequested();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });
  });

  group('PrivacySettingsEvent props', () {
    test('HidePhoneToggled == HidePhoneToggled (calls props)', () {
      const a = HidePhoneToggled();
      const b = HidePhoneToggled();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('ProfileVisibilityChanged props are correct', () {
      const a = ProfileVisibilityChanged('public');
      const b = ProfileVisibilityChanged('public');
      expect(a, equals(b));
      expect(a.props, equals(['public']));
    });

    test('ProfileVisibilityChanged with different values are not equal', () {
      const a = ProfileVisibilityChanged('public');
      const b = ProfileVisibilityChanged('limited');
      expect(a, isNot(equals(b)));
    });
  });

  group('AccessibilityEvent props', () {
    test('HighContrastToggled == HighContrastToggled (calls props)', () {
      const a = HighContrastToggled();
      const b = HighContrastToggled();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('ReduceAnimationsToggled == ReduceAnimationsToggled (calls props)',
        () {
      const a = ReduceAnimationsToggled();
      const b = ReduceAnimationsToggled();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('TextScaleChanged props are correct', () {
      const a = TextScaleChanged('large');
      const b = TextScaleChanged('large');
      expect(a, equals(b));
      expect(a.props, equals(['large']));
    });
  });

  group('NotificationPrefsEvent props', () {
    test('NotifPrefToggled props are correct', () {
      const a = NotifPrefToggled('push_payment');
      const b = NotifPrefToggled('push_payment');
      expect(a, equals(b));
      expect(a.props, equals(['push_payment']));
    });

    test('NotifPrefToggled with different keys are not equal', () {
      const a = NotifPrefToggled('push_payment');
      const b = NotifPrefToggled('sms_payment');
      expect(a, isNot(equals(b)));
    });
  });

  group('BusinessPrefsEvent props', () {
    test('WeightUnitChanged props are correct', () {
      const a = WeightUnitChanged('lbs');
      const b = WeightUnitChanged('lbs');
      expect(a, equals(b));
      expect(a.props, equals(['lbs']));
    });

    test('CurrencyChanged props are correct', () {
      const a = CurrencyChanged('XOF');
      const b = CurrencyChanged('XOF');
      expect(a, equals(b));
      expect(a.props, equals(['XOF']));
    });

    test('PickupRadiusChanged props are correct', () {
      const a = PickupRadiusChanged(25);
      const b = PickupRadiusChanged(25);
      expect(a, equals(b));
      expect(a.props, equals([25]));
    });

    test('PickupRadiusChanged with different values are not equal', () {
      const a = PickupRadiusChanged(10);
      const b = PickupRadiusChanged(20);
      expect(a, isNot(equals(b)));
    });
  });

  group('AccountDeletionEvent props', () {
    test('RequestDeletion == RequestDeletion (calls props)', () {
      const a = RequestDeletion();
      const b = RequestDeletion();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('ReactivateAccount == ReactivateAccount (calls props)', () {
      const a = ReactivateAccount();
      const b = ReactivateAccount();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('RequestOtpForImmediateDeletion == RequestOtpForImmediateDeletion',
        () {
      const a = RequestOtpForImmediateDeletion();
      const b = RequestOtpForImmediateDeletion();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });

    test('ConfirmImmediateDeletion props are correct', () {
      const a = ConfirmImmediateDeletion(
        verificationId: 'vid',
        smsCode: '123456',
      );
      const b = ConfirmImmediateDeletion(
        verificationId: 'vid',
        smsCode: '123456',
      );
      expect(a, equals(b));
      expect(a.props, equals(['vid', '123456']));
    });

    test('ConfirmImmediateDeletion with different codes are not equal', () {
      const a = ConfirmImmediateDeletion(
        verificationId: 'vid',
        smsCode: '111111',
      );
      const b = ConfirmImmediateDeletion(
        verificationId: 'vid',
        smsCode: '222222',
      );
      expect(a, isNot(equals(b)));
    });
  });
}
