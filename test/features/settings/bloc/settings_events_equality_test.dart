// Constructeurs appelés à l'exécution : un appel `const` n'est jamais exécuté
// et deux instances `const` identiques court-circuitent la comparaison.
// ignore_for_file: prefer_const_constructors

import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/bloc/privacy_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/value_equality.dart';

void main() {
  group('PrivacySettingsEvent — égalité manuelle', () {
    test('bascules : égales à valeur égale, distinctes sinon et par type', () {
      expectValueEquality(() => ShowResidenceCountryToggled(true), [
        ShowResidenceCountryToggled(false),
        ShowLastSeenToggled(true),
      ]);
      expectValueEquality(() => ShowLastSeenToggled(false), [
        ShowLastSeenToggled(true),
        HidePhoneNumberToggled(false),
      ]);
      expectValueEquality(() => ContactKycOnlyToggled(true), [
        ContactKycOnlyToggled(false),
      ]);
    });

    test('chargement : un événement à construire sans champ', () {
      expect(PrivacySettingsLoadRequested(), isA<PrivacySettingsEvent>());
    });
  });

  group('PrivacySettingsLoaded — égalité manuelle', () {
    test('chaque réglage participe à l’égalité et au hashCode', () {
      PrivacySettingsLoaded make() =>
          PrivacySettingsLoaded(contactKycOnly: true, hidePhoneNumber: true);
      expectValueEquality(make, [
        make().copyWith(contactKycOnly: false),
        make().copyWith(hidePhoneNumber: false),
        make().copyWith(saveFailed: true),
        make().copyWith(showResidenceCountry: true),
        make().copyWith(showLastSeen: false),
      ]);
    });
  });

  group('ConnectedDevicesEvent — égalité de valeur', () {
    test('chargement et révocation globale : sans champ, distincts', () {
      expectValueEquality(() => DevicesLoadRequested(), [
        AllOthersRevokeRequested(),
      ]);
      expectValueEquality(() => AllOthersRevokeRequested(), [
        DevicesLoadRequested(),
      ]);
      expect(DevicesLoadRequested().props, isEmpty);
    });

    test('révocation d’un appareil : identifiant', () {
      expectValueEquality(() => DeviceRevokeRequested('d-1'), [
        DeviceRevokeRequested('d-2'),
      ]);
    });
  });

  group('AccessibilityEvent — égalité de valeur', () {
    test('réglages à valeur unique', () {
      expectValueEquality(() => TextScaleFactorChanged(1.2), [
        TextScaleFactorChanged(1.4),
      ]);
      expectValueEquality(() => ReduceMotionModeChanged('ON'), [
        ReduceMotionModeChanged('SYSTEM'),
        HighContrastModeChanged('ON'),
      ]);
      expectValueEquality(() => UnderlineLinksToggled(true), [
        UnderlineLinksToggled(false),
      ]);
      expectValueEquality(() => ReinforceLabelsToggled(true), [
        ReinforceLabelsToggled(false),
      ]);
      expectValueEquality(() => PersistentMessagesToggled(true), [
        PersistentMessagesToggled(false),
      ]);
      expectValueEquality(() => ConfirmImportantActionsToggled(true), [
        ConfirmImportantActionsToggled(false),
        PersistentMessagesToggled(true),
      ]);
    });

    test('réinitialisation : sans champ', () {
      expectValueEquality(() => AccessibilityResetRequested(), [
        BoldTextToggled(true),
      ]);
      expect(AccessibilityResetRequested().props, isEmpty);
    });
  });

  group('AccountDeletionEvent — égalité de valeur', () {
    test('trois demandes sans champ, distinctes par type', () {
      expectValueEquality(() => RequestDeletion(), [
        ReactivateAccount(),
        ConfirmImmediateDeletion(),
      ]);
      expectValueEquality(() => ReactivateAccount(), [RequestDeletion()]);
      expectValueEquality(() => ConfirmImmediateDeletion(), [
        ReactivateAccount(),
      ]);
    });
  });

  group('DiagnosticsEvent — égalité de valeur', () {
    test('chargement et ping : sans champ, distincts', () {
      expectValueEquality(() => DiagnosticsLoadRequested(), [
        ApiPingRequested(),
      ]);
      expectValueEquality(() => ApiPingRequested(), [
        DiagnosticsLoadRequested(),
      ]);
    });
  });
}
