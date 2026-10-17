import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_form.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_labels.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_pieces_section.dart';
import 'package:dony/features/kyc/presentation/kyc_return_route.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ce que l'écran montre, déduit du chargement, du statut et du KYC.
enum _View {
  loading,
  failure,
  unavailable,
  kyc,
  form,
  open,
  active,
  rejected,
  revoked,
}

/// Écran `/profile/gp-pro` : demande du badge GP Pro puis suivi de son statut.
/// Lit [GpProCubit] (fourni par la route) et le KYC depuis [AuthBloc].
class GpProScreen extends StatefulWidget {
  const GpProScreen({super.key});

  @override
  State<GpProScreen> createState() => _GpProScreenState();
}

class _GpProScreenState extends State<GpProScreen> {
  /// Soumission fournie par [GpProForm] (le nom commercial vit dans son
  /// `State`), appelée par le bouton de la barre fixe.
  VoidCallback? _submit;

  static const _kycRequired = 'gp-pro-kyc-required';

  _View _view(GpProCubitState s, {required bool kycVerified}) {
    switch (s.load) {
      case GpProLoadStatus.loading:
        return _View.loading;
      case GpProLoadStatus.failure:
        return _View.failure;
      case GpProLoadStatus.unavailable:
        return _View.unavailable;
      case GpProLoadStatus.ready:
        break;
    }
    final state = s.status?.state ?? GpProState.none;
    if (state == GpProState.none || s.restarting) {
      // Le back peut savoir avant l'app que l'identité n'est pas vérifiée.
      return kycVerified && s.errorCode != _kycRequired
          ? _View.form
          : _View.kyc;
    }
    return switch (state) {
      GpProState.awaitingKyc || GpProState.pending => _View.open,
      GpProState.active => _View.active,
      GpProState.rejected => _View.rejected,
      GpProState.revoked => _View.revoked,
      GpProState.none => _View.form,
    };
  }

  Future<void> _openKyc() async {
    final cubit = context.read<GpProCubit>();
    await context.push(kycVerifyLocation(fromOnboarding: false));
    // Au retour, une demande AWAITING_KYC a pu passer en PENDING.
    if (mounted) await cubit.load();
  }

