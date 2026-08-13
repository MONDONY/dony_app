import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

class ReceptionConfirmScreen extends StatefulWidget {
  const ReceptionConfirmScreen({
    super.key,
    required this.bidId,
    required this.travelerName,
  });

  final String bidId;
  final String travelerName;

  @override
  State<ReceptionConfirmScreen> createState() => _ReceptionConfirmScreenState();
}

class _ReceptionConfirmScreenState extends State<ReceptionConfirmScreen> {
  static const _kCodeLength = 6;
  static const _kInitialSeconds = 900; // 15 min — matches server-side expiry

  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  final _tabIndex = ValueNotifier<int>(1);
  final _secondsLeft = ValueNotifier<int>(_kInitialSeconds);
  final _codeComplete = ValueNotifier<bool>(false);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _codeController.addListener(() {
      _codeComplete.value = _codeController.text.length == _kCodeLength;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    _tabIndex.dispose();
    _secondsLeft.dispose();
    _codeComplete.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _confirm(BuildContext context) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.deliveryConfirmed,
        properties: {'bid_id': widget.bidId},
      ),
    );
    context.push('/bids/${widget.bidId}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const DonyAppBar(title: 'Confirmation'),
      body: Builder(
        builder: (context) {
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              h,
              DonySpacing.xs,
              h,
              DonySpacing.huge,
            ),
            child: DonyLayout.constrained(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mascotte ─────────────────────────────────────────────────
                  const Center(
                    child: DonyMascotteAnimated(
                      type: DonyMascotteType.confiant,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.base),

                  // ── Caveat title ─────────────────────────────────────────────
                  Text(
                    'Confirmer la réception',
                    style: DonyTypography.caveat(
                      fontSize: 28,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    'Devant ${widget.travelerName}, choisissez :',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: DonySpacing.lg),

                  // ── Tab toggle ───────────────────────────────────────────────
                  ValueListenableBuilder<int>(
                    valueListenable: _tabIndex,
                    builder: (context, tab, _) => _TabToggle(
                      selected: tab,
                      onTap: (i) {
                        _tabIndex.value = i;
                        if (i == 1) {
                          _focusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xl),

                  // ── Tab content ──────────────────────────────────────────────
                  ValueListenableBuilder<int>(
                    valueListenable: _tabIndex,
                    builder: (context, tab, _) {
                      if (tab == 0) {
                        return const _QrTabContent();
                      }
                      return _CodeTabContent(
                        codeController: _codeController,
                        focusNode: _focusNode,
                        secondsLeft: _secondsLeft,
                        formatTime: _formatTime,
                      );
                    },
                  ),
                  const SizedBox(height: DonySpacing.xl),

                  // ── CTA ──────────────────────────────────────────────────────
                  ValueListenableBuilder<bool>(
                    valueListenable: _codeComplete,
                    builder: (context, complete, _) =>
                        ValueListenableBuilder<int>(
                          valueListenable: _tabIndex,
                          builder: (context, tab, _) => DonyButton(
                            label: 'Confirmer la réception',
                            iconAsset: 'check',
                            onPressed: (tab == 1 && complete)
                                ? () => _confirm(context)
                                : null,
                          ),
                        ),
                  ),
                  const SizedBox(height: DonySpacing.lg),

                  // ── Legal note ───────────────────────────────────────────────
                  _LegalNote(
                    travelerName: widget.travelerName,
                    bidId: widget.bidId,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Tab toggle ────────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.selected, required this.onTap});

  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              label: 'Lire le QR',
              selected: selected == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _TabItem(
              label: 'Taper le code',
              selected: selected == 1,
              onTap: () => onTap(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.sm,
          horizontal: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: DonyColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: tt.labelLarge?.copyWith(
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── QR tab content ────────────────────────────────────────────────────────────

class _QrTabContent extends StatelessWidget {
  const _QrTabContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          DonyIcon('scan-line', size: 48, color: cs.primary),
          const SizedBox(height: DonySpacing.base),
          Text(
            'Lire le QR code',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Demandez au voyageur d\'afficher le QR code sur son téléphone.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Code tab content ──────────────────────────────────────────────────────────

class _CodeTabContent extends StatelessWidget {
  const _CodeTabContent({
    required this.codeController,
    required this.focusNode,
    required this.secondsLeft,
    required this.formatTime,
  });

  final TextEditingController codeController;
  final FocusNode focusNode;
  final ValueNotifier<int> secondsLeft;
  final String Function(int) formatTime;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final defaultTheme = PinTheme(
      width: 64,
      height: 72,
      textStyle: tt.headlineMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline, width: 1.5),
      ),
    );

    final focusedTheme = defaultTheme.copyDecorationWith(
      border: Border.all(color: cs.primary, width: 2),
      borderRadius: BorderRadius.circular(DonyRadius.card),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPTION 2 · CODE',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        Center(
          child: Text(
            'Tapez le code reçu',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        Center(
          child: Pinput(
            length: 6,
            controller: codeController,
            focusNode: focusNode,
            defaultPinTheme: defaultTheme,
            focusedPinTheme: focusedTheme,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        ValueListenableBuilder<int>(
          valueListenable: secondsLeft,
          builder: (context, secs, _) {
            final innerCs = Theme.of(context).colorScheme;
            return Center(
              child: Text.rich(
                TextSpan(
                  style: tt.bodySmall?.copyWith(
                    color: innerCs.onSurfaceVariant,
                  ),
                  children: [
                    const TextSpan(text: 'Reçu par SMS · expire dans '),
                    TextSpan(
                      text: formatTime(secs),
                      style: TextStyle(
                        color: innerCs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Legal note ────────────────────────────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  const _LegalNote({required this.travelerName, required this.bidId});

  final String travelerName;
  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon(
            'shield',
            size: DonySpacing.iconSm,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                children: [
                  TextSpan(
                    text:
                        'En confirmant, vous libérez le paiement vers $travelerName. '
                        'Si quelque chose ne va pas, ',
                  ),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => context.push('/disputes'),
                      child: Text(
                        'contestez d\'abord',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
