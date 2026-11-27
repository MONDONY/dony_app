import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/form_draft_cubit.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/matching/data/models/trip_form_draft.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/bloc/package_request_form_draft.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_cubit.dart';
import 'package:dony/features/publish_gate/bloc/publish_gate_state.dart';
import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/models/publish_draft_entry.dart';
import 'package:dony/features/publish_gate/presentation/publish_drafts_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Rôle de publication : détermine tout le contenu (illustration, couleur,
/// engagements, destination du CTA) de [PublishIntroScreen].
enum PublishIntroRole {
  trip(PublishCommitmentRole.traveler),
  parcel(PublishCommitmentRole.sender);

  const PublishIntroRole(this.commitmentRole);

  /// Engagements acceptés pour ce rôle (serveur).
  final PublishCommitmentRole commitmentRole;
}

UserModel? _currentUser(AuthState authState) => switch (authState) {
  final AuthAuthenticated s => s.user,
  final AuthProfileUpdated s => s.user,
  _ => null,
};

/// Aiguillage avant le formulaire de publication, point de passage de tous
/// les boutons « Publier ».
///
/// Première publication du rôle (ou nouveau texte des engagements) : l'écran
/// rappelle les engagements du rôle, qu'il faut lire jusqu'en bas pour cocher
/// « J'ai lu… » puis continuer. Ensuite, l'écran ne s'affiche plus : on passe
/// directement au formulaire, ou d'abord par la feuille des brouillons s'il
/// en reste. Le même écran sert aux deux flux, voyageur (bleu) et expéditeur
/// (terracotta), pilotés par [role].
///
/// L'identité ne bloque plus ici : un utilisateur non vérifié lit une simple
/// information et entre dans le formulaire. La vérification lui est demandée
/// au clic sur « Publier » (`PublishKycGateSheet`).
class PublishIntroScreen extends StatelessWidget {
  const PublishIntroScreen({
    super.key,
    required this.role,
    this.resumeLocalDraft = false,
  });

  final PublishIntroRole role;

