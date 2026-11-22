import 'dart:async';

import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_fee_config_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../cancellation_fee_test_support.dart';

Widget _host() => MaterialApp(
  home: CancellationFeeConfigBuilder(
    builder: (_, config) => Text(config.active ? 'allumé' : 'éteint'),
  ),
);

void main() {
  tearDown(() async {
    await getIt.reset();
    resetCancellationFeeFlagForTest();
  });

  testWidgets('sans cubit enregistré : configuration éteinte', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('éteint'), findsOneWidget);
    expect(currentCancellationFeeConfig(), CancellationFeeConfigModel.inactive);
    warmUpCancellationFeeConfig(); // sans effet, ne lève rien
  });

  testWidgets('lit la configuration au premier affichage puis bascule à son '
      'arrivée', (tester) async {
    final repository = MockFeeConfigRepository();
    final pending = Completer<CancellationFeeConfigModel>();
    when(repository.getFeeConfig).thenAnswer((_) => pending.future);
    final cubit = CancellationFeeConfigCubit(
      repository,
      MockFeeConfigAnalytics(),
    );
    getIt.registerSingleton<CancellationFeeConfigCubit>(cubit);
    addTearDown(cubit.close);

    await tester.pumpWidget(_host());
    // Rien n'est encore lu : les textes d'avant.
    expect(find.text('éteint'), findsOneWidget);
    verify(repository.getFeeConfig).called(1);

    pending.complete(kActiveFeeConfig);
    await tester.pump();

    expect(find.text('allumé'), findsOneWidget);
    expect(currentCancellationFeeConfig(), kActiveFeeConfig);
    expect(cancellationFeeActive, isTrue);
  });

  testWidgets('configuration déjà en mémoire : aucune nouvelle lecture', (
    tester,
  ) async {
    final repository = MockFeeConfigRepository();
    final cubit = await registerFeeConfig(
      config: kActiveFeeConfig,
      repository: repository,
    );
    expect(cubit.state.config, kActiveFeeConfig);

    await tester.pumpWidget(_host());
    warmUpCancellationFeeConfig();
    await tester.pump();

    expect(find.text('allumé'), findsOneWidget);
    verify(repository.getFeeConfig).called(1);
  });

  testWidgets('back antérieur (404) : éteint', (tester) async {
    await registerFeeConfig();
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('éteint'), findsOneWidget);
    expect(cancellationFeeActive, isFalse);
  });
}
