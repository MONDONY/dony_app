import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TrackingSearchScreen extends StatefulWidget {
  const TrackingSearchScreen({
    super.key,
    this.onScanTrip,
    this.showBackButton = true,
  });

  /// Entrée additive « Scanner un trajet » (voyageur occasionnel). Null = non affichée.
  final VoidCallback? onScanTrip;

  /// Masque le bouton retour quand l'écran est rendu in-shell.
  final bool showBackButton;

  @override
  State<TrackingSearchScreen> createState() => _TrackingSearchScreenState();
}

class _TrackingSearchScreenState extends State<TrackingSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(BuildContext context) {
    final number = _controller.text.trim().toUpperCase();
    if (number.isEmpty) {
      return;
    }
    _focusNode.unfocus();
    context.read<TrackingBloc>().add(TrackingSearchRequested(number));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Suivre un colis',
        showBackButton: widget.showBackButton,
      ),
      body: Builder(
        builder: (context) {
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              h,
              DonySpacing.xxl,
              h,
              100 + MediaQuery.paddingOf(context).bottom,
            ),
            child: DonyLayout.constrained(
              context,
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.onScanTrip != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            0,
                            0,
                            0,
                            DonySpacing.lg,
                          ),
                          child: SecondaryActivityEntry(
                            iconAsset: 'scan-line',
                            label: 'Lire le QR d\'un trajet',
                            onTap: widget.onScanTrip!,
                          ),
                        ),
                      ],
                      _buildSearchHeader(cs, tt),
                      const SizedBox(height: DonySpacing.xl),
                      _buildSearchField(cs, tt),
                      const SizedBox(height: DonySpacing.lg),
                      DonyButton(
                        label: 'Rechercher',
                        onPressed: () => _search(context),
                        iconAsset: 'search',
                      ),
                      const SizedBox(height: DonySpacing.xxl),
                      BlocBuilder<TrackingBloc, TrackingState>(
                        builder: (context, state) {
                          if (state is TrackingSearchLoading) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: CircularProgressIndicator(
                                  color: cs.primary,
                                ),
                              ),
                            );
                          }
                          if (state is TrackingSearchError) {
                            return _buildError(
                              ErrorPresenter.resolve(state.error).message,
                              cs,
                              context,
                            );
                          }
                          if (state is TrackingSearchLoaded) {
                            return _TrackingResultCard(result: state.result);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.04, curve: Curves.easeOutCubic),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchHeader(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Numéro de suivi', style: tt.headlineLarge),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Entrez le numéro DON-XXXXXX pour suivre votre colis en temps réel.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme cs, TextTheme tt) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.characters,
      style: tt.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        labelText: 'Numéro de suivi',
        hintText: 'DON-XXXXXX',
        hintStyle: tt.bodyLarge?.copyWith(
          color: cs.outline,
          letterSpacing: 1.5,
        ),
        prefixIcon: DonyIcon('qr-code', size: 20, color: cs.primary),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      onSubmitted: (_) => _search(context),
    );
  }

  Widget _buildError(String message, ColorScheme cs, BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          DonyIcon('circle-alert', color: cs.error, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _TrackingResultCard extends StatelessWidget {
  final TrackingSearchModel result;
  const _TrackingResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (String? icon, Color color, _, String? iconAsset) = _stepVisuals(
      result.currentStep,
      cs,
    );

    return DonyCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header corridor
              Container(
                padding: const EdgeInsets.all(DonySpacing.lg),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [DonyColors.blue900, DonyColors.blue600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(DonyRadius.card),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.md,
                            vertical: DonySpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(DonyRadius.sm),
                          ),
                          child: Text(
                            result.trackingNumber,
                            style: tt.labelLarge?.copyWith(
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            result.departureCity,
                            textAlign: TextAlign.center,
                            style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.base,
                          ),
                          child: DonyIcon(
                            'arrow-right',
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            result.arrivalCity,
                            textAlign: TextAlign.center,
                            style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Step indicator
              Padding(
                padding: const EdgeInsets.all(DonySpacing.lg),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          switch (iconAsset) {
                            'plane-takeoff' => const DonyEmoji.planeTakeoff(
                              size: 22,
                            ),
                            'plane-landing' => const DonyEmoji.planeLanding(
                              size: 22,
                            ),
                            'package' => const DonyEmoji.parcel(size: 22),
                            _ => DonyIcon(icon!, color: color, size: 22),
                          },
                          const SizedBox(width: DonySpacing.md),
                          Expanded(
                            child: Text(
                              result.stepLabel,
                              style: tt.titleMedium?.copyWith(color: color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DonySpacing.base),
                    _StepTimeline(currentStep: result.currentStep),
                    if ((result.arrivalInstructions ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: DonySpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(DonySpacing.base),
                        decoration: BoxDecoration(
                          color: cs.infoLight,
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructions de retrait',
                              style: tt.titleSmall?.copyWith(color: cs.info),
                            ),
                            const SizedBox(height: DonySpacing.xs),
                            Text(
                              result.arrivalInstructions!,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: DonySpacing.lg),
                    DonyButton(
                      label: 'Voir le suivi détaillé',
                      onPressed: () {
                        final corridor =
                            '${result.departureCity} → ${result.arrivalCity}';
                        context.push(
                          '/tracking/${result.bidId}/timeline',
                          extra: corridor,
                        );
                      },
                      variant: DonyButtonVariant.secondary,
                      iconAsset: 'chart-line',
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  (String?, Color, String, String?) _stepVisuals(String step, ColorScheme cs) {
    return switch (step) {
      'DELIVERED' => ('circle-check', cs.success, step, null),
      'IN_TRANSIT' => (null, cs.primary, step, 'package'),
      'DEPARTED' => (null, cs.primary, step, 'plane-takeoff'),
      'PAYMENT_SECURED' => ('lock', cs.primary, step, null),
      'ACCEPTED' => ('handshake', cs.warning, step, null),
      'REJECTED' => ('circle-x', cs.error, step, null),
      'CANCELLED' => ('ban', cs.onSurfaceVariant, step, null),
      _ => ('hourglass', cs.warning, step, null),
    };
  }
}

class _StepTimeline extends StatelessWidget {
  final String currentStep;
  const _StepTimeline({required this.currentStep});

  static const _steps = [
    ('PENDING', 'En attente'),
    ('ACCEPTED', 'Confirmé'),
    ('PAYMENT_SECURED', 'Payé'),
    ('DEPARTED', 'Remis'),
    ('IN_TRANSIT', 'Transit'),
    ('DELIVERED', 'Livré'),
  ];

  int _stepIndex(String step) {
    final idx = _steps.indexWhere((s) => s.$1 == step);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (currentStep == 'REJECTED' || currentStep == 'CANCELLED') {
      return const SizedBox.shrink();
    }
    final current = _stepIndex(currentStep);

    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = (i + 1) ~/ 2;
          final isActive = stepIdx <= current;
          return Expanded(
            child: Container(
              height: 2,
              color: isActive ? cs.primary : cs.outline,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final isDone = stepIdx < current;
        final isActive = stepIdx == current;

        final Color dotColor;
        if (isDone || isActive) {
          dotColor = cs.primary;
        } else {
          dotColor = cs.outline;
        }

        return Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: isActive
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              _steps[stepIdx].$2,
              style: tt.labelSmall?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}
