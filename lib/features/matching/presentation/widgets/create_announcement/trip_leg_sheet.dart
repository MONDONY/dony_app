import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
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
/// heure de départ, point de récupération, kilos, devise et prix de l'étape.
///
/// La ville de départ est imposée ([origin]) : c'est l'arrivée de l'étape
/// précédente. Le reste du trajet (mode de transport, contenus) est repris du
/// premier trajet à la publication. Les escales sont propres à chaque étape en
/// avion (FLUTTER-GE).
///
/// Chaque étape a sa devise (FLUTTER-HP) : par défaut celle du pays de départ
/// ([defaultCurrency]), modifiable. Le suffixe du prix, son plancher et son
/// plafond la suivent : sans suffixe ni plafond, une étape est partie à
/// 8 XOF/kg (FLUTTER-GK).
///
/// Mise en page (FLUTTER-HN) : kilos, devise et prix empilés sur toute la
/// largeur, sans icône de préfixe, pour qu'aucun libellé ne se replie à
/// 320 dp ni en texte agrandi.
class TripLegSheet extends StatefulWidget {
  const TripLegSheet({
    super.key,
    required this.origin,
    this.initial,
    required this.showPrice,
    required this.defaultCurrency,
    this.defaultKg,
    this.defaultPrice,
    this.defaultPriceCurrency,
    this.showStops = false,
    this.defaultStops,
    this.onSubmitReady,
    this.onCanSubmitChanged,
  });

  final TripLegOrigin origin;
  final TripLegDraft? initial;

  /// Prix au kilo propre à l'étape (mode « au kilo »). En grille seule, il est
  /// masqué et l'étape reprend la grille du voyageur, convertie par le serveur
  /// dans la devise de l'étape.
  final bool showPrice;

  /// Devise proposée à l'ouverture d'une nouvelle étape (pays de départ),
  /// ou à défaut de devise sur [initial].
  final SupportedCurrency defaultCurrency;
  final double? defaultKg;

