import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris', 'Lyon', 'Marseille'];
const _arrivalCities = ['Dakar', 'Abidjan', 'Bamako', 'Douala'];
const _priceOptions = [5.0, 6.0, 7.0, 8.0];
const _contentTypes = [
  'Vêtements',
  'Médicaments',
  'Alim. sèche',
  'Hi-fi',
  'Documents',
  'Téléphone',
  'Cosmétiques',
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class CreateAnnouncementScreen extends StatefulWidget {
  final AnnouncementModel? announcement;
  const CreateAnnouncementScreen({super.key, this.announcement});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _departureCityNotifier = ValueNotifier<String?>(null);
  final _arrivalCityNotifier = ValueNotifier<String?>(null);
  final _departureDateNotifier = ValueNotifier<DateTime?>(null);
  final _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _departureLocationCtrl = TextEditingController();
  final _arrivalLocationCtrl = TextEditingController();
  final _availableKgNotifier = ValueNotifier<double>(15);
  final _priceOptionNotifier = ValueNotifier<int>(1);
  final _selectedContentNotifier = ValueNotifier<Set<String>>(
    {'Vêtements', 'Médicaments', 'Alim. sèche', 'Hi-fi'},
  );
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();

  bool get _isEdit => widget.announcement != null;
  double get _pricePerKg => _priceOptions[_priceOptionNotifier.value];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCityNotifier.value = a.departureCity;
      _arrivalCityNotifier.value = a.arrivalCity;
      _departureDateNotifier.value = a.departureDate;
      _availableKgNotifier.value = a.availableKg;

      if (a.departureTime != null) {
        final parts = a.departureTime!.split(':');
        _departureTimeNotifier.value = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (a.arrivalTime != null) {
        final parts = a.arrivalTime!.split(':');
        _arrivalTimeNotifier.value = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _departureLocationCtrl.text = a.departureLocation ?? '';
      _arrivalLocationCtrl.text = a.arrivalLocation ?? '';

      if (a.description != null) {
        _descriptionCtrl.text = a.description!;
      }

      if (a.acceptedContentTypes != null) {
        final presets = Set<String>.from(
          a.acceptedContentTypes!.where(_contentTypes.contains),
        );
        final custom = Set<String>.from(
          a.acceptedContentTypes!.where((t) => !_contentTypes.contains(t)),
        );
        _selectedContentNotifier.value = presets;
        _customAcceptedNotifier.value = custom;
      }
      if (a.refusedTypes != null) {
        _refusedTypesNotifier.value = Set<String>.from(a.refusedTypes!);
      }

      final price = a.pricePerKg;
      int closest = 1;
      double minDiff = double.infinity;
      for (int i = 0; i < _priceOptions.length; i++) {
        final diff = (price - _priceOptions[i]).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = i;
        }
      }
      _priceOptionNotifier.value = closest;
    }
  }

  @override
  void dispose() {
    _departureLocationCtrl.dispose();
    _arrivalLocationCtrl.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _departureDateNotifier.dispose();
    _departureTimeNotifier.dispose();
    _arrivalTimeNotifier.dispose();
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    _customAcceptedNotifier.dispose();
    _refusedTypesNotifier.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _submit() {
    final departureCity = _departureCityNotifier.value;
    final arrivalCity = _arrivalCityNotifier.value;
    final departureDate = _departureDateNotifier.value;
    final departureTimeVal = _departureTimeNotifier.value;
    final arrivalTimeVal = _arrivalTimeNotifier.value;

    if (departureCity == null) {
      _showError('Ville de départ obligatoire');
      return;
    }
    if (arrivalCity == null) {
      _showError('Ville d\'arrivée obligatoire');
      return;
    }
    if (departureDate == null) {
      _showError('Date de départ obligatoire');
      return;
    }

    final departureTime =
        departureTimeVal != null ? _formatTime(departureTimeVal) : null;
    final arrivalTime =
        arrivalTimeVal != null ? _formatTime(arrivalTimeVal) : null;
    final departureLocation = _departureLocationCtrl.text.trim().isEmpty
        ? null
        : _departureLocationCtrl.text.trim();
    final arrivalLocation = _arrivalLocationCtrl.text.trim().isEmpty
        ? null
        : _arrivalLocationCtrl.text.trim();

    final allAccepted = {
      ..._selectedContentNotifier.value,
      ..._customAcceptedNotifier.value,
    }.toList();
    final refused = _refusedTypesNotifier.value.toList();
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
            id: widget.announcement!.id,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            departureLocation: departureLocation,
            arrivalLocation: arrivalLocation,
            availableKg: _availableKgNotifier.value,
            pricePerKg: _pricePerKg,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
          ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            departureLocation: departureLocation,
            arrivalLocation: arrivalLocation,
            availableKg: _availableKgNotifier.value,
            pricePerKg: _pricePerKg,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
          ));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: DonyColors.error),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDateNotifier.value ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: DonyColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureDateNotifier.value = picked;
    }
  }

  Future<void> _selectDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _departureTimeNotifier.value ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: DonyColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureTimeNotifier.value = picked;
    }
  }

  Future<void> _selectArrivalTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _arrivalTimeNotifier.value ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: DonyColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _arrivalTimeNotifier.value = picked;
    }
  }

  String _formatCorridorDateTime() {
    final departureDate = _departureDateNotifier.value;
    final departureTime = _departureTimeNotifier.value;
    final arrivalTime = _arrivalTimeNotifier.value;
    if (departureDate == null) {
      return '';
    }
    final date = DateFormat('EEE d MMM', 'fr').format(departureDate);
    if (departureTime != null && arrivalTime != null) {
      return '$date · ${departureTime.hour}h–${arrivalTime.hour}h';
    } else if (departureTime != null) {
      return '$date · ${departureTime.hour}h';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementCreated || state is AnnouncementUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'Trajet modifié !' : 'Trajet publié !'),
            backgroundColor: DonyColors.success,
          ));
          context.go('/announcements');
        } else if (state is AnnouncementError) {
          _showError(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AnnouncementLoading;

        return Scaffold(
          backgroundColor: DonyColors.bgApp,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEdit ? 'Modifier le trajet' : 'Publier mon trajet',
                  style: tt.headlineLarge,
                ),
                Text(
                  'Affiché en 1 min',
                  style:
                      tt.bodySmall?.copyWith(color: DonyColors.textSubtle),
                ),
              ],
            ),
            backgroundColor: DonyColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: DonyColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: DonyColors.borderDefault),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DonyLayout.hPadding(context),
              DonySpacing.xl,
              DonyLayout.hPadding(context),
              MediaQuery.of(context).padding.bottom + 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Corridor preview ────────────────────────────────────────
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _departureCityNotifier,
                    _arrivalCityNotifier,
                    _departureDateNotifier,
                    _departureTimeNotifier,
                    _arrivalTimeNotifier,
                  ]),
                  builder: (context, _) {
                    final dep = _departureCityNotifier.value;
                    final arr = _arrivalCityNotifier.value;
                    if (dep == null || arr == null) {
                      return const SizedBox.shrink();
                    }

                    final depCode = cityAirportCode(dep, departure: true);
                    final arrCode = cityAirportCode(arr, departure: false);
                    final dateStr = _formatCorridorDateTime();

                    return Column(
                      children: [
                        _SectionCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.base,
                              vertical: DonySpacing.md,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$depCode → $arrCode',
                                        style: tt.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (dateStr.isNotEmpty)
                                        Text(
                                          dateStr,
                                          style: tt.bodySmall?.copyWith(
                                            color: DonyColors.textSubtle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.sm,
                                    vertical: DonySpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DonyColors.primarySoft,
                                    borderRadius: BorderRadius.circular(
                                        DonyRadius.full),
                                  ),
                                  child: Text(
                                    'Confirmé',
                                    style: tt.labelSmall?.copyWith(
                                      color: DonyColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 250.ms),
                        const SizedBox(height: DonySpacing.xl),
                      ],
                    );
                  },
                ),

                // ── TRAJET ──────────────────────────────────────────────────
                const _SectionLabel(label: 'TRAJET'),
                const SizedBox(height: DonySpacing.sm),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _departureCityNotifier,
                    _arrivalCityNotifier,
                    _departureDateNotifier,
                    _departureTimeNotifier,
                    _arrivalTimeNotifier,
                  ]),
                  builder: (context, _) {
                    return _SectionCard(
                      child: Column(
                        children: [
                          _CityRow(
                            isDeparture: true,
                            value: _departureCityNotifier.value,
                            airport: _departureCityNotifier.value != null
                                ? kDepartureCityCodes[_departureCityNotifier.value]
                                : null,
                            cities: _departureCities,
                            onChanged: (v) =>
                                _departureCityNotifier.value = v,
                          ),
                          const _RowDivider(),
                          _TimeRow(
                            isDeparture: true,
                            time: _departureTimeNotifier.value,
                            onTap: _selectDepartureTime,
                            onClear: _departureTimeNotifier.value != null
                                ? () => _departureTimeNotifier.value = null
                                : null,
                          ),
                          const _RowDivider(),
                          _CityRow(
                            isDeparture: false,
                            value: _arrivalCityNotifier.value,
                            airport: _arrivalCityNotifier.value != null
                                ? kArrivalCityCodes[_arrivalCityNotifier.value]
                                : null,
                            cities: _arrivalCities,
                            onChanged: (v) =>
                                _arrivalCityNotifier.value = v,
                          ),
                          const _RowDivider(),
                          _TimeRow(
                            isDeparture: false,
                            time: _arrivalTimeNotifier.value,
                            onTap: _selectArrivalTime,
                            onClear: _arrivalTimeNotifier.value != null
                                ? () => _arrivalTimeNotifier.value = null
                                : null,
                          ),
                          const _RowDivider(),
                          _DateRow(
                            date: _departureDateNotifier.value,
                            onTap: _selectDate,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 60.ms);
                  },
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── LIEUX DE REMISE ─────────────────────────────────────────
                const _SectionLabel(label: 'LIEUX DE REMISE'),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Précisez l\'endroit exact de remise et récupération',
                  style: tt.bodySmall?.copyWith(color: DonyColors.textSubtle),
                ),
                const SizedBox(height: DonySpacing.sm),
                _SectionCard(
                  child: Column(
                    children: [
                      _LocationField(
                        isDeparture: true,
                        controller: _departureLocationCtrl,
                      ),
                      const _RowDivider(),
                      _LocationField(
                        isDeparture: false,
                        controller: _arrivalLocationCtrl,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CAPACITÉ DISPONIBLE ─────────────────────────────────────
                const _SectionLabel(label: 'CAPACITÉ DISPONIBLE'),
                const SizedBox(height: DonySpacing.base),
                ValueListenableBuilder<double>(
                  valueListenable: _availableKgNotifier,
                  builder: (context, kg, _) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Expanded(child: SizedBox()),
                            Text(
                              kg.toStringAsFixed(0),
                              style: tt.displayLarge?.copyWith(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: DonyColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' kg',
                              style: tt.headlineMedium?.copyWith(
                                color: DonyColors.textSubtle,
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.sm,
                                    vertical: DonySpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DonyColors.neutral100,
                                    borderRadius: BorderRadius.circular(
                                        DonyRadius.full),
                                  ),
                                  child: Text(
                                    'VALISE',
                                    style: tt.labelSmall?.copyWith(
                                      color: DonyColors.textSubtle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: DonyColors.primary,
                            inactiveTrackColor: DonyColors.borderDefault,
                            thumbColor: DonyColors.primary,
                            overlayColor:
                                DonyColors.primary.withValues(alpha: 0.1),
                            trackHeight: 5,
                          ),
                          child: Slider(
                            value: kg,
                            min: 1,
                            max: 23,
                            divisions: 22,
                            onChanged: (v) =>
                                _availableKgNotifier.value = v,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 kg',
                                style: tt.bodySmall
                                    ?.copyWith(color: DonyColors.textSubtle)),
                            Text('max 23 kg',
                                style: tt.bodySmall
                                    ?.copyWith(color: DonyColors.textSubtle)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── PRIX PAR KG ─────────────────────────────────────────────
                const _SectionLabel(label: 'PRIX PAR KG'),
                const SizedBox(height: DonySpacing.md),
                ValueListenableBuilder<int>(
                  valueListenable: _priceOptionNotifier,
                  builder: (context, selectedIdx, _) {
                    final kg = _availableKgNotifier.value;
                    final pricePerKg = _priceOptions[selectedIdx];
                    final grossEstimate = kg * pricePerKg;
                    final netEstimate = grossEstimate * 0.88;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(_priceOptions.length, (i) {
                            final selected = selectedIdx == i;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: i == 0 ? 0 : DonySpacing.xs,
                                  right: i == _priceOptions.length - 1
                                      ? 0
                                      : DonySpacing.xs,
                                ),
                                child: GestureDetector(
                                  onTap: () =>
                                      _priceOptionNotifier.value = i,
                                  child: AnimatedContainer(
                                    duration: 180.ms,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: DonySpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? DonyColors.successLight
                                          : DonyColors.surface,
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.lg),
                                      border: Border.all(
                                        color: selected
                                            ? DonyColors.success
                                            : DonyColors.borderDefault,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_priceOptions[i].toStringAsFixed(0)}€',
                                        style: tt.titleMedium?.copyWith(
                                          color: selected
                                              ? DonyColors.success
                                              : DonyColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        Text(
                          'Estimation : ${grossEstimate.toStringAsFixed(0)}€ · vous touchez ${netEstimate.toStringAsFixed(0)}€',
                          style: tt.bodySmall
                              ?.copyWith(color: DonyColors.textSubtle),
                        ),
                      ],
                    );
                  },
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CE QUE J'ACCEPTE ────────────────────────────────────────
                const _SectionLabel(label: 'CE QUE J\'ACCEPTE'),
                const SizedBox(height: DonySpacing.sm),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _selectedContentNotifier,
                    _customAcceptedNotifier,
                  ]),
                  builder: (context, _) {
                    final selected = _selectedContentNotifier.value;
                    final custom = _customAcceptedNotifier.value;

                    return _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Predefined chips
                          Padding(
                            padding: const EdgeInsets.all(DonySpacing.base),
                            child: Wrap(
                              spacing: DonySpacing.xs,
                              runSpacing: DonySpacing.xs,
                              children: _contentTypes.map((type) {
                                final isSelected = selected.contains(type);
                                return GestureDetector(
                                  onTap: () {
                                    final updated =
                                        Set<String>.from(selected);
                                    if (isSelected) {
                                      updated.remove(type);
                                    } else {
                                      updated.add(type);
                                    }
                                    _selectedContentNotifier.value = updated;
                                  },
                                  child: AnimatedContainer(
                                    duration: 160.ms,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.md,
                                      vertical: DonySpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? DonyColors.success
                                          : DonyColors.bgApp,
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.full),
                                      border: Border.all(
                                        color: isSelected
                                            ? DonyColors.success
                                            : DonyColors.borderDefault,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(Icons.check_rounded,
                                              size: 12,
                                              color: DonyColors.surface),
                                          const SizedBox(width: DonySpacing.xs),
                                        ],
                                        Text(
                                          type,
                                          style: tt.bodySmall?.copyWith(
                                            color: isSelected
                                                ? DonyColors.surface
                                                : DonyColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          // Custom items
                          if (custom.isNotEmpty) ...[
                            const _RowDivider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.base,
                                vertical: DonySpacing.sm,
                              ),
                              child: Wrap(
                                spacing: DonySpacing.xs,
                                runSpacing: DonySpacing.xs,
                                children: custom.map((item) => _RemovableChip(
                                  label: item,
                                  accentColor: DonyColors.success,
                                  onRemove: () {
                                    final updated =
                                        Set<String>.from(custom)
                                          ..remove(item);
                                    _customAcceptedNotifier.value = updated;
                                  },
                                )).toList(),
                              ),
                            ),
                          ],
                          const _RowDivider(),
                          _InlineAddRow(
                            controller: _customAcceptedCtrl,
                            hint: 'Ajouter un autre type…',
                            onAdd: () {
                              final val =
                                  _customAcceptedCtrl.text.trim();
                              if (val.isEmpty) {
                                return;
                              }
                              _customAcceptedNotifier.value = {
                                ..._customAcceptedNotifier.value,
                                val,
                              };
                              _customAcceptedCtrl.clear();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 120.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CE QUE JE REFUSE ────────────────────────────────────────
                const _SectionLabel(label: 'CE QUE JE REFUSE'),
                const SizedBox(height: DonySpacing.sm),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: _refusedTypesNotifier,
                  builder: (context, refused, _) {
                    return _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InlineAddRow(
                            controller: _refusedCtrl,
                            hint: 'Ex: Liquides, Denrées périssables…',
                            accentColor: DonyColors.error,
                            onAdd: () {
                              final val = _refusedCtrl.text.trim();
                              if (val.isEmpty) {
                                return;
                              }
                              _refusedTypesNotifier.value = {...refused, val};
                              _refusedCtrl.clear();
                            },
                          ),
                          if (refused.isNotEmpty) ...[
                            const _RowDivider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.base,
                                vertical: DonySpacing.sm,
                              ),
                              child: Wrap(
                                spacing: DonySpacing.xs,
                                runSpacing: DonySpacing.xs,
                                children: refused.map((item) => _RemovableChip(
                                  label: item,
                                  accentColor: DonyColors.error,
                                  onRemove: () {
                                    final updated =
                                        Set<String>.from(refused)
                                          ..remove(item);
                                    _refusedTypesNotifier.value = updated;
                                  },
                                )).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 140.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── NOTE AUX EXPÉDITEURS ────────────────────────────────────
                const _SectionLabel(label: 'NOTE AUX EXPÉDITEURS'),
                const SizedBox(height: DonySpacing.sm),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _descriptionCtrl,
                  builder: (context, value, _) {
                    return _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DonySpacing.base,
                              vertical: DonySpacing.xs,
                            ),
                            child: TextField(
                              controller: _descriptionCtrl,
                              maxLines: 4,
                              maxLength: 500,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              style: tt.bodyMedium
                                  ?.copyWith(color: DonyColors.textPrimary),
                              decoration: InputDecoration(
                                hintText:
                                    'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.',
                                hintStyle: tt.bodyMedium
                                    ?.copyWith(color: DonyColors.textSubtle),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: DonySpacing.md,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              right: DonySpacing.base,
                              bottom: DonySpacing.sm,
                            ),
                            child: Text(
                              '${value.text.length}/500',
                              style: tt.bodySmall
                                  ?.copyWith(color: DonyColors.textSubtle),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 160.ms),
              ],
            ),
          ),
          bottomSheet: Container(
            padding: EdgeInsets.fromLTRB(
              DonyLayout.hPadding(context),
              DonySpacing.base,
              DonyLayout.hPadding(context),
              MediaQuery.of(context).padding.bottom + DonySpacing.base,
            ),
            decoration: const BoxDecoration(
              color: DonyColors.surface,
              border: Border(
                  top: BorderSide(color: DonyColors.borderDefault)),
            ),
            child: DonyButton(
              label: _isEdit ? 'Enregistrer les modifications' : 'Publier le trajet',
              onPressed: isLoading ? null : _submit,
              isLoading: isLoading,
            ),
          ),
        );
      },
    );
  }
}

// ─── Section card (white, no border, clip) ───────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        color: DonyColors.surface,
        child: child,
      ),
    );
  }
}

// ─── Thin row divider ─────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: DonyColors.borderDefault);
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: DonyColors.textSubtle,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ─── Inline add row (no wrapper) ─────────────────────────────────────────────

class _InlineAddRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final Color accentColor;

  const _InlineAddRow({
    required this.controller,
    required this.hint,
    required this.onAdd,
    this.accentColor = DonyColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style:
                  tt.bodyMedium?.copyWith(color: DonyColors.textPrimary),
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    tt.bodyMedium?.copyWith(color: DonyColors.textSubtle),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DonySpacing.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: DonyColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Removable chip ──────────────────────────────────────────────────────────

class _RemovableChip extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onRemove;

  const _RemovableChip({
    required this.label,
    required this.accentColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(
        left: DonySpacing.md,
        right: DonySpacing.xs,
        top: DonySpacing.xs,
        bottom: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: accentColor),
          ),
        ],
      ),
    );
  }
}

// ─── Rangée ville ─────────────────────────────────────────────────────────────

class _CityRow extends StatelessWidget {
  final bool isDeparture;
  final String? value;
  final String? airport;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  const _CityRow({
    required this.isDeparture,
    required this.value,
    required this.airport,
    required this.cities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _showPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDeparture ? DonyColors.primary : DonyColors.error,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: value == null
                  ? Text(
                      isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
                      style: tt.bodyMedium
                          ?.copyWith(color: DonyColors.textSubtle),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value!, style: tt.titleLarge),
                        if (airport != null)
                          Text(
                            airport!,
                            style: tt.bodySmall
                                ?.copyWith(color: DonyColors.textSubtle),
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.textSubtle),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DonyRadius.sheet),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          0,
          DonySpacing.lg,
          DonySpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DonyColors.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
              style: tt.headlineMedium,
            ),
            const SizedBox(height: DonySpacing.base),
            ...cities.map((city) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    city,
                    style: tt.titleMedium?.copyWith(
                      color: value == city
                          ? DonyColors.primary
                          : DonyColors.textPrimary,
                    ),
                  ),
                  trailing: value == city
                      ? const Icon(Icons.check_rounded,
                          color: DonyColors.primary)
                      : null,
                  onTap: () {
                    onChanged(city);
                    context.pop();
                  },
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Rangée heure ─────────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  final bool isDeparture;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeRow({
    required this.isDeparture,
    required this.time,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = isDeparture ? DonyColors.primary : DonyColors.error;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                time == null
                    ? isDeparture
                        ? 'Heure de départ (optionnel)'
                        : 'Heure d\'arrivée (optionnel)'
                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: tt.bodyMedium?.copyWith(
                  fontWeight:
                      time != null ? FontWeight.w600 : FontWeight.w400,
                  color: time != null
                      ? DonyColors.textPrimary
                      : DonyColors.textSubtle,
                ),
              ),
            ),
            if (time != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: DonyColors.textSubtle),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: DonyColors.textSubtle),
          ],
        ),
      ),
    );
  }
}

// ─── Rangée date ──────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: DonyColors.textSubtle),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                date == null
                    ? 'Date de départ'
                    : DateFormat('EEE d MMM yyyy', 'fr').format(date!),
                style: tt.bodyMedium?.copyWith(
                  fontWeight:
                      date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null
                      ? DonyColors.textPrimary
                      : DonyColors.textSubtle,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.textSubtle),
          ],
        ),
      ),
    );
  }
}

// ─── Champ lieu ───────────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final bool isDeparture;
  final TextEditingController controller;

  const _LocationField({
    required this.isDeparture,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            isDeparture
                ? Icons.location_on_rounded
                : Icons.location_on_outlined,
            size: 14,
            color: (isDeparture ? DonyColors.primary : DonyColors.error)
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              style:
                  tt.bodyMedium?.copyWith(color: DonyColors.textPrimary),
              decoration: InputDecoration(
                hintText: isDeparture
                    ? 'Lieu de départ (ex: Terminal 2E CDG)'
                    : 'Lieu d\'arrivée (ex: AIBD Arrière Cour)',
                hintStyle:
                    tt.bodyMedium?.copyWith(color: DonyColors.textSubtle),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: DonySpacing.md,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
