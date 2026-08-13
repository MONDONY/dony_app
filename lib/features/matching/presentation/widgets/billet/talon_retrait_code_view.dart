import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Talon "code de retrait" — extracted from _ConfirmationCodeCard.
///
/// Displays the confirmation code as individual dark digit boxes (one box per
/// character) instead of a single large text widget.  All regeneration logic,
/// rate-limit countdown and BLoC handling are preserved byte-for-byte from the
/// original _ConfirmationCodeCard / _ConfirmationCodeCardState.
class TalonRetraitCodeView extends StatefulWidget {
  final String bidId;
  final String initialCode;
  final int refreshCount;
  final DateTime? refreshWindowStart;

  const TalonRetraitCodeView({
    super.key,
    required this.bidId,
    required this.initialCode,
    required this.refreshCount,
    this.refreshWindowStart,
  });

  @override
  State<TalonRetraitCodeView> createState() => _TalonRetraitCodeViewState();
}

class _TalonRetraitCodeViewState extends State<TalonRetraitCodeView> {
  static const int _maxRefreshes = 5;
  static const Duration _window = Duration(hours: 24);

  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initCountdown(widget.refreshCount, widget.refreshWindowStart);
  }

  @override
  void didUpdateWidget(TalonRetraitCodeView old) {
    super.didUpdateWidget(old);
    if (old.refreshCount != widget.refreshCount ||
        old.refreshWindowStart != widget.refreshWindowStart) {
      _timer?.cancel();
      _initCountdown(widget.refreshCount, widget.refreshWindowStart);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initCountdown(int count, DateTime? windowStart) {
    if (count < _maxRefreshes || windowStart == null) {
      _remaining = Duration.zero;
      return;
    }
    final expiry = windowStart.toUtc().add(_window);
    final now = DateTime.now().toUtc();
    if (!now.isBefore(expiry)) {
      _remaining = Duration.zero;
      return;
    }
    _remaining = expiry.difference(now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Fix #2: always_put_control_body_on_new_line
      if (!mounted) {
        return;
      }
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _timer?.cancel();
        }
      });
    });
  }

  bool get _isRateLimited => _remaining > Duration.zero;

  String _formatRemaining() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    // Fix #2: always_put_control_body_on_new_line
    if (h > 0) {
      return '${h}h ${m}min ${s}s';
    }
    return '${m}min ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (_, c) =>
          c is TrackingConfirmCodeLoaded || c is TrackingRefreshCodeError,
      listener: (ctx, state) {
        if (state is TrackingRefreshCodeError) {
          ErrorPresenter.show(ctx, state.error);
        } else if (state is TrackingConfirmCodeLoaded) {
          ctx.read<BidBloc>().add(BidDetailRequested(widget.bidId));
        }
      },
      buildWhen: (_, c) =>
          c is TrackingRefreshCodeLoading ||
          c is TrackingConfirmCodeLoaded ||
          c is TrackingRefreshCodeError,
      builder: (ctx, state) {
        final isApiLoading = state is TrackingRefreshCodeLoading;
        final isBlocked = _isRateLimited || isApiLoading;
        final displayCode = state is TrackingConfirmCodeLoaded
            ? state.code ?? widget.initialCode
            : widget.initialCode;

        return Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CODE DE RETRAIT',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              // Fix #1: Responsive digit-box row using LayoutBuilder.
              // Formula: boxWidth = (availableWidth / digitCount).clamp(36, 56)
              // where availableWidth = constraints.maxWidth − (digitCount × 2 × DonySpacing.xs)
              // boxHeight = boxWidth × (56/48) ≈ 1.167 (original aspect ratio), clamped [42, 65]
              LayoutBuilder(
                builder: (_, constraints) {
                  final digits = displayCode.split('');
                  final n = digits.length;
                  // Total horizontal margin per box = 2 × DonySpacing.xs = 8px
                  const marginPerBox = DonySpacing.xs * 2.0;
                  final availableWidth =
                      constraints.maxWidth - (n * marginPerBox);
                  final boxWidth = (availableWidth / n).clamp(24.0, 56.0);
                  // Preserve original aspect ratio 56/48 ≈ 1.1667
                  final boxHeight = (boxWidth * 56.0 / 48.0).clamp(28.0, 65.0);
                  final fontSize = (boxWidth * 0.55).clamp(13.0, 22.0);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: digits.map((digit) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.xs,
                        ),
                        width: boxWidth,
                        height: boxHeight,
                        decoration: BoxDecoration(
                          color: DonyColors.ink800,
                          borderRadius: BorderRadius.circular(DonyRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          digit,
                          style: tt.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            fontSize: fontSize,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: DonySpacing.md),
              // Fix #3 + Fix #4: DonySnackbar + 44pt touch target for copy button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: displayCode));
                  DonySnackbar.show(
                    ctx,
                    message: 'Code copié',
                    type: DonySnackbarType.success,
                  );
                },
                child: SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary),
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DonyIcon('copy', size: 16, color: cs.primary),
                        const SizedBox(width: DonySpacing.sm),
                        Text(
                          'Copier le code',
                          style: tt.titleSmall?.copyWith(color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              // Fix #4: 44pt touch target for regenerate button
              Opacity(
                opacity: isBlocked ? 0.45 : 1.0,
                child: GestureDetector(
                  onTap: isBlocked
                      ? null
                      : () => ctx.read<TrackingBloc>().add(
                          TrackingRefreshCodeRequested(widget.bidId),
                        ),
                  child: SizedBox(
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.md),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isApiLoading)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onSecondaryContainer,
                              ),
                            )
                          else if (_isRateLimited)
                            DonyIcon(
                              'clock',
                              size: 16,
                              color: cs.onSecondaryContainer,
                            )
                          else
                            DonyIcon(
                              'refresh-cw',
                              size: 16,
                              color: cs.onSecondaryContainer,
                            ),
                          const SizedBox(width: DonySpacing.sm),
                          if (isApiLoading)
                            Text(
                              'Régénération…',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            )
                          else if (_isRateLimited)
                            Text(
                              'Disponible dans ${_formatRemaining()}',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            )
                          else
                            Text(
                              'Régénérer le code',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isRateLimited) ...[
                const SizedBox(height: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                    border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('ban', size: 14, color: cs.error),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          'Limite de 5 régénérations atteinte. Le bouton se réactivera automatiquement dans ${_formatRemaining()}.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.warningLight,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                    border: Border.all(
                      color: cs.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('info', size: 14, color: cs.warning),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          'Transmettez ce code au voyageur par vos propres moyens (SMS, WhatsApp…). Il devra le saisir à la livraison.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }
}
