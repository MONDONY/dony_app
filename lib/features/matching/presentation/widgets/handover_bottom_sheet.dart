import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class HandoverBottomSheet extends StatefulWidget {
  const HandoverBottomSheet({super.key, required this.bid});

  final BidModel bid;

  static Future<void> show(BuildContext context, {required BidModel bid}) {
    return DonyBottomSheet.show(
      context,
      title: 'Lieu de remise',
      subtitle: '${bid.id.substring(0, 6).toUpperCase()} · ${bid.weightKg} kg',
      child: BlocProvider.value(
        value: context.read<BidBloc>(),
        child: HandoverBottomSheet(bid: bid),
      ),
    );
  }

  @override
  State<HandoverBottomSheet> createState() => _HandoverBottomSheetState();
}

class _HandoverBottomSheetState extends State<HandoverBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  DateTime? _windowStart;
  DateTime? _windowEnd;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(BuildContext context,
      {required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: this.context, // ignore: use_build_context_synchronously
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) {
      return;
    }

    final dt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _windowStart = dt;
        if (_windowEnd != null && !_windowEnd!.isAfter(dt)) {
          _windowEnd = null;
        }
      } else {
        _windowEnd = dt;
      }
    });
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_windowStart == null || _windowEnd == null) {
      DonySnackbar.show(
        context,
        message: 'Veuillez définir le début et la fin de la fenêtre',
        type: DonySnackbarType.error,
      );
      return;
    }
    if (!_windowEnd!.isAfter(_windowStart!)) {
      DonySnackbar.show(
        context,
        message: 'La fin de la fenêtre doit être après le début',
        type: DonySnackbarType.error,
      );
      return;
    }
    context.read<BidBloc>().add(BidHandoverRequested(
      bidId: widget.bid.id,
      location: _locationCtrl.text.trim(),
      windowStart: _windowStart!,
      windowEnd: _windowEnd!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidHandoverSet) {
          Navigator.of(context).pop();
          DonySnackbar.show(
            context,
            message: "Fenêtre de remise enregistrée. L'expéditeur a été notifié.",
            type: DonySnackbarType.success,
          );
        } else if (state is BidError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is BidLoading;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  border:
                      Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: cs.primary, size: 20),
                    const SizedBox(width: DonySpacing.sm),
                    Expanded(
                      child: Text(
                        "L'expéditeur recevra une notification avec le lieu et l'heure de remise.",
                        style: tt.bodySmall?.copyWith(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DonySpacing.lg),

              // Location field
              Text(
                'Adresse de remise',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              TextFormField(
                controller: _locationCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Lieu requis' : null,
                scrollPadding: const EdgeInsets.only(bottom: 120),
                decoration: _inputDecoration(
                  'Ex: Gare du Nord, Paris — Hall 2',
                  cs: cs,
                  tt: tt,
                ),
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
              ),
              const SizedBox(height: DonySpacing.lg),

              // Time window
              Text(
                'Fenêtre horaire',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              _DateTimeTile(
                label: 'Heure de début',
                value: _windowStart,
                icon: Icons.schedule_rounded,
                onTap: () => _pickDateTime(context, isStart: true),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(height: DonySpacing.md),
              _DateTimeTile(
                label: 'Heure de fin',
                value: _windowEnd,
                icon: Icons.schedule_rounded,
                onTap: () => _pickDateTime(context, isStart: false),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(height: DonySpacing.xl),

              DonyButton(
                label: 'Confirmer la remise',
                isLoading: isLoading,
                onPressed: isLoading ? null : () => _submit(context),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: tt.bodyMedium?.copyWith(color: cs.outline),
      filled: true,
      fillColor: cs.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
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
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DonyRadius.md),
        borderSide: BorderSide(color: cs.error),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: value != null
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value != null ? cs.primary : cs.outline,
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value != null
                        ? DateFormat('EEE d MMM yyyy à HH:mm', 'fr')
                            .format(value!)
                        : 'Sélectionner',
                    style: tt.bodyMedium?.copyWith(
                      color:
                          value != null ? cs.onSurface : cs.outline,
                      fontWeight: value != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
