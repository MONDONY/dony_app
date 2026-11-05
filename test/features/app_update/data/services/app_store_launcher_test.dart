import 'package:dony/features/app_update/data/services/app_store_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  void mockLauncher({required bool canLaunch}) {
    calls = [];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'canLaunch') return canLaunch;
          if (call.method == 'launch') return true;
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }

  String? launchedUrl() => calls
      .where((c) => c.method == 'launch')
      .map((c) => (c.arguments as Map)['url'] as String)
      .firstOrNull;

  test('ouvre la fiche App Store sur iOS', () async {
    mockLauncher(canLaunch: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await AppStoreLauncher.open();

    expect(launchedUrl(), AppStoreLauncher.iosStoreUrl);
  });

  test('ouvre la fiche Google Play sur Android', () async {
    mockLauncher(canLaunch: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await AppStoreLauncher.open();

    expect(launchedUrl(), AppStoreLauncher.androidStoreUrl);
  });

  test('n\'ouvre rien quand le lien ne peut pas être lancé', () async {
    mockLauncher(canLaunch: false);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await AppStoreLauncher.open();

    expect(launchedUrl(), isNull);
  });
}
