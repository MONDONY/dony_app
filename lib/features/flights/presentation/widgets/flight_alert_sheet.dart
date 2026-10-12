import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_city_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Feuille « Nouvelle alerte prix » : trajet (repris de la recherche quand il
/// y en a une), période de départ et de retour (31 jours au plus), vols
/// directs et seuil. [onSubmit] crée l'alerte et rend `true` en cas de
/// succès ; la feuille se ferme alors en rendant `true`.
abstract final class FlightAlertSheet {
  static Future<bool?> show(
    BuildContext context, {
    FlightPlace? origin,
    FlightPlace? destination,
    DateTimeRange? departure,
    DateTimeRange? returnRange,
    bool directOnly = false,
    double? currentLowest,
    required String currencyCode,
    required Future<bool> Function(FlightAlertDraft draft) onSubmit,
  }) {
    return DonyBottomSheet.show<bool>(
      context,
      title: context.l10n.flightsAlertNewTitle,
      heightFraction: 0.92,
      child: _AlertForm(
        origin: origin,
        destination: destination,
        departure: departure,
        returnRange: returnRange,
        directOnly: directOnly,
        currentLowest: currentLowest,
        currencyCode: currencyCode,
        onSubmit: onSubmit,
      ),
    );
  }
}

class _AlertForm extends StatefulWidget {
  const _AlertForm({
    required this.origin,
    required this.destination,
    required this.departure,
    required this.returnRange,
    required this.directOnly,
    required this.currentLowest,
    required this.currencyCode,
    required this.onSubmit,
  });

  final FlightPlace? origin;
  final FlightPlace? destination;
  final DateTimeRange? departure;
  final DateTimeRange? returnRange;
  final bool directOnly;
  final double? currentLowest;
  final String currencyCode;
  final Future<bool> Function(FlightAlertDraft draft) onSubmit;

  @override
  State<_AlertForm> createState() => _AlertFormState();
}

class _AlertFormState extends State<_AlertForm> {
  late final ValueNotifier<FlightPlace?> _origin = ValueNotifier(widget.origin);
  late final ValueNotifier<FlightPlace?> _destination = ValueNotifier(
    widget.destination,
  );
  late final ValueNotifier<DateTimeRange?> _departure = ValueNotifier(
    _clamp(widget.departure),
  );
  late final ValueNotifier<bool> _roundTrip = ValueNotifier(
    widget.returnRange != null,
  );
  late final ValueNotifier<DateTimeRange?> _return = ValueNotifier(
    _clamp(widget.returnRange),
  );
  late final ValueNotifier<bool> _direct = ValueNotifier(widget.directOnly);
  final ValueNotifier<bool> _submitting = ValueNotifier(false);
  late final TextEditingController _price = TextEditingController(
    text: _suggestedThreshold(widget.currentLowest),
  );

  /// Seuil proposé : l'entier juste sous le prix le plus bas actuel. Au prix
  /// actuel ou au-dessus, la première vérification préviendrait aussitôt
  /// d'un prix déjà affiché.
  static String _suggestedThreshold(double? lowest) {
    if (lowest == null) return '';
    final below = lowest.ceil() - 1;
    return below >= 1 ? '$below' : '';
  }

  /// Une période trop longue (mois entier de 31 jours compris) est ramenée à
  /// 31 jours ; une période passée est ignorée.
  static DateTimeRange? _clamp(DateTimeRange? r) {
    if (r == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (r.end.isBefore(today)) return null;
    final start = r.start.isBefore(today) ? today : r.start;
    final maxEnd = DateTime(
      start.year,
      start.month,
      start.day + FlightAlertDraft.maxPeriodDays - 1,
    );
    return DateTimeRange(
      start: start,
      end: r.end.isAfter(maxEnd) ? maxEnd : r.end,
    );
  }

  Listenable get _all => Listenable.merge([
    _origin,
    _destination,
    _departure,
    _roundTrip,
    _return,
    _direct,
    _submitting,
    _price,
  ]);

  /// Jours calendaires, pas `duration.inDays` : une période qui traverse le
  /// passage à l'heure d'hiver ou d'été compterait un jour de moins ou de plus.
  static bool _tooLong(DateTimeRange? r) {
    if (r == null) return false;
    final start = DateTime.utc(r.start.year, r.start.month, r.start.day);
    final end = DateTime.utc(r.end.year, r.end.month, r.end.day);
    return end.difference(start).inDays + 1 > FlightAlertDraft.maxPeriodDays;
  }

  double? get _maxPrice => double.tryParse(_price.text.replaceAll(',', '.'));

  bool get _valid {
    final o = _origin.value;
    final d = _destination.value;
    final price = _maxPrice;
    final ret = _roundTrip.value ? _return.value : null;
    final dep = _departure.value;
    return o != null &&
        d != null &&
        o.code != d.code &&
        price != null &&
        price >= 1 &&
        !_tooLong(dep) &&
        !_tooLong(ret) &&
        (!_roundTrip.value || ret != null) &&
        (ret == null || dep == null || !ret.end.isBefore(dep.start));
  }

  Future<void> _pickRange(ValueNotifier<DateTimeRange?> target) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: target.value,
    );
    if (picked != null) target.value = picked;
  }

  Future<void> _pickCity(
    ValueNotifier<FlightPlace?> target,
    bool departure,
  ) async {
    final place = await FlightCitySheet.show(context, departure: departure);
    if (place != null) target.value = place;
  }

  Future<void> _submit() async {
    final o = _origin.value!;
    final d = _destination.value!;
    final dep = _departure.value;
    final ret = _roundTrip.value ? _return.value : null;
    _submitting.value = true;
    final ok = await widget.onSubmit(
      FlightAlertDraft(
        originCode: o.code,
        destinationCode: d.code,
        originLabel: o.name,
        destinationLabel: d.name,
        departureFrom: dep?.start,
        departureTo: dep?.end,
        returnFrom: ret?.start,
        returnTo: ret?.end,
        directOnly: _direct.value,
        maxPrice: _maxPrice!,
        // Le seuil est saisi dans la devise affichée à côté du champ.
        currency: widget.currencyCode,
      ),
    );
    if (!mounted) return;
    _submitting.value = false;
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    for (final n in [
      _origin,
      _destination,
      _departure,
      _roundTrip,
      _return,
      _direct,
      _submitting,
    ]) {
      n.dispose();
    }
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    String range(DateTimeRange? r) => r == null
        ? l.flightsAlertAnyDate
        : l.flightsAlertPeriod(
            FlightFormat.day(l, r.start),
            FlightFormat.day(l, r.end),
          );

    return ListenableBuilder(
      listenable: _all,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            key: const Key('flight-alert-origin'),
            label: l.flightsFieldDeparture,
            value: _origin.value?.name ?? l.flightsFieldChooseCity,
            onTap: () => _pickCity(_origin, true),
          ),
          const SizedBox(height: DonySpacing.sm),
          _Field(
            key: const Key('flight-alert-destination'),
            label: l.flightsFieldArrival,
            value: _destination.value?.name ?? l.flightsFieldChooseCity,
            onTap: () => _pickCity(_destination, false),
          ),
          const SizedBox(height: DonySpacing.base),
          _Field(
            key: const Key('flight-alert-departure'),
            label: l.flightsAlertDeparturePeriod,
            value: range(_departure.value),
            error: _tooLong(_departure.value)
                ? l.flightsAlertPeriodTooLong
                : null,
            onTap: () => _pickRange(_departure),
          ),
          SwitchListTile(
            key: const Key('flight-alert-roundtrip'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.flightsRoundTrip),
            value: _roundTrip.value,
            onChanged: (v) {
              _roundTrip.value = v;
              if (!v) _return.value = null;
            },
          ),
          if (_roundTrip.value)
            _Field(
              key: const Key('flight-alert-return'),
              label: l.flightsAlertReturnPeriod,
              value: _return.value == null
                  ? l.flightsFieldChooseDates
                  : range(_return.value),
              error: _tooLong(_return.value)
                  ? l.flightsAlertPeriodTooLong
                  : null,
              onTap: () => _pickRange(_return),
            ),
          SwitchListTile(
            key: const Key('flight-alert-direct'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.flightsDirectOnly),
            value: _direct.value,
            onChanged: (v) => _direct.value = v,
          ),
          TextField(
            key: const Key('flight-alert-price'),
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.flightsAlertThreshold,
              suffixText: widget.currencyCode,
            ),
          ),
          if (widget.currentLowest != null)
            Padding(
              padding: const EdgeInsets.only(top: DonySpacing.xs),
              child: Text(
                l.flightsAlertCurrentLowest(
                  FlightFormat.price(
                    widget.currentLowest!,
                    widget.currencyCode,
                  ),
                ),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            key: const Key('flight-alert-submit'),
            label: l.flightsAlertCreate,
            isLoading: _submitting.value,
            onPressed: _valid && !_submitting.value ? _submit : null,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.flightsAlertHint,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(
                  color: error != null ? cs.error : cs.outline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    value,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: DonySpacing.xs),
            child: Text(error!, style: tt.bodySmall?.copyWith(color: cs.error)),
          ),
      ],
    );
  }
}
