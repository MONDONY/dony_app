import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/traveler_status/bloc/publish_blocked_cubit.dart';
import 'package:dony/features/traveler_status/bloc/traveler_status_cubit.dart';
import 'package:dony/features/traveler_status/data/publishing_eligibility.dart';
import 'package:dony/features/traveler_status/data/traveler_status_repository.dart';
import 'package:dony/features/traveler_status/presentation/traveler_status_choice_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Paramètres de la route `/trips/publish-blocked`.
class PublishBlockedArgs {
  const PublishBlockedArgs(this.eligibility, {this.source = 'gate'});

  final PublishingEligibility eligibility;

  /// Origine du blocage, pour l'analytique : `gate` (point d'entrée « Créer un
  /// trajet ») ou `publish_error` (publication refusée par le back).
  final String source;
}

/// Écran qui arrête une création de trajet quand la limite mensuelle est
/// atteinte (`/trips/publish-blocked`).
///
/// Trois visages, selon la raison :
/// - `STATUS_REQUIRED` : « Limite de N trajets atteinte » et les deux choix
///   Particulier / GP Pro, sans « Plus tard » ;
/// - `LIMIT_REACHED` : plus de trajet ce mois-ci, date de reprise, « Devenir
///   GP Pro » ;
/// - `GP_PRO_PENDING` : la demande GP Pro est en cours d'examen.
///
/// Rend `true` (par `pop`) quand plus rien ne bloque, par exemple une demande
/// validée entre-temps : l'appelant reprend alors la publication.
class PublishBlockedScreen extends StatelessWidget {
  const PublishBlockedScreen({
    required this.eligibility,
    this.source = 'gate',
    super.key,
  });

  final PublishingEligibility eligibility;

  /// Origine du blocage, pour l'analytique : `gate` ou `publish_error`.
  final String source;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PublishBlockedCubit>(
          create: (_) => PublishBlockedCubit(
            eligibility,
            getIt<TravelerStatusRepository>(),
            getIt<AnalyticsService>(),
            source: source,
          )..start(),
        ),
        BlocProvider<TravelerStatusCubit>(
          create: (_) => getIt<TravelerStatusCubit>(),
        ),
      ],
      child: const _BlockedView(),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView();

  void _onDeclared(BuildContext context, TravelerStatusSuccess state) {
    final auth = maybeRead<AuthBloc>(context);
    final user = auth?.state.currentUser;
    if (auth != null && !auth.isClosed) {
      if (user != null) {
        auth.add(
          AuthUserSynced(user.withTravelerStatus(state.declaration.status)),
        );
      }
      auth.add(const AuthProfileRefreshRequested());
    }
    context.read<PublishBlockedCubit>().individualDeclared();
  }

  Future<void> _openGpPro(BuildContext context) async {
    final blocked = context.read<PublishBlockedCubit>();
    final auth = maybeRead<AuthBloc>(context);
    await context.push<void>('/profile/gp-pro');
    if (auth != null && !auth.isClosed) {
      auth.add(const AuthProfileRefreshRequested());
    }
    if (!blocked.isClosed) await blocked.refresh();
  }

  void _close(BuildContext context) => context.pop(false);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<TravelerStatusCubit, TravelerStatusState>(
          listenWhen: (prev, curr) =>
              curr is TravelerStatusSuccess || curr is TravelerStatusFailure,
          listener: (context, state) {
            switch (state) {
              case TravelerStatusSuccess():
                _onDeclared(context, state);
              case TravelerStatusFailure(:final error):
                ErrorPresenter.show(context, error);
              case TravelerStatusInitial() || TravelerStatusSubmitting():
                break;
            }
          },
        ),
        BlocListener<PublishBlockedCubit, PublishBlockedState>(
          listenWhen: (prev, curr) => curr.canPublish && !prev.canPublish,
          listener: (context, state) => context.pop(true),
        ),
      ],
      child: BlocBuilder<PublishBlockedCubit, PublishBlockedState>(
        buildWhen: (prev, curr) => prev.eligibility != curr.eligibility,
        builder: (context, state) {
          final eligibility = state.eligibility;
          return switch (eligibility.reason) {
            PublishingReason.statusRequired => DonyPageScaffold(
              title: l.publishBlockedAppBarTitle,
              body: _StatusRequiredBody(
                eligibility: eligibility,
                onGpPro: () => unawaited(_openGpPro(context)),
              ),
            ),
            PublishingReason.limitReached => DonyPageScaffold(
              title: l.publishBlockedAppBarTitle,
              body: _LimitReachedBody(eligibility: eligibility),
              stickyBottom: _Actions(
                primaryLabel: l.publishBlockedBecomeGpProCta,
                onPrimary: () => unawaited(_openGpPro(context)),
                onClose: () => _close(context),
              ),
            ),
            PublishingReason.gpProPending ||
            PublishingReason.ok => DonyPageScaffold(
              title: l.publishBlockedAppBarTitle,
              body: const _PendingBody(),
              stickyBottom: _Actions(
                primaryLabel: l.publishBlockedPendingCta,
                onPrimary: () => unawaited(_openGpPro(context)),
                onClose: () => _close(context),
              ),
            ),
          };
        },
      ),
    );
  }
}

