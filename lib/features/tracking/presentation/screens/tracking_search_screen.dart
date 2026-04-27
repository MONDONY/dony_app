import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: DonyColors.green400),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Suivre un colis',
          style: GoogleFonts.sora(
              fontWeight: FontWeight.w700, fontSize: 18, color: DonyColors.ink900),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.grey100),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHeader(),
            const SizedBox(height: 28),
            _buildSearchField(context),
            const SizedBox(height: 20),
            _buildSearchButton(context),
            const SizedBox(height: 32),
            BlocBuilder<TrackingBloc, TrackingState>(
              builder: (context, state) {
                if (state is TrackingSearchLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(color: DonyColors.green400),
                    ),
                  );
                }
                if (state is TrackingSearchError) {
                  return _buildError(state.message);
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

  Widget _buildSearchHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DonyColors.green100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.local_shipping_outlined, color: DonyColors.green400, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'Numéro de suivi',
          style: GoogleFonts.sora(
              fontSize: 22, fontWeight: FontWeight.w800, color: DonyColors.ink900),
        ),
        const SizedBox(height: 6),
        Text(
          'Entrez le numéro DON-XXXXXX pour suivre votre colis en temps réel.',
          style: GoogleFonts.sora(fontSize: 14, color: DonyColors.grey400, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textCapitalization: TextCapitalization.characters,
      style: GoogleFonts.sora(
          fontSize: 18, fontWeight: FontWeight.w700,
          letterSpacing: 2, color: DonyColors.ink900),
      decoration: InputDecoration(
        labelText: 'Numéro de suivi',
        hintText: 'DON-XXXXXX',
        hintStyle: GoogleFonts.sora(
            fontSize: 16, color: DonyColors.grey200, letterSpacing: 1.5),
        prefixIcon: const Icon(Icons.qr_code_rounded, color: DonyColors.green400),
        filled: true,
        fillColor: DonyColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.grey100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.grey100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DonyColors.green400, width: 2),
        ),
      ),
      onSubmitted: (_) => _search(context),
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _search(context),
        icon: const Icon(Icons.search_rounded),
        label: Text(
          'Rechercher',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: DonyColors.green400,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DonyColors.error.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DonyColors.error.withValues(alpha:0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DonyColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.sora(
                  fontSize: 13, fontWeight: FontWeight.w500, color: DonyColors.error),
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
    final (IconData icon, Color color, _) = _stepVisuals(result.currentStep);

    return Container(
      decoration: BoxDecoration(
        color: DonyColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DonyColors.grey100),
      ),
      child: Column(
        children: [
          // Header corridor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        result.trackingNumber,
                        style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        result.departureCity,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 24),
                    ),
                    Expanded(
                      child: Text(
                        result.arrivalCity,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Step indicator
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha:0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          result.stepLabel,
                          style: GoogleFonts.sora(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _StepTimeline(currentStep: result.currentStep),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final corridor =
                          '${result.departureCity} → ${result.arrivalCity}';
                      context.push(
                          '/tracking/${result.bidId}/timeline',
                          extra: corridor);
                    },
                    icon: const Icon(Icons.timeline_rounded, size: 18),
                    label: Text(
                      'Voir le suivi détaillé',
                      style: GoogleFonts.sora(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DonyColors.green400,
                      side: const BorderSide(color: DonyColors.green400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }

  (IconData, Color, String) _stepVisuals(String step) {
    return switch (step) {
      'DELIVERED'       => (Icons.check_circle_rounded, DonyColors.success, step),
      'IN_TRANSIT'      => (Icons.local_shipping_rounded, DonyColors.green400, step),
      'DEPARTED'        => (Icons.flight_takeoff_rounded, DonyColors.green400, step),
      'PAYMENT_SECURED' => (Icons.lock_rounded, DonyColors.green400, step),
      'ACCEPTED'        => (Icons.handshake_outlined, DonyColors.warning, step),
      'REJECTED'        => (Icons.cancel_outlined, DonyColors.error, step),
      'CANCELLED'       => (Icons.block_outlined, DonyColors.grey400, step),
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
              color: isActive ? DonyColors.green400 : DonyColors.grey100,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final isDone = stepIdx < current;
        final isActive = stepIdx == current;

        Color dotColor;
        if (isDone) {
          dotColor = DonyColors.green400;
        } else if (isActive) {
          dotColor = DonyColors.green400;
        } else {
          dotColor = DonyColors.grey100;
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
                    ? Border.all(color: DonyColors.green400, width: 2)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _steps[stepIdx].$2,
              style: GoogleFonts.sora(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? DonyColors.green400 : DonyColors.grey200),
            ),
          ],
        );
      }),
    );
  }
}
