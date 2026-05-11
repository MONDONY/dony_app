import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const _stepLabels = ['Trajet & colis', 'Prix & photo'];

class PublishPackageRequestBottomSheet {
  static Future<void> show(BuildContext context) async {
    final stepNotifier = ValueNotifier<int>(0);
    VoidCallback? onContinue;

    return DonyBottomSheet.show<void>(
      context,
      title: '', // Title rendered manually inside content for dynamic step label
      wrapper: (child) => BlocProvider(
        create: (_) => getIt<PackageRequestFormBloc>(),
        child: child,
      ),
      stickyBottom: ValueListenableBuilder<int>(
        valueListenable: stepNotifier,
        builder: (ctx, step, _) =>
            BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
          builder: (ctx, formState) {
            final isSubmitting =
                formState.submissionStatus == FormSubmissionStatus.submitting;
            return DonyButton(
              label: step == 0
                  ? 'Continuer'
                  : (isSubmitting ? 'Publication…' : 'Publier la demande'),
              isLoading: isSubmitting,
              onPressed:
                  isSubmitting ? null : () => onContinue?.call(),
            );
          },
        ),
      ),
      child: _PublishContent(
        stepNotifier: stepNotifier,
        onContinueReady: (cb) => onContinue = cb,
      ),
    ).whenComplete(stepNotifier.dispose);
  }
}

class _PublishContent extends StatefulWidget {
  const _PublishContent({
    required this.stepNotifier,
    required this.onContinueReady,
  });
  final ValueNotifier<int> stepNotifier;
  final void Function(VoidCallback) onContinueReady;

  @override
  State<_PublishContent> createState() => _PublishContentState();
}

