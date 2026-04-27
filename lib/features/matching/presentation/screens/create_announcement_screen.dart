import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const _departureCities = ['Paris', 'Lyon', 'Marseille'];
const _arrivalCities = ['Dakar', 'Abidjan', 'Bamako', 'Douala'];

const _departureAirports = {
  'Paris': 'CDG',
  'Lyon': 'LYS',
  'Marseille': 'MRS',
};
const _arrivalAirports = {
  'Dakar': 'AIBD',
  'Abidjan': 'ABJ',
  'Bamako': 'BKO',
  'Douala': 'DLA',
};

const _departureAirportCodes = {
  'Paris': 'CDG',
  'Lyon': 'LYS',
  'Marseille': 'MRS',
};
const _arrivalAirportCodes = {
  'Dakar': 'DSS',
  'Abidjan': 'ABJ',
  'Bamako': 'BKO',
  'Douala': 'DLA',
};

// Price selector options matching maquette: 5€, 6€, 7€, 8€
const _priceOptions = [5.0, 6.0, 7.0, 8.0];

// Accepted content types
const _contentTypes = [
  'Vêtements',
  'Médicaments',
  'Alim. sèche',
  'Hi-fi',
  'Documents',
  'Téléphone',
  'Cosmétiques',
];

class CreateAnnouncementScreen extends StatefulWidget {
  final AnnouncementModel? announcement;
  const CreateAnnouncementScreen({super.key, this.announcement});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  String? _departureCity;
  String? _arrivalCity;
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;
  final _departureLocationCtrl = TextEditingController();
  final _arrivalLocationCtrl = TextEditingController();

  // ValueNotifiers for UI state (no setState)
  final _availableKgNotifier = ValueNotifier<double>(15);
  final _priceOptionNotifier = ValueNotifier<int>(1); // index into _priceOptions
  final _selectedContentNotifier = ValueNotifier<Set<String>>(
    {'Vêtements', 'Médicaments', 'Alim. sèche', 'Hi-fi'},
  );

  bool get _isEdit => widget.announcement != null;
  double get _pricePerKg => _priceOptions[_priceOptionNotifier.value];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCity = a.departureCity;
      _arrivalCity = a.arrivalCity;
      _departureDate = a.departureDate;
      _availableKgNotifier.value = a.availableKg;

