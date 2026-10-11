import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('posthog_flutter');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return call.method == 'distinctId' ? 'anon-123' : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('PosthogBackend relaie chaque appel au SDK PostHog', () async {
    const backend = PosthogBackend();

    await backend.capture('bid_created', {'amount': 12});
    await backend.screen('home', null);
    await backend.identify('uid-1', {'role': 'SENDER'});
    await backend.optIn();
    await backend.optOut();
    await backend.reset();
    final id = await backend.distinctId();

    expect(id, 'anon-123');
    final methods = calls.map((c) => c.method).toList();
    expect(
      methods,
      containsAllInOrder([
        'capture',
        'screen',
        'identify',
        'enable',
        'disable',
        'reset',
        'distinctId',
      ]),
    );
    final capture = calls.firstWhere((c) => c.method == 'capture');
    expect((capture.arguments as Map)['eventName'], 'bid_created');
    final identify = calls.firstWhere((c) => c.method == 'identify');
    expect((identify.arguments as Map)['userId'], 'uid-1');
  });

  test('NoopAnalyticsConsentRemote ne lit ni n’envoie rien', () async {
    const remote = NoopAnalyticsConsentRemote();
    expect(await remote.fetch(), isNull);
    await remote.push(granted: true, policyVersion: 'v1', source: 'test');
    expect(calls, isEmpty);
  });
}
