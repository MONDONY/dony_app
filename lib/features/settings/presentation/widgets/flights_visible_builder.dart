import 'package:dony/core/config/flights_flag.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/settings/bloc/flights_visibility_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Préférence « Afficher les billets d'avion » de l'appareil. Sans cubit
/// enregistré (tests isolés), les billets restent visibles : c'est le défaut.
bool flightsPreferenceVisible() =>
    !getIt.isRegistered<FlightsVisibilityCubit>() ||
    getIt<FlightsVisibilityCubit>().state;

/// Les billets ont leur place à l'écran : flag plateforme `flights_enabled`
/// allumé ET préférence de l'appareil active.
bool flightsShown() =>
    flightsEnabledListenable.value && flightsPreferenceVisible();

/// Reconstruit [builder] quand le flag `flights_enabled` OU la préférence
/// « Afficher les billets d'avion » change : un point d'entrée vers les
/// billets apparaît ou disparaît sans redémarrage. `shown` vaut
/// [flightsShown].
class FlightsVisibleBuilder extends StatelessWidget {
  const FlightsVisibleBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool shown) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: flightsEnabledListenable,
      builder: (context, enabled, _) {
        if (!getIt.isRegistered<FlightsVisibilityCubit>()) {
          return builder(context, enabled);
        }
        return BlocBuilder<FlightsVisibilityCubit, bool>(
          bloc: getIt<FlightsVisibilityCubit>(),
          builder: (context, visible) => builder(context, enabled && visible),
        );
      },
    );
  }
}
