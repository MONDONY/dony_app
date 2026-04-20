import 'package:dony/app/theme.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  final AnnouncementModel? announcement;
  const CreateAnnouncementScreen({super.key, this.announcement});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _departureCity;
  String? _arrivalCity;
  DateTime? _departureDate;
  double _availableKg = 10.0;
  final _priceController = TextEditingController();

  final List<String> _departureCities = ['Paris', 'Lyon', 'Marseille'];
  final List<String> _arrivalCities = ['Dakar', 'Abidjan', 'Bamako', 'Douala'];

  bool get _isEdit => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _departureCity = widget.announcement!.departureCity;
      _arrivalCity = widget.announcement!.arrivalCity;
      _departureDate = widget.announcement!.departureDate;
      _availableKg = widget.announcement!.availableKg;
      _priceController.text = widget.announcement!.pricePerKg.toString();
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kGreenPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _departureDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_departureDate == null) {
      _showError('La date de départ est obligatoire');
      return;
    }
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showError('Veuillez entrer un prix valide');
      return;
    }

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
        id: widget.announcement!.id,
        departureCity: _departureCity!,
        arrivalCity: _arrivalCity!,
        departureDate: _departureDate!,
        availableKg: _availableKg,
        pricePerKg: price,
      ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
        departureCity: _departureCity!,
        arrivalCity: _arrivalCity!,
        departureDate: _departureDate!,
        availableKg: _availableKg,
        pricePerKg: price,
      ));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kError),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier le trajet' : 'Publier un trajet',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: kSurface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) {
          if (state is AnnouncementCreated || state is AnnouncementUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEdit ? 'Trajet modifié !' : 'Trajet publié !'),
                backgroundColor: kSuccess,
              ),
            );
            context.go('/announcements');
          } else if (state is AnnouncementError) {
            _showError(state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AnnouncementLoading;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section corridor
                  _SectionLabel(
                    icon: Icons.flight_takeoff_rounded,
                    label: 'Corridor',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Départ',
                          value: _departureCity,
                          items: _departureCities,
                          onChanged: (v) => setState(() => _departureCity = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kGreenLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, size: 16, color: kGreenPrimary),
                        ),
                      ),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Arrivée',
                          value: _arrivalCity,
                          items: _arrivalCities,
                          onChanged: (v) => setState(() => _arrivalCity = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Section date
                  _SectionLabel(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date de départ',
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: kGreenPrimary),
                          const SizedBox(width: 12),
                          Text(
                            _departureDate == null
                                ? 'Sélectionner une date'
                                : DateFormat('EEEE d MMMM yyyy', 'fr').format(_departureDate!),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: _departureDate != null ? FontWeight.w600 : FontWeight.w400,
                              color: _departureDate != null ? kTextPrimary : kTextHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section capacité
                  _SectionLabel(
                    icon: Icons.scale_rounded,
                    label: 'Capacité disponible',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_availableKg.toStringAsFixed(1)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: kGreenPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'kg',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: kGreenPrimary,
                      inactiveTrackColor: kGreenLight,
                      thumbColor: kGreenPrimary,
                      overlayColor: kGreenPrimary.withValues(alpha: 0.1),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _availableKg,
                      min: 1,
                      max: 30,
                      divisions: 58,
                      onChanged: (v) => setState(() => _availableKg = v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 kg', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextHint)),
                      Text('30 kg', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextHint)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Section prix
                  _SectionLabel(
                    icon: Icons.euro_rounded,
                    label: 'Prix par kilogramme',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ex: 8.50',
                      suffixText: '€/kg',
                      suffixStyle: GoogleFonts.plusJakartaSans(
                        color: kGreenPrimary, fontWeight: FontWeight.w600,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Veuillez entrer un prix';
                      }
                      if (double.tryParse(v) == null) {
                        return 'Prix invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isEdit ? 'Enregistrer les modifications' : 'Publier mon trajet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null ? 'Requis' : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kGreenLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kGreenPrimary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
      ],
    );
  }
}
