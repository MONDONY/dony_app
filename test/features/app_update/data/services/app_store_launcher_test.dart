import 'package:dony/features/app_update/data/services/app_store_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';

class _FakePlayClient implements PlayUpdateClient {
  _FakePlayClient({
    this.availability = UpdateAvailability.updateAvailable,
    this.immediateAllowed = true,
    this.result = AppUpdateResult.success,
    this.checkError,
  });

  final UpdateAvailability availability;
  final bool immediateAllowed;
  final AppUpdateResult result;
  final Object? checkError;
  int immediateCalls = 0;

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    if (checkError != null) throw checkError!;
    return AppUpdateInfo(
      updateAvailability: availability,
      immediateUpdateAllowed: immediateAllowed,
      immediateAllowedPreconditions: null,
      flexibleUpdateAllowed: true,
      flexibleAllowedPreconditions: null,
      availableVersionCode: 99,
      installStatus: InstallStatus.unknown,
      packageName: 'com.yadony.yadony',
      clientVersionStalenessDays: null,
      updatePriority: 0,
    );
  }

  @override
  Future<AppUpdateResult> performImmediateUpdate() async {
    immediateCalls++;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

  late List<MethodCall> urlCalls;
  late List<MethodCall> storeCalls;

  void setUp0({bool canLaunch = true, Object? overlay = true}) {
    urlCalls = [];
    storeCalls = [];
    messenger.setMockMethodCallHandler(urlChannel, (call) async {
      urlCalls.add(call);
      if (call.method == 'canLaunch') return canLaunch;
      if (call.method == 'launch') return true;
      return null;
    });
    messenger.setMockMethodCallHandler(AppStoreLauncher.iosChannel, (
      call,
    ) async {
      storeCalls.add(call);
      if (overlay is Exception) throw overlay;
      return overlay;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      AppStoreLauncher.playClient = const InAppUpdatePlayClient();
      messenger.setMockMethodCallHandler(urlChannel, null);
      messenger.setMockMethodCallHandler(AppStoreLauncher.iosChannel, null);
    });
  }

  String? launchedUrl() => urlCalls
      .where((c) => c.method == 'launch')
      .map((c) => (c.arguments as Map)['url'] as String)
      .firstOrNull;

  group('iOS', () {
    test('présente la fiche App Store par-dessus l\'app', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await AppStoreLauncher.open();

      expect(storeCalls.single.method, 'showProductPage');
      expect(storeCalls.single.arguments, {'appId': AppStoreLauncher.iosAppId});
      expect(launchedUrl(), isNull);
    });

    test('retombe sur le lien App Store si la fiche ne charge pas', () async {
      setUp0(overlay: false);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await AppStoreLauncher.open();

      expect(launchedUrl(), AppStoreLauncher.iosStoreUrl);
    });

    test('retombe sur le lien App Store si le canal plante', () async {
      setUp0(overlay: PlatformException(code: 'boom'));
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await AppStoreLauncher.open();

      expect(launchedUrl(), AppStoreLauncher.iosStoreUrl);
    });

    test('n\'ouvre rien quand le lien ne peut pas être lancé', () async {
      setUp0(canLaunch: false, overlay: false);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await AppStoreLauncher.open();

      expect(launchedUrl(), isNull);
    });
  });

  group('Android', () {
    test('lance la mise à jour Google Play dans l\'app', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final play = _FakePlayClient();
      AppStoreLauncher.playClient = play;

      await AppStoreLauncher.open();

      expect(play.immediateCalls, 1);
      expect(launchedUrl(), isNull);
    });

    test('reprend une mise à jour déjà commencée', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final play = _FakePlayClient(
        availability: UpdateAvailability.developerTriggeredUpdateInProgress,
      );
      AppStoreLauncher.playClient = play;

      await AppStoreLauncher.open();

      expect(play.immediateCalls, 1);
      expect(launchedUrl(), isNull);
    });

    test('refus sur l\'écran de Google : pas de Play Store en plus', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppStoreLauncher.playClient = _FakePlayClient(
        result: AppUpdateResult.userDeniedUpdate,
      );

      await AppStoreLauncher.open();

      expect(launchedUrl(), isNull);
    });

    test('échec de la mise à jour : ouvre la fiche Play Store', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppStoreLauncher.playClient = _FakePlayClient(
        result: AppUpdateResult.inAppUpdateFailed,
      );

      await AppStoreLauncher.open();

      expect(launchedUrl(), AppStoreLauncher.androidStoreUrl);
    });

    test(
      'aucune mise à jour Play connue : ouvre la fiche Play Store',
      () async {
        setUp0();
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final play = _FakePlayClient(
          availability: UpdateAvailability.updateNotAvailable,
        );
        AppStoreLauncher.playClient = play;

        await AppStoreLauncher.open();

        expect(play.immediateCalls, 0);
        expect(launchedUrl(), AppStoreLauncher.androidStoreUrl);
      },
    );

    test('mise à jour immédiate non permise : ouvre la fiche', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final play = _FakePlayClient(immediateAllowed: false);
      AppStoreLauncher.playClient = play;

      await AppStoreLauncher.open();

      expect(play.immediateCalls, 0);
      expect(launchedUrl(), AppStoreLauncher.androidStoreUrl);
    });

    test('Play Core absent (app hors Play) : ouvre la fiche', () async {
      setUp0();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppStoreLauncher.playClient = _FakePlayClient(
        checkError: PlatformException(code: 'ERROR_API_NOT_AVAILABLE'),
      );

      await AppStoreLauncher.open();

      expect(launchedUrl(), AppStoreLauncher.androidStoreUrl);
    });
  });
}
