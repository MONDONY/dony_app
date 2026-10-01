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
  late final ValueNotifier<DateTime?> _handoverDay = ValueNotifier(
    _initialHandoverDay(),
  );

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

  /// Date limite actuelle, jamais avant aujourd'hui : le champ est rempli et
  /// cliquable dès l'ouverture, puis suit la nouvelle date de départ.
  DateTime? _initialHandoverDay() {
    final deadline = widget.announcement.handoverDeadline;
    if (deadline == null) return null;
    final day = DateUtils.dateOnly(deadline.toLocal());
    final today = DateUtils.dateOnly(DateTime.now());
    return day.isBefore(today) ? today : day;
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
    // Borne haute : le nouveau départ s'il est choisi, sinon l'actuel.
    final last = _date.value ?? widget.announcement.departureDate;
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDay = last.isBefore(today) ? today : DateUtils.dateOnly(last);
    final current = _handoverDay.value ?? lastDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(lastDay)
          ? lastDay
          : (current.isBefore(today) ? today : current),
      firstDate: today,
      lastDate: lastDay,
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
          final time = _departureTime.value;
          final arrival = _arrivalTime.value;
          final handover = _handoverDay.value;
          final locale = l.localeName;
          String day(DateTime d) => DateFormat.MMMEd(locale).format(d);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScheduleSummary(
                current:
                    '${day(widget.announcement.departureDate)}'
                    '${widget.announcement.departureTime == null ? '' : ' · ${widget.announcement.departureTime!.padRight(5).substring(0, 5)}'}',
                next: date == null
                    ? null
                    : '${day(date)}${time == null ? '' : ' · ${_wire(time)}'}',
              ),
              const SizedBox(height: DonySpacing.lg),
              _SectionTitle(l.tripRescheduleReasonLabel),
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
              _SectionTitle(l.tripRescheduleSectionDeparture),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _PickerTile(
                      key: const Key('reschedule-date-field'),
                      iconAsset: 'calendar',
                      label: l.tripRescheduleDateShort,
                      value: date == null ? null : day(date),
                      placeholder: l.tripRescheduleChoose,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    flex: 2,
                    child: _PickerTile(
                      key: const Key('reschedule-departure-time-field'),
                      iconAsset: 'plane-takeoff',
                      label: l.tripRescheduleTimeShort,
                      value: time == null ? null : _wire(time),
                      placeholder: l.tripRescheduleChoose,
                      onTap: _pickDepartureTime,
                    ),
                  ),
                ],
              ),
              if (_isSameSchedule) ...[
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.tripRescheduleSameDateHint,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              const SizedBox(height: DonySpacing.lg),
              _SectionTitle(l.tripRescheduleSectionArrival),
              _PickerTile(
                key: const Key('reschedule-arrival-time-field'),
                iconAsset: 'plane-landing',
                label: l.tripRescheduleTimeShort,
                value: arrival == null ? null : _wire(arrival),
                placeholder: l.tripRescheduleOptional,
                onTap: _pickArrivalTime,
              ),
              if (arrival != null) ...[
                const SizedBox(height: DonySpacing.sm),
                ArrivalDayChips(notifier: _arrivalDayOffset),
              ],
              const SizedBox(height: DonySpacing.lg),
              _SectionTitle(l.tripRescheduleSectionHandover),
              _PickerTile(
                key: const Key('reschedule-handover-field'),
                iconAsset: 'clock',
                label: l.tripRescheduleHandoverShort,
                value: handover == null ? null : day(handover),
                placeholder: l.tripRescheduleChoose,
                onTap: _pickHandoverDay,
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                l.tripRescheduleHandoverHint,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: DonySpacing.lg),
              _SectionTitle(l.tripRescheduleSectionMessage),
              DonyTextField(
                controller: _noteCtrl,
                hint: l.tripRescheduleNoteHint,
                maxLines: 2,
              ),
              const SizedBox(height: DonySpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DonyIcon(
                      'info',
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Text(
                      l.tripRescheduleConsequences,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

/// Titre de section discret, aligné sur les sections du détail de trajet.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// « Actuellement → Nouveau départ » : ce qui change, lisible d'un coup d'œil.
class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.current, required this.next});

  final String current;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const figures = [FontFeature.tabularFigures()];
    Widget column(String label, String value, {required bool emphasized}) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.titleSmall?.copyWith(
                  fontFeatures: figures,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                  color: emphasized ? cs.primary : cs.onSurfaceVariant,
                  decoration: emphasized ? null : TextDecoration.lineThrough,
                  decorationColor: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
    return Container(
      key: const Key('reschedule-summary'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Row(
        children: [
          column(l.tripRescheduleCurrentLabel, current, emphasized: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
            child: DonyIcon('arrow-right', size: 18, color: cs.primary),
          ),
          column(
            l.tripRescheduleSectionDeparture,
            next ?? l.tripRescheduleChoose,
            emphasized: next != null,
          ),
        ],
      ),
    );
  }
}

/// Tuile de choix (date, heure) : surface douce sans bordure dure, libellé
/// court au-dessus de la valeur, chiffres à largeur fixe.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final empty = value == null;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(DonyRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.sm,
            ),
            child: Row(
              children: [
                DonyIcon(iconAsset, size: 20, color: cs.primary),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: empty ? FontWeight.w500 : FontWeight.w600,
                          color: empty ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
