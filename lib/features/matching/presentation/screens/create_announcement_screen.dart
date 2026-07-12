import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
const _priceOptions = [5.0, 6.0, 7.0, 8.0];

// ─── Screen ──────────────────────────────────────────────────────────────────

class CreateAnnouncementScreen extends StatefulWidget {
  final AnnouncementModel? announcement;
  const CreateAnnouncementScreen({super.key, this.announcement});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _departureCityNotifier = ValueNotifier<String?>(null);
  final _arrivalCityNotifier = ValueNotifier<String?>(null);
  // Code pays ISO-2 capturé lors de la sélection ville (null en édition d'une
  // annonce ancienne sans code — le backend retombe alors sur le nom de ville).
  final _departureCountryCodeNotifier = ValueNotifier<String?>(null);
  final _arrivalCountryCodeNotifier = ValueNotifier<String?>(null);
  final _departureDateNotifier = ValueNotifier<DateTime?>(null);
  final _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _handoverStartNotifier = ValueNotifier<DateTime?>(null);
  final _handoverEndNotifier = ValueNotifier<DateTime?>(null);
  AddressData? _pickupAddress;
  AddressData? _deliveryAddress;
  late final ValueNotifier<double> _availableKgNotifier;
  final _priceOptionNotifier = ValueNotifier<int>(1);
  final _transportModeNotifier = ValueNotifier<TransportMode?>(null);
  final _selectedContentNotifier = ValueNotifier<Set<String>>({
    'Vêtements & tissus',
    'Médicaments traditionnels',
    'Alimentation sèche',
    'Téléphone & électronique',
  });
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  // Catalogue de types de contenu — seedé synchrone avec le catalogue
  // embarqué (fallbackCatalog), puis remplacé par le catalogue live du
  // repository dès qu'il répond (repli automatique hors ligne intégré).
  final _catalogLabelsNotifier = ValueNotifier<List<String>>(
    fallbackCatalog.map((c) => c.label).toList(),
  );
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _cashEnabledNotifier = ValueNotifier<bool>(false);
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();

  bool get _isEdit => widget.announcement != null;
  double get _pricePerKg => _priceOptions[_priceOptionNotifier.value];