  Future<void> _confirmCancel() async {
    final l = context.l10n;
    final cubit = context.read<GpProCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.gpProCancelDialogTitle,
      message: l.gpProCancelDialogBody,
      confirmLabel: l.gpProCancelDialogConfirm,
      cancelLabel: l.gpProCancelDialogKeep,
      variant: DonyDialogVariant.destructive,
      iconAsset: 'circle-alert',
    );
    if (confirmed ?? false) await cubit.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kycVerified = context.select<AuthBloc, bool>(
      (b) => b.state.currentUser?.isKycVerified ?? false,
    );
    return BlocConsumer<GpProCubit, GpProCubitState>(
      listenWhen: (p, c) => c.errorCode != null && c.errorCode != p.errorCode,
      listener: (context, s) {
        final code = s.errorCode!;
        DonySnackbar.show(
          context,
          message: l.gpProError(code),
          type: DonySnackbarType.error,
        );
      },
      builder: (context, s) {
        final view = _view(s, kycVerified: kycVerified);
        final fills = switch (view) {
          _View.loading || _View.failure || _View.unavailable => true,
          _ => false,
        };
        return DonyPageScaffold(
          title: l.gpProScreenTitle,
          scrollable: !fills,
          padding: fills
              ? EdgeInsets.zero
              : EdgeInsets.fromLTRB(
                  DonyLayout.hPadding(context),
                  DonySpacing.base,
                  DonyLayout.hPadding(context),
                  DonySpacing.xl,
                ),
          stickyBottom: _bottom(view, s, kycVerified: kycVerified),
          body: _body(view, s),
        );
      },
    );
  }

  Widget? _bottom(_View view, GpProCubitState s, {required bool kycVerified}) {
    final l = context.l10n;
    final cubit = context.read<GpProCubit>();
    switch (view) {
      case _View.kyc:
        return DonyButton(
          label: l.gpProKycCta,
          iconAsset: 'shield-check',
          flat: true,
          onPressed: _openKyc,
        );
      case _View.form:
        return DonyButton(
          key: const Key('gp_pro_submit'),
          label: l.gpProSubmit,
          flat: true,
          isLoading: s.submitting,
          onPressed: s.canSubmit ? () => _submit?.call() : null,
        );
      case _View.open:
        final cancel = DonyButton(
          label: l.gpProCancel,
          variant: DonyButtonVariant.destructiveGhost,
          isLoading: s.cancelling,
          onPressed: s.cancelling ? null : _confirmCancel,
        );
        if (s.status?.state != GpProState.awaitingKyc || kycVerified) {
          return cancel;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: l.gpProKycCta,
              iconAsset: 'shield-check',
              flat: true,
              onPressed: _openKyc,
            ),
            const SizedBox(height: DonySpacing.xs),
            cancel,
          ],
        );
      case _View.rejected || _View.revoked:
        return DonyButton(
          label: l.gpProRestart,
          flat: true,
          onPressed: cubit.restart,
        );
      case _View.loading || _View.failure || _View.unavailable || _View.active:
        return null;
    }
  }

  Widget _body(_View view, GpProCubitState s) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<GpProCubit>();
    final status = s.status;

    final List<Widget> sections;
    switch (view) {
      case _View.loading:
        return Center(child: CircularProgressIndicator(color: cs.primary));
      case _View.failure:
        return DonyEmptyState(
          type: DonyEmptyStateType.error,
          iconAsset: 'wifi-off',
          title: l.gpProFailureTitle,
          description: l.gpProFailureBody,
          actionLabel: l.commonRetry,
          onAction: cubit.load,
        );
      case _View.unavailable:
        return DonyEmptyState(
          iconAsset: 'hourglass',
          title: l.gpProUnavailableTitle,
          description: l.gpProUnavailableBody,
          actionLabel: l.commonRetry,
          onAction: cubit.load,
        );
      case _View.kyc:
        sections = [
          _StatusCard(
            tone: _Tone.warning,
            iconAsset: 'shield-check',
            title: l.gpProKycTitle,
            body: l.gpProKycBody,
          ),
        ];
      case _View.form:
        sections = [
          _StatusCard(
            tone: _Tone.info,
            iconAsset: 'luggage',
            title: l.gpProIntroTitle,
            body: l.gpProIntroBody,
          ),
          GpProForm(onSubmitReady: (submit) => _submit = submit),
        ];
      case _View.open:
        final awaiting = status?.state == GpProState.awaitingKyc;
        sections = [
          _StatusCard(
            tone: awaiting ? _Tone.warning : _Tone.info,
            iconAsset: awaiting ? 'shield-check' : 'hourglass',
            title: awaiting ? l.gpProAwaitingKycTitle : l.gpProPendingTitle,
            body: awaiting ? l.gpProAwaitingKycBody : l.gpProPendingBody,
          ),
          if (status != null) _Summary(status: status),
          const GpProPiecesSection(),
        ];
      case _View.active:
        sections = [
          _StatusCard(
            tone: _Tone.info,
            leading: const GpProBadge(
              surface: 'gp_pro_screen',
              interactive: false,
            ),
            title: l.gpProActiveTitle,
            body: l.gpProActiveBody,
          ),
          Text(
            l.gpProInfoBody,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ];
      case _View.rejected:
        sections = [
          _StatusCard(
            tone: _Tone.error,
            iconAsset: 'circle-x',
            title: l.gpProRejectedTitle,
            body: l.gpProRejectedBody,
            reason: status?.reason,
          ),
        ];
      case _View.revoked:
        sections = [
          _StatusCard(
            tone: _Tone.warning,
            iconAsset: 'ban',
            title: l.gpProRevokedTitle,
            body: l.gpProRevokedBody,
            reason: status?.reason,
          ),
        ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: DonySpacing.lg),
          sections[i]
              .animate()
              .fadeIn(duration: 260.ms, delay: (60 * i).ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ],
      ],
    );
  }
}

enum _Tone { info, warning, error }

/// Encart d'état en tête d'écran : aplat de couleur, icône (ou badge), titre,
/// explication et, s'il y en a un, motif de la décision.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.tone,
    required this.title,
    required this.body,
    this.iconAsset,
    this.leading,
    this.reason,
  });

  final _Tone tone;
  final String title;
  final String body;
  final String? iconAsset;
  final Widget? leading;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (bg, fg) = switch (tone) {
      _Tone.info => (cs.infoLight, cs.info),
      _Tone.warning => (cs.warningLight, cs.warning),
      _Tone.error => (cs.errorLight, cs.error),
    };
    final motif = reason?.trim();
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconAsset != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: DonyIcon(iconAsset!, size: 20, color: fg),
            ),
            const SizedBox(width: DonySpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(height: DonySpacing.sm),
                ],
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(body, style: tt.bodyMedium),
                if (motif != null && motif.isNotEmpty) ...[
                  const SizedBox(height: DonySpacing.sm),
                  Text(
                    context.l10n.gpProReason(motif),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rappel de la demande ouverte : fréquence et nom commercial.
class _Summary extends StatelessWidget {
  const _Summary({required this.status});

  final GpProStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final frequency = status.travelFrequency;
    final name = status.commercialName?.trim();
    final rows = [
      if (frequency != null)
        (l.gpProSummaryFrequency, l.gpProFrequency(frequency)),
      if (name != null && name.isNotEmpty) (l.gpProSummaryCommercialName, name),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DonyCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: DonySpacing.lg, color: cs.outline),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rows[i].$1,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: DonySpacing.base),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.end,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