  /// Prix prérempli (étape précédente ou premier trajet), dans
  /// [defaultPriceCurrency]. Ignoré si l'étape s'ouvre dans une autre
  /// devise : jamais de conversion silencieuse (FLUTTER-HP).
  final double? defaultPrice;
  final SupportedCurrency? defaultPriceCurrency;

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
    required SupportedCurrency defaultCurrency,
    double? defaultKg,
    double? defaultPrice,
    SupportedCurrency? defaultPriceCurrency,
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
        defaultCurrency: defaultCurrency,
        defaultKg: defaultKg,
        defaultPrice: defaultPrice,
        defaultPriceCurrency: defaultPriceCurrency,
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
  late final ValueNotifier<SupportedCurrency> _currency;
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
    _currency = ValueNotifier<SupportedCurrency>(
      SupportedCurrency.fromCode(i?.currency) ?? widget.defaultCurrency,
    );
    _kgCtrl = TextEditingController(
      text: _formatNumber(i?.availableKg ?? widget.defaultKg),
    );
    // Prix prérempli seulement dans sa devise : 8 €/kg ne deviennent pas
    // 8 F CFA/kg (FLUTTER-HP).
    final priceCurrency = widget.defaultPriceCurrency;
    final defaultPrice =
        priceCurrency == null || priceCurrency == _currency.value
        ? widget.defaultPrice
        : null;
    _priceCtrl = TextEditingController(
      text: _formatNumber(i?.pricePerKg ?? defaultPrice),
    );
    for (final n in _watched) {
      n.addListener(_notifyValidity);
    }
    widget.onSubmitReady?.call(_submit);
  }

  List<Listenable> get _watched => [
    _cityName,
    _date,
    _time,
    _address,
    _currency,
    _kgCtrl,
    _priceCtrl,
  ];

  @override
  void dispose() {
    for (final n in _watched) {
      n.removeListener(_notifyValidity);
    }
    _city.dispose();
    _cityName.dispose();
    _countryCode.dispose();
    _date.dispose();
    _time.dispose();
    _address.dispose();
    _stops.dispose();
    _currency.dispose();
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

  /// Prix saisi au-delà du plafond de la devise de l'étape (FLUTTER-GK).
  bool get _priceTooHigh {
    if (!widget.showPrice) return false;
    final price = _parseNumber(_priceCtrl.text);
    return price != null && price > maxUnitPriceFor(_currency.value);
  }

  /// Prix saisi sous le plancher de la devise de l'étape (1 €/kg converti) :
  /// 8 XOF/kg tapés en croyant saisir des euros (FLUTTER-GK).
  bool get _priceTooLow {
    if (!widget.showPrice) return false;
    return unitPriceOutOfBounds(
          _parseNumber(_priceCtrl.text),
          _currency.value,
        ) ==
        UnitPriceBound.tooLow;
  }

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
    if (widget.showPrice &&
        (price == null || price <= 0 || _priceTooHigh || _priceTooLow)) {
      return null;
    }
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
      currency: _currency.value.code,
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
    const gap = SizedBox(height: DonySpacing.md);
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
        gap,
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
        gap,
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
          const SizedBox(height: DonySpacing.base),
          // Bascule segmentée : les puces passaient à la ligne à 360 dp
          // (FLUTTER-HN).
          StopsChips(notifier: _stops, segmented: true),
        ],
        const SizedBox(height: DonySpacing.base),
        ValueListenableBuilder<AddressData?>(
          valueListenable: _address,
          builder: (context, address, _) => AddressSelectorField(
            type: AddressSelectorType.livraison,
            value: address,
            dense: true,
            caption: l.tripLegSheetAddressCaption,
            onChanged: (a) => _address.value = a,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        // Kilos, devise et prix empilés (FLUTTER-HN) : côte à côte, chaque
        // champ faisait ~150 dp et son libellé se repliait sur 2 ou 3 lignes
        // entre l'icône de préfixe et le suffixe.
        DonyTextField(
          key: const Key('trip-leg-kg'),
          controller: _kgCtrl,
          label: l.tripLegSheetKg,
          requiredLabel: true,
          suffixIcon: _UnitSuffix(
            key: const Key('trip-leg-kg-unit'),
            text: l.tripLegSheetKgSuffix,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: widget.showPrice
              ? TextInputAction.next
              : TextInputAction.done,
        ),
        gap,
        _CurrencyField(notifier: _currency),
        if (widget.showPrice) ...[
          gap,
          ListenableBuilder(
            listenable: Listenable.merge([_priceCtrl, _currency]),
            builder: (context, _) {
              final currency = _currency.value;
              return DonyTextField(
                key: const Key('trip-leg-price'),
                controller: _priceCtrl,
                label: l.tripLegSheetPrice,
                requiredLabel: true,
                // Devise de l'étape rappelée dans le champ (FLUTTER-GK).
                suffixIcon: _UnitSuffix(
                  key: const Key('trip-leg-price-currency'),
                  text: l.tripLegSheetPriceSuffix(currency.symbol),
                ),
                errorText: _priceTooLow
                    ? l.pricePerKgTooLow(
                        CurrencyFormatter.format(
                          minUnitPriceFor(currency),
                          currency,
                          compact: true,
                        ),
                      )
                    : _priceTooHigh
                    ? l.tripLegSheetPriceTooHigh(
                        CurrencyFormatter.format(
                          maxUnitPriceFor(currency),
                          currency,
                          compact: true,
                        ),
                      )
                    : null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
              );
            },
          ),
        ],
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}

/// Unité courte en fin de champ (« kg », « F CFA/kg »), sur une ligne.
class _UnitSuffix extends StatelessWidget {
  const _UnitSuffix({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DonySpacing.base),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Choix de la devise de l'étape (FLUTTER-HP), parmi les devises de l'app.
/// Un menu ancré plutôt qu'une seconde feuille par-dessus celle de l'étape.
class _CurrencyField extends StatelessWidget {
  const _CurrencyField({required this.notifier});

  final ValueNotifier<SupportedCurrency> notifier;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: notifier,
      builder: (context, current, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuAnchor(
            alignmentOffset: const Offset(0, DonySpacing.xs),
            menuChildren: [
              for (final c in SupportedCurrency.values)
                MenuItemButton(
                  key: Key('trip-leg-currency-${c.code}'),
                  leadingIcon: Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: c == current ? cs.primary : Colors.transparent,
                  ),
                  onPressed: () => notifier.value = c,
                  child: Text(
                    l.tripLegSheetCurrencyOption(c.name(l), c.symbol),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            builder: (context, controller, _) {
              void toggle() =>
                  controller.isOpen ? controller.close() : controller.open();
              return Semantics(
                button: true,
                label: l.tripLegSheetCurrencyMenuSemantics(current.name(l)),
                onTap: toggle,
                excludeSemantics: true,
                child: DonyTextField.tappable(
                  key: const Key('trip-leg-currency'),
                  label: l.tripLegSheetCurrency,
                  value: l.tripLegSheetCurrencyOption(
                    current.name(l),
                    current.symbol,
                  ),
                  trailing: Icon(
                    Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: toggle,
                ),
              );
            },
          ),
          const SizedBox(height: DonySpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
            child: Text(
              l.tripLegSheetCurrencyHint,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
