import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/trip_leg_draft.dart';
import 'package:dony/features/matching/data/models/trip_stops.dart';
import 'package:dony/features/matching/presentation/widgets/address_selector_field.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/stops_chips.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Feuille d'une étape d'un voyage (FLUTTER-4D) : ville d'arrivée, date et
/// heure de départ, point de récupération, kilos et prix de l'étape.
///
/// La ville de départ est imposée ([origin]) : c'est l'arrivée de l'étape
/// précédente. Le reste du trajet (mode de transport, contenus, paiements,
/// devise) est repris du premier trajet à la publication. Les escales sont
/// propres à chaque étape en avion (FLUTTER-GE).
class TripLegSheet extends StatefulWidget {
  const TripLegSheet({
    super.key,
    required this.origin,
    this.initial,
    required this.showPrice,
    this.defaultKg,
    this.defaultPrice,
    this.showStops = false,
    this.defaultStops,
    this.onSubmitReady,
    this.onCanSubmitChanged,
  });

  final TripLegOrigin origin;
  final TripLegDraft? initial;

  /// Prix au kilo propre à l'étape (mode « au kilo »). En grille seule, il est
  /// masqué et l'étape reprend le prix du premier trajet.
  final bool showPrice;
  final double? defaultKg;
  final double? defaultPrice;

  /// Trajet en avion : l'étape a son propre choix d'escales (FLUTTER-GE),
  /// prérempli avec [defaultStops] (celui de l'étape précédente).
  final bool showStops;
  final TripStops? defaultStops;
  final void Function(VoidCallback)? onSubmitReady;
  final ValueChanged<bool>? onCanSubmitChanged;

  /// Ouvre la feuille ; rend l'étape saisie, ou `null` si elle est fermée.
  static Future<TripLegDraft?> show(
    BuildContext context, {
    required int legNumber,
    required TripLegOrigin origin,
    TripLegDraft? initial,
    required bool showPrice,
    double? defaultKg,
    double? defaultPrice,
    bool showStops = false,
    TripStops? defaultStops,
  }) {
    final l = context.l10n;
    VoidCallback? submit;
    // Écrit uniquement par des gestes de l'utilisateur (saisie, sélecteurs) :
    // il peut donc être libéré à la fermeture de la feuille.
    final canSubmit = ValueNotifier<bool>(initial != null);
    return DonyBottomSheet.show<TripLegDraft>(
      context,
      title: l.tripLegsLegLabel(legNumber),
      subtitle: l.tripLegSheetSubtitle(origin.city),
      wrapper: (child) => BlocProvider<CitySearchBloc>(
        create: (_) => getIt<CitySearchBloc>(),
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canSubmit,
        builder: (ctx, enabled, _) => DonyButton(
          key: const Key('trip-leg-submit'),
          label: initial == null ? l.tripLegSheetSubmit : l.tripLegSheetSave,
          icon: initial == null ? DonyIcons.add : DonyIcons.check,
          onPressed: enabled ? () => submit?.call() : null,
        ),
      ),
      child: TripLegSheet(
        origin: origin,
        initial: initial,
        showPrice: showPrice,
        defaultKg: defaultKg,
        defaultPrice: defaultPrice,
        showStops: showStops,
        defaultStops: defaultStops,
        onSubmitReady: (fn) => submit = fn,
        onCanSubmitChanged: (v) => canSubmit.value = v,
      ),
    ).whenComplete(canSubmit.dispose);
  }

  @override
  State<TripLegSheet> createState() => _TripLegSheetState();
}

class _TripLegSheetState extends State<TripLegSheet> {
  late final ValueNotifier<CityModel?> _city;
  late final ValueNotifier<String?> _cityName;
  late final ValueNotifier<String?> _countryCode;
  late final ValueNotifier<DateTime?> _date;
  late final ValueNotifier<TimeOfDay?> _time;
  late final ValueNotifier<AddressData?> _address;
  late final ValueNotifier<TripStops?> _stops;
  late final TextEditingController _kgCtrl;
  late final TextEditingController _priceCtrl;

