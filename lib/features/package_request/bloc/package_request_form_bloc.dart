import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/parcel_fit_wire.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_duplicate.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/data/parcel_dimensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PackageRequestFormBloc
    extends Bloc<PackageRequestFormEvent, PackageRequestFormState> {
  /// Valeur de la propriété analytics `transport_mode` pour « peu importe ».
  static const _anyMode = 'any';

  /// [editing] non-null → mode édition : l'état initial est pré-rempli depuis la
  /// demande existante (de façon synchrone, pour que les steps puissent lire ces
  /// valeurs dans leur `initState`). La soumission de l'étape 3 appellera alors
  /// `update` au lieu de `create`.
  ///
  /// [duplicating] non-null → création pré-remplie depuis une demande
  /// existante (dupliquer / republier) : pas d'id d'édition, pas de photos.
  PackageRequestFormBloc(
    this._repository, {
    required AnalyticsService analytics,
    PackageRequest? editing,
    PackageRequestDuplicate? duplicating,
  }) : _analytics = analytics,
       _editedItemSize = editing?.itemSize,
       super(
         editing != null
             ? _prefilledFrom(editing)
             : duplicating != null
             ? _duplicatedFrom(duplicating)
             : const PackageRequestFormState(),
       ) {
    on<FormStep1Submitted>(_onStep1);
    on<FormDesiredDateCleared>(_onDesiredDateCleared);
    on<FormTransportModeChanged>(_onTransportModeChanged);
    on<FormItemSizeChanged>(_onItemSizeChanged);
    on<FormStep2Submitted>(_onStep2);
    on<FormStep3Submitted>(_onStep3);
    on<FormStepBack>(_onStepBack);
    on<FormReset>((_, emit) => emit(const PackageRequestFormState()));
    on<FormDraftRestored>((e, emit) {
      if (e.fromAi) _fromAi = true;
      emit(e.draft.copyWith(draftRevision: state.draftRevision + 1));
    });
    on<PackageRequestNegotiableToggled>(
      (e, emit) => emit(state.copyWith(negotiable: e.value)),
    );
    on<PackageRequestPaymentMethodToggled>(_onPaymentMethodToggled);
    on<PackageRequestCurrencyChanged>(_onCurrencyChanged);
    on<PackageRequestTotalBudgetChanged>(
      (e, emit) => emit(
        state.copyWith(
          totalBudgetEur: e.value,
          clearTotalBudgetEur: e.value == null,
        ),
      ),
    );
    on<PackageRequestPromoCodeChanged>(
      (e, emit) => emit(
        state.copyWith(
          promoCode: e.value,
          clearPromoCode: e.value == null || e.value!.isEmpty,
        ),
      ),
    );
  }

  final PackageRequestRepository _repository;
  final AnalyticsService _analytics;

  /// Le formulaire a été rempli par « Créer avec l'IA » (`from_ai`).
  bool _fromAi = false;

  /// Construit l'état initial pré-rempli pour l'édition. L'utilisateur
  /// saisit et voit le brut, le backend stocke le net : le brut servi par le
  /// serveur ([PackageRequest.grossPriceEur]) prime, sinon le net est
  /// reconverti sur la grille figée de la demande quand l'app la connaît (à
  /// défaut la grille en vigueur). Une demande sans grille figée a été créée
  /// avant les paliers : le back la recalcule au taux unique, l'app aussi.
  static PackageRequestFormState _prefilledFrom(PackageRequest r) {
    final net = r.targetPriceEur;
    final gross =
        r.grossPriceEur ??
        (net != null
            ? senderPriceForNet(
                net,
                r.currency,
                grid: CommissionGridStore.byId(r.commissionGridId),
                legacy: r.commissionGridId == null,
              ).gross
            : null);
    return PackageRequestFormState(
      editingRequestId: r.id,
      departureCity: r.departureCity,
      arrivalCity: r.arrivalCity,
      desiredDate: r.desiredDate,
      dateToleranceDays: r.dateToleranceDays,
      transportMode: r.transportMode,
      transportModeAny: r.transportMode == null,
      weightKg: r.weightKg,
      parcelSize: r.parcelSize,
      itemSize: r.itemSize,
      lengthCm: r.lengthCm,
      widthCm: r.widthCm,
      heightCm: r.heightCm,
      categories: r.categories,
      description: r.description,
      photoUrl: r.photoUrl,
      pickupNeighborhood: r.pickupNeighborhood,
      deliveryNeighborhood: r.deliveryNeighborhood,
      negotiable: r.negotiable,
      acceptedPaymentMethods: r.acceptedPaymentMethods.isEmpty
          ? const {PaymentMethod.stripe}
          : r.acceptedPaymentMethods,
      totalBudgetEur: gross,
      targetPriceEur: gross,
      promoCode: r.promoCode,
      // Devise de la demande éditée, pas celle du portefeuille actif : sinon
      // les puces de l'étape 3 se calent sur ActiveCurrency et proposent
      // « Mobile money » sur une demande EUR (ou « Carte » sur une XOF) qui
      // sera silencieusement retirée au PUT (restrictToCurrency côté back).
      currency: SupportedCurrency.fromCodeOrDefault(r.currency),
      commissionGridId: r.commissionGridId,
    );
  }

  /// Création pré-remplie depuis une demande existante. Pas d'id d'édition (la
  /// soumission appelle `create`), pas de photos (une clé R2 n'appartient qu'à
  /// une demande), date vidée pour « Republier avec de nouvelles dates ».
  static PackageRequestFormState _duplicatedFrom(PackageRequestDuplicate d) {
    final base = _prefilledFrom(d.source);
    return PackageRequestFormState(
      departureCity: base.departureCity,
      arrivalCity: base.arrivalCity,
      desiredDate: d.clearDate ? null : base.desiredDate,
      dateToleranceDays: base.dateToleranceDays,
      transportMode: base.transportMode,
      transportModeAny: base.transportModeAny,
      weightKg: base.weightKg,
      parcelSize: base.parcelSize,
      itemSize: base.itemSize,
      lengthCm: base.lengthCm,
      widthCm: base.widthCm,
      heightCm: base.heightCm,
      categories: base.categories,
      description: base.description,
      pickupNeighborhood: base.pickupNeighborhood,
      deliveryNeighborhood: base.deliveryNeighborhood,
      negotiable: base.negotiable,
      acceptedPaymentMethods: base.acceptedPaymentMethods,
      totalBudgetEur: base.totalBudgetEur,
      targetPriceEur: base.targetPriceEur,
      currency: base.currency,
    );
  }

  /// Taille de la demande éditée telle que chargée ; `null` en création, ou
  /// quand la demande chargée n'en porte pas (ancien back, liste).
  final ItemSize? _editedItemSize;

  /// Intention d'écriture de la taille en modification, comparée à celle de la
  /// demande chargée : identique ou jamais connue puis jamais choisie = rien
  /// envoyé ; changée = envoyée ; retirée = effacée.
  FieldChange<ItemSize> _itemSizeChange() {
    final now = state.itemSize;
    if (now == _editedItemSize) return const FieldChange.keep();
    return now == null ? const FieldChange.clear() : FieldChange.set(now);
  }

  /// Une chaîne vide signifie « champ laissé à blanc » côté formulaire ; le
  /// backend, lui, attend `null` pour l'absence de valeur.
  static String? _blankToNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  void _onStep1(FormStep1Submitted e, Emitter<PackageRequestFormState> emit) {
    final hasDate = e.desiredDate != null;
    emit(
      _withModeRules(
        state.copyWith(
          currentStep: 1,
          departureCity: e.departureCity,
          arrivalCity: e.arrivalCity,
          desiredDate: e.desiredDate,
          dateToleranceDays: hasDate ? e.dateToleranceDays : null,
          clearDesiredDate: !hasDate,
          transportMode: e.transportMode,
          transportModeAny: e.transportMode == null,
        ),
      ),
    );
    _logStepCompleted(1, {
      'transport_mode': e.transportMode?.name ?? _anyMode,
      'has_date': hasDate,
    });
  }

  /// Étape du formulaire validée : sans cet événement, l'abandon par étape
  /// ne se reconstruisait pas (seul `form_draft_saved` en gardait une trace,
  /// quand l'utilisateur enregistrait). Propriétés `step` (1, 2), `editing`
  /// et des choix sans PII de l'étape.
  void _logStepCompleted(int step, Map<String, Object> extra) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.packageRequestStepCompleted,
        properties: {
          'step': step,
          'editing': state.editingRequestId != null,
          ...extra,
        },
      ),
    );
  }

  void _onTransportModeChanged(
    FormTransportModeChanged e,
    Emitter<PackageRequestFormState> emit,
  ) {
    emit(
      _withModeRules(
        state.copyWith(transportMode: e.mode, transportModeAny: e.mode == null),
      ),
    );
  }

  /// Un mode sans taille de colis (avion, bateau) efface celle déjà choisie :
  /// une taille invisible serait envoyée à l'insu de l'expéditeur. De même, un
  /// mode sans dimensions (avion, route) efface celles déjà saisies.
  static PackageRequestFormState _withModeRules(PackageRequestFormState next) {
    var rules = next;
    if (!rules.modeHasItemSize) rules = rules.copyWith(clearItemSize: true);
    if (!rules.modeKeepsDimensions) {
      rules = rules.copyWith(clearDimensions: true);
    }
    return rules;
  }

  void _onItemSizeChanged(
    FormItemSizeChanged e,
    Emitter<PackageRequestFormState> emit,
  ) {
    if (!state.modeHasItemSize) return;
    emit(state.copyWith(itemSize: e.size, clearItemSize: e.size == null));
  }

  void _onDesiredDateCleared(
    FormDesiredDateCleared e,
    Emitter<PackageRequestFormState> emit,
  ) {
    emit(state.copyWith(clearDesiredDate: true));
  }

  void _onStep2(FormStep2Submitted e, Emitter<PackageRequestFormState> emit) {
    // Dimensions tout ou rien, et seulement pour un mode qui les porte.
    final dimensions =
        state.modeKeepsDimensions &&
        e.lengthCm != null &&
        e.widthCm != null &&
        e.heightCm != null;
    emit(
      state.copyWith(
        currentStep: 2,
        weightKg: e.weightKg,
        parcelSize: e.parcelSize,
        categories: e.categories,
        description: e.description,
        lengthCm: dimensions ? e.lengthCm : null,
        widthCm: dimensions ? e.widthCm : null,
        heightCm: dimensions ? e.heightCm : null,
        clearDimensions: !dimensions,
      ),
    );
    _logStepCompleted(2, {
      'parcel_size': e.parcelSize.wireName,
      'categories_count': e.categories.length,
      if (state.modeKeepsDimensions) 'has_dimensions': dimensions,
    });
  }

  Future<void> _onStep3(
    FormStep3Submitted e,
    Emitter<PackageRequestFormState> emit,
  ) async {
    // Poids saisi pour un autre mode (route, puis retour à l'étape « Le
    // trajet » pour passer en avion) : refusé ici, sans rien effacer.
    if (!PackageRequestLimits.isWeightValidFor(
      state.weightKg,
      state.requestTransportMode,
    )) {
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.error,
          formError: PackageRequestFormError.weightTooHeavyForMode,
          clearDraftLimitMessage: true,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.packageRequestSubmitFailed,
          properties: {
            'error_code': 'weight-too-heavy-for-mode',
            'is_draft': e.saveAsDraft,
            'editing': state.editingRequestId != null,
          },
        ),
      );
      return;
    }
    // Bateau : les dimensions sont obligatoires (le back refuserait en 422
    // `boat-dimensions-required`). Cas d'un brouillon repris sans elles.
    if (ParcelDimensions.isRequiredFor(state.requestTransportMode) &&
        !state.hasDimensions) {
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.error,
          formError: PackageRequestFormError.dimensionsRequired,
          clearDraftLimitMessage: true,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.packageRequestSubmitFailed,
          properties: {
            'error_code': 'boat-dimensions-required',
            'is_draft': e.saveAsDraft,
            'editing': state.editingRequestId != null,
          },
        ),
      );
      return;
    }
    final totalBudgetEur = state.totalBudgetEur ?? e.targetPriceEur;
    if (totalBudgetEur == null) {
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.error,
          formError: PackageRequestFormError.budgetRequired,
          clearDraftLimitMessage: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: FormSubmissionStatus.submitting,
        targetPriceEur: totalBudgetEur,
        // Chaque nouvelle tentative repart d'un message de limite propre :
        // sinon un draftLimitMessage périmé d'une tentative précédente peut
        // survivre à côté d'un nouvel errorMessage générique posé par le
        // catch ci-dessous. Idem pour formError : sans ce clear, un
        // budgetRequired affiché une fois resterait lu par l'écran à la
        // tentative suivante, même après un succès serveur.
        clearDraftLimitMessage: true,
        clearFormError: true,
      ),
    );
    try {
      final editingId = state.editingRequestId;
      PackageRequest saved;
      if (editingId != null) {
        saved = await _repository.update(
          editingId,
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate,
          dateToleranceDays: state.desiredDate == null
              ? null
              : state.dateToleranceDays ?? 0,
          weightKg: state.weightKg!,
          categories: state.categories,
          parcelSize: state.parcelSize!,
          transportMode: state.requestTransportMode,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: totalBudgetEur,
          description: state.description,
          // null → conserver les photos existantes ; liste → remplacer l'ensemble.
          photoKeys: e.photoKeys,
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
          promoCode: _blankToNull(state.promoCode),
          // Taille non touchée : clé absente (le back la conserve) ; changée :
          // envoyée ; retirée : effacée côté back (`NONE`).
          itemSize: _itemSizeChange(),
          // Dimensions absentes : le back conserve celles de la demande (il
          // n'existe pas de moyen de les effacer en « peu importe »).
          lengthCm: _sentDimensions ? state.lengthCm : null,
          widthCm: _sentDimensions ? state.widthCm : null,
          heightCm: _sentDimensions ? state.heightCm : null,
        );
      } else {
        saved = await _repository.create(
          departureCity: state.departureCity!,
          arrivalCity: state.arrivalCity!,
          desiredDate: state.desiredDate,
          dateToleranceDays: state.desiredDate == null
              ? null
              : state.dateToleranceDays ?? 0,
          weightKg: state.weightKg!,
          categories: state.categories,
          parcelSize: state.parcelSize!,
          transportMode: state.requestTransportMode,
          negotiable: state.negotiable,
          acceptedPaymentMethods: state.acceptedPaymentMethods,
          totalBudgetEur: totalBudgetEur,
          description: state.description,
          photoKeys: e.photoKeys,
          // Le lieu de remise n'est plus saisi à la publication ; il ne
          // subsiste que sur les demandes déjà créées, et l'édition doit le
          // conserver au lieu de l'écraser.
          pickupNeighborhood: _blankToNull(state.pickupNeighborhood),
          deliveryNeighborhood: _blankToNull(state.deliveryNeighborhood),
          saveAsDraft: e.saveAsDraft,
          promoCode: _blankToNull(state.promoCode),
          // Devise choisie à l'étape budget. Absente → l'API retombe sur la
          // devise du portefeuille de l'expéditeur (jamais renvoyée en
          // édition : une demande déjà créée garde sa devise d'origine).
          currency: state.currency?.code,
          // Facultative : la clé ne part que renseignée.
          itemSize: state.itemSize,
          lengthCm: _sentDimensions ? state.lengthCm : null,
          widthCm: _sentDimensions ? state.widthCm : null,
          heightCm: _sentDimensions ? state.heightCm : null,
        );
      }
      if (!e.saveAsDraft && saved.status == PackageRequestStatus.draft) {
        saved = await _repository.publish(saved.id);
      }
      emit(
        state.copyWith(
          submissionStatus: FormSubmissionStatus.success,
          createdRequest: saved,
        ),
      );
      unawaited(
        _analytics.logEvent(
          editingId != null
              ? AnalyticsEvents.packageRequestUpdated
              : AnalyticsEvents.packageRequestCreated,
          properties: {
            'corridor': '${state.departureCity}→${state.arrivalCity}',
            'negotiable': state.negotiable,
            'payment_methods': state.acceptedPaymentMethods
                .map((m) => m.wireName)
                .toList(),
            'from_ai': _fromAi,
            // Un brouillon partait sous le même nom qu'une publication :
            // seul `success_screen_viewed.context` permettait de les séparer.
            'is_draft': saved.status == PackageRequestStatus.draft,
            'currency': saved.currency,
            'budget_bracket': analyticsAmountBracket(totalBudgetEur),
            'transport_mode': state.requestTransportMode?.name ?? _anyMode,
            if (state.parcelSize != null)
              'parcel_size': state.parcelSize!.wireName,
            if (state.itemSize != null) 'item_size': state.itemSize!.wire,
            if (state.modeKeepsDimensions) 'has_dimensions': _sentDimensions,
            'has_photos': (e.photoKeys ?? const []).isNotEmpty,
            'has_promo_code': _blankToNull(state.promoCode) != null,
          },
        ),
      );
    } catch (err) {
      final error = unwrapDioError(err);
      // Soumission refusée (limite de brouillons, KYC, réseau…) : l'échec
      // n'était visible qu'à l'écran.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.packageRequestSubmitFailed,
          properties: {
            'error_code': error.code ?? 'unknown',
            'is_draft': e.saveAsDraft,
            'editing': state.editingRequestId != null,
          },
        ),
      );
      if (error is ForbiddenException && error.code == 'draft-limit-reached') {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            draftLimitMessage: error.message,
            error: error,
          ),
        );
      } else {
        emit(
          state.copyWith(
            submissionStatus: FormSubmissionStatus.error,
            errorMessage: error.message,
            error: error,
          ),
        );
      }
    }
  }

  /// Les dimensions partent avec la demande : bateau ou « peu importe », les
  /// trois renseignées. Jamais pour l'avion ni la route.
  bool get _sentDimensions => state.modeKeepsDimensions && state.hasDimensions;

  void _onStepBack(FormStepBack e, Emitter<PackageRequestFormState> emit) {
    if (state.currentStep > 0) {
      emit(state.copyWith(currentStep: state.currentStep - 1));
    }
  }

  /// Peut-on encore décocher un mode de paiement ? La règle est lue ici et par
  /// l'écran, qui a besoin de la même réponse pour expliquer son refus.
  static bool canDeselectPaymentMethod(Set<PaymentMethod> selected) =>
      selected.length > 1;

  /// La devise borne les moyens de paiement : entrer en franc CFA retire la
  /// carte (le serveur la retirerait de toute façon) et coche le mobile money
  /// avec les espèces, l'expéditeur pouvant le décocher ensuite ; entre XOF
  /// et XAF le choix est conservé ; repasser en euro retire le mobile money.
  /// Le choix ne reste jamais vide : l'espèce est toujours possible.
  void _onCurrencyChanged(
    PackageRequestCurrencyChanged e,
    Emitter<PackageRequestFormState> emit,
  ) {
    final allowed = PaymentMethod.selectableIn(e.currency);
    final enteringCfa =
        e.currency.isMobileMoneyEligible &&
        !(state.currency?.isMobileMoneyEligible ?? false);
    final next = enteringCfa
        ? allowed.toSet()
        : state.acceptedPaymentMethods.where(allowed.contains).toSet();
    if (next.isEmpty) {
      next.add(PaymentMethod.cash);
    }
    emit(state.copyWith(currency: e.currency, acceptedPaymentMethods: next));
  }

  void _onPaymentMethodToggled(
    PackageRequestPaymentMethodToggled e,
    Emitter<PackageRequestFormState> emit,
  ) {
    final next = {...state.acceptedPaymentMethods};
    if (next.contains(e.method)) {
      // Décocher le dernier mode retenu était absorbé en silence : la case se
      // rendait décochée puis re-cochée, et le tap passait pour une panne. On
      // refuse explicitement, l'écran peut alors dire pourquoi.
      if (!canDeselectPaymentMethod(next)) return;
      next.remove(e.method);
    } else {
      next.add(e.method);
    }
    emit(state.copyWith(acceptedPaymentMethods: next));
  }
}
