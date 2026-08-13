// Tests covering the props() getters on event/state classes to hit
// the abstract base class overrides that are otherwise uncovered.
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/data_export_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/notification_prefs_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
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
    test(
      'DiagnosticsLoadRequested == DiagnosticsLoadRequested (calls props)',
      () {
        const a = DiagnosticsLoadRequested();
        const b = DiagnosticsLoadRequested();
        expect(a, equals(b));
        expect(a.props, isEmpty);
      },
    );

    test('ApiPingRequested == ApiPingRequested (calls props)', () {
      const a = ApiPingRequested();
      const b = ApiPingRequested();
      expect(a, equals(b));
      expect(a.props, isEmpty);
    });
  });

  group('PrivacySettingsEvent', () {
    test('PrivacySettingsLoadRequested == PrivacySettingsLoadRequested', () {
      const a = PrivacySettingsLoadRequested();
      const b = PrivacySettingsLoadRequested();
      expect(a, equals(b));
    });

    test('ContactKycOnlyToggled with same value are equal', () {
      const a = ContactKycOnlyToggled(true);
      const b = ContactKycOnlyToggled(true);
      expect(a, equals(b));
    });

    test('ContactKycOnlyToggled with different values are not equal', () {
      const a = ContactKycOnlyToggled(true);
      const b = ContactKycOnlyToggled(false);
      expect(a, isNot(equals(b)));
    });
  });

  group('AccessibilityEvent props', () {
    // Ancien HighContrastToggled() sans argument -> tri-état avec successeur.
    test('HighContrastModeChanged props are correct', () {
      const a = HighContrastModeChanged(AccessibilityMode.on);
      const b = HighContrastModeChanged(AccessibilityMode.on);
      expect(a, equals(b));
      expect(a.props, equals([AccessibilityMode.on]));
    });

    test('HighContrastModeChanged with different modes are not equal', () {
      const a = HighContrastModeChanged(AccessibilityMode.on);
      const b = HighContrastModeChanged(AccessibilityMode.off);
      expect(a, isNot(equals(b)));
    });

    // Ancien ReduceAnimationsToggled() sans argument -> tri-état avec successeur.
    test('ReduceMotionModeChanged props are correct', () {
      const a = ReduceMotionModeChanged(AccessibilityMode.system);
      const b = ReduceMotionModeChanged(AccessibilityMode.system);
      expect(a, equals(b));
      expect(a.props, equals([AccessibilityMode.system]));
    });

    test('ReduceMotionModeChanged with different modes are not equal', () {
      const a = ReduceMotionModeChanged(AccessibilityMode.on);
      const b = ReduceMotionModeChanged(AccessibilityMode.off);
      expect(a, isNot(equals(b)));
    });

    // Ancien TextScaleChanged('large') -> scindé en deux events dans le
    // nouvel état (suivre le système, ou facteur explicite).
    test('FollowSystemTextScaleToggled props are correct', () {
      const a = FollowSystemTextScaleToggled(true);
      const b = FollowSystemTextScaleToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test(
      'FollowSystemTextScaleToggled with different values are not equal',
      () {
        const a = FollowSystemTextScaleToggled(true);
        const b = FollowSystemTextScaleToggled(false);
        expect(a, isNot(equals(b)));
      },
    );

    test('TextScaleFactorChanged props are correct', () {
      const a = TextScaleFactorChanged(1.3);
      const b = TextScaleFactorChanged(1.3);
      expect(a, equals(b));
      expect(a.props, equals([1.3]));
    });

    test('TextScaleFactorChanged with different values are not equal', () {
      const a = TextScaleFactorChanged(1.0);
      const b = TextScaleFactorChanged(1.6);
      expect(a, isNot(equals(b)));
    });

    // Reste des events tri-état / booléens du nouvel AccessibilityState,
    // pas couverts ailleurs.
    test('BoldTextToggled props are correct', () {
      const a = BoldTextToggled(true);
      const b = BoldTextToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test('UnderlineLinksToggled props are correct', () {
      const a = UnderlineLinksToggled(true);
      const b = UnderlineLinksToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test('ReinforceLabelsToggled props are correct', () {
      const a = ReinforceLabelsToggled(true);
      const b = ReinforceLabelsToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test('PersistentMessagesToggled props are correct', () {
      const a = PersistentMessagesToggled(true);
      const b = PersistentMessagesToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test('ConfirmImportantActionsToggled props are correct', () {
      const a = ConfirmImportantActionsToggled(true);
      const b = ConfirmImportantActionsToggled(true);
      expect(a, equals(b));
      expect(a.props, equals([true]));
    });

    test('AccessibilityResetRequested == AccessibilityResetRequested '
        '(calls props)', () {
      const a = AccessibilityResetRequested();
      const b = AccessibilityResetRequested();
      expect(a, equals(b));
      expect(a.props, isEmpty);
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

    test(
      'ConfirmImmediateDeletion == ConfirmImmediateDeletion (calls props)',
      () {
        const a = ConfirmImmediateDeletion();
        const b = ConfirmImmediateDeletion();
        expect(a, equals(b));
        expect(a.props, isEmpty);
      },
    );
  });
}
