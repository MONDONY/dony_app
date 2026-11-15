import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfig extends Fake implements IConfigRepository {
  _FakeConfig(this.number);

  final String? number;

  @override
  Future<String?> getSupportWhatsappNumber() async => number;
}

class _SilentAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {}
}

/// Enregistre dans GetIt le [SupportContactCubit] qu'attend la carte WhatsApp
/// des écrans Support et FAQ. Sans [number], la carte reste masquée : les
/// tests de ces écrans n'ont rien à changer à leurs attentes.
void registerSupportContactCubit({String? number}) {
  if (getIt.isRegistered<SupportContactCubit>()) {
    getIt.unregister<SupportContactCubit>();
  }
  getIt.registerFactory<SupportContactCubit>(
    () => SupportContactCubit(_FakeConfig(number), _SilentAnalytics()),
  );
  addTearDown(() {
    if (getIt.isRegistered<SupportContactCubit>()) {
      getIt.unregister<SupportContactCubit>();
    }
  });
}
