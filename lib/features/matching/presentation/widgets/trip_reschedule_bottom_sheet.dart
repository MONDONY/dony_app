import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/arrival_day_chips.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Bottom sheet « Reporter le trajet » : vol annulé, voyage repoussé. Le
/// voyageur choisit la nouvelle date même avec des colis acceptés ; chaque
/// expéditeur concerné pourra garder son colis ou se retirer sans frais.
class TripRescheduleBottomSheet extends StatefulWidget {
  const TripRescheduleBottomSheet({
    super.key,
    required this.announcement,
    this.onSubmitReady,
    this.onCanSubmitChanged,
  });

  final AnnouncementModel announcement;
  final void Function(VoidCallback)? onSubmitReady;
  final ValueChanged<bool>? onCanSubmitChanged;

  static Future<void> show(
    BuildContext context, {
    required AnnouncementModel announcement,
  }) {
    final announcementBloc = context.read<AnnouncementBloc>();
    VoidCallback? submit;
    final canSubmit = ValueNotifier<bool>(false);
    final l = context.l10n;
    return DonyBottomSheet.show(
      context,
      title: l.tripRescheduleTitle,
      subtitle: l.tripRescheduleSubtitle,
      wrapper: (child) =>
          BlocProvider.value(value: announcementBloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<AnnouncementBloc, AnnouncementState>(
              builder: (ctx, state) {
                final loading = state is AnnouncementLoading;
                return DonyButton(
                  key: const Key('trip-reschedule-submit'),
                  label: l.tripRescheduleSubmit,
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: TripRescheduleBottomSheet(
        announcement: announcement,
        onSubmitReady: (fn) => submit = fn,
        onCanSubmitChanged: (v) => canSubmit.value = v,
      ),
    ).whenComplete(canSubmit.dispose);
  }

  @override
  State<TripRescheduleBottomSheet> createState() =>
      _TripRescheduleBottomSheetState();
}

class _TripRescheduleBottomSheetState extends State<TripRescheduleBottomSheet> {
  final _reason = ValueNotifier<TripRescheduleReason?>(null);
  final _date = ValueNotifier<DateTime?>(null);
  late final ValueNotifier<TimeOfDay?> _departureTime = ValueNotifier(
    _parseTime(widget.announcement.departureTime),
  );
  late final ValueNotifier<TimeOfDay?> _arrivalTime = ValueNotifier(
    _parseTime(widget.announcement.arrivalTime),
  );
  late final ValueNotifier<int> _arrivalDayOffset = ValueNotifier(
    _initialArrivalOffset(),
  );
  final _handoverDay = ValueNotifier<DateTime?>(null);

  /// Vrai dès que le voyageur a choisi lui-même la date limite de remise :
  /// elle ne suit plus la date de départ.
  bool _handoverTouched = false;
  final _noteCtrl = TextEditingController();

  late final Listenable _form = Listenable.merge([
    _reason,
    _date,
    _departureTime,
    _arrivalTime,
    _arrivalDayOffset,
    _handoverDay,
  ]);

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
    _form.addListener(_notifyValidity);
  }

  @override
  void dispose() {
    _form.removeListener(_notifyValidity);
    for (final n in [
      _reason,
      _date,
      _departureTime,
      _arrivalTime,
      _handoverDay,
    ]) {
      n.dispose();
    }
    _arrivalDayOffset.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.length < 5) return null;
    final h = int.tryParse(raw.substring(0, 2));
    final m = int.tryParse(raw.substring(3, 5));
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  int _initialArrivalOffset() {
    final a = widget.announcement;
    if (a.arrivalDate == null) return 0;
    final days = DateUtils.dateOnly(
      a.arrivalDate!,
    ).difference(DateUtils.dateOnly(a.departureDate)).inDays;
    return days.clamp(0, 2);
  }

  static String _wire(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Même écart départ / remise qu'avant le report (« 1 jour avant »), jamais
  /// avant aujourd'hui.
  DateTime _defaultHandoverDay(DateTime newDate) {
    final a = widget.announcement;
    final lead = a.handoverDeadline == null
        ? 0
        : DateUtils.dateOnly(a.departureDate)
              .difference(DateUtils.dateOnly(a.handoverDeadline!.toLocal()))
              .inDays;
    final candidate = newDate.subtract(Duration(days: lead.clamp(0, 7)));
    final today = DateUtils.dateOnly(DateTime.now());
    return candidate.isBefore(today) ? today : candidate;
  }

  bool get _isSameSchedule {
    final a = widget.announcement;
    final date = _date.value;
    final time = _departureTime.value;
    if (date == null || time == null) return false;
    return DateUtils.isSameDay(date, a.departureDate) &&
        _wire(time) == (a.departureTime ?? '').padRight(5).substring(0, 5);
  }

  bool get _isValid =>
      _reason.value != null &&
      _date.value != null &&
      _departureTime.value != null &&
      _handoverDay.value != null &&
      !_handoverDay.value!.isAfter(_date.value!) &&
      !_isSameSchedule;

  void _notifyValidity() => widget.onCanSubmitChanged?.call(_isValid);

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _date.value ?? widget.announcement.departureDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    _date.value = picked;
    final handover = _handoverDay.value;
    if (!_handoverTouched || (handover != null && handover.isAfter(picked))) {
      _handoverDay.value = _defaultHandoverDay(picked);
    }
  }

  Future<void> _pickDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime.value ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) _departureTime.value = picked;
  }

  Future<void> _pickArrivalTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime.value ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null) return;
    _arrivalTime.value = picked;
    // Arrivée plus tôt que le départ : vol de nuit, lendemain proposé.
    final dep = _departureTime.value;
    if (dep != null &&
        _arrivalDayOffset.value == 0 &&
        picked.hour * 60 + picked.minute <= dep.hour * 60 + dep.minute) {
      _arrivalDayOffset.value = 1;
    }
  }

  Future<void> _pickHandoverDay() async {
    final date = _date.value;
    if (date == null) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final current = _handoverDay.value ?? date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(date) ? date : current,
      firstDate: today,
      lastDate: date,
    );
    if (picked == null) return;
    _handoverTouched = true;
    _handoverDay.value = picked;
  }

  /// Le jour du départ, la remise se cale sur l'heure du départ ; un autre
  /// jour, en fin de journée (même règle qu'à la publication).
  DateTime _resolveHandoverDeadline(
    DateTime day,
    DateTime date,
    TimeOfDay time,
  ) {
    if (DateUtils.isSameDay(day, date)) {
      return DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
    return DateTime(day.year, day.month, day.day, 23, 59);
  }

  void _submit() {
    if (!_isValid) return;
    final date = _date.value!;
    final time = _departureTime.value!;
    final arrival = _arrivalTime.value;
    final offset = arrival == null ? 0 : _arrivalDayOffset.value;
    context.read<AnnouncementBloc>().add(
      AnnouncementRescheduleRequested(
        announcementId: widget.announcement.id,
        departureDate: date,
        departureTime: _wire(time),
        arrivalTime: arrival == null ? null : _wire(arrival),
        arrivalDate: offset > 0
            ? DateFormat('yyyy-MM-dd').format(date.add(Duration(days: offset)))
            : null,
        handoverDeadline: _resolveHandoverDeadline(
          _handoverDay.value!,
          date,
          time,
        ),
        reason: _reason.value!,
        note: _noteCtrl.text,
      ),
    );
  }

  String _reasonLabel(TripRescheduleReason r) {
    final l = context.l10n;
    return switch (r) {
      TripRescheduleReason.flightCancelled =>
        l.tripRescheduleReasonFlightCancelled,
      TripRescheduleReason.postponed => l.tripRescheduleReasonPostponed,
      TripRescheduleReason.other => l.tripRescheduleReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocListener<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementRescheduled) {
          Navigator.of(context, rootNavigator: true).pop();
          DonySnackbar.show(
            context,
            message: l.tripRescheduledSnackbar(
              state.result.parcelsAwaitingDecision,
            ),
            type: DonySnackbarType.success,
          );
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: ListenableBuilder(
        listenable: _form,
        builder: (context, _) {
          final date = _date.value;
          final handover = _handoverDay.value;
          final time = _departureTime.value;
          final arrival = _arrivalTime.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.tripRescheduleReasonLabel, style: tt.titleSmall),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final r in TripRescheduleReason.values)
                    DonyChip(
                      key: Key('reschedule-reason-${r.wire}'),
                      label: _reasonLabel(r),
                      selected: _reason.value == r,
                      onTap: () => _reason.value = r,
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.lg),
              DonyTextField.tappable(
                key: const Key('reschedule-date-field'),
                label: l.tripRescheduleNewDateLabel,
                requiredLabel: true,
                value: date == null
                    ? null
                    : DateFormat.yMMMEd(l.localeName).format(date),
                prefixWidget: DonyIcon('calendar', size: 20, color: cs.primary),
                onTap: _pickDate,
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyTextField.tappable(
                key: const Key('reschedule-departure-time-field'),
                label: l.tripRescheduleDepartureTimeLabel,
                requiredLabel: true,
                value: time == null ? null : _wire(time),
                prefixWidget: DonyIcon(
                  'plane-takeoff',
                  size: 20,
                  color: cs.primary,
                ),
                onTap: _pickDepartureTime,
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyTextField.tappable(
                key: const Key('reschedule-arrival-time-field'),
                label: l.tripRescheduleArrivalTimeLabel,
                value: arrival == null ? null : _wire(arrival),
                prefixWidget: DonyIcon(
                  'plane-landing',
                  size: 20,
                  color: cs.primary,
                ),
                onTap: _pickArrivalTime,
              ),
              if (arrival != null) ...[
                const SizedBox(height: DonySpacing.sm),
                ArrivalDayChips(notifier: _arrivalDayOffset),
              ],
              const SizedBox(height: DonySpacing.sm),
              DonyTextField.tappable(
                key: const Key('reschedule-handover-field'),
                label: l.tripRescheduleHandoverLabel,
                requiredLabel: true,
                value: handover == null
                    ? null
                    : DateFormat.yMMMEd(l.localeName).format(handover),
                prefixWidget: DonyIcon('clock', size: 20, color: cs.primary),
                onTap: date == null ? null : _pickHandoverDay,
              ),
              const SizedBox(height: DonySpacing.sm),
              DonyTextField(
                controller: _noteCtrl,
                label: l.tripRescheduleNoteLabel,
                hint: l.tripRescheduleNoteHint,
                maxLines: 2,
              ),
              const SizedBox(height: DonySpacing.md),
              if (_isSameSchedule) ...[
                Text(
                  l.tripRescheduleSameDateHint,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                ),
                const SizedBox(height: DonySpacing.sm),
              ],
              Container(
                padding: const EdgeInsets.all(DonySpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Text(
                  l.tripRescheduleConsequences,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: DonySpacing.xl),
            ],
          );
        },
      ),
    );
  }
}