      if (a.departureTime != null) {
        final parts = a.departureTime!.split(':');
        _departureTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (a.arrivalTime != null) {
        final parts = a.arrivalTime!.split(':');
        _arrivalTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _departureLocationCtrl.text = a.departureLocation ?? '';
      _arrivalLocationCtrl.text = a.arrivalLocation ?? '';

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
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _submit() {
    if (_departureCity == null) {
      _showError('Ville de départ obligatoire');
      return;
    }
    if (_arrivalCity == null) {
      _showError('Ville d\'arrivée obligatoire');
      return;
    }
    if (_departureDate == null) {
      _showError('Date de départ obligatoire');
      return;
    }

    final departureTime = _departureTime != null ? _formatTime(_departureTime!) : null;
    final arrivalTime = _arrivalTime != null ? _formatTime(_arrivalTime!) : null;
    final departureLocation = _departureLocationCtrl.text.trim().isEmpty
        ? null
        : _departureLocationCtrl.text.trim();
    final arrivalLocation = _arrivalLocationCtrl.text.trim().isEmpty
        ? null
        : _arrivalLocationCtrl.text.trim();

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
        id: widget.announcement!.id,
        departureCity: _departureCity!,
        arrivalCity: _arrivalCity!,
        departureDate: _departureDate!,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureLocation: departureLocation,
        arrivalLocation: arrivalLocation,
        availableKg: _availableKgNotifier.value,
        pricePerKg: _pricePerKg,
      ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
        departureCity: _departureCity!,
        arrivalCity: _arrivalCity!,
        departureDate: _departureDate!,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureLocation: departureLocation,
        arrivalLocation: arrivalLocation,
        availableKg: _availableKgNotifier.value,
        pricePerKg: _pricePerKg,
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
      initialDate: _departureDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: DonyColors.green400),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _selectDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: DonyColors.green400),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _departureTime = picked);
  }

  Future<void> _selectArrivalTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _arrivalTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: DonyColors.green400),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _arrivalTime = picked);
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

        // Computed corridor labels for display
        final depCode = _departureCity != null
            ? (_departureAirportCodes[_departureCity] ?? _departureCity!)
            : null;
        final arrCode = _arrivalCity != null
            ? (_arrivalAirportCodes[_arrivalCity] ?? _arrivalCity!)
            : null;

        return Scaffold(
          backgroundColor: DonyColors.bg,
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
                  'Aff. en 1 min',
                  style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                ),
              ],
            ),
            backgroundColor: DonyColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 22, color: DonyColors.ink900),
              onPressed: () => context.pop(),
              tooltip: 'Fermer',
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Corridor card ───────────────────────────────────────────
                if (_departureCity != null && _arrivalCity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: DonyColors.white,
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                      border: Border.all(color: DonyColors.grey200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$depCode → $arrCode',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_departureDate != null)
                                Text(
                                  _formatCorridorDateTime(),
                                  style: tt.bodyMedium?.copyWith(
                                    color: DonyColors.grey400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Scroll back or allow re-selection
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: DonyColors.green400,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Modifier',
                            style: tt.bodyMedium?.copyWith(
                              color: DonyColors.green400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 250.ms),

                if (_departureCity != null && _arrivalCity != null)
                  const SizedBox(height: DonySpacing.xl),

                // ── Trajet section ──────────────────────────────────────────
                _SectionLabel(label: 'TRAJET'),
                const SizedBox(height: DonySpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: DonyColors.white,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(color: DonyColors.grey200),
                  ),
                  child: Column(
                    children: [
                      _CityRow(
                        isDeparture: true,
                        value: _departureCity,
                        airport: _departureCity != null
                            ? _departureAirports[_departureCity]
                            : null,
                        cities: _departureCities,
                        onChanged: (v) => setState(() => _departureCity = v),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: DonySpacing.icon),
                        child: Divider(height: 1),
                      ),
                      _TimeRow(
                        isDeparture: true,
                        time: _departureTime,
                        onTap: _selectDepartureTime,
                        onClear: _departureTime != null
                            ? () => setState(() => _departureTime = null)
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: DonySpacing.icon),
                        child: Divider(height: 1),
                      ),
                      _CityRow(
                        isDeparture: false,
                        value: _arrivalCity,
                        airport: _arrivalCity != null
                            ? _arrivalAirports[_arrivalCity]
                            : null,
                        cities: _arrivalCities,
                        onChanged: (v) => setState(() => _arrivalCity = v),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: DonySpacing.icon),
                        child: Divider(height: 1),
                      ),
                      _TimeRow(
                        isDeparture: false,
                        time: _arrivalTime,
                        onTap: _selectArrivalTime,
                        onClear: _arrivalTime != null
                            ? () => setState(() => _arrivalTime = null)
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: DonySpacing.icon),
                        child: Divider(height: 1),
                      ),
                      _DateRow(
                        date: _departureDate,
                        onTap: _selectDate,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── LIEUX DE REMISE ─────────────────────────────────────────
                _SectionLabel(label: 'LIEUX DE REMISE (optionnel)'),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Précisez l\'endroit exact de remise / récupération des colis',
                  style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                ),
                const SizedBox(height: DonySpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: DonyColors.white,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(color: DonyColors.grey200),
                  ),
                  child: Column(
                    children: [
                      _LocationField(
                        isDeparture: true,
                        controller: _departureLocationCtrl,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: DonySpacing.icon),
                        child: Divider(height: 1),
                      ),
                      _LocationField(
                        isDeparture: false,
                        controller: _arrivalLocationCtrl,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CAPACITÉ DISPONIBLE ─────────────────────────────────────
                _SectionLabel(label: 'CAPACITÉ DISPONIBLE'),
                const SizedBox(height: DonySpacing.base),
                ValueListenableBuilder<double>(
                  valueListenable: _availableKgNotifier,
                  builder: (context, kg, _) {
                    return Column(
                      children: [
                        // Large display row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(child: const SizedBox()),
                            Text(
                              kg.toStringAsFixed(0),
                              style: tt.displayLarge?.copyWith(
                                color: DonyColors.ink900,
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              ' kg',
                              style: tt.headlineMedium?.copyWith(
                                color: DonyColors.grey400,
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
                                    color: DonyColors.grey100,
                                    borderRadius: BorderRadius.circular(DonyRadius.full),
                                  ),
                                  child: Text(
                                    'VALISE',
                                    style: tt.labelSmall?.copyWith(
                                      color: DonyColors.grey400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: DonyColors.green400,
                            inactiveTrackColor: DonyColors.grey200,
                            thumbColor: DonyColors.green400,
                            overlayColor: DonyColors.green400.withValues(alpha: 0.1),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: kg,
                            min: 1,
                            max: 23,
                            divisions: 22,
                            onChanged: (v) => _availableKgNotifier.value = v,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '1 kg',
                              style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                            ),
                            Text(
                              'max 23 kg',
                              style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── PRIX PAR KG ─────────────────────────────────────────────
                _SectionLabel(label: 'PRIX PAR KG'),
                const SizedBox(height: DonySpacing.md),
                ValueListenableBuilder<int>(
                  valueListenable: _priceOptionNotifier,
                  builder: (context, selectedIdx, _) {
                    final kg = _availableKgNotifier.value;
                    final pricePerKg = _priceOptions[selectedIdx];
                    final grossEstimate = kg * pricePerKg;
                    final netEstimate = grossEstimate * 0.88; // 12% commission

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
                                  onTap: () => _priceOptionNotifier.value = i,
                                  child: AnimatedContainer(
                                    duration: 180.ms,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.md,
                                      vertical: DonySpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? DonyColors.green50
                                          : DonyColors.white,
                                      borderRadius: BorderRadius.circular(DonyRadius.lg),
                                      border: Border.all(
                                        color: selected
                                            ? DonyColors.green400
                                            : DonyColors.grey200,
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_priceOptions[i].toStringAsFixed(0)}€',
                                        style: tt.titleMedium?.copyWith(
                                          color: selected
                                              ? DonyColors.green400
                                              : DonyColors.ink900,
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
                          'Estimation gain : ${grossEstimate.toStringAsFixed(0)}€ · vous touchez ${netEstimate.toStringAsFixed(0)}€',
                          style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                        ),
                      ],
                    );
                  },
                ).animate().fadeIn(delay: 140.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── LIMITE DÉPART ───────────────────────────────────────────
                _SectionLabel(label: 'LIMITE DÉPART'),
                const SizedBox(height: DonySpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.base,
                    vertical: DonySpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: DonyColors.white,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    border: Border.all(color: DonyColors.grey200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: DonyColors.green400,
                        size: 20,
                      ),
                      const SizedBox(width: DonySpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _departureDate != null
                                  ? _formatHandoverDate()
                                  : 'Jeu 17 avril · 18h–20h',
                              style: tt.bodyMedium,
                            ),
                            Text(
                              _departureLocationCtrl.text.isNotEmpty
                                  ? _departureLocationCtrl.text
                                  : 'Adresse de remise · 12e arrond.',
                              style: tt.bodySmall?.copyWith(
                                color: DonyColors.grey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CE QUE J'ACCEPTE DE TRANSPORTER ────────────────────────
                _SectionLabel(label: 'Ce que j\'accepte de transporter'),
                const SizedBox(height: DonySpacing.md),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: _selectedContentNotifier,
                  builder: (context, selected, _) {
                    return Wrap(
                      spacing: DonySpacing.sm,
                      runSpacing: DonySpacing.sm,
                      children: _contentTypes.map((type) {
                        final isSelected = selected.contains(type);
                        return GestureDetector(
                          onTap: () {
                            final updated = Set<String>.from(selected);
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
                              vertical: DonySpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? DonyColors.ink900
                                  : DonyColors.white,
                              borderRadius: BorderRadius.circular(DonyRadius.full),
                              border: Border.all(
                                color: isSelected
                                    ? DonyColors.ink900
                                    : DonyColors.grey200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: DonyColors.white,
                                  ),
                                  const SizedBox(width: DonySpacing.xs),
                                ],
                                Text(
                                  type,
                                  style: tt.bodySmall?.copyWith(
                                    color: isSelected
                                        ? DonyColors.white
                                        : DonyColors.ink900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ).animate().fadeIn(delay: 160.ms),
              ],
            ),
          ),
          bottomSheet: Container(
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.lg,
              MediaQuery.of(context).padding.bottom + DonySpacing.base,
            ),
            decoration: const BoxDecoration(
              color: DonyColors.white,
              border: Border(top: BorderSide(color: DonyColors.grey200)),
            ),
            child: DonyButton(
              label: '→ Publier le trajet',
              icon: Icons.send_rounded,
              onPressed: isLoading ? null : _submit,
              isLoading: isLoading,
            ),
          ),
        );
      },
    );
  }

  String _formatCorridorDateTime() {
    if (_departureDate == null) return '';
    final date = DateFormat('EEE d MMM', 'fr').format(_departureDate!);
    if (_departureTime != null && _arrivalTime != null) {
      return '$date · ${_departureTime!.hour}h–${_arrivalTime!.hour}h';
    } else if (_departureTime != null) {
      return '$date · ${_departureTime!.hour}h';
    }
    return date;
  }

  String _formatHandoverDate() {
    if (_departureDate == null) return '';
    final date = DateFormat('EEE d MMMM', 'fr').format(_departureDate!);
    if (_departureTime != null && _arrivalTime != null) {
      return '$date · ${_departureTime!.hour}h–${_arrivalTime!.hour}h';
    }
    return date;
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: DonyColors.grey400,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Rangée ville ─────────────────────────────────────────────────────────────

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.isDeparture,
    required this.value,
    required this.airport,
    required this.cities,
    required this.onChanged,
  });

  final bool isDeparture;
  final String? value;
  final String? airport;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(DonyRadius.card),
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
                color: isDeparture ? DonyColors.green400 : DonyColors.error,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: value == null
                  ? Text(
                      isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
                      style: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value!,
                          style: tt.titleLarge,
                        ),
                        if (airport != null)
                          Text(
                            airport!,
                            style: tt.bodySmall?.copyWith(color: DonyColors.grey400),
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.grey400),
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
          color: DonyColors.white,
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
                  color: DonyColors.grey200,
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
                  title: Text(
                    city,
                    style: tt.titleMedium?.copyWith(
                      color: value == city
                          ? DonyColors.green400
                          : DonyColors.ink900,
                    ),
                  ),
                  trailing: value == city
                      ? const Icon(Icons.check_rounded, color: DonyColors.green400)
                      : null,
                  onTap: () {
                    onChanged(city);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

// ── Rangée heure ─────────────────────────────────────────────────────────────

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.isDeparture,
    required this.time,
    required this.onTap,
    this.onClear,
  });

  final bool isDeparture;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = isDeparture ? DonyColors.green400 : DonyColors.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.card),
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
                  fontWeight: time != null ? FontWeight.w600 : FontWeight.w400,
                  color: time != null ? DonyColors.ink900 : DonyColors.grey400,
                ),
              ),
            ),
            if (time != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: DonyColors.grey400),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: DonyColors.grey400),
          ],
        ),
      ),
    );
  }
}

// ── Rangée date ──────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: DonyColors.grey400),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                date == null
                    ? 'Date de départ'
                    : DateFormat('EEE d MMM yyyy', 'fr').format(date!),
                style: tt.bodyMedium?.copyWith(
                  fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
                  color: date != null ? DonyColors.ink900 : DonyColors.grey400,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: DonyColors.grey400),
          ],
        ),
      ),
    );
  }
}

// ── Champ lieu ───────────────────────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.isDeparture,
    required this.controller,
  });

  final bool isDeparture;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isDeparture ? Icons.location_on_rounded : Icons.location_on_outlined,
            size: 14,
            color: isDeparture
                ? DonyColors.green400.withValues(alpha: 0.7)
                : DonyColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              style: tt.bodyMedium?.copyWith(color: DonyColors.ink900),
              decoration: InputDecoration(
                hintText: isDeparture
                    ? 'Lieu de départ (ex: Terminal 2E CDG)'
                    : 'Lieu d\'arrivée (ex: AIBD Arrière Cour)',
                hintStyle: tt.bodyMedium?.copyWith(color: DonyColors.grey400),
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
