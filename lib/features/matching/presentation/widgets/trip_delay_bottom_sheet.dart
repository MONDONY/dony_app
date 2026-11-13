import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/trip_delay/trip_delay_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/presentation/trip_delay_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Longueur maximale du message aux expéditeurs, alignée sur le serveur
/// (`TripDelayRequest.message`, `@Size(max = 300)`).
const int kTripDelayMessageMaxLength = 300;

/// Feuille « Annoncer un retard » d'un trajet parti, tous modes (maquette
/// VoyMerRetard) : motif (« Congestion au port » en bateau seulement), nouvelle
/// arrivée estimée du / au, message facultatif aux expéditeurs, puis
/// « Prévenir les expéditeurs ». Le serveur prévient chaque expéditeur dont le
/// colis est à bord et réécrit l'arrivée estimée du trajet.
///
/// Dates bornées comme le back : début au plus tôt le départ et aujourd'hui,
/// fin au plus tôt le début, au plus tard le départ plus la durée maximale du
/// mode ([TransportModeRules.maxArrivalDays] : 120 jours en bateau, 14 sur la
/// route, 3 en avion). Le serveur reste juge (422 `arrival-range-invalid`,
/// `arrival-too-far`, traduits par le catalogue d'erreurs).
///
/// Le bouton est dans le `stickyBottom` (patron « bouton avec BLoC » :
/// `wrapper` qui fournit le [TripDelayCubit], `BlocBuilder` dans le bouton).
/// [canSubmit] est créé par [show] mais possédé par le `State` du contenu,
/// qui le dispose : jamais au `whenComplete`, qui part dès le `pop`.
class TripDelayBottomSheet extends StatefulWidget {
  const TripDelayBottomSheet({
    super.key,
    required this.trip,
    required this.canSubmit,
    this.onSubmitReady,
    this.clock,
  });

  final AnnouncementModel trip;

  /// Formulaire complet et valide : le bouton du pied s'allume.
  final ValueNotifier<bool> canSubmit;
  final void Function(VoidCallback)? onSubmitReady;

  /// Horloge (« aujourd'hui ») ; `DateTime.now` par défaut, remplacée en test.
  final DateTime Function()? clock;

  /// Ouvre la feuille pour [trip]. [senderCount] : expéditeurs distincts dont
  /// le colis est à bord ou arrivé (0 : phrase sans nombre). Rend le retard
  /// accepté par le serveur, `null` si la feuille est fermée sans envoi.
  static Future<TripDelayInfo?> show(
    BuildContext context, {
    required AnnouncementModel trip,
    int senderCount = 0,
    @visibleForTesting DateTime Function()? clock,
  }) {
    VoidCallback? submit;
    // Disposé par le State du contenu.
    final canSubmit = ValueNotifier<bool>(false);
    final l = context.l10n;
    return DonyBottomSheet.show<TripDelayInfo>(
      context,
      title: l.tripDelaySheetTitle,
      subtitle: l.tripDelaySheetSubtitle(senderCount),
      analyticsName: 'trip-owner/delay',
      wrapper: (child) => BlocProvider<TripDelayCubit>(
        create: (_) => getIt<TripDelayCubit>(param1: trip),
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) =>
            BlocBuilder<TripDelayCubit, TripDelayState>(
              builder: (ctx, state) {
                final loading = state is TripDelayLoading;
                return DonyButton(
                  key: const Key('trip-delay-submit'),
                  label: l.tripDelaySubmit,
                  isLoading: loading,
                  onPressed: (loading || !enabled)
                      ? null
                      : () => submit?.call(),
                );
              },
            ),
      ),
      child: TripDelayBottomSheet(
        trip: trip,
        canSubmit: canSubmit,
        onSubmitReady: (fn) => submit = fn,
        clock: clock,
      ),
    );
  }

  @override
  State<TripDelayBottomSheet> createState() => _TripDelayBottomSheetState();
}

