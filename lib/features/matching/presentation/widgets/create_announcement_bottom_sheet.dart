import 'package:dony/core/constants/city_airport_codes.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/address_autocomplete_service.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/connect_onboarding/bloc/connect_onboarding_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:dony/features/matching/presentation/widgets/address_picker_field.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/capacity_selector.dart';
import 'package:dony/features/matching/presentation/widgets/price_hint_widget.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart' show NegotiationThreadStatus;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

// ─── Public entry point ───────────────────────────────────────────────────────

class CreateAnnouncementBottomSheet {
  static Future<void> show(
    BuildContext context, {
    AnnouncementModel? announcement,
    LockedTripContext? lockContext,
    NegotiationBloc? negotiationBloc,
  }) {
    assert(lockContext == null || negotiationBloc != null,
        'lockContext requires a negotiationBloc to dispatch the dedicated-trip event');
    final canSubmitNotifier =
        ValueNotifier<bool>(announcement?.transportMode != null || lockContext != null);
    final currentStepNotifier = ValueNotifier<int>(0);
    final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
    VoidCallback? submit;
    final isLocked = lockContext != null;
    return DonyBottomSheet.show(
      context,
      title: isLocked
          ? 'Créer le trajet pour cette demande'
          : (announcement != null ? 'Modifier le trajet' : 'Publier un trajet'),
      wrapper: (child) {
        final providers = <BlocProvider>[
          BlocProvider<AnnouncementBloc>(create: (_) => getIt<AnnouncementBloc>()),
          BlocProvider<CommissionMethodBloc>(create: (_) => getIt<CommissionMethodBloc>()),
          BlocProvider<ConnectOnboardingBloc>(create: (_) => getIt<ConnectOnboardingBloc>()),
          BlocProvider<AnnouncementFormBloc>(create: (_) => AnnouncementFormBloc()),
          if (negotiationBloc != null)
            BlocProvider<NegotiationBloc>.value(value: negotiationBloc),
        ];
        return MultiBlocProvider(providers: providers, child: child);
      },
      stickyBottom: isLocked
          ? ValueListenableBuilder<bool>(
              valueListenable: canSubmitNotifier,
              builder: (ctx, canSubmit, _) {
                return BlocBuilder<NegotiationBloc, NegotiationState>(
                  builder: (ctx, state) {
                    final isLoading = state is NegotiationLoading
                        || state is NegotiationActionInProgress;
                    return DonyButton(
                      key: const Key('create-dedicated-trip-submit'),
                      label: 'Confirmer le trajet',
                      isLoading: isLoading,
                      onPressed: (canSubmit && !isLoading) ? () => submit?.call() : null,
                    );
                  },
                );
              },
            )
          : ListenableBuilder(
              listenable: Listenable.merge([canSubmitNotifier, currentStepNotifier]),
              builder: (ctx, _) {
                final step = currentStepNotifier.value;
                final canSubmit = canSubmitNotifier.value;

                if (step < 2) {
                  return Row(
                    children: [
                      if (step > 0) ...[
                        Expanded(
                          child: DonyButton(
                            label: '← Retour',
                            variant: DonyButtonVariant.secondary,
                            onPressed: () => currentStepNotifier.value = step - 1,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                      ],
                      Expanded(
                        child: DonyButton(
                          label: 'Continuer →',
                          onPressed: () => currentStepNotifier.value = step + 1,
                        ),
                      ),
                    ],
                  );
                }

                // Étape 3 — Enregistrer (mode edit) ou Aperçu (mode création)
                if (announcement != null) {
                  return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                    builder: (ctx, state) {
                      final isLoading = state is AnnouncementLoading;
                      return Row(
                        children: [
                          Expanded(
                            child: DonyButton(
                              label: '← Retour',
                              variant: DonyButtonVariant.secondary,
                              onPressed: () => currentStepNotifier.value = step - 1,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Expanded(
                            child: DonyButton(
                              key: const Key('create-announcement-submit'),
                              label: 'Enregistrer',
                              isLoading: isLoading,
                              onPressed: (canSubmit && !isLoading) ? () => submit?.call() : null,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                return BlocBuilder<AnnouncementBloc, AnnouncementState>(
                  builder: (ctx, state) {
                    final isLoading = state is AnnouncementLoading;
                    return BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
                      builder: (ctx3, connectState) {
                        final isStripeConfigured = connectState is ConnectOnboardingComplete ||
                            connectState is ConnectOnboardingPending;
                        final isConnectLoading = connectState is ConnectOnboardingInitial ||
                            connectState is ConnectOnboardingLoading;

                        if (!isStripeConfigured && !isConnectLoading) {
                          return Row(
                            children: [
                              Expanded(
                                child: DonyButton(
                                  label: '← Retour',
                                  variant: DonyButtonVariant.secondary,
                                  onPressed: () => currentStepNotifier.value = step - 1,
                                ),
                              ),
                              const SizedBox(width: DonySpacing.sm),
                              Expanded(
                                child: DonyButton(
                                  key: const Key('configure-stripe-btn'),
                                  label: 'Configurer Stripe',
                                  onPressed: () => ctx3.push('/connect/onboarding/intro'),
                                ),
                              ),
                            ],
                          );
                        }

                        return BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
                          builder: (ctx2, formState) {
                            return Row(
                              children: [
                                Expanded(
                                  child: DonyButton(
                                    label: '← Retour',
                                    variant: DonyButtonVariant.secondary,
                                    onPressed: () => currentStepNotifier.value = step - 1,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: DonyButton(
                                    key: const Key('create-announcement-preview'),
                                    label: 'Aperçu →',
                                    isLoading: isLoading || isConnectLoading,
                                    onPressed: (canSubmit && !isLoading && !isConnectLoading)
                                        ? () {
                                            AnnouncementPreviewSheet.show(
                                              ctx2,
                                              formState: ctx2
                                                  .read<AnnouncementFormBloc>()
                                                  .state,
                                              onConfirm: () {
                                                Navigator.of(ctx2, rootNavigator: true).pop();
                                                submit?.call();
                                              },
                                              isSubmitting: isLoading,
                                              departureTime: departureTimeNotifier.value,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
      child: _CreateAnnouncementContent(
        announcement: announcement,
        lockContext: lockContext,
        canSubmitNotifier: canSubmitNotifier,
        currentStepNotifier: currentStepNotifier,
        departureTimeNotifier: departureTimeNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(() {
      canSubmitNotifier.dispose();
      currentStepNotifier.dispose();
      departureTimeNotifier.dispose();
    });
  }
}

// ─── Content widget ───────────────────────────────────────────────────────────

class _CreateAnnouncementContent extends StatefulWidget {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;
  final ValueNotifier<bool>? canSubmitNotifier;
  final ValueNotifier<int>? currentStepNotifier;
  final ValueNotifier<TimeOfDay?>? departureTimeNotifier;
  final void Function(VoidCallback)? onSubmitReady;
  const _CreateAnnouncementContent({
    this.announcement,
    this.lockContext,
    this.canSubmitNotifier,
    this.currentStepNotifier,
    this.departureTimeNotifier,
    this.onSubmitReady,
  });

  @override
  State<_CreateAnnouncementContent> createState() =>
      _CreateAnnouncementContentState();
}

class _CreateAnnouncementContentState
    extends State<_CreateAnnouncementContent> {
  final _formKey = GlobalKey<FormState>();
  final _departureCityNotifier = ValueNotifier<String?>(null);
  final _arrivalCityNotifier = ValueNotifier<String?>(null);
  final _departureDateNotifier = ValueNotifier<DateTime?>(null);
  final _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  AddressData? _pickupAddress;
  AddressData? _deliveryAddress;
  final _availableKgNotifier = ValueNotifier<double>(15);
  final _priceOptionNotifier = ValueNotifier<int>(1);
  final _transportModeNotifier = ValueNotifier<TransportMode?>(null);
  final _selectedContentNotifier = ValueNotifier<Set<String>>(
    {'Vêtements', 'Médicaments', 'Documents'},
  );
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _cashEnabledNotifier = ValueNotifier<bool>(false);
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customPriceNotifier = ValueNotifier<double>(6.0);

  bool get _isEdit => widget.announcement != null;
  bool get _isLocked => widget.lockContext != null;
  bool get _isCustomPrice => _priceOptionNotifier.value == _priceOptions.length;
  double get _pricePerKg => _isCustomPrice
      ? _customPriceNotifier.value
      : _priceOptions[_priceOptionNotifier.value.clamp(0, _priceOptions.length - 1)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
        context.read<ConnectOnboardingBloc>().add(const ConnectOnboardingStatusRequested());
      }
    });
    if (_isLocked) {
      final ctx = widget.lockContext!;
      _departureCityNotifier.value = ctx.departureCity;
      _arrivalCityNotifier.value = ctx.arrivalCity;
      _departureDateNotifier.value = ctx.desiredDate;
      _availableKgNotifier.value = ctx.weightKg;
      _transportModeNotifier.value = ctx.transportMode;
    }
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
      _pickupAddress = a.pickupAddress;
      _deliveryAddress = a.deliveryAddress;
      _transportModeNotifier.value = a.transportMode;

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

      _cashEnabledNotifier.value =
          a.acceptedPaymentMethods.contains(BidPaymentMethod.cash);

      final price = a.pricePerKg;
      final presetIdx = _priceOptions.indexOf(price);
      if (presetIdx != -1) {
        _priceOptionNotifier.value = presetIdx;
      } else {
        // Prix custom — sélectionner "Autre" et pré-remplir le champ
        _priceOptionNotifier.value = _priceOptions.length;
        _customPriceNotifier.value = price;
        _customPriceCtrl.text = price.toStringAsFixed(0);
      }
    }
    widget.onSubmitReady?.call(_submit);
    _transportModeNotifier.addListener(_syncCanSubmit);
    // Avion sélectionné par défaut en mode création
    if (!_isEdit && !_isLocked) {
      _transportModeNotifier.value = TransportMode.plane;
      widget.canSubmitNotifier?.value = true;
    } else {
      widget.canSubmitNotifier?.value = _transportModeNotifier.value != null;
    }

    // Sync form fields to AnnouncementFormBloc for preview and validation
    _departureCityNotifier.addListener(_syncCityToFormBloc);
    _arrivalCityNotifier.addListener(_syncCityToFormBloc);
    _departureDateNotifier.addListener(_syncDateToFormBloc);
    _priceOptionNotifier.addListener(_syncPriceToFormBloc);
    _customPriceNotifier.addListener(_syncPriceToFormBloc);
    _availableKgNotifier.addListener(_syncKgToFormBloc);
    _descriptionCtrl.addListener(_syncDescriptionToFormBloc);
    _transportModeNotifier.addListener(_syncTransportModeToFormBloc);
    _cashEnabledNotifier.addListener(_syncCashAcceptedToFormBloc);
    _selectedContentNotifier.addListener(_syncAcceptedTypesToFormBloc);
    _customAcceptedNotifier.addListener(_syncAcceptedTypesToFormBloc);
    _refusedTypesNotifier.addListener(_syncRejectedTypesToFormBloc);
    _departureTimeNotifier.addListener(_syncDepartureTimeToParent);
  }

  void _syncCanSubmit() {
    widget.canSubmitNotifier?.value = _transportModeNotifier.value != null;
  }

  void _syncCityToFormBloc() {
    if (!mounted) return;
    final formBloc = context.read<AnnouncementFormBloc>();
    if (_departureCityNotifier.value != null) {
      formBloc.add(DepartureCityChanged(_departureCityNotifier.value!));
    }
    if (_arrivalCityNotifier.value != null) {
      formBloc.add(ArrivalCityChanged(_arrivalCityNotifier.value!));
    }
  }

  void _syncDateToFormBloc() {
    if (!mounted) return;
    if (_departureDateNotifier.value != null) {
      context
          .read<AnnouncementFormBloc>()
          .add(DepartureDateChanged(_departureDateNotifier.value!));
    }
  }

  void _syncPriceToFormBloc() {
    if (!mounted) return;
    context
        .read<AnnouncementFormBloc>()
        .add(PriceChanged(_pricePerKg));
  }

  void _syncKgToFormBloc() {
    if (!mounted) return;
    context
        .read<AnnouncementFormBloc>()
        .add(AvailableKgChanged(_availableKgNotifier.value));
  }

  void _syncDescriptionToFormBloc() {
    if (!mounted) return;
    final desc = _descriptionCtrl.text.trim();
    if (desc.isNotEmpty) {
      context.read<AnnouncementFormBloc>().add(DescriptionChanged(desc));
    }
  }

  void _syncTransportModeToFormBloc() {
    if (!mounted) return;
    final mode = _transportModeNotifier.value;
    if (mode != null) {
      context.read<AnnouncementFormBloc>().add(TransportModeChanged(mode));
    }
  }

  void _syncCashAcceptedToFormBloc() {
    if (!mounted) return;
    context
        .read<AnnouncementFormBloc>()
        .add(CashAcceptedChanged(_cashEnabledNotifier.value));
  }

  void _syncAcceptedTypesToFormBloc() {
    if (!mounted) return;
    final all = {
      ..._selectedContentNotifier.value,
      ..._customAcceptedNotifier.value,
    }.toList();
    context.read<AnnouncementFormBloc>().add(AcceptedTypesChanged(all));
  }

  void _syncDepartureTimeToParent() {
    widget.departureTimeNotifier?.value = _departureTimeNotifier.value;
  }

  void _syncRejectedTypesToFormBloc() {
    if (!mounted) return;
    context
        .read<AnnouncementFormBloc>()
        .add(RejectedTypesChanged(_refusedTypesNotifier.value.toList()));
  }

  @override
  void dispose() {
    _departureCityNotifier.removeListener(_syncCityToFormBloc);
    _arrivalCityNotifier.removeListener(_syncCityToFormBloc);
    _departureDateNotifier.removeListener(_syncDateToFormBloc);
    _priceOptionNotifier.removeListener(_syncPriceToFormBloc);
    _customPriceNotifier.removeListener(_syncPriceToFormBloc);
    _availableKgNotifier.removeListener(_syncKgToFormBloc);
    _descriptionCtrl.removeListener(_syncDescriptionToFormBloc);
    _transportModeNotifier.removeListener(_syncCanSubmit);
    _transportModeNotifier.removeListener(_syncTransportModeToFormBloc);
    _cashEnabledNotifier.removeListener(_syncCashAcceptedToFormBloc);
    _selectedContentNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _customAcceptedNotifier.removeListener(_syncAcceptedTypesToFormBloc);
    _refusedTypesNotifier.removeListener(_syncRejectedTypesToFormBloc);
    _departureTimeNotifier.removeListener(_syncDepartureTimeToParent);
    _cashEnabledNotifier.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _customPriceCtrl.dispose();
    _customPriceNotifier.dispose();
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
    _transportModeNotifier.dispose();
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

    if (_isLocked) {
      final lc = widget.lockContext!;
      context.read<NegotiationBloc>().add(NegotiationCreateDedicatedTripRequested(
            threadId: lc.threadId,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            pickupAddress: {
              'label': _pickupAddress!.label,
              'lat': _pickupAddress!.lat,
              'lng': _pickupAddress!.lng,
            },
            deliveryAddress: {
              'label': _deliveryAddress!.label,
              'lat': _deliveryAddress!.lat,
              'lng': _deliveryAddress!.lng,
            },
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
          ));
      return;
    }

    final paymentMethods = ['STRIPE', if (_cashEnabledNotifier.value) 'CASH'];

    final capacityUnitWire =
        context.read<AnnouncementFormBloc>().state.capacityUnit.toWire();

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
            id: widget.announcement!.id,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
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
            capacityUnit: capacityUnitWire,
          ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
            departureCity: departureCity,
            arrivalCity: arrivalCity,
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
            capacityUnit: capacityUnitWire,
          ));
    }
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  Future<void> _selectDate() async {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    DateTime firstDate = today;
    DateTime lastDate = today.add(const Duration(days: 365));
    if (_isLocked) {
      final lc = widget.lockContext!;
      // Clamp to today as floor — backend rejects past dates regardless of tolerance.
      firstDate = lc.earliestDate.isBefore(today) ? today : lc.earliestDate;
      lastDate = lc.latestDate;
    }
    final initial = _departureDateNotifier.value ??
        (_isLocked ? widget.lockContext!.desiredDate : today.add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
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
    final formChild = _buildForm(context);
    if (_isLocked) {
      return BlocListener<NegotiationBloc, NegotiationState>(
        listener: (context, state) {
          if (state is NegotiationLoaded
              && state.thread.status == NegotiationThreadStatus.awaitingPayment) {
            Navigator.of(context, rootNavigator: true).pop();
            DonySnackbar.show(context,
                message: 'Trajet lié — l\'expéditeur peut désormais payer.',
                type: DonySnackbarType.success);
          } else if (state is NegotiationError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        child: formChild,
      );
    }

    return BlocConsumer<AnnouncementBloc, AnnouncementState>(
      listener: (context, state) async {
        if (state is AnnouncementCreated || state is AnnouncementUpdated) {
          Navigator.of(context, rootNavigator: true).pop();
          if (context.mounted) context.go('/announcements');
        } else if (state is AnnouncementProLimitReached) {
          Navigator.of(context, rootNavigator: true).pop();
          if (context.mounted) {
            final confirmed = await DonyDialog.show(
              context,
              title: 'Limite mensuelle atteinte',
              message: state.message,
              confirmLabel: 'Passer en PRO',
              cancelLabel: 'Plus tard',
              variant: DonyDialogVariant.info,
            );
            if (confirmed == true && context.mounted) {
              context.push('/profile/upgrade-to-pro');
            }
          }
        } else if (state is AnnouncementError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) => formChild,
    );
  }

  // ── Step 0 — Trajet + Transport ─────────────────────────────────────────────
  List<Widget> _buildStep0(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      // ── Corridor preview ──────────────────────────────────────────────────
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                          borderRadius: BorderRadius.circular(DonyRadius.full),
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

      // ── TRAJET ────────────────────────────────────────────────────────────
      const _SectionLabel(label: 'TRAJET', icon: Icons.flight_takeoff_rounded),
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
          return Column(
            children: [
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: _FieldCard(
                  child: CityAutocompleteField(
                    label: 'Ville de départ',
                    initialValue: _departureCityNotifier.value,
                    prefixIcon: const _FieldIcon(icon: Icons.flight_takeoff_rounded),
                    onSelected: (CityModel city) {
                      _departureCityNotifier.value = city.name;
                    },
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              _TimeRow(
                isDeparture: true,
                time: _departureTimeNotifier.value,
                onTap: _selectDepartureTime,
                onClear: _departureTimeNotifier.value != null
                    ? () => _departureTimeNotifier.value = null
                    : null,
              ),
              const SizedBox(height: DonySpacing.sm),
              BlocProvider(
                create: (_) => getIt<CitySearchBloc>(),
                child: _FieldCard(
                  child: CityAutocompleteField(
                    label: 'Ville d\'arrivée',
                    initialValue: _arrivalCityNotifier.value,
                    prefixIcon: const _FieldIcon(icon: Icons.flight_land_rounded),
                    onSelected: (CityModel city) {
                      _arrivalCityNotifier.value = city.name;
                    },
                  ),
                ),
              ),
              const SizedBox(height: DonySpacing.sm),
              _TimeRow(
                isDeparture: false,
                time: _arrivalTimeNotifier.value,
                onTap: _selectArrivalTime,
                onClear: _arrivalTimeNotifier.value != null
                    ? () => _arrivalTimeNotifier.value = null
                    : null,
              ),
              const SizedBox(height: DonySpacing.sm),
              _DateRow(
                date: _departureDateNotifier.value,
                onTap: _selectDate,
              ),
            ],
          ).animate().fadeIn(delay: 60.ms);
        },
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODE DE TRANSPORT ─────────────────────────────────────────────────
      const _SectionLabel(
        label: 'MODE DE TRANSPORT',
        icon: Icons.commute_rounded,
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
                Opacity(
                  opacity: mode != TransportMode.plane ? 0.4 : 1.0,
                  child: DonyChip(
                    key: Key('transport-chip-${mode.name}'),
                    label: mode.label,
                    icon: mode.icon,
                    selected: current == mode,
                    onTap: mode == TransportMode.plane
                        ? () => _transportModeNotifier.value = mode
                        : () {
                            DonySnackbar.show(
                              context,
                              message: 'Bientôt disponible',
                              type: DonySnackbarType.info,
                            );
                          },
                  ),
                ),
            ],
          );
        },
      ).animate().fadeIn(delay: 110.ms),
      const SizedBox(height: DonySpacing.xxl),
    ];
  }

  // ── Step 1 — Lieux & Capacité ────────────────────────────────────────────────
  List<Widget> _buildStep1(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      // ── LIEUX DE REMISE ───────────────────────────────────────────────────
      const _SectionLabel(label: 'LIEUX DE REMISE', icon: Icons.swap_horiz_rounded),
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
        onChanged: (addr) {
          _pickupAddress = addr;
          if (!mounted) return;
          context
              .read<AnnouncementFormBloc>()
              .add(PickupAddressChanged(addr));
        },
        autocompleteService: getIt<AddressAutocompleteService>(),
      ).animate().fadeIn(delay: 80.ms),
      const SizedBox(height: 16),
      AddressPickerField(
        fieldLabel: 'Lieu de récupération *',
        isRequired: true,
        showGpsButton: false,
        initialValue: widget.announcement?.deliveryAddress,
        onSaved: (v) => _deliveryAddress = v,
        onChanged: (addr) {
          _deliveryAddress = addr;
          if (!mounted) return;
          context
              .read<AnnouncementFormBloc>()
              .add(DeliveryAddressChanged(addr));
        },
        autocompleteService: getIt<AddressAutocompleteService>(),
      ).animate().fadeIn(delay: 90.ms),
      const SizedBox(height: DonySpacing.xxl),

      // ── CAPACITÉ DISPONIBLE ───────────────────────────────────────────────
      const _SectionLabel(label: 'CAPACITÉ DISPONIBLE', icon: Icons.luggage_rounded),
      const SizedBox(height: DonySpacing.base),
      const CapacitySelector(),
      const SizedBox(height: DonySpacing.md),
      BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
        buildWhen: (prev, curr) => prev.capacityUnit != curr.capacityUnit,
        builder: (ctx, formState) {
          final unit = formState.capacityUnit;
          if (unit == CapacityUnit.kgFree) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildKgFreeDisplay(tt, cs),
            );
          }
          final maxKg = unit.maxKg ?? 23.0;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: ValueListenableBuilder<double>(
              key: ValueKey(unit),
              valueListenable: _availableKgNotifier,
              builder: (ctx2, kg, _) {
                final clamped = kg.clamp(1.0, maxKg);
                if (clamped != kg) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _availableKgNotifier.value = clamped;
                  });
                }
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Expanded(child: SizedBox()),
                        Text(
                          clamped.toStringAsFixed(0),
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
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.full),
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
                        overlayColor: cs.primary.withValues(alpha: 0.1),
                        trackHeight: 5,
                      ),
                      child: Slider(
                        value: clamped,
                        min: 1,
                        max: maxKg,
                        divisions: (maxKg - 1).toInt(),
                        onChanged: (v) => _availableKgNotifier.value = v,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 kg',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        Text('max ${maxKg.toStringAsFixed(0)} kg',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      const SizedBox(height: DonySpacing.xxl),
    ];
  }

  Widget _buildKgFreeDisplay(TextTheme tt, ColorScheme cs) {
    return Container(
      key: const ValueKey('kg-free'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.lg),
      child: Column(
        children: [
          Icon(Icons.all_inclusive_rounded, size: 56, color: cs.primary),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Kg libre — pas de limite',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'L\'expéditeur verra \'kilo disponible\' sans quota précis',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildStripeNotConfiguredPaymentSection(
    TextTheme tt,
    ColorScheme cs,
    BuildContext ctx,
  ) {
    return _SectionCard(
      child: Column(
        children: [
          // ── Bannière warning ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.successLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DonyRadius.card),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: cs.warning, size: 18),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Connectez Stripe pour recevoir des paiements et publier votre trajet.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                GestureDetector(
                  onTap: () => ctx.push('/connect/onboarding/intro'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      'Configurer →',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Ligne Carte bancaire (désactivée) ─────────────────────────────
          SwitchListTile(
            value: false,
            onChanged: null,
            title: Row(
              children: [
                Icon(Icons.credit_card_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  'Carte bancaire (Stripe)',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Non configuré',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs,
            ),
          ),
          const _RowDivider(),
          // ── Ligne Espèces (désactivée) ────────────────────────────────────
          SwitchListTile(
            value: false,
            onChanged: null,
            title: Row(
              children: [
                Icon(Icons.payments_rounded,
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  'Espèces',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Disponible après Stripe',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 — Prix & Conditions ───────────────────────────────────────────────
  List<Widget> _buildStep2(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      // ── PRIX PAR KG ───────────────────────────────────────────────────────
      const _SectionLabel(label: 'PRIX PAR KG', icon: Icons.sell_rounded),
      const SizedBox(height: DonySpacing.md),
      ListenableBuilder(
        listenable: Listenable.merge([_priceOptionNotifier, _customPriceNotifier]),
        builder: (context, _) {
          final selectedIdx = _priceOptionNotifier.value;
          final isCustom = _isCustomPrice;
          final pricePerKg = _pricePerKg;
          final kg = _availableKgNotifier.value;
          final grossEstimate = kg * pricePerKg;
          final netEstimate = grossEstimate * 0.88;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Chips preset ──────────────────────────────────────────────
              Row(
                children: List.generate(_priceOptions.length, (i) {
                  final selected = selectedIdx == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : DonySpacing.xs,
                        right: DonySpacing.xs,
                      ),
                      child: GestureDetector(
                        onTap: () => _priceOptionNotifier.value = i,
                        child: AnimatedContainer(
                          duration: 180.ms,
                          padding: const EdgeInsets.symmetric(
                            vertical: DonySpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? cs.successLight : cs.surface,
                            borderRadius: BorderRadius.circular(DonyRadius.lg),
                            border: Border.all(
                              color: selected ? cs.success : cs.outline,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${_priceOptions[i].toStringAsFixed(0)}€',
                              style: tt.titleMedium?.copyWith(
                                color: selected ? cs.success : cs.onSurface,
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
              const SizedBox(height: DonySpacing.xs),
              // ── Chip "Autre" ──────────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  _priceOptionNotifier.value = _priceOptions.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  });
                },
                child: AnimatedContainer(
                  duration: 180.ms,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: DonySpacing.sm,
                    horizontal: DonySpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color: isCustom ? cs.successLight : cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.lg),
                    border: Border.all(
                      color: isCustom ? cs.success : cs.outline,
                      width: isCustom ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: isCustom ? cs.success : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        'Autre prix',
                        style: tt.bodyMedium?.copyWith(
                          color: isCustom ? cs.success : cs.onSurfaceVariant,
                          fontWeight: isCustom ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Champ prix custom ─────────────────────────────────────────
              if (isCustom) ...[
                const SizedBox(height: DonySpacing.sm),
                DonyTextField(
                  label: 'Prix par kg',
                  hint: 'ex: 12',
                  controller: _customPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: DonySpacing.md),
                    child: Text('€/kg',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null && parsed > 0) {
                      _customPriceNotifier.value = parsed;
                    }
                  },
                ),
              ],
              const SizedBox(height: DonySpacing.sm),
              Text(
                'Estimation : ${grossEstimate.toStringAsFixed(0)}€ · vous touchez ${netEstimate.toStringAsFixed(0)}€',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
        },
      ).animate().fadeIn(delay: 100.ms),
      BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
        buildWhen: (p, c) =>
            p.priceWarning != c.priceWarning ||
            p.pricePerKg != c.pricePerKg ||
            p.departureCity != c.departureCity ||
            p.arrivalCity != c.arrivalCity,
        builder: (context, formState) {
          final dep = formState.departureCity;
          final arr = formState.arrivalCity;
          final corridor =
              (dep != null && arr != null) ? '$dep – $arr' : null;
          return PriceHintWidget(
            marketMedianPrice: 8.0,
            warning: formState.priceWarning,
            corridor: corridor,
          );
        },
      ),
      const SizedBox(height: DonySpacing.xxl),

      // ── MODES DE PAIEMENT ACCEPTÉS ────────────────────────────────────────
      const _SectionLabel(
        label: 'MODES DE PAIEMENT ACCEPTÉS',
        icon: Icons.payments_rounded,
      ),
      const SizedBox(height: DonySpacing.sm),
      BlocBuilder<ConnectOnboardingBloc, ConnectOnboardingState>(
        builder: (ctx, connectState) {
          final isStripeConfigured = connectState is ConnectOnboardingComplete ||
              connectState is ConnectOnboardingPending;
          final isConnectLoading = connectState is ConnectOnboardingInitial ||
              connectState is ConnectOnboardingLoading;

          if (!isStripeConfigured && !isConnectLoading) {
            return _buildStripeNotConfiguredPaymentSection(tt, cs, ctx);
          }

          return BlocBuilder<CommissionMethodBloc, CommissionMethodState>(
            builder: (context, cmState) {
              final isLoaded = cmState is CommissionMethodLoaded &&
                  cmState.card.expirationStatus != ExpirationStatus.expired;
              return _SectionCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('payment-method-stripe'),
                      value: true,
                      onChanged: null,
                      activeThumbColor: cs.primary,
                      title: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, size: 18),
                          const SizedBox(width: DonySpacing.sm),
                          Text(
                            'Carte bancaire (Stripe)',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Icon(Icons.lock_rounded,
                              size: 14, color: cs.onSurfaceVariant),
                        ],
                      ),
                      subtitle: Text(
                        'Paiement sécurisé par défaut',
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                        return SwitchListTile(
                          key: const Key('payment-method-cash'),
                          value: isLoaded ? cashEnabled : false,
                          onChanged: isLoaded
                              ? (val) => _cashEnabledNotifier.value = val
                              : null,
                          activeThumbColor: cs.primary,
                          title: Row(
                            children: [
                              const Icon(Icons.payments_rounded, size: 18),
                              const SizedBox(width: DonySpacing.sm),
                              Text(
                            'Espèces',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isLoaded ? cs.onSurface : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      subtitle: isLoaded
                          ? Text(
                              'Le voyageur perçoit la commission à la remise',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            )
                          : GestureDetector(
                              onTap: () => context.push('/payments/commission-method'),
                              child: Text(
                                'Ajouter une carte commission →',
                                key: const Key('add-commission-card-link'),
                                style: tt.bodySmall?.copyWith(
                                  color: cs.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.base,
                        vertical: DonySpacing.xs,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
        },
      ).animate().fadeIn(delay: 180.ms),
      const SizedBox(height: DonySpacing.xxl),

      // ── CE QUE J'ACCEPTE ──────────────────────────────────────────────────
      const _SectionLabel(label: 'CE QUE J\'ACCEPTE', icon: Icons.check_circle_outline_rounded),
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
                            vertical: DonySpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.success
                                : Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(DonyRadius.full),
                            border: Border.all(
                              color: isSelected ? cs.success : cs.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded,
                                    size: 12, color: DonyColors.white),
                                const SizedBox(width: DonySpacing.xs),
                              ],
                              Text(
                                type,
                                style: tt.bodySmall?.copyWith(
                                  color: isSelected ? DonyColors.white : cs.onSurface,
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
                      children: custom
                          .map((item) => _RemovableChip(
                                label: item,
                                accentColor: cs.success,
                                onRemove: () {
                                  final updated = Set<String>.from(custom)
                                    ..remove(item);
                                  _customAcceptedNotifier.value = updated;
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ],
                const _RowDivider(),
                _InlineAddRow(
                  controller: _customAcceptedCtrl,
                  hint: 'Ajouter un autre type…',
                  onAdd: () {
                    final val = _customAcceptedCtrl.text.trim();
                    if (val.isEmpty) return;
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

      // ── CE QUE JE REFUSE ──────────────────────────────────────────────────
      const _SectionLabel(label: 'CE QUE JE REFUSE', icon: Icons.block_rounded),
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
                  accentColor: cs.error,
                  onAdd: () {
                    final val = _refusedCtrl.text.trim();
                    if (val.isEmpty) return;
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
                      children: refused
                          .map((item) => _RemovableChip(
                                label: item,
                                accentColor: cs.error,
                                onRemove: () {
                                  final updated = Set<String>.from(refused)
                                    ..remove(item);
                                  _refusedTypesNotifier.value = updated;
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ).animate().fadeIn(delay: 140.ms),
      const SizedBox(height: DonySpacing.xxl),

      // ── NOTE AUX EXPÉDITEURS ──────────────────────────────────────────────
      const _SectionLabel(label: 'NOTE AUX EXPÉDITEURS', icon: Icons.edit_note_rounded),
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
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText:
                          'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.',
                      hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        },
      ).animate().fadeIn(delay: 160.ms),
      const SizedBox(height: DonySpacing.xl),
    ];
  }

  Widget _buildForm(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Mode locked — formulaire plat, pas de stepper
    if (_isLocked) {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LockedBanner(lockContext: widget.lockContext!),
            const SizedBox(height: DonySpacing.lg),
            // ── Corridor preview ───────────────────────────────────────────
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
                if (dep == null || arr == null) return const SizedBox.shrink();
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$depCode → $arrCode',
                                    style: tt.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(
                                      dateStr,
                                      style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant),
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
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.full),
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
            // ── TRAJET ────────────────────────────────────────────────────
            const _SectionLabel(label: 'TRAJET', icon: Icons.flight_takeoff_rounded),
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
                      _LockedCityRow(
                        label: 'Ville de départ',
                        value: _departureCityNotifier.value ?? '',
                        icon: Icons.flight_takeoff_rounded,
                        iconColor: cs.primary,
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
                      _LockedCityRow(
                        label: 'Ville d\'arrivée',
                        value: _arrivalCityNotifier.value ?? '',
                        icon: Icons.flight_land_rounded,
                        iconColor: DonyColors.accent,
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
            // ── LIEUX DE REMISE ───────────────────────────────────────────
            const _SectionLabel(label: 'LIEUX DE REMISE', icon: Icons.swap_horiz_rounded),
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
            // ── CAPACITÉ DISPONIBLE ───────────────────────────────────────
            const _SectionLabel(label: 'CAPACITÉ DISPONIBLE', icon: Icons.luggage_rounded),
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
                              color: cs.onSurfaceVariant),
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
                                borderRadius:
                                    BorderRadius.circular(DonyRadius.full),
                              ),
                              child: Text(
                                'VALISE',
                                style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      'Capacité fixée par la demande',
                      style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: DonySpacing.xxl),
            // ── PRIX verrouillé ───────────────────────────────────────────
            _LockedTotalPriceCard(
              agreedPriceEur: widget.lockContext!.agreedPriceEur,
            ),
            const SizedBox(height: DonySpacing.xxl),
            // ── MODE DE TRANSPORT ─────────────────────────────────────────
            const _SectionLabel(
              label: 'MODE DE TRANSPORT',
              icon: Icons.commute_rounded,
            ),
            const SizedBox(height: DonySpacing.sm),
            IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.7,
                child: ValueListenableBuilder<TransportMode?>(
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
                            onTap: () {},
                          ),
                      ],
                    );
                  },
                ),
              ),
            ).animate().fadeIn(delay: 110.ms),
            const SizedBox(height: DonySpacing.xxl),
            // ── CE QUE J'ACCEPTE ──────────────────────────────────────────
            const _SectionLabel(
              label: 'CE QUE J\'ACCEPTE',
              icon: Icons.check_circle_outline_rounded,
            ),
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
                      Padding(
                        padding: const EdgeInsets.all(DonySpacing.base),
                        child: Wrap(
                          spacing: DonySpacing.xs,
                          runSpacing: DonySpacing.xs,
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
                                  vertical: DonySpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.success
                                      : Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.full),
                                  border: Border.all(
                                    color: isSelected ? cs.success : cs.outline,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(Icons.check_rounded,
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
                            children: custom
                                .map((item) => _RemovableChip(
                                      label: item,
                                      accentColor: cs.success,
                                      onRemove: () {
                                        final updated =
                                            Set<String>.from(custom)
                                              ..remove(item);
                                        _customAcceptedNotifier.value = updated;
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                      const _RowDivider(),
                      _InlineAddRow(
                        controller: _customAcceptedCtrl,
                        hint: 'Ajouter un autre type…',
                        onAdd: () {
                          final val = _customAcceptedCtrl.text.trim();
                          if (val.isEmpty) return;
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
            // ── CE QUE JE REFUSE ──────────────────────────────────────────
            const _SectionLabel(label: 'CE QUE JE REFUSE', icon: Icons.block_rounded),
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
                        accentColor: cs.error,
                        onAdd: () {
                          final val = _refusedCtrl.text.trim();
                          if (val.isEmpty) return;
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
                            children: refused
                                .map((item) => _RemovableChip(
                                      label: item,
                                      accentColor: cs.error,
                                      onRemove: () {
                                        final updated =
                                            Set<String>.from(refused)
                                              ..remove(item);
                                        _refusedTypesNotifier.value = updated;
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: DonySpacing.xxl),
            // ── NOTE AUX EXPÉDITEURS ──────────────────────────────────────
            const _SectionLabel(
              label: 'NOTE AUX EXPÉDITEURS',
              icon: Icons.edit_note_rounded,
            ),
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
                          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
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
            const SizedBox(height: DonySpacing.xl),
          ],
        ),
      );
    }

    // Mode création ou édition — formulaire avec stepper.
    // IndexedStack garde les 3 steps dans l'arbre en permanence :
    // - les AddressPickerField (step 1) ne perdent pas leur état quand on
    //   navigue vers step 0 ou step 2
    // - form.validate() et form.save() couvrent tous les champs quelle que
    //   soit l'étape visible
    return ValueListenableBuilder<int>(
      valueListenable: widget.currentStepNotifier!,
      builder: (context, step, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepperHeader(currentStep: step, totalSteps: _totalSteps),
              const SizedBox(height: DonySpacing.lg),
              IndexedStack(
                index: step,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildStep0(context, tt, cs),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildStep1(context, tt, cs),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildStep2(context, tt, cs),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static const int _totalSteps = 3;
}

// ─── Locked banner & locked-mode helpers ─────────────────────────────────────

class _LockedCityRow extends StatelessWidget {
  const _LockedCityRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  value,
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, size: 14, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LockedTotalPriceCard extends StatelessWidget {
  const _LockedTotalPriceCard({required this.agreedPriceEur});
  final double agreedPriceEur;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.lg),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: cs.success, size: 28),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prix total convenu',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '${agreedPriceEur.toStringAsFixed(0)} €',
                  style: tt.headlineSmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.lockContext});
  final LockedTripContext lockContext;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, size: 20, color: cs.primary),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trajet dédié à la demande',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Corridor, capacité, mode de transport et prix sont verrouillés. '
                  'La date doit rester dans la fenêtre de tolérance de l\'expéditeur.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field card (same as section card — thin white container for a single field) ─

class _FieldCard extends StatelessWidget {
  final Widget child;
  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(color: cs.surface, child: child),
    );
  }
}

// ─── Field icon (styled prefix icon for form fields) ─────────────────────────

class _FieldIcon extends StatelessWidget {
  final IconData icon;
  const _FieldIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(icon, size: 20, color: cs.primary);
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
    final cs = Theme.of(context).colorScheme;
    return Container(height: 0.5, color: cs.outline);
  }
}

// ─── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _SectionLabel({required this.label, this.icon});

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
    if (icon == null) return labelWidget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
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
              child: const Icon(Icons.add_rounded,
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
            child: Icon(Icons.close_rounded, size: 14, color: accentColor),
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
                      ? cs.onSurface
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
            if (time != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    size: 16, color: cs.onSurfaceVariant),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─── Stepper header ───────────────────────────────────────────────────────────

class _StepperHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepperHeader({required this.currentStep, required this.totalSteps});

  static const _labels = ['Trajet', 'Lieux & Cap.', 'Prix & Cond.'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          child: Row(
            children: [
              for (int i = 0; i < totalSteps; i++) ...[
                _StepNode(index: i, currentStep: currentStep),
                if (i < totalSteps - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      color: i < currentStep ? cs.primary : cs.outlineVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          children: List.generate(totalSteps, (i) {
            return Expanded(
              child: Text(
                i < currentStep ? '${_labels[i]} ✓' : _labels[i],
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: i == currentStep
                      ? cs.primary
                      : i < currentStep
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant,
                  fontWeight: i == currentStep ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final int index;
  final int currentStep;
  const _StepNode({required this.index, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = index < currentStep;
    final isActive = index == currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone || isActive ? cs.primary : cs.surfaceContainerHighest,
        border: isActive
            ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 4)
            : null,
        boxShadow: isActive
            ? [BoxShadow(color: cs.primary.withValues(alpha: 0.25), blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: isDone
            ? Icon(Icons.check_rounded, size: 14, color: cs.onPrimary)
            : Text(
                '${index + 1}',
                style: tt.labelSmall?.copyWith(
                  color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
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
            Icon(Icons.calendar_today_rounded,
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
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
