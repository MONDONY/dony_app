import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
// PricingMode is exported from announcement_form_event.dart
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_preview_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/lieux_capacite_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/prix_conditions_step.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trajet_step.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart' show NegotiationThreadStatus;
import 'package:dony/features/trip_templates/bloc/trip_template_bloc.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_event.dart';
import 'package:dony/features/trip_templates/bloc/trip_template_state.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// ─── Public entry point ───────────────────────────────────────────────────────

class CreateAnnouncementBottomSheet {
  static Future<void> show(
    BuildContext context, {
    AnnouncementModel? announcement,
    LockedTripContext? lockContext,
    NegotiationBloc? negotiationBloc,
    bool lockCorridorAndDate = false,
  }) {
    assert(lockContext == null || negotiationBloc != null,
        'lockContext requires a negotiationBloc to dispatch the dedicated-trip event');
    final canSubmitNotifier =
        ValueNotifier<bool>(announcement?.transportMode != null || lockContext != null);
    final currentStepNotifier = ValueNotifier<int>(0);
    final departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
    // true dès que ville départ + ville arrivée + date sont renseignés (étape 0).
    // Initialisé à true en mode édition ET en trajet dédié car le corridor +
    // la date sont pré-remplis depuis la demande.
    final canContinueNotifier =
        ValueNotifier<bool>(announcement != null || lockContext != null);
    // true dès que lieu de remise + lieu de récupération sont renseignés (étape 1).
    final canContinueStep1Notifier = ValueNotifier<bool>(
      announcement?.pickupAddress != null && announcement?.deliveryAddress != null,
    );
    VoidCallback? submit;
    // Callback de validation de l'étape 0 (Trajet) — injecté depuis le widget Content.
    // Retourne true si les champs obligatoires sont renseignés.
    bool Function()? validateStep0;
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
          BlocProvider<AnnouncementFormBloc>(
            create: (_) => AnnouncementFormBloc(
              priceGridRepository: getIt<PriceGridRepository>(),
            ),
          ),
          BlocProvider<TripTemplateBloc>(
            create: (_) => getIt<TripTemplateBloc>()..add(const TripTemplateLoaded()),
          ),
          if (negotiationBloc != null)
            BlocProvider<NegotiationBloc>.value(value: negotiationBloc),
        ];
        // ScaffoldMessenger + Scaffold transparent : ancre les snackbars
        // à l'intérieur du sheet, pas sur l'écran derrière.
        return ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: MultiBlocProvider(providers: providers, child: child),
          ),
        );
      },
      stickyBottom: ListenableBuilder(
              listenable: Listenable.merge([canSubmitNotifier, currentStepNotifier, canContinueNotifier, canContinueStep1Notifier]),
              builder: (ctx, _) {
                final step = currentStepNotifier.value;
                final canSubmit = canSubmitNotifier.value;
                final canContinue = canContinueNotifier.value;
                final canContinueStep1 = canContinueStep1Notifier.value;

                if (step < 2) {
                  return Row(
                    children: [
                      if (step > 0) ...[
                        Expanded(
                          child: DonyButton(
                            label: 'Retour',
                            variant: DonyButtonVariant.secondary,
                            icon: DonyIcons.back,
                            onPressed: () => currentStepNotifier.value = step - 1,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.sm),
                      ],
                      Expanded(
                        child: DonyButton(
                          label: 'Continuer',
                          iconRight: DonyIcons.arrowRight,
                          onPressed: ((step == 0 && !canContinue) || (step == 1 && !canContinueStep1))
                              ? null
                              : () {
                                  if (step == 0) {
                                    final isValid = validateStep0?.call() ?? true;
                                    if (!isValid) return;
                                  }
                                  currentStepNotifier.value = step + 1;
                                },
                        ),
                      ),
                    ],
                  );
                }

                // Étape 3 (finale) — Trajet dédié : « Confirmer le trajet »
                // (dispatch NegotiationCreateDedicatedTripRequested).
                if (isLocked) {
                  return BlocBuilder<NegotiationBloc, NegotiationState>(
                    builder: (ctx, state) {
                      final isLoading = state is NegotiationLoading ||
                          state is NegotiationActionInProgress;
                      return Row(
                        children: [
                          Expanded(
                            child: DonyButton(
                              label: 'Retour',
                              variant: DonyButtonVariant.secondary,
                              icon: DonyIcons.back,
                              onPressed: () =>
                                  currentStepNotifier.value = step - 1,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.sm),
                          Expanded(
                            child: DonyButton(
                              key: const Key('create-dedicated-trip-submit'),
                              label: 'Confirmer le trajet',
                              isLoading: isLoading,
                              onPressed: (canSubmit && !isLoading)
                                  ? () => submit?.call()
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
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
                              label: 'Retour',
                              variant: DonyButtonVariant.secondary,
                              icon: DonyIcons.back,
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
                  builder: (ctx, annState) {
                    final isLoading = annState is AnnouncementLoading;
                    return BlocBuilder<StripeAccountBloc, StripeAccountState>(
                      builder: (ctx3, stripeState) {
                        final isStripeConfigured = stripeState is StripeAccountReady &&
                            stripeState.accountStatus.isComplete;

                        if (!isStripeConfigured) {
                          return Row(
                            children: [
                              Expanded(
                                child: DonyButton(
                                  label: 'Retour',
                                  variant: DonyButtonVariant.secondary,
                                  icon: DonyIcons.back,
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
                                    label: 'Retour',
                                    variant: DonyButtonVariant.secondary,
                                    icon: DonyIcons.back,
                                    onPressed: () => currentStepNotifier.value = step - 1,
                                  ),
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: DonyButton(
                                    key: const Key('create-announcement-preview'),
                                    label: 'Aperçu',
                                    iconRight: DonyIcons.arrowRight,
                                    isLoading: isLoading,
                                    onPressed: (canSubmit && !isLoading)
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
        lockCorridorAndDate: lockCorridorAndDate,
        canSubmitNotifier: canSubmitNotifier,
        canContinueNotifier: canContinueNotifier,
        canContinueStep1Notifier: canContinueStep1Notifier,
        currentStepNotifier: currentStepNotifier,
        departureTimeNotifier: departureTimeNotifier,
        onSubmitReady: (fn) => submit = fn,
        onValidateStep0Ready: (fn) => validateStep0 = fn,
      ),
    ).whenComplete(() {
      canSubmitNotifier.dispose();
      canContinueNotifier.dispose();
      canContinueStep1Notifier.dispose();
      currentStepNotifier.dispose();
      departureTimeNotifier.dispose();
    });
  }
}

// ─── Content widget ───────────────────────────────────────────────────────────

class _CreateAnnouncementContent extends StatefulWidget {
  final AnnouncementModel? announcement;
  final LockedTripContext? lockContext;
  /// Édition d'un trajet à lier à une négo : corridor + date verrouillés, et on
  /// reste sur l'écran de liaison au succès (pas de redirection /announcements).
  final bool lockCorridorAndDate;
  final ValueNotifier<bool>? canSubmitNotifier;
  final ValueNotifier<bool>? canContinueNotifier;
  final ValueNotifier<bool>? canContinueStep1Notifier;
  final ValueNotifier<int>? currentStepNotifier;
  final ValueNotifier<TimeOfDay?>? departureTimeNotifier;
  final void Function(VoidCallback)? onSubmitReady;
  /// Injecte le callback de validation de l'étape 0 dans le parent (show()).
  /// Le callback retourne true si tous les champs obligatoires de l'étape 0
  /// (ville départ, ville arrivée, date) sont renseignés.
  final void Function(bool Function())? onValidateStep0Ready;
  const _CreateAnnouncementContent({
    this.announcement,
    this.lockContext,
    this.lockCorridorAndDate = false,
    this.canSubmitNotifier,
    this.canContinueNotifier,
    this.canContinueStep1Notifier,
    this.currentStepNotifier,
    this.departureTimeNotifier,
    this.onSubmitReady,
    this.onValidateStep0Ready,
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
  // Code pays ISO-2 capturé lors de la sélection ville. Synchronisé vers le
  // form bloc via _syncCityToFormBloc et lu au submit depuis l'état du bloc.
  final _departureCountryCodeNotifier = ValueNotifier<String?>(null);
  final _arrivalCountryCodeNotifier = ValueNotifier<String?>(null);
  final _departureDateNotifier = ValueNotifier<DateTime?>(null);
  final _departureTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _arrivalTimeNotifier = ValueNotifier<TimeOfDay?>(null);
  final _pickupAddressNotifier = ValueNotifier<AddressData?>(null);
  final _deliveryAddressNotifier = ValueNotifier<AddressData?>(null);
  AddressData? get _pickupAddress => _pickupAddressNotifier.value;
  AddressData? get _deliveryAddress => _deliveryAddressNotifier.value;
  final _availableKgNotifier = ValueNotifier<double>(15);
  final _priceOptionNotifier = ValueNotifier<int>(-1); // -1 = aucune sélection
  final _transportModeNotifier = ValueNotifier<TransportMode?>(null);
  final _selectedContentNotifier = ValueNotifier<Set<String>>(
    {'Vêtements', 'Médicaments', 'Documents'},
  );
  final _customAcceptedNotifier = ValueNotifier<Set<String>>({});
  final _refusedTypesNotifier = ValueNotifier<Set<String>>({});
  final _cashEnabledNotifier = ValueNotifier<bool>(false);
  late final ValueNotifier<bool> _kgPriceEnabledNotifier;
  final _descriptionCtrl = TextEditingController();
  final _customAcceptedCtrl = TextEditingController();
  final _refusedCtrl = TextEditingController();
  final _customPriceCtrl = TextEditingController();
  final _customPriceNotifier = ValueNotifier<double>(6.0);

  bool get _isEdit => widget.announcement != null;
  bool get _isLocked => widget.lockContext != null;
  bool get _isCustomPrice => _priceOptionNotifier.value == kPriceOptions.length;
  double get _pricePerKg => _isCustomPrice
      ? _customPriceNotifier.value
      : kPriceOptions[_priceOptionNotifier.value.clamp(0, kPriceOptions.length - 1)];

  // Vrai si le prix est correctement renseigné :
  // — mode verrouillé → prix fixé par la demande, toujours valide
  // — kg toggle OFF (mode grille) → tarification via la grille, toujours valide
  // — aucun choix effectué (idx == -1) → invalide
  // — chip preset sélectionnée → valide
  // — "Autre prix" sélectionné → le champ doit contenir un nombre > 0
  bool get _isPriceValid {
    if (_isLocked) return true;
    if (!_kgPriceEnabledNotifier.value) return true;
    final idx = _priceOptionNotifier.value;
    if (idx == -1) return false;
    if (!_isCustomPrice) return true;
    final parsed = double.tryParse(_customPriceCtrl.text.replaceAll(',', '.'));
    return parsed != null && parsed > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommissionMethodBloc>().add(CommissionMethodLoadRequested());
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
      _departureCountryCodeNotifier.value = a.departureCountryCode;
      _arrivalCountryCodeNotifier.value = a.arrivalCountryCode;
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
      _pickupAddressNotifier.value = a.pickupAddress;
      _deliveryAddressNotifier.value = a.deliveryAddress;
      _transportModeNotifier.value = a.transportMode;

      if (a.description != null) {
        _descriptionCtrl.text = a.description!;
      }

      if (a.acceptedContentTypes != null) {
        final presets = Set<String>.from(
          a.acceptedContentTypes!.where(kContentTypes.contains),
        );
        final custom = Set<String>.from(
          a.acceptedContentTypes!.where((t) => !kContentTypes.contains(t)),
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
      final presetIdx = kPriceOptions.indexOf(price);
      if (presetIdx != -1) {
        _priceOptionNotifier.value = presetIdx;
      } else {
        // Prix custom — sélectionner "Autre" et pré-remplir le champ
        _priceOptionNotifier.value = kPriceOptions.length;
        _customPriceNotifier.value = price;
        _customPriceCtrl.text = price.toStringAsFixed(0);
      }

      // Sync capacityUnit et pricingMode vers le BLoC (requiert context → postFrame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final formBloc = context.read<AnnouncementFormBloc>();

        final unit = switch (a.capacityUnit) {
          'KG_FREE' => CapacityUnit.kgFree,
          'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
          'KG_EXACT' => CapacityUnit.custom,
          _ => CapacityUnit.suitcase23kg,
        };
        formBloc.add(CapacityUnitChanged(unit));

        final mode = a.pricingMode == 'MIXED'
            ? PricingMode.mixed
            : PricingMode.kg;
        formBloc.add(AnnouncementPricingModeSetRequested(mode));

        // Seed le prix dans le form bloc depuis les notifiers pré-remplis : le
        // listener ne s'est pas déclenché (valeurs posées avant son attache).
        // Indispensable quand la section prix est masquée (lockPrice) — sinon
        // le submit enverrait pricePerKg = 0 et écraserait le prix du trajet.
        _syncPriceToFormBloc();

        // Seed la ville + le code pays dans le form bloc depuis les notifiers
        // pré-remplis (lignes 411-414) : le listener _syncCityToFormBloc n'a pas
        // pu se déclencher (valeurs posées avant son attache, l.515-516). Sans ce
        // sync explicite, éditer une annonce SANS re-sélectionner la ville
        // submitterait departureCountryCode/arrivalCountryCode = null (asymétrie
        // vs le nom de ville qui, lui, est préservé). Edit-mode uniquement.
        _syncCityToFormBloc();
      });
    }
    widget.onSubmitReady?.call(_submit);
    widget.onValidateStep0Ready?.call(_validateStep0);
    _kgPriceEnabledNotifier = ValueNotifier<bool>(true); // KG = ON par défaut
    _kgPriceEnabledNotifier.addListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.addListener(_syncCanSubmit);
    _transportModeNotifier.addListener(_syncCanSubmit);
    _priceOptionNotifier.addListener(_syncCanSubmit);
    _customPriceCtrl.addListener(_syncCanSubmit);
    // Avion sélectionné par défaut en mode création
    if (!_isEdit && !_isLocked) {
      _transportModeNotifier.value = TransportMode.plane;
    }
    _syncCanSubmit(); // état initial — transport + prix

    // Désactivation du bouton Continuer tant que les 3 champs obligatoires
    // de l'étape 0 ne sont pas renseignés.
    _departureCityNotifier.addListener(_updateCanContinue);
    _arrivalCityNotifier.addListener(_updateCanContinue);
    _departureDateNotifier.addListener(_updateCanContinue);
    _updateCanContinue(); // état initial (pré-remplissage en mode édition)

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

  void _updateCanContinue() {
    widget.canContinueNotifier?.value =
        _departureCityNotifier.value != null &&
        _arrivalCityNotifier.value != null &&
        _departureDateNotifier.value != null;
  }

  void _updateCanContinueStep1() {
    widget.canContinueStep1Notifier?.value =
        _pickupAddress != null && _deliveryAddress != null;
  }

  void _syncCanSubmit() {
    widget.canSubmitNotifier?.value =
        _transportModeNotifier.value != null && _isPriceValid;
  }

  /// Valide les champs obligatoires de l'étape 0 (Trajet).
  /// Affiche un snackbar d'erreur si un champ manque et retourne false.
  bool _validateStep0() {
    if (_departureCityNotifier.value == null) {
      _showError('Remplis tous les champs obligatoires');
      return false;
    }
    if (_arrivalCityNotifier.value == null) {
      _showError('Remplis tous les champs obligatoires');
      return false;
    }
    if (_departureDateNotifier.value == null) {
      _showError('Remplis tous les champs obligatoires');
      return false;
    }
    return true;
  }

  void _syncCityToFormBloc() {
    if (!mounted) return;
    final formBloc = context.read<AnnouncementFormBloc>();
    if (_departureCityNotifier.value != null) {
      formBloc.add(DepartureCityChanged(
        _departureCityNotifier.value!,
        countryCode: _departureCountryCodeNotifier.value,
      ));
    }
    if (_arrivalCityNotifier.value != null) {
      formBloc.add(ArrivalCityChanged(
        _arrivalCityNotifier.value!,
        countryCode: _arrivalCountryCodeNotifier.value,
      ));
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
    if (!_kgPriceEnabledNotifier.value) return; // évite d'écraser le clear
    if (_priceOptionNotifier.value == -1) return; // pas encore de sélection
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

  void _onKgToggleChanged() {
    if (!mounted) return;
    if (!_kgPriceEnabledNotifier.value) {
      context
          .read<AnnouncementFormBloc>()
          .add(const AnnouncementPricePerKgClearedRequested());
      _priceOptionNotifier.value = 0; // reset chips visuellement
    }
  }

  @override
  void dispose() {
    _departureCityNotifier.removeListener(_updateCanContinue);
    _arrivalCityNotifier.removeListener(_updateCanContinue);
    _departureDateNotifier.removeListener(_updateCanContinue);
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
    _kgPriceEnabledNotifier.removeListener(_onKgToggleChanged);
    _kgPriceEnabledNotifier.removeListener(_syncCanSubmit);
    _priceOptionNotifier.removeListener(_syncCanSubmit);
    _customPriceCtrl.removeListener(_syncCanSubmit);
    _kgPriceEnabledNotifier.dispose();
    _cashEnabledNotifier.dispose();
    _descriptionCtrl.dispose();
    _customAcceptedCtrl.dispose();
    _refusedCtrl.dispose();
    _customPriceCtrl.dispose();
    _customPriceNotifier.dispose();
    _departureCityNotifier.dispose();
    _arrivalCityNotifier.dispose();
    _departureCountryCodeNotifier.dispose();
    _arrivalCountryCodeNotifier.dispose();
    _departureDateNotifier.dispose();
    _departureTimeNotifier.dispose();
    _arrivalTimeNotifier.dispose();
    _availableKgNotifier.dispose();
    _priceOptionNotifier.dispose();
    _selectedContentNotifier.dispose();
    _customAcceptedNotifier.dispose();
    _refusedTypesNotifier.dispose();
    _transportModeNotifier.dispose();
    _pickupAddressNotifier.dispose();
    _deliveryAddressNotifier.dispose();
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
            paymentMethod: lc.paymentMethod,
          ));
      return;
    }

    final paymentMethods = ['STRIPE', if (_cashEnabledNotifier.value) 'CASH'];

    final formBlocState = context.read<AnnouncementFormBloc>().state;
    final capacityUnitWire = formBlocState.capacityUnit.toWire();
    final pricingModeWire = formBlocState.pricingMode == PricingMode.mixed ? 'MIXED' : 'KG';
    final pricePerKgToSubmit = formBlocState.pricePerKg ?? 0.0;

    // TODO(Task 7): remplacer par le vrai créneau saisi via le picker
    final handoverStart = DateTime.now();
    final handoverEnd = handoverStart.add(const Duration(hours: 2));

    if (_isEdit) {
      context.read<AnnouncementBloc>().add(AnnouncementUpdateRequested(
            id: widget.announcement!.id,
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureCountryCode: formBlocState.departureCountryCode,
            arrivalCountryCode: formBlocState.arrivalCountryCode,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            pickupAddress: _pickupAddress!,
            deliveryAddress: _deliveryAddress!,
            availableKg: _availableKgNotifier.value,
            pricePerKg: pricePerKgToSubmit,
            transportMode: transportMode,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
            acceptedPaymentMethods: paymentMethods,
            capacityUnit: capacityUnitWire,
            pricingMode: pricingModeWire,
            handoverWindowStart: handoverStart,
            handoverWindowEnd: handoverEnd,
          ));
    } else {
      context.read<AnnouncementBloc>().add(AnnouncementCreateRequested(
            departureCity: departureCity,
            arrivalCity: arrivalCity,
            departureCountryCode: formBlocState.departureCountryCode,
            arrivalCountryCode: formBlocState.arrivalCountryCode,
            departureDate: departureDate,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            pickupAddress: _pickupAddress!,
            deliveryAddress: _deliveryAddress!,
            availableKg: _availableKgNotifier.value,
            pricePerKg: pricePerKgToSubmit,
            transportMode: transportMode,
            description: description,
            acceptedContentTypes: allAccepted,
            refusedTypes: refused,
            acceptedPaymentMethods: paymentMethods,
            capacityUnit: capacityUnitWire,
            pricingMode: pricingModeWire,
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

    return BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
      listenWhen: (prev, curr) => prev.pricingMode != curr.pricingMode,
      listener: (context, formState) {
        if (formState.pricingMode == PricingMode.mixed) {
          _kgPriceEnabledNotifier.value = false;
        } else {
          _kgPriceEnabledNotifier.value = true;
        }
      },
      child: BlocConsumer<AnnouncementBloc, AnnouncementState>(
        listener: (context, state) async {
          if (state is AnnouncementCreated || state is AnnouncementUpdated) {
            Navigator.of(context, rootNavigator: true).pop();
            // En modification depuis « Lier un trajet », on reste sur l'écran de
            // liaison (le caller rafraîchit) — pas de redirection /announcements.
            if (!widget.lockCorridorAndDate && context.mounted) {
              context.go('/announcements');
            }
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
        builder: (context, state) => BlocListener<AnnouncementFormBloc, AnnouncementFormState>(
          listenWhen: (prev, curr) => prev.availableKg != curr.availableKg,
          listener: (context, formState) {
            final kg = formState.availableKg ?? 0.0;
            if (kg != _availableKgNotifier.value) {
              _availableKgNotifier.value = kg;
            }
          },
          child: formChild,
        ),
      ),
    );
  }

  /// Applique un modèle de trajet enregistré : pré-remplit corridor, transport,
  /// capacité, poids, prix et contenu (les listeners synchronisent vers le BLoC).
  void _applyTemplate(TripTemplate t) {
    _departureCityNotifier.value = t.departureCity;
    _arrivalCityNotifier.value = t.arrivalCity;
    _transportModeNotifier.value =
        transportModeFromWire(t.transportMode) ?? TransportMode.plane;
    _availableKgNotifier.value = t.availableKg.toDouble();

    _kgPriceEnabledNotifier.value = true;
    final presetIdx = kPriceOptions.indexOf(t.pricePerKg);
    if (presetIdx != -1) {
      _priceOptionNotifier.value = presetIdx;
    } else {
      _priceOptionNotifier.value = kPriceOptions.length; // "Autre prix"
      _customPriceNotifier.value = t.pricePerKg;
      _customPriceCtrl.text = t.pricePerKg.toStringAsFixed(0);
    }

    _selectedContentNotifier.value =
        t.acceptedCategories.where(kContentTypes.contains).toSet();
    _customAcceptedNotifier.value =
        t.acceptedCategories.where((c) => !kContentTypes.contains(c)).toSet();

    final unit = switch (t.capacityUnit) {
      'KG_FREE' => CapacityUnit.kgFree,
      'SUITCASE_32KG' => CapacityUnit.suitcase32kg,
      'KG_EXACT' => CapacityUnit.custom,
      _ => CapacityUnit.suitcase23kg,
    };
    context.read<AnnouncementFormBloc>().add(CapacityUnitChanged(unit));

    DonySnackbar.show(context,
        message: 'Modèle « ${t.label} » appliqué',
        type: DonySnackbarType.success);
  }

  Widget _buildTemplatesSuggestionBar(
      BuildContext context, TextTheme tt, ColorScheme cs) {
    return BlocBuilder<TripTemplateBloc, TripTemplateState>(
      builder: (context, state) {
        if (state.templates.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CaSectionLabel(label: 'Mes modèles', icon: Icons.bookmark_rounded),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Applique un modèle pour pré-remplir le trajet',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: DonySpacing.sm),
                itemBuilder: (context, i) {
                  final t = state.templates[i];
                  return ActionChip(
                    avatar: t.emoji != null
                        ? Text(t.emoji!)
                        : Icon(Icons.bookmark_border_rounded, size: 16, color: cs.primary),
                    label: Text('${t.label} · ${t.pricePerKg.toStringAsFixed(0)}€/kg'),
                    onPressed: () => _applyTemplate(t),
                  );
                },
              ),
            ),
            const SizedBox(height: DonySpacing.xl),
          ],
        );
      },
    );
  }

  // ── Step 0 — Trajet + Transport ─────────────────────────────────────────────
  List<Widget> _buildStep0(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      if (_isLocked) ...[
        _LockedBanner(lockContext: widget.lockContext!),
        const SizedBox(height: DonySpacing.lg),
      ],
      if (!_isEdit && !_isLocked) _buildTemplatesSuggestionBar(context, tt, cs),
      TrajetStep(
        departureCityNotifier: _departureCityNotifier,
        arrivalCityNotifier: _arrivalCityNotifier,
        departureCountryCodeNotifier: _departureCountryCodeNotifier,
        arrivalCountryCodeNotifier: _arrivalCountryCodeNotifier,
        departureDateNotifier: _departureDateNotifier,
        departureTimeNotifier: _departureTimeNotifier,
        arrivalTimeNotifier: _arrivalTimeNotifier,
        transportModeNotifier: _transportModeNotifier,
        onSelectDepartureTime: _selectDepartureTime,
        onSelectArrivalTime: _selectArrivalTime,
        onSelectDate: _selectDate,
        // Corridor verrouillé en modification (Q1) ET en trajet dédié (lockContext).
        // Date verrouillée seulement en modification ; le dédié la garde éditable
        // dans la fenêtre de tolérance.
        lockCorridor: widget.lockCorridorAndDate || _isLocked,
        lockDate: widget.lockCorridorAndDate,
      ),
    ];
  }

  // ── Step 1 — Lieux & Capacité ────────────────────────────────────────────────
  List<Widget> _buildStep1(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      LieuxCapaciteStep(
        initialPickupAddress: _pickupAddressNotifier.value,
        initialDeliveryAddress: _deliveryAddressNotifier.value,
        onPickupSaved: (v) => _pickupAddressNotifier.value = v,
        onPickupChanged: (addr) {
          _pickupAddressNotifier.value = addr;
          _updateCanContinueStep1();
        },
        onDeliverySaved: (v) => _deliveryAddressNotifier.value = v,
        onDeliveryChanged: (addr) {
          _deliveryAddressNotifier.value = addr;
          _updateCanContinueStep1();
        },
        // Trajet dédié : capacité fixée par la demande → affichage verrouillé.
        lockedCapacityKg: _isLocked ? widget.lockContext!.weightKg : null,
      ),
    ];
  }

  // ── Step 2 — Prix & Conditions ───────────────────────────────────────────────
  List<Widget> _buildStep2(BuildContext context, TextTheme tt, ColorScheme cs) {
    return [
      PrixConditionsStep(
        priceOptionNotifier: _priceOptionNotifier,
        customPriceNotifier: _customPriceNotifier,
        availableKgNotifier: _availableKgNotifier,
        cashEnabledNotifier: _cashEnabledNotifier,
        kgPriceEnabledNotifier: _kgPriceEnabledNotifier, // ← NOUVEAU
        selectedContentNotifier: _selectedContentNotifier,
        customAcceptedNotifier: _customAcceptedNotifier,
        refusedTypesNotifier: _refusedTypesNotifier,
        descriptionCtrl: _descriptionCtrl,
        customAcceptedCtrl: _customAcceptedCtrl,
        refusedCtrl: _refusedCtrl,
        customPriceCtrl: _customPriceCtrl,
        // Prix verrouillé en modification-pour-négo ET en trajet dédié : il est
        // fixé par la négociation.
        lockPrice: widget.lockCorridorAndDate || _isLocked,
        // Trajet dédié : affiche le prix total convenu et masque la section
        // « Modes de paiement » (déjà fixé par la négociation).
        lockedTotalPriceEur:
            _isLocked ? widget.lockContext!.agreedPriceEur : null,
        showPaymentMethods: !_isLocked,
      ),
    ];
  }

  Widget _buildForm(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Mode création ou édition — formulaire avec stepper.
    // Offstage garde les 3 steps dans l'arbre en permanence :
    // - les AddressPickerField (step 1) ne perdent pas leur état quand on
    //   navigue vers step 0 ou step 2
    // - form.validate() et form.save() couvrent tous les champs quelle que
    //   soit l'étape visible
    // - contrairement à IndexedStack, Offstage n'impose pas la hauteur du
    //   plus grand enfant : le sheet se dimensionne au contenu de l'étape active
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.currentStepNotifier!,
        _pickupAddressNotifier,
        _deliveryAddressNotifier,
      ]),
      builder: (context, _) {
        final step = widget.currentStepNotifier!.value;
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaStepperHeader(currentStep: step, totalSteps: _totalSteps),
              const SizedBox(height: DonySpacing.lg),
              Offstage(
                offstage: step != 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep0(context, tt, cs),
                ),
              ),
              Offstage(
                offstage: step != 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep1(context, tt, cs),
                ),
              ),
              Offstage(
                offstage: step != 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildStep2(context, tt, cs),
                ),
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
                  'Corridor, capacité et prix sont verrouillés. '
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