  /// Retour d'une vérification d'identité demandée au clic sur « Publier »
  /// (`?resume=kyc`) : le brouillon local gardé à ce moment se rouvre
  /// directement, sans passer par la feuille des brouillons.
  final bool resumeLocalDraft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublishGateCubit>(
      create: (_) =>
          getIt<PublishGateCubit>(param1: role.commitmentRole)..start(),
      child: BlocConsumer<PublishGateCubit, PublishGateState>(
        listenWhen: (prev, next) =>
            (next.status == PublishGateStatus.ready &&
                prev.status != PublishGateStatus.ready) ||
            next.errorSeq != prev.errorSeq,
        listener: _onGateChanged,
        builder: (context, gate) => gate.introShown
            ? _buildIntro(context, gate)
            : _buildPending(context, gate),
      ),
    );
  }

  void _onGateChanged(BuildContext context, PublishGateState gate) {
    final error = gate.error;
    if (error != null && gate.status == PublishGateStatus.intro) {
      DonySnackbar.show(
        context,
        message: switch (error) {
          PublishGateError.acceptFailed =>
            context.l10n.publishCommitmentAcceptFailed,
          PublishGateError.outdated => context.l10n.publishCommitmentOutdated,
        },
        type: DonySnackbarType.warning,
      );
      return;
    }
    if (gate.status == PublishGateStatus.ready) {
      unawaited(_continueToForm(context, gate));
    }
  }

  /// Feuille des brouillons s'il en reste, sinon directement le formulaire.
  Future<void> _continueToForm(
    BuildContext context,
    PublishGateState gate,
  ) async {
    final cubit = context.read<PublishGateCubit>();
    if (resumeLocalDraft) {
      final local = gate.drafts.whereType<LocalPublishDraft>().firstOrNull;
      if (local != null) {
        _openForm(context, local);
        return;
      }
    }
    if (!gate.hasChoices) {
      _openForm(context, null);
      return;
    }
    final result = await PublishDraftsSheet.show(
      context,
      role: role.commitmentRole,
      drafts: gate.drafts,
      templates: gate.templates,
    );
    if (!context.mounted) return;
    switch (result) {
      case ResumePublishDraft(:final entry):
        cubit.trackChoice(switch (entry) {
          LocalPublishDraft() => PublishDraftChoice.local,
          ServerTripDraftSeries() => PublishDraftChoice.series,
          _ => PublishDraftChoice.server,
        }, entry: entry);
        _openForm(context, entry);
      case UsePublishTemplate(:final template):
        cubit.trackChoice(PublishDraftChoice.template);
        context.pushReplacement(
          '/trips/create',
          extra: CreateTripArgs(template: template),
        );
      case CreateNewPublication():
        cubit.trackChoice(PublishDraftChoice.createNew);
        _openForm(context, null);
      case null:
        cubit.trackChoice(PublishDraftChoice.dismissed);
        // Sans écran des engagements derrière, il n'y a rien à montrer.
        if (!gate.introShown) _leave(context);
    }
  }

  /// Remplace cet écran : le retour depuis le formulaire ramène là d'où
  /// l'utilisateur est parti, pas à un aiguillage déjà franchi.
  void _openForm(BuildContext context, PublishDraftEntry? entry) {
    switch ((role, entry)) {
      case (PublishIntroRole.trip, final LocalPublishDraft d):
        context.pushReplacement(
          '/trips/create',
          extra: CreateTripArgs(
            resumeDraft: TripFormDraft.fromJson(d.draft.data),
            fromKycGate: FormDraftCubit.isFromKycGate(d.draft.data),
          ),
        );
      case (PublishIntroRole.trip, ServerTripDraftSeries()):
        // Plusieurs brouillons d'une même série : « Mes trajets », filtré
        // sur les brouillons, pour les relire et les publier.
        context.pushReplacement('/announcements/trips?filter=draft');
      case (PublishIntroRole.trip, final ServerTripDraft d):
        context.pushReplacement(
          '/announcements/${d.announcement.id}/trip',
          extra: d.announcement,
        );
      case (PublishIntroRole.trip, _):
        context.pushReplacement('/trips/create', extra: const CreateTripArgs());
      case (PublishIntroRole.parcel, final LocalPublishDraft d):
        context.pushReplacement(
          '/package-requests/new',
          extra: PackageRequestDraftResume(d.draft.data),
        );
      case (PublishIntroRole.parcel, final ServerRequestDraft d):
        context.pushReplacement('/package-requests/${d.request.id}');
      case (PublishIntroRole.parcel, _):
        context.pushReplacement('/package-requests/new');
    }
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Engagements déjà acceptés : rien à lire, on attend les brouillons. Une
  /// fois prêt, la feuille des brouillons recouvre un fond vide.
  Widget _buildPending(BuildContext context, PublishGateState gate) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const DonyAppBarBackButton(),
      ),
      body: gate.status == PublishGateStatus.ready
          ? const SizedBox.shrink()
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  Widget _buildIntro(BuildContext context, PublishGateState gate) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final config = _IntroConfig.of(role, cs, l10n);

    final user = _currentUser(context.watch<AuthBloc>().state);
    final verified = user?.isKycVerified ?? false;
    final busy =
        gate.status == PublishGateStatus.accepting ||
        gate.status == PublishGateStatus.checkingDrafts;

    // Numéro du premier engagement de chaque bloc : la numérotation court
    // d'un bloc à l'autre (1 à 15).
    final firstNumbers = <int>[];
    var next = 1;
    for (final group in config.groups) {
      firstNumbers.add(next);
      next += group.rules.length;
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        actions: const [DonyFeedbackButton()],
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const DonyAppBarBackButton(),
        title: Text(
          config.title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: cs.outline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // Arrivée en bas de la liste (ou liste qui tient sur un écran) :
            // la case se débloque. Les notifications de métriques couvrent le
            // cas sans défilement, celles de défilement le geste de l'utilisateur.
            child: NotificationListener<Notification>(
              onNotification: (notification) {
                _markListReadAtEnd(context, notification);
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DonySpacing.lg),
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NoticeCard(
                              verified: verified,
                              verifiedText: config.verifiedText,
                              noCardText: config.noCardText,
                              accent: config.accent,
                            ),
                            const SizedBox(height: DonySpacing.lg),
                            _SectionHeader(
                              iconAsset: config.sectionIcon,
                              accent: config.accent,
                              title: config.engagementsTitle,
                            ),
                            const SizedBox(height: DonySpacing.xs),
                            Text(
                              l10n.publishCommitmentsIntro(config.ruleCount),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.md),
                            for (final (i, group) in config.groups.indexed) ...[
                              _GroupHeader(
                                title: group.title,
                                accent: config.accent,
                              ),
                              const SizedBox(height: DonySpacing.sm),
                              _RulesCard(
                                rules: group.rules,
                                firstNumber: firstNumbers[i],
                                accent: config.accent,
                              ),
                              const SizedBox(height: DonySpacing.base),
                            ],
                            _TermsLink(accent: config.accent),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
                        .slideY(begin: 0.03, curve: Curves.easeOutCubic),
              ),
            ),
          ),
          _CommitmentBar(
            accent: config.accent,
            buttonVariant: config.buttonVariant,
            label: config.checkboxLabel,
            ruleCount: config.ruleCount,
            commitmentRequired: gate.commitmentRequired,
            listRead: gate.listRead,
            checked: gate.checked,
            busy: busy,
            onChecked: (v) => context.read<PublishGateCubit>().setChecked(v),
            onContinue: () =>
                unawaited(context.read<PublishGateCubit>().accept()),
          ),
        ],
      ),
    );
  }

  /// Le bas de la liste est atteint : à 24 px près, ou dès qu'il n'y a rien à
  /// faire défiler.
  void _markListReadAtEnd(BuildContext context, Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      final ScrollMetricsNotification n => n.metrics,
      final ScrollNotification n => n.metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.vertical) return;
    if (metrics.maxScrollExtent - metrics.pixels <= 24) {
      context.read<PublishGateCubit>().markListRead();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config par rôle
// ─────────────────────────────────────────────────────────────────────────────

class _IntroConfig {
  const _IntroConfig({
    required this.title,
    required this.accent,
    required this.buttonVariant,
    required this.verifiedText,
    required this.noCardText,
    required this.sectionIcon,
    required this.engagementsTitle,
    required this.groups,
    required this.checkboxLabel,
  });

  final String title;
  final Color accent;
  final DonyButtonVariant buttonVariant;
  final String verifiedText;

  /// « Aucune carte à enregistrer » (voyageur) / « Rien à payer » (expéditeur) :
  /// publier ne demande aucun moyen de paiement.
  final String noCardText;
  final String sectionIcon;
  final String engagementsTitle;
  final List<_Group> groups;

  /// « J'ai lu et j'ai pris connaissance de mes engagements… ».
  final String checkboxLabel;

  int get ruleCount => groups.fold(0, (sum, g) => sum + g.rules.length);

  static _IntroConfig of(
    PublishIntroRole role,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    switch (role) {
      case PublishIntroRole.trip:
        return _IntroConfig(
          title: l10n.tripPublishTitle,
          accent: cs.primary,
          buttonVariant: DonyButtonVariant.primary,
          verifiedText: l10n.tripPublishIntroVerifiedTextTrip,
          noCardText: l10n.publishIntroNoCardTrip,
          sectionIcon: 'route',
          engagementsTitle: l10n.tripPublishIntroEngagementsTitleTrip,
          groups: [
            _Group(l10n.publishCommitmentTripGroupBefore, [
              _Rule(l10n.publishCommitmentTrip01, '3, 16'),
              _Rule(l10n.publishCommitmentTrip02, '4'),
              _Rule(l10n.publishCommitmentTrip03, '4'),
              _Rule(l10n.publishCommitmentTrip04, '3'),
              _Rule(l10n.publishCommitmentTrip05, ''),
            ]),
            _Group(l10n.publishCommitmentTripGroupDuring, [
              _Rule(l10n.publishCommitmentTrip06, '4, 6'),
              _Rule(l10n.publishCommitmentTrip07, '6'),
              _Rule(l10n.publishCommitmentTrip08, '12'),
              _Rule(l10n.publishCommitmentTrip09, '7, 10'),
              _Rule(l10n.publishCommitmentTrip10, '7, 16'),
            ]),
            _Group(l10n.publishCommitmentTripGroupMoney, [
              _Rule(l10n.publishCommitmentTrip11, '7'),
              _Rule(l10n.publishCommitmentTrip12, '10'),
              _Rule(l10n.publishCommitmentTrip13, '16'),
              _Rule(l10n.publishCommitmentTrip14, '12bis'),
              _Rule(l10n.publishCommitmentTrip15, '2, 12'),
            ]),
          ],
          checkboxLabel: l10n.publishCommitmentCheckboxTrip,
        );
      case PublishIntroRole.parcel:
        return _IntroConfig(
          title: l10n.requestPublishIntroTitle,
          accent: cs.secondary,
          buttonVariant: DonyButtonVariant.accent,
          verifiedText: l10n.requestPublishIntroVerifiedText,
          noCardText: l10n.publishIntroNoPaymentParcel,
          sectionIcon: 'package',
          engagementsTitle: l10n.requestPublishIntroEngagementsTitle,
          groups: [
            _Group(l10n.publishCommitmentParcelGroupParcel, [
              _Rule(l10n.publishCommitmentParcel01, '4'),
              _Rule(l10n.publishCommitmentParcel02, '4'),
              // La valeur déclarée (500 € maximum) est celle des CGU, pas un
              // champ du wizard : on la cite comme règle, pas comme saisie.
              _Rule(l10n.publishCommitmentParcel03, '4'),
              _Rule(l10n.publishCommitmentParcel04, '4'),
              _Rule(l10n.publishCommitmentParcel05, '4'),
            ]),
            _Group(l10n.publishCommitmentParcelGroupHandover, [
              _Rule(l10n.publishCommitmentParcel06, '4, 6'),
              _Rule(l10n.publishCommitmentParcel07, '4'),
              _Rule(l10n.publishCommitmentParcel08, '7, 10'),
              _Rule(l10n.publishCommitmentParcel09, '7, 16'),
              _Rule(l10n.publishCommitmentParcel10, '4'),
            ]),
            _Group(l10n.publishCommitmentParcelGroupLiability, [
              _Rule(l10n.publishCommitmentParcel11, '12'),
              _Rule(l10n.publishCommitmentParcel12, '10'),
              _Rule(l10n.publishCommitmentParcel13, '10'),
              _Rule(l10n.publishCommitmentParcel14, '10'),
              _Rule(l10n.publishCommitmentParcel15, '2, 16'),
            ]),
          ],
          checkboxLabel: l10n.publishCommitmentCheckboxParcel,
        );
    }
  }
}

/// Un bloc d'engagements : un titre et ses règles.
class _Group {
  const _Group(this.title, this.rules);
  final String title;
  final List<_Rule> rules;
}

/// Un engagement : un texte où `**...**` marque les segments gras, et les
/// articles des CGU dont il est tiré (« 4, 6 » ; vide si aucun).
class _Rule {
  const _Rule(this.text, this.articles);
  final String text;
  final String articles;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sous-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Ce qu'il faut savoir avant de lire : l'identité se vérifie à la
/// publication, et publier ne demande ni carte ni paiement. Cette seconde
/// ligne répond à l'idée reçue qu'il faudrait enregistrer sa carte d'abord.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.verified,
    required this.verifiedText,
    required this.noCardText,
    required this.accent,
  });

  final bool verified;
  final String verifiedText;
  final String noCardText;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('publish-intro-notice'),
      padding: const EdgeInsets.all(DonySpacing.md + 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Non vérifié : simple information, rien à toucher. La
          // vérification est demandée au clic sur « Publier », une fois le
          // formulaire rempli.
          _NoticeLine(
            key: verified ? null : const Key('publish-intro-kyc-notice'),
            iconAsset: verified ? 'circle-check' : 'shield-check',
            accent: accent,
            text: verified ? verifiedText : context.l10n.publishIntroKycNotice,
          ),
          const SizedBox(height: DonySpacing.sm),
          _NoticeLine(
            key: const Key('publish-intro-no-card'),
            iconAsset: 'credit-card',
            accent: accent,
            text: noCardText,
          ),
        ],
      ),
    );
  }
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({
    super.key,
    required this.iconAsset,
    required this.accent,
    required this.text,
  });

  final String iconAsset;
  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: DonyIcon(iconAsset, size: 18, color: accent),
        ),
        const SizedBox(width: DonySpacing.sm + 2),
        Expanded(
          child: Text.rich(
            _boldSpans(text, tt.bodySmall!, cs.onSurface),
            style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.iconAsset,
    required this.accent,
    required this.title,
  });

  final String iconAsset;
  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon(iconAsset, size: 18, color: accent),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Titre d'un bloc : une pastille pleine et un filet.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.accent});

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md - 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                color: DonyColors.neutral0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(child: Container(height: 1, color: cs.outline)),
      ],
    );
  }
}