  @override
  void initState() {
    super.initState();
    // Initialize _availableKgNotifier from pref (clamped to slider bounds 1–23).
    // BusinessPrefsBloc est toujours enregistré en prod ; absent dans certains
    // widget tests isolés → on retombe sur la valeur par défaut DB (23 kg).
    final defaultKg = getIt.isRegistered<BusinessPrefsBloc>()
        ? getIt<BusinessPrefsBloc>().state.defaultPackageWeightKg
        : 23;
    _availableKgNotifier = ValueNotifier<double>(
      defaultKg.toDouble().clamp(1.0, 23.0),
    );
    unawaited(_loadCatalog());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
      }
    });
    if (_isEdit) {
      final a = widget.announcement!;
      _departureCityNotifier.value = a.departureCity;
      _arrivalCityNotifier.value = a.arrivalCity;
      _departureCountryCodeNotifier.value = a.departureCountryCode;
      _arrivalCountryCodeNotifier.value = a.arrivalCountryCode;
      _departureDateNotifier.value = a.departureDate;
      _handoverStartNotifier.value = widget.announcement?.handoverWindowStart;
      _handoverEndNotifier.value = widget.announcement?.handoverWindowEnd;
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
      _pickupAddress = a.pickupAddress;
      _deliveryAddress = a.deliveryAddress;
      _transportModeNotifier.value = a.transportMode;

      if (a.description != null) {
        _descriptionCtrl.text = a.description!;
      }

      if (a.acceptedContentTypes != null) {
        final presets = Set<String>.from(
          a.acceptedContentTypes!.where(_catalogLabelsNotifier.value.contains),
        );
        final custom = Set<String>.from(
          a.acceptedContentTypes!
              .where((t) => !_catalogLabelsNotifier.value.contains(t)),
        );
        _selectedContentNotifier.value = presets;
        _customAcceptedNotifier.value = custom;
      }
      if (a.refusedTypes != null) {
        _refusedTypesNotifier.value = Set<String>.from(a.refusedTypes!);
      }

      _cashEnabledNotifier.value =
          a.acceptedPaymentMethods.contains(BidPaymentMethod.cash);

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

  Future<void> _loadCatalog() async {
    final categories =
        await getIt<IContentCategoryRepository>().getCategories();
    if (!mounted) return;
    _catalogLabelsNotifier.value = categories.map((c) => c.label).toList();
  }

  @override
  void dispose() {
    _cashEnabledNotifier.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _departureCountryCodeNotifier.dispose();
    _arrivalCountryCodeNotifier.dispose();
    _departureDateNotifier.dispose();
    _departureTimeNotifier.dispose();
    _arrivalTimeNotifier.dispose();
    _handoverStartNotifier.dispose();
    _handoverEndNotifier.dispose();
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    _customAcceptedNotifier.dispose();
    _catalogLabelsNotifier.dispose();
    _refusedTypesNotifier.dispose();
    _transportModeNotifier.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatPrice(double p) =>
      p == p.roundToDouble() ? p.toInt().toString() : p.toString();

  void _applyTemplate(TripTemplate t) {
    _departureCityNotifier.value = t.departureCity;
    _arrivalCityNotifier.value = t.arrivalCity;
    _transportModeNotifier.value = transportModeFromWire(t.transportMode);
    _availableKgNotifier.value = t.availableKg.toDouble().clamp(1.0, 23.0);
    int closest = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < _priceOptions.length; i++) {
      final diff = (t.pricePerKg - _priceOptions[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    _priceOptionNotifier.value = closest;
    _selectedContentNotifier.value = t.acceptedCategories
        .where(_catalogLabelsNotifier.value.contains)
        .toSet();
    _customAcceptedNotifier.value = t.acceptedCategories
        .where((c) => !_catalogLabelsNotifier.value.contains(c))
        .toSet();
    DonySnackbar.show(
      context,
      message: 'Modèle « ${t.label} » appliqué',
      type: DonySnackbarType.success,
    );
  }

  Widget _buildTemplatesBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<TripTemplateBloc, TripTemplateState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DonyIcon('bookmark', size: 18, color: cs.primary),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text('Mes modèles',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final bloc = context.read<TripTemplateBloc>();
                      await context.push('/trip-templates');
                      if (context.mounted) {
                        bloc.add(const TripTemplateLoaded());
                      }
                    },
                    child: const Text('Gérer'),
                  ),
                ],
              ),
              if (state.templates.isEmpty)
                Text(
                  'Aucun modèle. Crée-en un pour publier en quelques secondes.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.templates.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: DonySpacing.sm),
                    itemBuilder: (context, i) {
                      final t = state.templates[i];
                      return ActionChip(
                        avatar: t.emoji != null
                            ? Text(t.emoji!)
                            : DonyIcon('bookmark',
                                size: 16, color: cs.primary),
                        label: Text('${t.label} · ${_formatPrice(t.pricePerKg)}€/kg'),
                        onPressed: () => _applyTemplate(t),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
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

    _formKey.currentState!.save();

    if (_pickupAddress == null) {
      _showError('Lieu de remise du colis obligatoire');
      return;
    }
    if (_deliveryAddress == null) {
      _showError('Lieu de récupération obligatoire');
      return;
    }
    if (_transportModeNotifier.value == null) {
      _showError('Mode de transport obligatoire');
      return;
    }

    final handoverStart = _handoverStartNotifier.value;
    final handoverEnd = _handoverEndNotifier.value;
    if (handoverStart == null || handoverEnd == null) {
      _showError('Fenêtre de remise obligatoire');
      return;
    }
    if (!handoverEnd.isAfter(handoverStart)) {
      _showError('La fin de la fenêtre doit être après le début');
      return;
    }
    final departureBound = departureTimeVal != null
        ? DateTime(departureDate.year, departureDate.month, departureDate.day,
            departureTimeVal.hour, departureTimeVal.minute)
        : DateTime(departureDate.year, departureDate.month, departureDate.day, 23, 59);
    if (handoverEnd.isAfter(departureBound)) {
      _showError('La fenêtre de remise doit se terminer avant le départ');
      return;
    }

    final departureTime =
        departureTimeVal != null ? _formatTime(departureTimeVal) : null;
    final arrivalTime =
        arrivalTimeVal != null ? _formatTime(arrivalTimeVal) : null;

    final allAccepted = {
      ..._selectedContentNotifier.value,
      ..._customAcceptedNotifier.value,
    }.toList();
    final refused = _refusedTypesNotifier.value.toList();
    final description = _descriptionCtrl.text.trim().isEmpty
        ? null
        : _descriptionCtrl.text.trim();

    final transportMode = _transportModeNotifier.value!;
    final paymentMethods = ['STRIPE', if (_cashEnabledNotifier.value) 'CASH'];

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
            id: widget.announcement!.id,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureCountryCode: _departureCountryCodeNotifier.value,
            arrivalCountryCode: _arrivalCountryCodeNotifier.value,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            pickupAddress: _pickupAddress!,
            deliveryAddress: _deliveryAddress!,
            availableKg: _availableKgNotifier.value,
            pricePerKg: _pricePerKg,
            transportMode: transportMode,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
            acceptedPaymentMethods: paymentMethods,
            handoverWindowStart: handoverStart,
            handoverWindowEnd: handoverEnd,
          ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureCountryCode: _departureCountryCodeNotifier.value,
            arrivalCountryCode: _arrivalCountryCodeNotifier.value,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            pickupAddress: _pickupAddress!,
            deliveryAddress: _deliveryAddress!,
            availableKg: _availableKgNotifier.value,
            pricePerKg: _pricePerKg,
            transportMode: transportMode,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
            acceptedPaymentMethods: paymentMethods,
            handoverWindowStart: handoverStart,
            handoverWindowEnd: handoverEnd,
          ));
    }
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  Future<void> _selectDate() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDateNotifier.value ??
          DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              ColorScheme.light(primary: cs.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureDateNotifier.value = picked;
    }
  }

  Future<void> _selectDepartureTime() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _departureTimeNotifier.value ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              ColorScheme.light(primary: cs.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _departureTimeNotifier.value = picked;
    }
  }

  Future<void> _selectArrivalTime() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _arrivalTimeNotifier.value ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              ColorScheme.light(primary: cs.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _arrivalTimeNotifier.value = picked;
    }
  }

  Future<DateTime?> _pickDateTime(
    DateTime? initial, {
    TimeOfDay defaultTime = const TimeOfDay(hour: 18, minute: 0),
  }) async {
    final cs = Theme.of(context).colorScheme;
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime:
          initial != null ? TimeOfDay.fromDateTime(initial) : defaultTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: cs.primary)),
        child: child!,
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _selectHandoverStart() async {
    // Défaut 16:00 : avec la fin par défaut à 18:00, accepter les deux propose
    // d'emblée une fenêtre de remise valide de 2 h.
    final picked = await _pickDateTime(_handoverStartNotifier.value,
        defaultTime: const TimeOfDay(hour: 16, minute: 0));
    if (picked != null) _handoverStartNotifier.value = picked;
  }

  Future<void> _selectHandoverEnd() async {
    final picked = await _pickDateTime(_handoverEndNotifier.value,
        defaultTime: const TimeOfDay(hour: 18, minute: 0));
    if (picked != null) _handoverEndNotifier.value = picked;
  }

  /// Raison pour laquelle la fenêtre de remise saisie est invalide, ou null si
  /// elle est correcte (ou pas encore renseignée). Affichée en direct sous le
  /// picker et utilisée pour bloquer la publication.
  String? _handoverWindowError() {
    final start = _handoverStartNotifier.value;
    final end = _handoverEndNotifier.value;
    if (start == null || end == null) return null;
    if (!end.isAfter(start)) {
      return 'La fin de la fenêtre doit être après le début.';
    }
    final date = _departureDateNotifier.value;
    if (date != null) {
      final t = _departureTimeNotifier.value;
      final bound = t != null
          ? DateTime(date.year, date.month, date.day, t.hour, t.minute)
          : DateTime(date.year, date.month, date.day, 23, 59);
      if (end.isAfter(bound)) {
        return t != null
            ? 'La fenêtre doit se terminer avant le départ (${_formatTime(t)}).'
            : 'La fenêtre doit se terminer le jour du départ au plus tard.';
      }
    }
    return null;
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
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) {
        if (state is AnnouncementCreated || state is AnnouncementUpdated) {
          DonySnackbar.show(
            context,
            message: _isEdit ? 'Trajet modifié !' : 'Trajet publié !',
            type: DonySnackbarType.success,
          );
          context.go('/announcements');
        } else if (state is AnnouncementProLimitReached) {
          DonyDialog.show(
            context,
            title: 'Limite mensuelle atteinte',
            message: state.message,
            confirmLabel: 'Passer en PRO',
            cancelLabel: 'Plus tard',
            variant: DonyDialogVariant.info,
          ).then((confirmed) {
            if (confirmed == true && context.mounted) {
              context.push('/profile/upgrade-to-pro');
            }
          });
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is AnnouncementLoading;

        return Form(
          key: _formKey,
          child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              tooltip: 'Fermer',
              onPressed: () => context.pop(),
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                ),
                child: DonyIcon('x', size: 20, color: cs.primary),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: cs.outline),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    DonyLayout.hPadding(context),
                    DonySpacing.xl,
                    DonyLayout.hPadding(context),
                    DonySpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                // ── Mes modèles (raccourci de pré-remplissage) ──────────────
                if (!_isEdit) _buildTemplatesBar(context),
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
                                        '$dep → $arr',
                                        style: tt.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (dateStr.isNotEmpty)
                                        Text(
                                          dateStr,
                                          style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
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
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                        DonyRadius.full),
                                  ),
                                  child: Text(
                                    'Confirmé',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.primary,
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
                // CityAutocompleteField gère lui-même le style de son champ
                // (CaFieldCard) et rend ses suggestions HORS de tout ClipRRect.
                // Ne pas entourer ces champs dans un _SectionCard (ClipRRect)
                // qui masquerait la liste de suggestions — fix B1.
                const _SectionLabel(label: 'TRAJET', iconAsset: 'plane-takeoff'),
                const SizedBox(height: DonySpacing.sm),
                Column(
                  children: [
                    BlocProvider(
                      create: (_) => getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        label: 'Ville de départ',
                        prefixIcon: DonyIcon(
                          'plane-takeoff',
                          color: cs.primary,
                          size: 20,
                        ),
                        initialValue: _departureCityNotifier.value,
                        onSelected: (CityModel city) {
                          _departureCityNotifier.value = city.name;
                          _departureCountryCodeNotifier.value = city.countryCode;
                        },
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    _SectionCard(
                      child: ValueListenableBuilder<TimeOfDay?>(
                        valueListenable: _departureTimeNotifier,
                        builder: (context, time, _) => _TimeRow(
                          isDeparture: true,
                          time: time,
                          onTap: _selectDepartureTime,
                          onClear: time != null
                              ? () => _departureTimeNotifier.value = null
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    BlocProvider(
                      create: (_) => getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        label: 'Ville d\'arrivée',
                        prefixIcon: const DonyIcon(
                          'plane-landing',
                          color: DonyColors.accent,
                          size: 20,
                        ),
                        initialValue: _arrivalCityNotifier.value,
                        onSelected: (CityModel city) {
                          _arrivalCityNotifier.value = city.name;
                          _arrivalCountryCodeNotifier.value = city.countryCode;
                        },
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    _SectionCard(
                      child: Column(
                        children: [
                          ValueListenableBuilder<TimeOfDay?>(
                            valueListenable: _arrivalTimeNotifier,
                            builder: (context, time, _) => _TimeRow(
                              isDeparture: false,
                              time: time,
                              onTap: _selectArrivalTime,
                              onClear: time != null
                                  ? () => _arrivalTimeNotifier.value = null
                                  : null,
                            ),
                          ),
                          const _RowDivider(),
                          ValueListenableBuilder<DateTime?>(
                            valueListenable: _departureDateNotifier,
                            builder: (context, date, _) => _DateRow(
                              date: date,
                              onTap: _selectDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: DonySpacing.xs,
                              left: DonySpacing.base,
                              top: DonySpacing.sm,
                            ),
                            child: Text('Fenêtre de remise du colis',
                                style: Theme.of(context).textTheme.labelMedium),
                          ),
                          ValueListenableBuilder<DateTime?>(
                            valueListenable: _handoverStartNotifier,
                            builder: (context, dt, _) => ListTile(
                              key: const Key('handover-start-row'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.base,
                              ),
                              leading: DonyIcon('clock', size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              title: const Text('Début'),
                              trailing: Text(dt != null
                                  ? DateFormat('dd/MM HH:mm', 'fr').format(dt) : 'Choisir'),
                              onTap: _selectHandoverStart,
                            ),
                          ),
                          const _RowDivider(),
                          ValueListenableBuilder<DateTime?>(
                            valueListenable: _handoverEndNotifier,
                            builder: (context, dt, _) => ListTile(
                              key: const Key('handover-end-row'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.base,
                              ),
                              leading: DonyIcon('clock', size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              title: const Text('Fin'),
                              trailing: Text(dt != null
                                  ? DateFormat('dd/MM HH:mm', 'fr').format(dt) : 'Choisir'),
                              onTap: _selectHandoverEnd,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _handoverStartNotifier,
                              _handoverEndNotifier,
                              _departureDateNotifier,
                              _departureTimeNotifier,
                            ]),
                            builder: (context, _) {
                              final err = _handoverWindowError();
                              if (err == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  DonySpacing.base,
                                  DonySpacing.xs,
                                  DonySpacing.base,
                                  DonySpacing.sm,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DonyIcon('circle-alert',
                                        size: 16,
                                        color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: DonySpacing.xs),
                                    Expanded(
                                      child: Text(
                                        err,
                                        key: const Key('handover-error'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── LIEUX DE REMISE ─────────────────────────────────────────
                const _SectionLabel(label: 'LIEUX DE REMISE', iconAsset: 'arrow-left-right'),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Précisez l\'endroit exact de remise et récupération',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),
                AddressPickerField(
                  fieldLabel: 'Lieu de remise du colis *',
                  isRequired: true,
                  initialValue: widget.announcement?.pickupAddress,
                  onSaved: (v) => _pickupAddress = v,
                  autocompleteService: getIt<AddressAutocompleteService>(),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 16),
                AddressPickerField(
                  fieldLabel: 'Lieu de récupération *',
                  isRequired: true,
                  showGpsButton: false,
                  initialValue: widget.announcement?.deliveryAddress,
                  onSaved: (v) => _deliveryAddress = v,
                  autocompleteService: getIt<AddressAutocompleteService>(),
                ).animate().fadeIn(delay: 90.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CAPACITÉ DISPONIBLE ─────────────────────────────────────
                const _SectionLabel(label: 'CAPACITÉ DISPONIBLE', iconAsset: 'luggage'),
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
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              ' kg',
                              style: tt.headlineMedium?.copyWith(
                                color: cs.onSurfaceVariant,
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
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                        DonyRadius.full),
                                  ),
                                  child: Text(
                                    'VALISE',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
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
                            activeTrackColor: cs.primary,
                            inactiveTrackColor: cs.outline,
                            thumbColor: cs.primary,
                            overlayColor:
                                cs.primary.withValues(alpha: 0.1),
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
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            Text('max 23 kg',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.xxl),

                // ── PRIX PAR KG ─────────────────────────────────────────────
                const _SectionLabel(label: 'PRIX PAR KG', iconAsset: 'tag'),
                const SizedBox(height: DonySpacing.md),
                ValueListenableBuilder<int>(
                  valueListenable: _priceOptionNotifier,
                  builder: (context, selectedIdx, _) {
                    final kg = _availableKgNotifier.value;
                    final pricePerKg = _priceOptions[selectedIdx];
                    final travelerNet = kg * pricePerKg;
                    final senderTotal = netToSenderPrice(travelerNet);

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
                                          ? cs.successLight
                                          : cs.surface,
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.lg),
                                      border: Border.all(
                                        color: selected
                                            ? cs.success
                                            : cs.outline,
                                        width: selected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_priceOptions[i].toStringAsFixed(0)}€',
                                        style: tt.titleMedium?.copyWith(
                                          color: selected
                                              ? cs.success
                                              : cs.onSurface,
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
                          'Vous touchez ${travelerNet.toStringAsFixed(0)}€ · l\'expéditeur paie ${senderTotal.toStringAsFixed(0)}€',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    );
                  },
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── MODE DE TRANSPORT ───────────────────────────────────────
                const _SectionLabel(
                  label: 'MODE DE TRANSPORT',
                  iconAsset: 'route',
                ),
                const SizedBox(height: DonySpacing.sm),
                ValueListenableBuilder<TransportMode?>(
                  valueListenable: _transportModeNotifier,
                  builder: (context, current, _) {
                    return Wrap(
                      spacing: DonySpacing.sm,
                      runSpacing: DonySpacing.sm,
                      children: [
                        for (final mode in TransportMode.values)
                          DonyChip(
                            key: Key('transport-chip-${mode.name}'),
                            label: mode.label,
                            icon: mode.icon,
                            selected: current == mode,
                            onTap: () => _transportModeNotifier.value = mode,
                          ),
                      ],
                    );
                  },
                ).animate().fadeIn(delay: 110.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── CE QUE J'ACCEPTE ────────────────────────────────────────
                const _SectionLabel(label: 'CE QUE J\'ACCEPTE', iconAsset: 'circle-check'),
                const SizedBox(height: DonySpacing.sm),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _selectedContentNotifier,
                    _customAcceptedNotifier,
                    _catalogLabelsNotifier,
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
                              children: _catalogLabelsNotifier.value.map((type) {
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
                                          ? cs.success
                                          : Theme.of(context).scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(
                                          DonyRadius.full),
                                      border: Border.all(
                                        color: isSelected
                                            ? cs.success
                                            : cs.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const DonyIcon('check',
                                              size: 12,
                                              color: DonyColors.white),
                                          const SizedBox(width: DonySpacing.xs),
                                        ],
                                        Text(
                                          type,
                                          style: tt.bodySmall?.copyWith(
                                            color: isSelected
                                                ? DonyColors.white
                                                : cs.onSurface,
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
                                  accentColor: cs.success,
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
                const _SectionLabel(label: 'CE QUE JE REFUSE', iconAsset: 'ban'),
                const SizedBox(height: DonySpacing.sm),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _refusedTypesNotifier,
                    _catalogLabelsNotifier,
                  ]),
                  builder: (context, _) {
                    final refused = _refusedTypesNotifier.value;
                    final catalogLabels = _catalogLabelsNotifier.value;
                    final catalogLabelSet = catalogLabels.toSet();
                    final customRefused = refused
                        .where((r) => !catalogLabelSet.contains(r))
                        .toList();

                    return _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Predefined chips (catalogue complet, à cocher).
                          Padding(
                            padding: const EdgeInsets.all(DonySpacing.base),
                            child: Wrap(
                              spacing: DonySpacing.xs,
                              runSpacing: DonySpacing.xs,
                              children: catalogLabels.map((type) {
                                final isSelected = refused.contains(type);
                                return GestureDetector(
                                  onTap: () {
                                    final updated = Set<String>.from(refused);
                                    if (isSelected) {
                                      updated.remove(type);
                                    } else {
                                      updated.add(type);
                                    }
                                    _refusedTypesNotifier.value = updated;
                                  },
                                  child: AnimatedContainer(
                                    duration: 160.ms,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.md,
                                      vertical: DonySpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? cs.error
                                          : Theme.of(context)
                                              .scaffoldBackgroundColor,
                                      borderRadius:
                                          BorderRadius.circular(DonyRadius.full),
                                      border: Border.all(
                                        color: isSelected ? cs.error : cs.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const DonyIcon('ban',
                                              size: 12, color: DonyColors.white),
                                          const SizedBox(width: DonySpacing.xs),
                                        ],
                                        Text(
                                          type,
                                          style: tt.bodySmall?.copyWith(
                                            color: isSelected
                                                ? DonyColors.white
                                                : cs.onSurface,
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
                          const _RowDivider(),
                          _InlineAddRow(
                            controller: _refusedCtrl,
                            hint: 'Ex: Liquides, Denrées périssables…',
                            accentColor: cs.error,
                            onAdd: () {
                              final val = _refusedCtrl.text.trim();
                              if (val.isEmpty) {
                                return;
                              }
                              _refusedTypesNotifier.value = {...refused, val};
                              _refusedCtrl.clear();
                            },
                          ),
                          if (customRefused.isNotEmpty) ...[
                            const _RowDivider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DonySpacing.base,
                                vertical: DonySpacing.sm,
                              ),
                              child: Wrap(
                                spacing: DonySpacing.xs,
                                runSpacing: DonySpacing.xs,
                                children: customRefused.map((item) => _RemovableChip(
                                  label: item,
                                  accentColor: cs.error,
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
                const _SectionLabel(label: 'NOTE AUX EXPÉDITEURS', iconAsset: 'notebook-pen'),
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
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurface),
                              decoration: InputDecoration(
                                hintText:
                                    'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.',
                                hintStyle: tt.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
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
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 160.ms),
                const SizedBox(height: DonySpacing.xxl),

                // ── MODES DE PAIEMENT ACCEPTÉS ───────────────────────────────
                const _SectionLabel(
                  label: 'MODES DE PAIEMENT ACCEPTÉS',
                  iconAsset: 'banknote',
                ),
                const SizedBox(height: DonySpacing.sm),
                // La carte de commission n'est plus requise à la création d'annonce.
                // La vérification (wallet ou carte) est reportée à l'acceptation du bid.
                _SectionCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('payment-method-stripe'),
                        value: true,
                        onChanged: null,
                        activeColor: cs.primary,
                        title: Row(
                          children: [
                            const DonyIcon('credit-card', size: 18),
                            const SizedBox(width: DonySpacing.sm),
                            Text(
                              'Carte bancaire (Stripe)',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Paiement sécurisé par défaut',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.base,
                          vertical: DonySpacing.xs,
                        ),
                      ),
                      const _RowDivider(),
                      ValueListenableBuilder<bool>(
                        valueListenable: _cashEnabledNotifier,
                        builder: (context, cashEnabled, _) {
                          return Column(
                            children: [
                              SwitchListTile(
                                key: const Key('payment-method-cash'),
                                value: cashEnabled,
                                onChanged: (val) =>
                                    _cashEnabledNotifier.value = val,
                                activeColor: cs.primary,
                                title: Row(
                                  children: [
                                    const DonyIcon('banknote',
                                        size: 18),
                                    const SizedBox(width: DonySpacing.sm),
                                    Text(
                                      'Espèces',
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Commission prélevée au voyageur à la remise',
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.base,
                                  vertical: DonySpacing.xs,
                                ),
                              ),
                              AnimatedSize(
                                duration: 200.ms,
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: cashEnabled
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          DonySpacing.base,
                                          0,
                                          DonySpacing.base,
                                          DonySpacing.md,
                                        ),
                                        child: const CashCommissionNotice()
                                            .animate()
                                            .fadeIn(duration: 200.ms),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 180.ms),
              ],
            ),
          ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  DonyLayout.hPadding(context),
                  DonySpacing.base,
                  DonyLayout.hPadding(context),
                  MediaQuery.of(context).padding.bottom + DonySpacing.base,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                      top: BorderSide(color: cs.outline)),
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _transportModeNotifier,
                    _handoverStartNotifier,
                    _handoverEndNotifier,
                    _departureDateNotifier,
                    _departureTimeNotifier,
                  ]),
                  builder: (context, _) {
                    final canSubmit = !isLoading &&
                        _transportModeNotifier.value != null &&
                        _handoverWindowError() == null;
                    return DonyButton(
                      key: const Key('create-announcement-submit'),
                      label: _isEdit
                          ? 'Enregistrer les modifications'
                          : 'Publier le trajet',
                      onPressed: canSubmit ? _submit : null,
                      isLoading: isLoading,
                    );
                  },
                ),
              ),
            ],
          ),
        ));
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
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        color: cs.surface,
        // Material ancestor so the section's ListTiles paint ink above the
        // colored Container (Flutter 3.44 ListTile-in-ColoredBox assertion).
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

// ─── Thin row divider ─────────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(height: 0.5, color: cs.outline);
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? iconAsset;
  const _SectionLabel({required this.label, this.icon, this.iconAsset});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final labelWidget = Text(
      label,
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
    if (icon == null && iconAsset == null) return labelWidget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconAsset != null
            ? DonyIcon(iconAsset!, size: 13, color: cs.onSurfaceVariant)
            : Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        labelWidget,
      ],
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
    final cs = Theme.of(context).colorScheme;
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
                  tt.bodyMedium?.copyWith(color: cs.onSurface),
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
              child: const DonyIcon('plus',
                  size: 18, color: DonyColors.white),
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
            child: DonyIcon('x', size: 14, color: accentColor),
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final color = isDeparture ? cs.primary : DonyColors.accent;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            DonyIcon('clock',
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
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            if (time != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: DonyIcon('x',
                    size: 16, color: cs.onSurfaceVariant),
              )
            else
              DonyIcon('chevron-right',
                  size: 18, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        child: Row(
          children: [
            DonyIcon('calendar',
                size: 14, color: cs.onSurfaceVariant),
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
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            DonyIcon('chevron-right',
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