  DateTime get _minDay => DateUtils.dateOnly(widget.origin.arrivalDay);

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _city = ValueNotifier<CityModel?>(null);
    _cityName = ValueNotifier<String?>(i?.arrivalCity);
    _countryCode = ValueNotifier<String?>(i?.arrivalCountryCode);
    _date = ValueNotifier<DateTime?>(i?.departureDate);
    _time = ValueNotifier<TimeOfDay?>(
      i != null ? _parseTime(i.departureTime) : null,
    );
    _address = ValueNotifier<AddressData?>(i?.deliveryAddress);
    // Une étape déjà saisie garde son choix, même « non renseigné ».
    _stops = ValueNotifier<TripStops?>(
      i != null ? i.stops : widget.defaultStops,
    );
    _kgCtrl = TextEditingController(
      text: _formatNumber(i?.availableKg ?? widget.defaultKg),
    );
    _priceCtrl = TextEditingController(
      text: _formatNumber(i?.pricePerKg ?? widget.defaultPrice),
    );
    for (final n in <Listenable>[
      _cityName,
      _date,
      _time,
      _address,
      _kgCtrl,
      _priceCtrl,
    ]) {
      n.addListener(_notifyValidity);
    }
    widget.onSubmitReady?.call(_submit);
  }

  @override
  void dispose() {
    for (final n in <Listenable>[
      _cityName,
      _date,
      _time,
      _address,
      _kgCtrl,
      _priceCtrl,
    ]) {
      n.removeListener(_notifyValidity);
    }
    _city.dispose();
    _cityName.dispose();
    _countryCode.dispose();
    _date.dispose();
    _time.dispose();
    _address.dispose();
    _stops.dispose();
    _kgCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatNumber(double? v) {
    if (v == null || v <= 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static double? _parseNumber(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  bool get _sameCityAsOrigin =>
      TripLegChain.sameCity(_cityName.value, widget.origin.city);

  bool get _dateTooEarly =>
      _date.value != null && _date.value!.isBefore(_minDay);

  TripLegDraft? _draftOrNull() {
    final city = _cityName.value;
    final date = _date.value;
    final time = _time.value;
    final address = _address.value;
    final kg = _parseNumber(_kgCtrl.text);
    final price = widget.showPrice ? _parseNumber(_priceCtrl.text) : null;
    if (city == null || city.isEmpty || _sameCityAsOrigin) return null;
    if (date == null || _dateTooEarly || time == null || address == null) {
      return null;
    }
    if (kg == null || kg < 1) return null;
    if (widget.showPrice && (price == null || price <= 0)) return null;
    return TripLegDraft(
      arrivalCity: city,
      arrivalCountryCode: _countryCode.value,
      departureDate: DateUtils.dateOnly(date),
      departureTime:
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      deliveryAddress: address,
      availableKg: kg,
      pricePerKg: price,
      stops: widget.showStops ? _stops.value : null,
    );
  }

  void _notifyValidity() {
    widget.onCanSubmitChanged?.call(_draftOrNull() != null);
  }

  void _submit() {
    final draft = _draftOrNull();
    if (draft == null) return;
    Navigator.of(context, rootNavigator: true).pop(draft);
  }

  void _onCitySelected(CityModel city) {
    _city.value = city;
    _countryCode.value = city.countryCode;
    _cityName.value = city.name;
    // Point de récupération par défaut : la ville elle-même, que le voyageur
    // peut préciser. Une adresse déjà choisie dans une autre ville est remplacée.
    final current = _address.value;
    if (current == null || current.city != city.name) {
      _address.value = AddressData(
        label: city.name,
        lat: city.lat,
        lng: city.lng,
        city: city.name,
        country: city.countryCode,
      );
    }
  }

  void _onCityCleared() {
    _city.value = null;
    _cityName.value = null;
    _countryCode.value = null;
  }

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = _minDay.isAfter(now) ? _minDay : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.value != null && !_date.value!.isBefore(first)
          ? _date.value!
          : first,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) _date.value = picked;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time.value ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null && mounted) _time.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: _cityName,
          builder: (context, name, _) => CityAutocompleteField(
            fieldKey: const Key('trip-leg-arrival-city'),
            label: l.tripLegSheetArrivalCity,
            requiredLabel: true,
            initialValue: name,
            recentRole: CityFieldRole.arrival,
            prefixIcon: Icon(DonyIcons.arrivalCity, color: cs.secondary),
            errorText: _sameCityAsOrigin ? l.tripLegSheetSameCity : null,
            onSelected: _onCitySelected,
            onCleared: _onCityCleared,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        ValueListenableBuilder<DateTime?>(
          valueListenable: _date,
          builder: (context, date, _) => DonyTextField.tappable(
            key: const Key('trip-leg-date'),
            label: l.tripLegSheetDate,
            requiredLabel: true,
            value: date != null ? DateFormat.yMMMEd(locale).format(date) : null,
            prefixIcon: DonyIcons.date,
            prefixIconColor: cs.primary,
            errorText: _dateTooEarly
                ? l.tripLegSheetDateTooEarly(
                    DateFormat.yMMMd(locale).format(_minDay),
                  )
                : null,
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        ValueListenableBuilder<TimeOfDay?>(
          valueListenable: _time,
          builder: (context, time, _) => DonyTextField.tappable(
            key: const Key('trip-leg-time'),
            label: l.tripLegSheetTime,
            requiredLabel: true,
            value: time?.format(context),
            prefixIcon: DonyIcons.time,
            prefixIconColor: cs.primary,
            onTap: _pickTime,
          ),
        ),
        if (widget.showStops) ...[
          const SizedBox(height: DonySpacing.md),
          StopsChips(notifier: _stops),
        ],
        const SizedBox(height: DonySpacing.md),
        ValueListenableBuilder<AddressData?>(
          valueListenable: _address,
          builder: (context, address, _) => AddressSelectorField(
            type: AddressSelectorType.livraison,
            value: address,
            onChanged: (a) => _address.value = a,
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DonyTextField(
                key: const Key('trip-leg-kg'),
                controller: _kgCtrl,
                label: l.tripLegSheetKg,
                requiredLabel: true,
                prefixIcon: DonyIcons.suitcase,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: widget.showPrice
                    ? TextInputAction.next
                    : TextInputAction.done,
              ),
            ),
            if (widget.showPrice) ...[
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: DonyTextField(
                  key: const Key('trip-leg-price'),
                  controller: _priceCtrl,
                  label: l.tripLegSheetPrice,
                  requiredLabel: true,
                  prefixIcon: DonyIcons.editPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}
