import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/features/cancellation/bloc/cancellation_fee_config/cancellation_fee_config_cubit.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Configuration des frais d'annulation connue maintenant, sans attendre :
/// éteinte si rien n'est encore lu ou sans cubit enregistré (tests isolés).
/// Pour un texte choisi hors du rendu (snackbar d'un listener).
CancellationFeeConfigModel currentCancellationFeeConfig() =>
    getIt.isRegistered<CancellationFeeConfigCubit>()
    ? getIt<CancellationFeeConfigCubit>().state.config
    : CancellationFeeConfigModel.inactive;

/// Lance la lecture de la configuration si elle n'est pas connue (à
/// l'ouverture d'un écran qui en dépend), pour qu'elle soit là quand une
/// feuille ou une snackbar la demande. Sans effet sans cubit enregistré.
void warmUpCancellationFeeConfig() {
  if (!getIt.isRegistered<CancellationFeeConfigCubit>()) return;
  unawaited(getIt<CancellationFeeConfigCubit>().ensureLoaded());
}

/// Reconstruit [builder] avec la configuration des frais d'annulation, lue au
/// premier affichage si besoin. Tant qu'elle n'est pas lue (ou sans cubit
/// enregistré), la configuration est éteinte : l'écran montre les textes
/// d'avant la fonction, puis bascule à son arrivée.
class CancellationFeeConfigBuilder extends StatefulWidget {
  const CancellationFeeConfigBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, CancellationFeeConfigModel config)
  builder;

  @override
  State<CancellationFeeConfigBuilder> createState() =>
      _CancellationFeeConfigBuilderState();
}

class _CancellationFeeConfigBuilderState
    extends State<CancellationFeeConfigBuilder> {
  @override
  void initState() {
    super.initState();
    warmUpCancellationFeeConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<CancellationFeeConfigCubit>()) {
      return widget.builder(context, CancellationFeeConfigModel.inactive);
    }
    return BlocBuilder<CancellationFeeConfigCubit, CancellationFeeConfigState>(
      bloc: getIt<CancellationFeeConfigCubit>(),
      buildWhen: (previous, current) => previous.config != current.config,
      builder: (context, state) => widget.builder(context, state.config),
    );
  }
}
