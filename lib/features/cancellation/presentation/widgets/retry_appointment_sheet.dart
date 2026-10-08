import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Feuille « Nouveau rendez-vous » de l'expéditeur pendant la garde du colis
/// (FLUTTER-E2). Le rendez-vous doit tomber avant la fin de la garde
/// ([holdUntil]) : la garde n'est pas prolongée.
class RetryAppointmentSheet extends StatefulWidget {
  const RetryAppointmentSheet({
    super.key,
    required this.holdUntil,
    this.onSubmitReady,
    this.onCanSubmitChanged,
    this.now,
  });

  final DateTime holdUntil;
  final void Function(VoidCallback)? onSubmitReady;
  final ValueChanged<bool>? onCanSubmitChanged;

  /// Horloge injectable pour les tests.
  final DateTime Function()? now;

  static Future<void> show(
    BuildContext context, {
    required DeliveryNoShowProcedureCubit cubit,
    required DateTime holdUntil,
  }) {
    VoidCallback? submit;
    // Écrit uniquement par les choix de l'utilisateur (date, heure) : la
    // disposition au pop est sûre (CLAUDE.md, règle des ValueNotifier).
    final canSubmit = ValueNotifier<bool>(false);
    final l = context.l10n;
    return DonyBottomSheet.show(
      context,
      title: l.dnpAppointmentSheetTitle,
      subtitle: l.dnpAppointmentSheetSubtitle(
        DateFormat.MMMEd(l.localeName).add_Hm().format(holdUntil.toLocal()),
      ),
      wrapper: (child) => BlocProvider.value(value: cubit, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<
              DeliveryNoShowProcedureCubit,
              DeliveryNoShowProcedureState
            >(
              builder: (ctx, state) {
                final loading =
                    state is DeliveryNoShowProcedureLoaded && state.submitting;
                return DonyButton(
                  key: const Key('dnp-appointment-submit'),
                  label: l.dnpAppointmentSubmit,
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: RetryAppointmentSheet(
        holdUntil: holdUntil,
        onSubmitReady: (fn) => submit = fn,
        onCanSubmitChanged: (v) => canSubmit.value = v,
      ),
    ).whenComplete(canSubmit.dispose);
  }

  @override
  State<RetryAppointmentSheet> createState() => _RetryAppointmentSheetState();
}

class _RetryAppointmentSheetState extends State<RetryAppointmentSheet> {
  final _date = ValueNotifier<DateTime?>(null);
  final _time = ValueNotifier<TimeOfDay?>(null);
  final _noteCtrl = TextEditingController();
  late final Listenable _form = Listenable.merge([_date, _time]);

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
    _form.addListener(_notifyValidity);
  }

  @override
  void dispose() {
    _form.removeListener(_notifyValidity);
    _date.dispose();
    _time.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime? get _appointment {
    final d = _date.value;
    final t = _time.value;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _isValid {
    final at = _appointment;
    return at != null &&
        at.isAfter(_now()) &&
        !at.isAfter(widget.holdUntil.toLocal());
  }

  void _notifyValidity() => widget.onCanSubmitChanged?.call(_isValid);

  void _submit() {
    final at = _appointment;
    if (at == null || !_isValid) {
      DonySnackbar.show(
        context,
        message: context.l10n.dnpAppointmentOutOfHold,
        type: DonySnackbarType.error,
      );
      return;
    }
    context.read<DeliveryNoShowProcedureCubit>().setRetryAppointment(
      appointmentAt: at,
      note: _noteCtrl.text,
    );
  }

  Future<void> _pickDate() async {
    final now = _now();
    final last = widget.holdUntil.toLocal();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.value ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(last.year, last.month, last.day),
    );
    if (picked != null) _date.value = picked;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time.value ?? TimeOfDay.fromDateTime(_now()),
    );
    if (picked != null) _time.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocListener<
      DeliveryNoShowProcedureCubit,
      DeliveryNoShowProcedureState
    >(
      listener: (ctx, state) {
        if (state is! DeliveryNoShowProcedureLoaded) return;
        if (state.appointmentSaved) {
          Navigator.of(ctx, rootNavigator: true).pop();
          DonySnackbar.show(
            ctx,
            message: l.dnpAppointmentSaved,
            type: DonySnackbarType.success,
          );
        } else if (state.submitError != null) {
          ErrorPresenter.show(ctx, state.submitError);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<DateTime?>(
              valueListenable: _date,
              builder: (_, d, _) => DonyListTile(
                key: const Key('dnp-appointment-date'),
                icon: Icons.calendar_today_rounded,
                label: l.dnpAppointmentDateLabel,
                subtitle: d == null
                    ? l.dnpAppointmentPick
                    : DateFormat.yMMMEd(l.localeName).format(d),
                onTap: _pickDate,
              ),
            ),
            ValueListenableBuilder<TimeOfDay?>(
              valueListenable: _time,
              builder: (_, t, _) => DonyListTile(
                key: const Key('dnp-appointment-time'),
                icon: Icons.schedule_rounded,
                label: l.dnpAppointmentTimeLabel,
                subtitle: t == null ? l.dnpAppointmentPick : t.format(context),
                showDivider: false,
                onTap: _pickTime,
              ),
            ),
            const SizedBox(height: DonySpacing.md),
            DonyTextField(
              key: const Key('dnp-appointment-note'),
              controller: _noteCtrl,
              label: l.dnpAppointmentNoteLabel,
              maxLines: 3,
            ),
            const SizedBox(height: DonySpacing.md),
          ],
        ),
      ),
    );
  }

  /// Pour les tests : pose la date et l'heure sans ouvrir les sélecteurs.
  @visibleForTesting
  void debugSet(DateTime date, TimeOfDay time) {
    _date.value = date;
    _time.value = time;
  }
}
