import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PackageRequestCreateScreen extends StatelessWidget {
  const PackageRequestCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PackageRequestFormBloc>(),
      child: const _CreateView(),
    );
  }
}

class _CreateView extends StatefulWidget {
  const _CreateView();

  @override
  State<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends State<_CreateView> {
  final _step1Form = GlobalKey<FormState>();
  final _step2Form = GlobalKey<FormState>();
  final _step3Form = GlobalKey<FormState>();

  final _depCtrl = TextEditingController();
  final _arrCtrl = TextEditingController();
  DateTime? _date;
  int _tolerance = 2;
  TransportMode _transportMode = TransportMode.plane;
  final _weightCtrl = TextEditingController();
  ParcelSize _size = ParcelSize.small;
  final _categoryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  @override
  void dispose() {
    _depCtrl.dispose();
    _arrCtrl.dispose();
    _weightCtrl.dispose();
    _categoryCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PackageRequestFormBloc, PackageRequestFormState>(
      listener: (context, state) {
        if (state.submissionStatus == FormSubmissionStatus.success &&
            state.createdRequest != null) {
          context.go('/package-requests/me');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande créée avec succès'),
              backgroundColor: kSuccess,
            ),
          );
        } else if (state.submissionStatus == FormSubmissionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(state.errorMessage ?? 'Erreur lors de la création'),
              backgroundColor: kError,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            backgroundColor: kSurface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: kGreenPrimary),
              onPressed: () => state.currentStep > 0
                  ? context
                      .read<PackageRequestFormBloc>()
                      .add(const FormStepBack())
                  : context.pop(),
            ),
            title: Text(
              'Étape ${state.currentStep + 1} / 3',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: (state.currentStep + 1) / 3,
                backgroundColor: kBorder,
                valueColor: const AlwaysStoppedAnimation(kGreenPrimary),
                minHeight: 4,
              ),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                switch (state.currentStep) {
                  0 => _buildStep1(context),
                  1 => _buildStep2(context),
                  _ => _buildStep3(context, state),
                },
                if (state.currentStep < 2)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    child: DonyButton(
                      label: 'Continuer',
                      onPressed: () => state.currentStep == 0
                          ? _onStep1Continue(context)
                          : _onStep2Continue(context),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep1(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Form(
        key: _step1Form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Où voulez-vous envoyer votre colis ?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Renseignez le corridor et la date souhaitée',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 32),
            BlocProvider(
              create: (_) => getIt<CitySearchBloc>(),
              child: CityAutocompleteField(
                label: 'Ville de départ',
                initialValue: _depCtrl.text.isEmpty ? null : _depCtrl.text,
                prefixIcon: const Icon(Icons.flight_takeoff_rounded,
                    color: kGreenPrimary, size: 20),
                onSelected: (city) {
                  _depCtrl.text = city.name;
                },
              ),
            ),
            const SizedBox(height: 16),
            BlocProvider(
              create: (_) => getIt<CitySearchBloc>(),
              child: CityAutocompleteField(
                label: 'Ville d\'arrivée',
                initialValue: _arrCtrl.text.isEmpty ? null : _arrCtrl.text,
                prefixIcon: const Icon(Icons.flight_land_rounded,
                    color: kGreenPrimary, size: 20),
                onSelected: (city) {
                  _arrCtrl.text = city.name;
                },
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ??
                      DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 20, color: kTextSecondary),
                    const SizedBox(width: 12),
                    Text(
                      _date == null
                          ? 'Date souhaitée'
                          : '${_date!.day}/${_date!.month}/${_date!.year}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: _date == null ? kTextHint : kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tolérance : ±$_tolerance jour${_tolerance > 1 ? 's' : ''}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: _tolerance.toDouble(),
              min: 0,
              max: 7,
              divisions: 7,
              activeColor: kGreenPrimary,
              onChanged: (v) => setState(() => _tolerance = v.round()),
            ),
            const SizedBox(height: 12),
            Text(
              'Mode de transport',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransportMode.values.map((m) {
                final selected = m == _transportMode;
                return ChoiceChip(
                  avatar: Icon(m.icon, size: 18,
                      color: selected ? Colors.white : kGreenPrimary),
                  label: Text(m.label),
                  selected: selected,
                  selectedColor: kGreenPrimary,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: selected ? Colors.white : kTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _transportMode = m),
                );
              }).toList(),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(
            begin: 0.04,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Form(
        key: _step2Form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Détails du colis',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Poids',
                suffixText: 'kg',
              ),
              validator: (v) {
                final d = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (d == null) return 'Valeur invalide';
                if (d < 0.5 || d > 30) return 'Entre 0.5 et 30 kg';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Taille',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: ParcelSize.values.map((s) {
                final selected = s == _size;
                return ChoiceChip(
                  label: Text(s.name.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => setState(() => _size = s),
                  selectedColor: kGreenLight,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? kGreenPrimary : kTextSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Catégorie de contenu',
                hintText: 'vêtements, documents, cadeaux…',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                hintText: 'Cadeau pour ma mère',
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(
            begin: 0.04,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  Widget _buildStep3(BuildContext context, PackageRequestFormState state) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 24, 20, MediaQuery.of(context).padding.bottom + 100),
          child: Form(
            key: _step3Form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Prix souhaité',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optionnel — proposez un budget pour orienter les voyageurs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prix cible (optionnel)',
                    suffixText: '€',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final d = double.tryParse(v.replaceAll(',', '.'));
                    if (d == null || d < 0 || d > 500) {
                      return 'Entre 0 et 500€';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kGreenPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: kGreenPrimary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Les voyageurs vous feront leurs propositions. Vous pourrez négocier jusqu\'à 5 rounds.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: kGreenDark,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(
                begin: 0.04,
                curve: Curves.easeOutCubic,
              ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: DonyButton(
            label: state.submissionStatus == FormSubmissionStatus.submitting
                ? 'Création…'
                : 'Publier ma demande',
            isLoading:
                state.submissionStatus == FormSubmissionStatus.submitting,
            onPressed: () {
              if (_step3Form.currentState!.validate()) {
                final target =
                    double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
                context.read<PackageRequestFormBloc>().add(
                      FormStep3Submitted(targetPriceEur: target),
                    );
              }
            },
          ),
        ),
      ],
    );
  }

  void _onStep1Continue(BuildContext context) {
    if (!_step1Form.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une date')),
      );
      return;
    }
    context.read<PackageRequestFormBloc>().add(
          FormStep1Submitted(
            departureCity: _depCtrl.text.trim(),
            arrivalCity: _arrCtrl.text.trim(),
            desiredDate: _date!,
            dateToleranceDays: _tolerance,
            transportMode: _transportMode,
          ),
        );
  }

  void _onStep2Continue(BuildContext context) {
    if (!_step2Form.currentState!.validate()) return;
    final w = double.parse(_weightCtrl.text.replaceAll(',', '.'));
    context.read<PackageRequestFormBloc>().add(
          FormStep2Submitted(
            weightKg: w,
            parcelSize: _size,
            contentCategory: _categoryCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
          ),
        );
  }
}
