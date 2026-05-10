import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HandoverScreen extends StatefulWidget {
  final BidModel bid;
  const HandoverScreen({super.key, required this.bid});

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  DateTime? _windowStart;
  DateTime? _windowEnd;

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
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
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !mounted) {
      return;
    }

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

  void _submit() {
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

    return BlocListener<BidBloc, BidState>(
      listener: (context, state) {
        if (state is BidHandoverSet) {
          DonySnackbar.show(
            context,
            message: "Fenêtre de remise enregistrée. L'expéditeur a été notifié.",
            type: DonySnackbarType.success,
          );
          context.read<AnnouncementBloc>().add(AnnouncementListRequested());
          context.go('/announcements');
        } else if (state is BidError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Scaffold(
        appBar: const DonyAppBar(title: 'Fenêtre de remise'),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            DonyLayout.hPadding(context), DonySpacing.xl, DonyLayout.hPadding(context), DonySpacing.huge + DonySpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoBanner(cs: cs, tt: tt),
                const SizedBox(height: DonySpacing.xl),
                _Section(
                  title: 'Lieu de remise',
                  tt: tt,
                  cs: cs,
                  child: TextFormField(
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
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: DonySpacing.lg),
                _Section(
                  title: 'Fenêtre horaire',
                  tt: tt,
                  cs: cs,
                  child: Column(
                    children: [
                      _DateTimeTile(
                        label: 'Début',
                        value: _windowStart,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(true),
                        cs: cs,
                        tt: tt,
                      ),
                      const SizedBox(height: DonySpacing.md),
                      _DateTimeTile(
                        label: 'Fin',
                        value: _windowEnd,
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickDateTime(false),
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        ),
        bottomNavigationBar: _SubmitBar(onSubmit: _submit, cs: cs),
      ),
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
        horizontal: DonySpacing.base, vertical: DonySpacing.md,
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
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              "L'expéditeur recevra une notification avec le lieu et l'heure de remise dès que vous confirmez.",
              style: tt.bodySmall?.copyWith(color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final ColorScheme cs;
  final TextTheme tt;
  const _Section({required this.title, required this.child, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        child,
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base, vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: value != null ? cs.primary.withValues(alpha: 0.4) : cs.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: value != null ? cs.primary : cs.outline),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    value != null
                        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(value!)
                        : 'Sélectionner',
                    style: tt.bodyMedium?.copyWith(
                      color: value != null ? cs.onSurface : cs.outline,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final VoidCallback onSubmit;
  final ColorScheme cs;
  const _SubmitBar({required this.onSubmit, required this.cs});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BidBloc, BidState>(
      builder: (context, state) {
        final isLoading = state is BidLoading;
        return Container(
          color: cs.surface,
          padding: EdgeInsets.fromLTRB(
            DonyLayout.hPadding(context), DonySpacing.base,
            DonyLayout.hPadding(context), MediaQuery.of(context).padding.bottom + DonySpacing.base,
          ),
          child: DonyButton(
            label: 'Confirmer la fenêtre de remise',
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
          ),
        );
      },
    );
  }
}
