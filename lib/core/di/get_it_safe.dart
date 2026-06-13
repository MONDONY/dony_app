import 'package:dony/core/di/injection.dart';

/// GetIt lookup that tolerates missing registrations. Returns `null` if
/// [T] is not registered, making analytics best-effort in contexts that
/// don't wire up the full DI graph (tests, preview widgets, etc.).
T? getItSafe<T extends Object>() {
  try {
    return getIt<T>();
  } catch (_) {
    return null;
  }
}
