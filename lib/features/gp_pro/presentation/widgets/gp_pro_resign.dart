import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// « Redevenir particulier », partagé par « Modifier le profil » et l'écran GP
/// Pro : la même confirmation légère, puis `GpProCubit.resign()`.
///
/// Confirmation avec « Annuler » (libellé par défaut du dialogue) et le
/// bouton destructif.
Future<void> confirmGpProResign(BuildContext context, GpProCubit cubit) async {
  final l = context.l10n;
  final confirmed = await DonyDialog.show(
    context,
    title: l.gpProResignConfirmTitle,
    message: l.gpProResignConfirmBody,
    confirmLabel: l.gpProManageResign,
    variant: DonyDialogVariant.destructive,
    iconAsset: 'circle-alert',
  );
  if ((confirmed ?? false) && !cubit.isClosed) await cubit.resign();
}

/// Le voyageur n'est plus GP Pro : le profil local suit tout de suite (statut
/// particulier, plus de badge), puis il est rechargé ; une confirmation discrète
/// le dit.
void applyGpProResigned(BuildContext context) {
  final auth = maybeRead<AuthBloc>(context);
  if (auth != null && !auth.isClosed) {
    final current = auth.state.currentUser;
    if (current != null) {
      auth.add(
        AuthUserSynced(
          current
              .withTravelerStatus(TravelerStatus.individual)
              .copyWith(gpPro: false),
        ),
      );
    }
    auth.add(const AuthProfileRefreshRequested());
  }
  DonySnackbar.show(
    context,
    message: context.l10n.gpProResignDone,
    type: DonySnackbarType.success,
  );
}
