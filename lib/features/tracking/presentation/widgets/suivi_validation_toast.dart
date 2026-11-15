import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/suivi_validation_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bandeaux des validations rapides en attente d'envoi, du plus récent au
/// plus ancien : « Transit de Madou validé », « Annuler » et le décompte.
/// Le délai écoulé, le bandeau devient « Envoi… » jusqu'à la réponse du
/// serveur : une photo peut mettre du temps à partir.
class SuiviPendingValidations extends StatelessWidget {
  const SuiviPendingValidations({super.key});

  /// Au-delà, les plus anciens restent en attente sans bandeau (ils partent
  /// quand même à la fin de leur délai).
  static const maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SuiviValidationCubit, SuiviValidationState>(
      buildWhen: (a, b) => a.pending != b.pending || a.sending != b.sending,
      builder: (context, state) {
        final visible = state.pending.reversed.take(maxVisible).toList();
        final sending = state.sending.reversed
            .take(maxVisible - visible.length)
            .toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pending in visible)
              Padding(
                key: ValueKey<int>(pending.id),
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: _ValidationToast(pending: pending),
              ),
            for (final item in sending)
              Padding(
                key: ValueKey<String>('sending-${item.id}'),
                padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                child: _SendingToast(sending: item),
              ),
          ],
        );
      },
    );
  }
}

class _ValidationToast extends StatefulWidget {
  const _ValidationToast({required this.pending});

  final PendingValidation pending;

  @override
  State<_ValidationToast> createState() => _ValidationToastState();
}

class _ValidationToastState extends State<_ValidationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;

  @override
  void initState() {
    super.initState();
    final total = context.read<SuiviValidationCubit>().delay;
    final left = widget.pending.deadline.difference(DateTime.now());
    final start = total.inMilliseconds == 0
        ? 1.0
        : (1 - left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    _countdown = AnimationController(vsync: this, duration: total, value: start)
      ..forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final pending = widget.pending;
    final total = context.read<SuiviValidationCubit>().delay;

    return Semantics(
      liveRegion: true,
      child: Material(
        color: cs.surface,
        elevation: 8,
        shadowColor: DonyColors.neutral900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _countdown,
          builder: (context, _) {
            final seconds =
                ((1 - _countdown.value) * total.inMilliseconds / 1000).ceil();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base,
                    DonySpacing.md,
                    DonySpacing.md,
                    DonySpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pending.deposit
                                  ? l.suiviDepositValidatedToast(
                                      pending.parcelLabel,
                                    )
                                  : l.suiviStepValidatedToast(
                                      pending.step,
                                      pending.parcelLabel,
                                    ),
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: DonySpacing.xxs),
                            Text(
                              l.suiviToastSendingIn(
                                pending.photoPath != null ? 'yes' : 'no',
                                seconds,
                              ),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: DonySpacing.md),
                      OutlinedButton(
                        key: Key('suivi-undo-${pending.id}'),
                        onPressed: () => context
                            .read<SuiviValidationCubit>()
                            .undo(pending.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(color: cs.outline),
                          minimumSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                          ),
                        ),
                        child: Text(l.suiviUndo),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: LinearProgressIndicator(
                    value: 1 - _countdown.value,
                    minHeight: 3,
                    color: cs.primary,
                    backgroundColor: cs.outline.withValues(alpha: 0.4),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Validation partie, réponse du serveur attendue : ni décompte ni
/// « Annuler », un indicateur d'envoi.
class _SendingToast extends StatelessWidget {
  const _SendingToast({required this.sending});

  final PendingValidation sending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      child: Material(
        key: Key('suivi-sending-${sending.bidId}'),
        color: cs.surface,
        elevation: 8,
        shadowColor: DonyColors.neutral900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Text(
                      l.suiviSendingToast(
                        sending.photoPath != null ? 'yes' : 'no',
                        sending.parcelLabel,
                      ),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                minHeight: 3,
                color: cs.primary,
                backgroundColor: cs.outline.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