/// Icône ronde, titre et paragraphes, centrés.
class _Message extends StatelessWidget {
  const _Message({
    required this.iconAsset,
    required this.tone,
    required this.title,
    required this.paragraphs,
  });

  final String iconAsset;
  final Color tone;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: DonySpacing.lg),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: DonyIcon(iconAsset, size: 30, color: tone),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(
          title,
          textAlign: TextAlign.center,
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.xs),
            child: Text(
              paragraph,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _StatusRequiredBody extends StatelessWidget {
  const _StatusRequiredBody({required this.eligibility, required this.onGpPro});

  final PublishingEligibility eligibility;
  final VoidCallback onGpPro;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final limit = eligibility.limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Message(
          iconAsset: 'circle-alert',
          tone: Theme.of(context).colorScheme.warning,
          title: limit == null
              ? l.publishBlockedStatusTitleNoLimit
              : l.publishBlockedStatusTitle(limit),
          paragraphs: [l.publishBlockedStatusBody],
        ),
        const SizedBox(height: DonySpacing.lg),
        BlocBuilder<TravelerStatusCubit, TravelerStatusState>(
          builder: (context, state) => TravelerStatusChoiceTiles(
            busy: state is TravelerStatusSubmitting,
            onIndividual: context.read<TravelerStatusCubit>().chooseIndividual,
            onGpPro: onGpPro,
          ),
        ),
      ],
    );
  }
}

class _LimitReachedBody extends StatelessWidget {
  const _LimitReachedBody({required this.eligibility});

  final PublishingEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final limit = eligibility.limit;
    final resetsOn = eligibility.resetsOn;
    return _Message(
      iconAsset: 'ban',
      tone: Theme.of(context).colorScheme.onSurfaceVariant,
      title: l.publishBlockedLimitTitle,
      paragraphs: [
        if (limit != null) l.publishBlockedLimitBody(limit),
        if (resetsOn == null)
          l.publishBlockedResumeNextMonth
        else
          l.publishBlockedResumeOn(
            DateFormat.MMMMd(l.localeName).format(resetsOn),
          ),
        l.publishBlockedBecomeGpPro,
      ],
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _Message(
      iconAsset: 'hourglass',
      tone: Theme.of(context).colorScheme.warning,
      title: l.publishBlockedPendingTitle,
      paragraphs: [l.publishBlockedPendingBody],
    );
  }
}

/// Pied de page : le bouton principal, puis « Fermer ». Libellés courts, sur
/// une ligne, empilés en pleine largeur.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onClose,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(label: primaryLabel, onPressed: onPrimary),
        const SizedBox(height: DonySpacing.xs),
        DonyButton(
          label: context.l10n.commonClose,
          variant: DonyButtonVariant.ghost,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Ouvre l'écran de blocage après une publication refusée par le back (403
/// `traveler-status-required`, `monthly-limit-reached` ou `gp-pro-pending`).
///
/// Relit d'abord le droit de publier pour afficher le chiffre de la limite et
/// la date de reprise ; si la lecture échoue ou ne bloque plus (ancien back),
/// l'écran se construit sur la raison du 403 seule. Rend `true` quand plus rien
/// ne bloque (l'appelant peut reprendre la publication), `false` sinon.
Future<bool> showPublishingBlocked(
  BuildContext context,
  PublishingReason reason,
) async {
  final result = await getIt<TravelerStatusRepository>().checkEligibility();
  if (!context.mounted) return false;
  final eligibility = result.eligibility.allowed
      ? PublishingEligibility.blockedBy(reason)
      : result.eligibility;
  final canPublish = await context.push<bool>(
    '/trips/publish-blocked',
    extra: PublishBlockedArgs(eligibility, source: 'publish_error'),
  );
  return canPublish ?? false;
}
