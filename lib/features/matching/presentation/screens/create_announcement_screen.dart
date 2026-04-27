import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  double _availableKg = 15;
  int _priceOption = 1; // 0=éco, 1=standard, 2=premium
  static const _priceOptions = [10.0, 12.0, 15.0];
  static const _priceLabels = ['Économique', 'Standard', 'Premium'];

  bool get _isEdit => widget.announcement != null;
  double get _pricePerKg => _priceOptions[_priceOption];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCity = a.departureCity;
      _arrivalCity = a.arrivalCity;
      _departureDate = a.departureDate;
      _availableKg = a.availableKg;

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
      _priceOption = closest;
    }
  }

  @override
  void dispose() {
    _departureLocationCtrl.dispose();
    _arrivalLocationCtrl.dispose();
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
        availableKg: _availableKg,
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
        availableKg: _availableKg,
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
    if (picked != null) setState(() => _departureDate = picked);
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
          backgroundColor: DonyColors.grey50,
          appBar: AppBar(
            title: Text(
              _isEdit ? 'Modifier le trajet' : 'Publier un trajet',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            backgroundColor: DonyColors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: DonyColors.green400),
              onPressed: () => context.pop(),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bannière motivationnelle
                if (!_isEdit)
                  _MotivationBanner().animate().fadeIn(duration: 250.ms),
                if (!_isEdit) const SizedBox(height: 24),

                // Section TRAJET
                Text(
                  'TRAJET',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.grey400,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: DonyColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DonyColors.grey100),
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
                        padding: EdgeInsets.only(left: 40),
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
                        padding: EdgeInsets.only(left: 40),
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
                        padding: EdgeInsets.only(left: 40),
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
                        padding: EdgeInsets.only(left: 40),
                        child: Divider(height: 1),
                      ),
                      _DateRow(
                        date: _departureDate,
                        onTap: _selectDate,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: 28),

                // Section LIEUX DE REMISE
                Text(
                  'LIEUX DE REMISE (optionnel)',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.grey400,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Précisez l\'endroit exact de remise / récupération des colis',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: DonyColors.grey200,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: DonyColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DonyColors.grey100),
                  ),
                  child: Column(
                    children: [
                      _LocationField(
                        isDeparture: true,
                        controller: _departureLocationCtrl,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 40),
                        child: Divider(height: 1),
                      ),
                      _LocationField(
                        isDeparture: false,
                        controller: _arrivalLocationCtrl,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 28),

                // Capacité disponible
                Text(
                  'CAPACITÉ DISPONIBLE',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.grey400,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_availableKg.toStringAsFixed(0)}',
                          style: GoogleFonts.sora(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: DonyColors.ink900,
                          ),
                        ),
                        TextSpan(
                          text: 'kg',
                          style: GoogleFonts.sora(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: DonyColors.grey400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: DonyColors.green400,
                    inactiveTrackColor: DonyColors.green100,
                    thumbColor: DonyColors.green400,
                    overlayColor: DonyColors.green400.withValues(alpha: 0.1),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _availableKg,
                    min: 1,
                    max: 23,
                    divisions: 22,
                    onChanged: (v) => setState(() => _availableKg = v),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1 kg',
                        style: GoogleFonts.sora(
                            fontSize: 12, color: DonyColors.grey200)),
                    Text('23 kg max',
                        style: GoogleFonts.sora(
                            fontSize: 12, color: DonyColors.grey200)),
                  ],
                ),
                const SizedBox(height: 28),

                // Prix par kg
                Text(
                  'PRIX PAR KG',
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: DonyColors.grey400,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (i) {
                    final selected = _priceOption == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : 6,
                          right: i == 2 ? 0 : 6,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _priceOption = i),
                          child: AnimatedContainer(
                            duration: 180.ms,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selected ? DonyColors.ink900 : DonyColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? DonyColors.ink900 : DonyColors.grey100,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${_priceOptions[i].toStringAsFixed(0)} €',
                                  style: GoogleFonts.sora(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? Colors.white
                                        : DonyColors.ink900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _priceLabels[i],
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    color: selected
                                        ? Colors.white70
                                        : DonyColors.grey400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ).animate().fadeIn(delay: 140.ms),
              ],
            ),
          ),
          bottomSheet: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: DonyColors.white,
              border: Border(top: BorderSide(color: DonyColors.grey100)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEdit
                            ? 'Enregistrer les modifications'
                            : 'Publier mon trajet',
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Bannière motivationnelle ─────────────────────────────────────────────────

class _MotivationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.flight_rounded,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gagnez avec vos kilos libres',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  'Moyenne : 180€ par trajet · paiement en 24h',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const SizedBox(width: 14),
            Expanded(
              child: value == null
                  ? Text(
                      isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        color: DonyColors.grey200,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value!,
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DonyColors.ink900,
                          ),
                        ),
                        if (airport != null)
                          Text(
                            airport!,
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              color: DonyColors.grey400,
                            ),
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: DonyColors.grey200),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: DonyColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DonyColors.grey100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isDeparture ? 'Ville de départ' : 'Ville d\'arrivée',
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...cities.map((city) => ListTile(
                  title: Text(
                    city,
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w500,
                      color: value == city ? DonyColors.green400 : DonyColors.ink900,
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
    final color = isDeparture ? DonyColors.green400 : DonyColors.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                time == null
                    ? isDeparture
                        ? 'Heure de départ (optionnel)'
                        : 'Heure d\'arrivée (optionnel)'
                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: time != null ? FontWeight.w700 : FontWeight.w400,
                  color: time != null ? DonyColors.ink900 : DonyColors.grey200,
                ),
              ),
            ),
            if (time != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 16, color: DonyColors.grey200),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 18, color: DonyColors.grey200),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14, color: DonyColors.grey400),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                date == null
                    ? 'Date de départ'
                    : DateFormat('EEE d MMM yyyy', 'fr').format(date!),
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: date != null ? FontWeight.w700 : FontWeight.w400,
                  color: date != null ? DonyColors.ink900 : DonyColors.grey200,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: DonyColors.grey200),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isDeparture ? Icons.location_on_rounded : Icons.location_on_outlined,
            size: 14,
            color: isDeparture ? DonyColors.green400.withValues(alpha: 0.7) : DonyColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: DonyColors.ink900,
              ),
              decoration: InputDecoration(
                hintText: isDeparture
                    ? 'Lieu de départ (ex: Terminal 2E CDG)'
                    : 'Lieu d\'arrivée (ex: AIBD Arrière Cour)',
                hintStyle: GoogleFonts.sora(
                  fontSize: 14,
                  color: DonyColors.grey200,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