/// Les engagements d'un bloc dans une même carte, numérotés à la suite.
class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.rules,
    required this.firstNumber,
    required this.accent,
  });

  final List<_Rule> rules;
  final int firstNumber;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (final (i, rule) in rules.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: cs.outline),
            _RuleRow(rule: rule, number: firstNumber + i, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.number,
    required this.accent,
  });

  final _Rule rule;
  final int number;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final base = tt.bodyMedium!;
    final body = _boldSpans(rule.text, base, cs.onSurface);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base - 2,
        vertical: DonySpacing.md - 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: tt.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  ...?body.children,
                  if (rule.articles.isNotEmpty)
                    TextSpan(
                      text:
                          ' ${context.l10n.publishCommitmentArticle(rule.articles)}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              style: base.copyWith(color: cs.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Lire les CGU en entier » : ouvre les CGU en ligne.
class _TermsLink extends StatelessWidget {
  const _TermsLink({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      key: const Key('publish-intro-terms-link'),
      onTap: () => context.push('/legal/terms'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            context.l10n.publishCommitmentReadTerms,
            style: tt.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pied collant : la case des engagements et « Continuer » vont ensemble, donc
/// toujours visibles. La case reste verrouillée tant que la liste n'est pas
/// lue jusqu'en bas.
class _CommitmentBar extends StatelessWidget {
  const _CommitmentBar({
    required this.accent,
    required this.buttonVariant,
    required this.label,
    required this.ruleCount,
    required this.commitmentRequired,
    required this.listRead,
    required this.checked,
    required this.busy,
    required this.onChecked,
    required this.onContinue,
  });

  final Color accent;
  final DonyButtonVariant buttonVariant;
  final String label;
  final int ruleCount;
  final bool commitmentRequired;
  final bool listRead;
  final bool checked;

  /// Acceptation en cours d'envoi, ou brouillons en cours de lecture.
  final bool busy;
  final ValueChanged<bool> onChecked;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsCheck = commitmentRequired && !checked;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
        boxShadow: DonyShadow.sm,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            DonySpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (commitmentRequired) ...[
                if (listRead)
                  _CommitmentCheck(
                    label: label,
                    accent: accent,
                    checked: checked,
                    enabled: !busy,
                    onChanged: onChecked,
                  )
                else
                  _LockedCheck(count: ruleCount),
                const SizedBox(height: DonySpacing.sm + 2),
              ],
              DonyButton(
                key: const Key('publish-intro-continue'),
                label: context.l10n.commonContinue,
                iconRightAsset: 'arrow-right',
                variant: buttonVariant,
                isLoading: busy,
                onPressed: (needsCheck || busy) ? null : onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Case encore verrouillée : elle existe, on voit ce qu'il reste à faire.
class _LockedCheck extends StatelessWidget {
  const _LockedCheck({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        key: const Key('publish-commitment-locked'),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base - 2,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline, width: 2),
        ),
        child: Row(
          children: [
            DonyIcon('lock', color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text.rich(
                _boldSpans(
                  context.l10n.publishCommitmentLockedHint(count),
                  tt.bodyMedium!,
                  cs.onSurfaceVariant,
                ),
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Case d'acceptation des engagements, débloquée en bas de liste.
class _CommitmentCheck extends StatelessWidget {
  const _CommitmentCheck({
    required this.label,
    required this.accent,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final Color accent;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: checked ? accent.withValues(alpha: 0.10) : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        // Bordure pleine de l'accent : la case se voit, elle est à toucher.
        border: Border.all(color: accent, width: 2),
      ),
      child: DonyCheckbox(
        key: const Key('publish-commitment-checkbox'),
        label: label,
        value: checked,
        enabled: enabled,
        onChanged: (v) => onChanged(v ?? false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Construit un [TextSpan] où les segments entourés de `**` sont en gras.
TextSpan _boldSpans(String text, TextStyle base, Color color) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) {
      continue;
    }
    final bold = i.isOdd;
    spans.add(
      TextSpan(
        text: parts[i],
        style: base.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    );
  }
  return TextSpan(children: spans);
}
