import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_choice_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que le voyageur a répondu à la feuille « Vous voyagez en tant que ? ».
enum TravelerStatusOutcome {
  /// « Particulier » : déclaré, le profil est à jour.
  individual,

  /// « GP Pro » touché : la feuille se ferme et le formulaire s'ouvre. Valeur
  /// interne, jamais rendue par [TravelerStatusSheet.show] (qui rend
  /// [gpProSent] ou [gpProAbandoned] au retour du formulaire).
  gpProRequested,

  /// « GP Pro » : le formulaire s'est refermé sur une demande envoyée (en
  /// validation). Le voyageur publie comme particulier pendant l'examen.
  gpProSent,

  /// « GP Pro » : le formulaire s'est refermé sans demande envoyée. Le voyageur
  /// a renoncé, rien ne doit être publié à sa place.
  gpProAbandoned,

  /// « Plus tard » : rien n'a été répondu.
  later,
}

/// Feuille « Vous voyagez en tant que ? » : Particulier ou GP Pro, sans clavier
/// ni présélection.
///
/// - Particulier : un tap déclare (`PUT /traveler-status/me`), la phrase sous
///   l'option vaut confirmation de voyager à titre personnel.
/// - GP Pro : un tap ferme la feuille et ouvre le formulaire GP Pro, validé par
///   l'équipe. Pendant la validation, le voyageur reste un particulier.
/// - « Plus tard » (dans le pied) : la publication part quand même.
///
/// Le bouton vit dans le `stickyBottom`, jamais dans le contenu défilant.
class TravelerStatusSheet extends StatelessWidget {
  const TravelerStatusSheet({super.key});

  /// Ouvre la feuille. Rend la réponse, ou `null` si elle est fermée d'un
  /// geste.
  ///
  /// [allowLater] : propose « Plus tard » (défaut). Le profil le retire :
  /// modifier son statut n'est pas un rappel qu'on reporte.
  ///
  /// Après « Particulier », la réponse du `PUT` est appliquée tout de suite au
  /// profil local (`AuthUserSynced`), puis le profil est rechargé : le
  /// rechargement avale ses échecs, la pastille et la ligne du profil ne
  /// doivent pas en dépendre. Après « GP Pro », le profil est rechargé au
  /// retour du formulaire (une validation a pu partir).
  static Future<TravelerStatusOutcome?> show(
    BuildContext context, {
    bool allowLater = true,
  }) async {
    final auth = maybeRead<AuthBloc>(context);
    // Créé ici pour relire la déclaration une fois la feuille fermée ; le
    // `BlocProvider` le ferme avec la feuille.
    final cubit = getIt<TravelerStatusCubit>();
    final outcome = await DonyBottomSheet.show<TravelerStatusOutcome>(
      context,
      analyticsName: 'traveler-status',
      wrapper: (child) =>
          BlocProvider<TravelerStatusCubit>(create: (_) => cubit, child: child),
      stickyBottom: allowLater ? const _LaterButton() : null,
      child: const TravelerStatusSheet(),
    );
    switch (outcome) {
      case TravelerStatusOutcome.individual:
        final state = cubit.state;
        final user = auth?.state.currentUser;
        if (auth != null &&
            !auth.isClosed &&
            state is TravelerStatusSuccess &&
            user != null) {
          auth.add(
            AuthUserSynced(user.withTravelerStatus(state.declaration.status)),
          );
        }
      case TravelerStatusOutcome.gpProRequested:
        // Le vrai résultat se lit au retour du formulaire, sur le statut de la
        // demande.
        if (!context.mounted) return TravelerStatusOutcome.gpProAbandoned;
        await context.push<void>('/profile/gp-pro');
        final sent = await _applicationSent();
        if (auth != null && !auth.isClosed) {
          auth.add(const AuthProfileRefreshRequested());
        }
        return sent
            ? TravelerStatusOutcome.gpProSent
            : TravelerStatusOutcome.gpProAbandoned;
      case TravelerStatusOutcome.gpProSent ||
          TravelerStatusOutcome.gpProAbandoned ||
          TravelerStatusOutcome.later ||
          null:
        return outcome;
    }
    if (auth != null && !auth.isClosed) {
      auth.add(const AuthProfileRefreshRequested());
    }
    return outcome;
  }

  /// La demande GP Pro est partie : en validation (ou en attente de l'identité).
  /// Toute autre réponse, ou une lecture en échec, vaut « pas envoyée » : on ne
  /// publie jamais sur un doute.
  static Future<bool> _applicationSent() async {
    try {
      return (await getIt<GpProRepository>().fetchStatus()).isOpen;
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<TravelerStatusCubit, TravelerStatusState>(
      listenWhen: (prev, curr) =>
          curr is TravelerStatusSuccess || curr is TravelerStatusFailure,
      listener: (context, state) {
        switch (state) {
          case TravelerStatusSuccess():
            Navigator.of(context).pop(TravelerStatusOutcome.individual);
          case TravelerStatusFailure(:final error):
            ErrorPresenter.show(context, error);
          case TravelerStatusInitial() || TravelerStatusSubmitting():
            break;
        }
      },
      buildWhen: (prev, curr) =>
          (prev is TravelerStatusSubmitting) !=
          (curr is TravelerStatusSubmitting),
      builder: (context, state) {
        final cubit = context.read<TravelerStatusCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.travelerStatusSheetTitle, style: tt.headlineSmall),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l.travelerStatusSheetSubtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.base),
            TravelerStatusChoiceTiles(
              busy: state is TravelerStatusSubmitting,
              onIndividual: cubit.chooseIndividual,
              onGpPro: () => Navigator.of(
                context,
              ).pop(TravelerStatusOutcome.gpProRequested),
            ),
          ],
        );
      },
    );
  }
}

/// Pied collant : « Plus tard » ferme la feuille, la publication continue.
class _LaterButton extends StatelessWidget {
  const _LaterButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TravelerStatusCubit, TravelerStatusState>(
      builder: (context, state) => DonyButton(
        label: context.l10n.commonLater,
        variant: DonyButtonVariant.ghost,
        onPressed: state is TravelerStatusSubmitting
            ? null
            : () => Navigator.of(context).pop(TravelerStatusOutcome.later),
      ),
    );
  }
}
