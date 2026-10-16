import 'package:dony/app/app.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Boîte Hive en mémoire qui honore `defaultValue`, comme la vraie.
class _MemoryBox implements Box<dynamic> {
  final Map<String, dynamic> stored = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      stored.containsKey(key) ? stored[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    stored[key as String] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppPreferencesBloc bloc;
  var builds = 0;

  setUp(() {
    builds = 0;
    bloc = AppPreferencesBloc(_MemoryBox());
  });

  tearDown(() => bloc.close());

  /// Laisse le BLoC traiter ses événements (temps réel), puis repeint.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
      bloc: bloc,
      buildWhen: appPreferencesNeedAppRebuild,
      builder: (context, state) {
        builds++;
        return const SizedBox();
      },
    ),
  );

  testWidgets('déplacer la bulle ne reconstruit pas MaterialApp.router', (
    tester,
  ) async {
    await pump(tester);
    final before = builds;
    for (var i = 0; i < 5; i++) {
      bloc.add(AssistantBubbleMoved(i.isEven ? 'left' : 'right', i / 5));
      await settle(tester);
    }
    expect(builds, before);
  });

  testWidgets('aide vue, bulle masquée ou remise à zéro : pas de rebuild', (
    tester,
  ) async {
    await pump(tester);
    final before = builds;
    bloc
      ..add(const AssistantHintDismissed())
      ..add(const AssistantBubbleToggled(false))
      ..add(const AssistantBubbleReset());
    await settle(tester);
    expect(builds, before);
  });

  testWidgets('le thème et la langue reconstruisent bien l’app', (
    tester,
  ) async {
    await pump(tester);
    final before = builds;
    bloc.add(const ThemeChanged('dark'));
    await settle(tester);
    expect(builds, before + 1);
    bloc.add(const LanguageChanged('en'));
    await settle(tester);
    expect(builds, before + 2);
  });
}