class _PublishContentState extends State<_PublishContent> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  String? _departureCity;
  String? _arrivalCity;
  DateTime? _date;
  int _tolerance = 2;
  TransportMode _transportMode = TransportMode.plane;

  final _weightCtrl = TextEditingController();
  ParcelSize _size = ParcelSize.small;
  ContentCategory? _category;

  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pickupNeighCtrl = TextEditingController();
  final _deliveryNeighCtrl = TextEditingController();

  File? _photoFile;
  bool _photoUploading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    widget.onContinueReady(_handleContinue);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _pickupNeighCtrl.dispose();
    _deliveryNeighCtrl.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final step = widget.stepNotifier.value;
    if (step == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
      if (_departureCity == null || _arrivalCity == null) {
        _snack('Sélectionne les villes de départ et d\'arrivée');
        return;
      }
      if (_departureCity!.toLowerCase() == _arrivalCity!.toLowerCase()) {
        _snack('Les villes doivent être différentes');
        return;
      }
      if (_date == null) {
        _snack('Choisis une date souhaitée');
        return;
      }
      if (_category == null) {
        _snack('Choisis une catégorie de contenu');
        return;
      }
      // Hydrate the form bloc step 1 (so submission has the data ready)
      context.read<PackageRequestFormBloc>().add(FormStep1Submitted(
            departureCity: _departureCity!,
            arrivalCity: _arrivalCity!,
            desiredDate: _date!,
            dateToleranceDays: _tolerance,
            transportMode: _transportMode,
          ));
      context.read<PackageRequestFormBloc>().add(FormStep2Submitted(
            weightKg: double.parse(_weightCtrl.text.replaceAll(',', '.')),
            parcelSize: _size,
            contentCategory: _category!,
          ));
      widget.stepNotifier.value = 1;
      return;
    }
    // Step 2 → submit
    if (!_step2FormKey.currentState!.validate()) return;
    final price = _priceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    context.read<PackageRequestFormBloc>().add(FormStep3Submitted(
          targetPriceEur: price,
          photoUrl: _photoUrl,
          pickupNeighborhood: _pickupNeighCtrl.text.trim().isEmpty
              ? null
              : _pickupNeighCtrl.text.trim(),
          deliveryNeighborhood: _deliveryNeighCtrl.text.trim().isEmpty
              ? null
              : _deliveryNeighCtrl.text.trim(),
        ));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _photoFile = file;
      _photoUploading = true;
    });
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: 'package_request.jpg'),
      });
      final response = await getIt<ApiClient>()
          .dio
          .post('/storage/upload/package-request', data: formData);
      final url = (response.data as Map<String, dynamic>)['url'] as String;
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        _snack('Échec de l\'upload : $e');
        setState(() => _photoFile = null);
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<PackageRequestFormBloc, PackageRequestFormState>(
      listener: (ctx, state) {
        if (state.submissionStatus == FormSubmissionStatus.success) {
          Navigator.of(ctx, rootNavigator: true).pop();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: const Text('Demande publiée avec succès'),
              backgroundColor: cs.success,
            ),
          );
          ctx.push('/package-requests/me');
        } else if (state.submissionStatus == FormSubmissionStatus.error) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Erreur lors de la publication'),
              backgroundColor: cs.error,
            ),
          );
        }
      },
      child: ValueListenableBuilder<int>(
        valueListenable: widget.stepNotifier,
        builder: (ctx, step, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Text(
                _stepLabels[step],
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                'Étape ${step + 1} sur ${_stepLabels.length}',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: DonySpacing.base),
              DonyStepIndicator.labeled(
                steps: _stepLabels,
                current: step,
              ),
              const SizedBox(height: DonySpacing.xl),
              // ── Body ──────────────────────────────────────────────────────
              if (step == 0) _buildStep1() else _buildStep2(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep1() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocProvider(
            create: (_) => getIt<CitySearchBloc>(),
            child: CityAutocompleteField(
              label: 'Ville de départ',
              initialValue: _departureCity,
              prefixIcon: Icon(Icons.flight_takeoff_rounded,
                  color: cs.primary, size: 20),
              onSelected: (CityModel city) {
                setState(() => _departureCity = city.name);
              },
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          BlocProvider(
            create: (_) => getIt<CitySearchBloc>(),
            child: CityAutocompleteField(
              label: 'Ville d\'arrivée',
              initialValue: _arrivalCity,
              prefixIcon:
                  Icon(Icons.flight_land_rounded, color: cs.secondary, size: 20),
              onSelected: (CityModel city) {
                setState(() => _arrivalCity = city.name);
              },
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _date ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            borderRadius: BorderRadius.circular(DonyRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.base, vertical: 18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.md),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Text(
                      _date == null
                          ? 'Date souhaitée'
                          : DateFormat('EEEE d MMMM yyyy', 'fr')
                              .format(_date!),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _date == null
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Tolérance ± $_tolerance jour${_tolerance > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _tolerance.toDouble(),
            min: 0,
            max: 7,
            divisions: 7,
            label: '$_tolerance',
            onChanged: (v) => setState(() => _tolerance = v.round()),
          ),
          const SizedBox(height: DonySpacing.md),
          Text('Mode de transport', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: TransportMode.values.map((m) {
              final selected = m == _transportMode;
              return ChoiceChip(
                avatar: Icon(m.icon, size: 18,
                    color: selected ? cs.onPrimary : cs.primary),
                label: Text(m.label),
                selected: selected,
                onSelected: (_) => setState(() => _transportMode = m),
              );
            }).toList(),
          ),
          const SizedBox(height: DonySpacing.lg),
          Text(
            'Détails du colis',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: DonySpacing.md),
          TextFormField(
            controller: _weightCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Poids',
              suffixText: 'kg',
            ),
            validator: (v) {
              final d = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (d == null) return 'Valeur requise';
              if (d < 0.5 || d > 30) return 'Entre 0.5 et 30 kg';
              return null;
            },
          ),
          const SizedBox(height: DonySpacing.md),
          Text('Taille', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.sm,
            children: ParcelSize.values.map((s) {
              final selected = s == _size;
              return ChoiceChip(
                label: Text(s.name.toUpperCase()),
                selected: selected,
                onSelected: (_) => setState(() => _size = s),
              );
            }).toList(),
          ),
          const SizedBox(height: DonySpacing.md),
          Text('Catégorie', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: ContentCategory.values.map((cat) {
              final selected = cat == _category;
              return ChoiceChip(
                label: Text(cat.label),
                selected: selected,
                onSelected: (_) => setState(() => _category = cat),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo picker
          GestureDetector(
            onTap: _photoUploading
                ? null
                : () => showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_camera_rounded),
                              title: const Text('Prendre une photo'),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                _pickPhoto(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded),
                              title: const Text('Choisir dans la galerie'),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                _pickPhoto(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.outline),
                image: _photoFile != null
                    ? DecorationImage(
                        image: FileImage(_photoFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _photoUploading
                  ? Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    )
                  : _photoFile != null
                      ? null
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 36, color: cs.onSurfaceVariant),
                              const SizedBox(height: DonySpacing.xs),
                              Text(
                                'Ajouter une photo (optionnel)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          TextFormField(
            controller: _priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Budget cible (optionnel)',
              suffixText: '€',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final d = double.tryParse(v.replaceAll(',', '.'));
              if (d == null || d < 0 || d > 500) return 'Entre 0 et 500€';
              return null;
            },
          ),
          const SizedBox(height: DonySpacing.md),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            maxLength: 280,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              hintText: 'Ex : Cadeau pour ma mère, fragile',
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          TextFormField(
            controller: _pickupNeighCtrl,
            decoration: const InputDecoration(
              labelText: 'Quartier de pickup (optionnel)',
              hintText: 'Ex : 10e arrondissement',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          TextFormField(
            controller: _deliveryNeighCtrl,
            decoration: const InputDecoration(
              labelText: 'Quartier de livraison (optionnel)',
              hintText: 'Ex : Plateau',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
