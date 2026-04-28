import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TrackingSearchScreen extends StatefulWidget {
  const TrackingSearchScreen({super.key});

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
      appBar: const DonyAppBar(title: 'Suivre un colis'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xxl, DonySpacing.lg, DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHeader(cs, tt),
            const SizedBox(height: DonySpacing.xl),
            _buildSearchField(cs, tt),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(
              label: 'Rechercher',
              onPressed: () => _search(context),
              icon: Icons.search_rounded,
            ),
            const SizedBox(height: DonySpacing.xxl),
            BlocBuilder<TrackingBloc, TrackingState>(
              builder: (context, state) {
                if (state is TrackingSearchLoading) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: cs.primary),
                    ),
                  );
                }
                if (state is TrackingSearchError) {
                  return _buildError(state.message, cs, context);
                }
                if (state is TrackingSearchLoaded) {
                  return _TrackingResultCard(result: state.result);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildSearchHeader(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          child: Icon(Icons.local_shipping_outlined, color: cs.primary, size: 28),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(
          'Numéro de suivi',
          style: tt.headlineLarge,
        ),
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
        prefixIcon: Icon(Icons.qr_code_rounded, color: cs.primary),
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
          Icon(Icons.error_outline_rounded, color: cs.error, size: 22),
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
    final (IconData icon, Color color, _) = _stepVisuals(result.currentStep, cs);

    return DonyCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header corridor
          Container(
            padding: const EdgeInsets.all(DonySpacing.lg),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
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
                        horizontal: DonySpacing.sm + 2,
                        vertical: DonySpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: DonyColors.neutral0.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: Text(
                        result.trackingNumber,
                        style: tt.labelLarge?.copyWith(
                          color: DonyColors.neutral0,
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
                          color: DonyColors.neutral0,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
                      child: Icon(Icons.arrow_forward_rounded,
                          color: DonyColors.neutral0.withValues(alpha: 0.7), size: 24),
                    ),
                    Expanded(
                      child: Text(
                        result.arrivalCity,
                        textAlign: TextAlign.center,
                        style: tt.headlineMedium?.copyWith(
                          color: DonyColors.neutral0,
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
                      Icon(icon, color: color, size: 22),
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
                const SizedBox(height: DonySpacing.lg),
                DonyButton(
                  label: 'Voir le suivi détaillé',
                  onPressed: () {
                    final corridor =
                        '${result.departureCity} → ${result.arrivalCity}';
                    context.push(
                        '/tracking/${result.bidId}/timeline',
                        extra: corridor);
                  },
                  variant: DonyButtonVariant.secondary,
                  icon: Icons.timeline_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  (IconData, Color, String) _stepVisuals(String step, ColorScheme cs) {
    return switch (step) {
      'DELIVERED'       => (Icons.check_circle_rounded, DonyColors.success, step),
      'IN_TRANSIT'      => (Icons.local_shipping_rounded, cs.primary, step),
      'DEPARTED'        => (Icons.flight_takeoff_rounded, cs.primary, step),
      'PAYMENT_SECURED' => (Icons.lock_rounded, cs.primary, step),
      'ACCEPTED'        => (Icons.handshake_outlined, DonyColors.warning, step),
      'REJECTED'        => (Icons.cancel_outlined, DonyColors.error, step),
      'CANCELLED'       => (Icons.block_outlined, DonyColors.neutral400, step),
      _                 => (Icons.hourglass_empty_rounded, DonyColors.warning, step),
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
            const SizedBox(height: DonySpacing.xs + 2),
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
