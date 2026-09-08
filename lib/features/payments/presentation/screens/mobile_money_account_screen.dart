import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_bloc.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_event.dart';
import 'package:dony/features/payments/bloc/mobile_money_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compte de versement mobile money du voyageur (Wave / Orange Money via
/// pawaPay) : consultation, activation et désactivation.
///
/// Accessible depuis « Moi » → section ARGENT → « Versement mobile money ».
/// Style d'AppBar identique à `MobileMoneyAwaitingScreen`.
class MobileMoneyAccountScreen extends StatelessWidget {
  const MobileMoneyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: Text('Versement mobile money', style: tt.headlineMedium),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocConsumer<MobileMoneyAccountBloc, MobileMoneyAccountState>(
        listener: (context, state) {
          if (state is MobileMoneyAccountError) {
            // Jamais state.error brut : toujours passer par ErrorPresenter,
            // qui résout le code métier via ErrorCatalog et retombe sur un
            // message générique français.
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) => switch (state) {
          MobileMoneyAccountInitial() || MobileMoneyAccountLoading() => Center(
            child: CircularProgressIndicator(color: cs.primary),
          ),
          MobileMoneyAccountLoaded(:final account) => _AccountBody(
            account: account,
          ),
          MobileMoneyAccountUpdating(:final account) => _AccountBody(
            account: account,
            isLoading: true,
          ),
          // Échec d'activation/désactivation : le dernier compte connu reste
          // affiché (le listener ci-dessus a déjà notifié l'erreur).
          MobileMoneyAccountError(:final account) when account != null =>
            _AccountBody(account: account),
          // Échec du premier chargement : aucun compte connu à afficher.
          MobileMoneyAccountError() => DonyEmptyState(
            type: DonyEmptyStateType.error,
            title: 'Impossible de charger ton compte',
            actionLabel: 'Réessayer',
            onAction: () => context.read<MobileMoneyAccountBloc>().add(
              const MobileMoneyAccountRequested(),
            ),
          ),
        },
      ),
    );
  }
}

/// Contenu selon le statut du compte, commun aux états `Loaded`, `Updating`
/// et `Error` (avec compte conservé).
class _AccountBody extends StatelessWidget {
  const _AccountBody({required this.account, this.isLoading = false});

  final MobileMoneyAccount account;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        DonySpacing.xl,
      ),
      child: switch (account.status) {
        MobileMoneyAccountStatus.notConfigured => _NotConfiguredView(
          isLoading: isLoading,
        ),
        MobileMoneyAccountStatus.active => _ActiveView(
          account: account,
          isLoading: isLoading,
        ),
        MobileMoneyAccountStatus.disabled => _DisabledView(
          isLoading: isLoading,
        ),
      },
    );
  }
}

/// Aucun versement configuré : explique le principe et propose l'activation.
class _NotConfiguredView extends StatelessWidget {
  const _NotConfiguredView({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('smartphone', color: cs.primary, size: 32),
                  const SizedBox(height: DonySpacing.base),
                  Text(
                    'Ton numéro de téléphone Yadony devient ton compte de '
                    'versement. Le montant net de chaque envoi t\'est versé '
                    'dessus à la livraison.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.lg),
                  Text(
                    'Opérateurs disponibles',
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text('Orange Money, Wave, MTN, Free…', style: tt.bodyMedium),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Activer le versement mobile money',
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountActivateRequested(),
          ),
        ),
      ],
    );
  }
}

/// Versement actif : détail du compte et désactivation.
class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.account, required this.isLoading});

  final MobileMoneyAccount account;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.providerLabel ?? 'Mobile money',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      const DonyBadge(
                        label: 'ACTIF',
                        type: DonyBadgeType.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.base),
                  DonyInfoRow(
                    label: 'Numéro',
                    value: account.msisdnMasked ?? 'Non renseigné',
                  ),
                  const DonyInfoRow.divider(),
                  DonyInfoRow(
                    label: 'Devise',
                    value: account.currency ?? 'Non renseigné',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Désactiver',
          variant: DonyButtonVariant.ghost,
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountDisableRequested(),
          ),
        ),
      ],
    );
  }
}

/// Versement désactivé : les informations sont conservées, on peut réactiver.
class _DisabledView extends StatelessWidget {
  const _DisabledView({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DonyCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonyIcon('smartphone', color: cs.onSurfaceVariant, size: 28),
                  const SizedBox(width: DonySpacing.base),
                  Expanded(
                    child: Text(
                      'Versement désactivé. Tes informations sont '
                      'conservées.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        DonyButton(
          label: 'Réactiver',
          isLoading: isLoading,
          onPressed: () => context.read<MobileMoneyAccountBloc>().add(
            const MobileMoneyAccountActivateRequested(),
          ),
        ),
      ],
    );
  }
}