class _TripDelayBottomSheetState extends State<TripDelayBottomSheet> {
  final _reason = ValueNotifier<TripDelayReason?>(null);
  final _from = ValueNotifier<DateTime?>(null);
  final _to = ValueNotifier<DateTime?>(null);
  final _message = TextEditingController();
  late final Listenable _form = Listenable.merge([_reason, _from, _to]);

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
    _form.addListener(_notifyValidity);
  }

  @override
  void dispose() {
    _form.removeListener(_notifyValidity);
    _reason.dispose();
    _from.dispose();
    _to.dispose();
    _message.dispose();
    widget.canSubmit.dispose();
    super.dispose();
  }

  TransportMode? get _mode => widget.trip.transportMode;

  DateTime get _today => DateUtils.dateOnly((widget.clock ?? DateTime.now)());

  DateTime get _departure => DateUtils.dateOnly(widget.trip.departureDate);

  /// Dernier jour d'arrivée accepté : départ + durée maximale du mode.
  DateTime get _limit {
    final d = _departure;
    return DateTime(
      d.year,
      d.month,
      d.day + transportModeOrPlane(_mode).maxArrivalDays,
    );
  }

  /// Premier jour possible : jamais avant le départ ni avant aujourd'hui.
  DateTime get _first => _today.isBefore(_departure) ? _departure : _today;

  /// Message d'une date saisie hors de [first]..[_limit] : la règle du mode
  /// (120 jours en bateau, 14 en route), jamais « Hors de portée. ».
  String _outOfRange(DateTime first) => arrivalOutOfRangeText(
    context.l10n,
    first: first,
    last: _limit,
    maxDays: transportModeOrPlane(_mode).maxArrivalDays,
  );

  /// Il reste au moins un jour entre [_first] et [_limit].
  bool get _canPick => !_first.isAfter(_limit);

  bool get _isValid {
    final from = _from.value;
    final to = _to.value;
    return _reason.value != null &&
        from != null &&
        to != null &&
        !from.isBefore(_departure) &&
        !to.isBefore(from) &&
        !to.isBefore(_today) &&
        !to.isAfter(_limit);
  }

  void _notifyValidity() => widget.canSubmit.value = _isValid;

  /// [day] ramené entre [low] et [_limit].
  DateTime _clamp(DateTime day, DateTime low) {
    if (day.isBefore(low)) return low;
    if (day.isAfter(_limit)) return _limit;
    return day;
  }

  /// Arrivée estimée actuelle du trajet, point de départ du calendrier.
  DateTime get _currentArrival {
    final a = widget.trip.arrivalDateMax ?? widget.trip.arrivalDate;
    return a == null ? _first : DateUtils.dateOnly(a);
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clamp(_from.value ?? _currentArrival, _first),
      firstDate: _first,
      lastDate: _limit,
      errorInvalidText: _outOfRange(_first),
    );
    if (picked == null || !mounted) return;
    final day = DateUtils.dateOnly(picked);
    _from.value = day;
    final to = _to.value;
    if (to != null && to.isBefore(day)) _to.value = day;
  }

  Future<void> _pickTo() async {
    final low = _from.value ?? _first;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clamp(_to.value ?? _from.value ?? _currentArrival, low),
      firstDate: low,
      lastDate: _limit,
      errorInvalidText: _outOfRange(low),
    );
    if (picked == null || !mounted) return;
    _to.value = DateUtils.dateOnly(picked);
  }

  void _submit() {
    if (!_isValid) return;
    context.read<TripDelayCubit>().submit(
      reason: _reason.value!,
      arrivalDate: _from.value!,
      arrivalDateMax: _to.value!,
      message: _message.text,
    );
  }

  /// Aide du message : un port en bateau, un vol en avion ; neutre sur la
  /// route et pour un mode inconnu ou absent (comme les motifs,
  /// `trip_delay_labels`).
  String _messageHint(AppLocalizations l) => switch (_mode) {
    TransportMode.boat => l.tripDelayMessageHintBoat,
    TransportMode.plane => l.tripDelayMessageHintPlane,
    _ => l.tripDelayMessageHint,
  };

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripDelayCubit, TripDelayState>(
      listenWhen: (_, state) => state is TripDelaySuccess,
      listener: (context, state) {
        if (state is TripDelaySuccess) Navigator.of(context).pop(state.delay);
      },
      builder: (context, state) => PopScope(
        // Pendant l'envoi la feuille reste ouverte : fermée, la réponse du
        // serveur n'aurait plus d'écran pour la confirmer.
        canPop: state is! TripDelayLoading,
        child: ListenableBuilder(
          listenable: _form,
          builder: (context, _) => _content(context, state),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, TripDelayState state) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = (widget.clock ?? DateTime.now)();
    String day(DateTime d) => arrivalRangeDays(l, d, null, now: now).from;
    final from = _from.value;
    final to = _to.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l.tripDelayReasonSection),
        Wrap(
          spacing: DonySpacing.sm,
          runSpacing: DonySpacing.sm,
          children: [
            for (final reason in TripDelayReason.forMode(_mode))
              DonyChip(
                key: Key('trip-delay-reason-${reason.wire}'),
                label: tripDelayReasonLabel(l, reason, _mode),
                selected: _reason.value == reason,
                onTap: () => _reason.value = reason,
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.lg),
        _SectionTitle(l.tripDelayArrivalSection),
        Row(
          children: [
            Expanded(
              child: _DateTile(
                key: const Key('trip-delay-from'),
                label: l.tripDelayFromLabel,
                value: from == null ? null : day(from),
                placeholder: l.tripRescheduleChoose,
                onTap: _canPick ? _pickFrom : null,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _DateTile(
                key: const Key('trip-delay-to'),
                label: l.tripDelayToLabel,
                value: to == null ? null : day(to),
                placeholder: l.tripRescheduleChoose,
                onTap: _canPick ? _pickTo : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.tripDelayArrivalLimit(day(_limit)),
          key: const Key('trip-delay-limit'),
          style: tt.bodySmall?.copyWith(
            color: _canPick ? cs.onSurfaceVariant : cs.error,
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        _SectionTitle(l.tripDelayMessageSection),
        DonyTextField(
          key: const Key('trip-delay-message'),
          controller: _message,
          hint: _messageHint(l),
          maxLines: 3,
          minLines: 2,
          enabled: state is! TripDelayLoading,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            LengthLimitingTextInputFormatter(kTripDelayMessageMaxLength),
          ],
        ),
        const SizedBox(height: DonySpacing.lg),
        if (state is TripDelayError) ...[
          Container(
            key: const Key('trip-delay-error'),
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: cs.errorLight,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Text(
              state.message,
              style: tt.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: DonyIcon('info', size: 16, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                l.tripDelayInfo,
                key: const Key('trip-delay-info'),
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
  }
}

/// Titre de section discret, comme la feuille de report.
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

/// Choix d'un jour : libellé court au-dessus de la valeur, chiffres à largeur
/// fixe. Sans [onTap] (plus aucun jour possible), la tuile est inactive.
class _DateTile extends StatelessWidget {
  const _DateTile({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;

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
                DonyIcon('calendar', size: 20, color: cs.primary),
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
