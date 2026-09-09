import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_bloc.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/confirm_bid_payment.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid/payer_phone.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid/photo_section.dart';
import 'package:dony/features/matching/presentation/widgets/custom_items_section.dart';
import 'package:dony/features/matching/presentation/widgets/grid_item_selection_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/reimbursement_info_banner.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/presentation/payment_auth.dart';
import 'package:dony/features/payments/presentation/widgets/dony_payment_sheet.dart';
import 'package:dony/features/payments/presentation/widgets/payment_method_names.dart';
import 'package:dony/features/recipients/presentation/widgets/recipient_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _kAccentBorder = 3.0;

// ── Multi-step helpers ─────────────────────────────────────────────────────────

enum _FormStep { form, paymentPicker }

class _BtnConfig {
  const _BtnConfig({
    required this.label,
    required this.iconAsset,
    this.onPressed,
  });
  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
}

class _CollectedFormData {
  const _CollectedFormData({
    required this.weightKg,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
    this.gridItems,
    this.promoCode,
    this.photoKeys,
  });
  final double weightKg;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;
  final List<Map<String, dynamic>>? gridItems;
  final String? promoCode;
  final List<String>? photoKeys;
}

// ── Public API ─────────────────────────────────────────────────────────────────

/// Arguments de la route `/bids/new`.
///
/// Le mode négociation double la route plutôt que de la dupliquer : c'est le
/// même formulaire, avec en plus les articles hors grille et le prix proposé.
class CreateBidArgs {
  const CreateBidArgs({required this.announcement, this.negotiation = false});

  final AnnouncementModel announcement;
  final bool negotiation;
}

class CreateBidBottomSheet {
  static Future<void> show(
    BuildContext context, {
    required AnnouncementModel announcement,
    bool negotiation = false,
  }) => context.push<void>(
    '/bids/new',
    extra: CreateBidArgs(announcement: announcement, negotiation: negotiation),
  );
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class CreateBidScreen extends StatefulWidget {
  const CreateBidScreen({
    super.key,
    required this.announcement,
    this.negotiation = false,
  });

  final AnnouncementModel announcement;

  /// L'expéditeur propose son prix au lieu de payer le tarif affiché.
  /// Le trajet doit être `negotiable`, le backend en reste l'arbitre.
  final bool negotiation;

  @override
  State<CreateBidScreen> createState() => _CreateBidScreenState();
}

class _CreateBidScreenState extends State<CreateBidScreen> {
  // ── BLoCs (créés ici, fermés dans dispose) ──────────────────────────────────
  late final ValueNotifier<_BtnConfig?> _btnConfigNotifier;
  late final BidBloc _bidBloc;
  late final PaymentBloc _paymentBloc;
  late final BidPhotosCubit _photosCubit;

  /// Nul hors mode négociation : les écrans à prix ferme n'ont pas à exiger
  /// ce BLoC de leurs appelants (ni de leurs tests).
  late final BidNegotiationBloc? _negotiationBloc;

  // ── Mode négociation ────────────────────────────────────────────────────────
  /// Articles que le voyageur n'a pas tarifés, chiffrés par l'expéditeur.
  final _customItemsNotifier = ValueNotifier<List<BidCustomItemDraft>>([]);

  /// Prix global proposé. Pré-rempli avec la suggestion, puis libre.
  final _proposalCtrl = TextEditingController();

  /// Dernière suggestion écrite dans le champ. Sert à distinguer un champ
  /// resté au montant suggéré (à resynchroniser) d'une saisie de l'expéditeur
  /// (à ne jamais écraser).
  String _lastWrittenSuggestion = '';

  // ── Payment method availability ─────────────────────────────────────────────
  // Le mobile money direct est de retour comme moyen de paiement d'un bid,
  // porté par le nouveau rail pawaPay (BidPaymentMethod.mobileMoney, valeur
  // API MOBILE_MONEY) — distinct des anciens WAVE/ORANGE_MONEY, qui restent
  // retirés (backend : 422 mobile-money-bid-payment-retired).
  late final bool _isCashAvailable;
  // Trajets cash-only (publiés sans Stripe Connect) : la chip Stripe doit
  // disparaître et le mode par défaut doit basculer sur cash.
  late final bool _isStripeAvailable;
  // Mobile money (Orange Money, Wave, MTN…) via pawaPay — proposé dès que
  // l'annonce l'accepte (le backend restreint déjà pawaPay aux annonces
  // XOF/XAF à la création, rien à revérifier côté app).
  late final bool _isMobileMoneyAvailable;

  /// Numéro qui recevra la demande de paiement mobile money. Pré-rempli avec
  /// le téléphone de l'utilisateur connecté quand `AuthBloc` est accessible
  /// depuis ce contexte (toujours vrai dans l'app réelle — voir
  /// [_initialPayerPhone] pour le repli en test) ; toujours modifiable ou
  /// effaçable par l'expéditeur, jamais requis pour soumettre.
  late final TextEditingController _payerPhoneCtrl;

  /// Vrai quand [_initialPayerPhone] est vide (compte Yadony sans numéro de
  /// téléphone, vérification SMS pas encore configurée) : fait basculer le
  /// texte d'aide de [_PayerPhoneField], qui ne peut plus affirmer un
  /// pré-remplissage qui n'a pas eu lieu.
  late final bool _payerPhoneEmpty;

  // ── Form step fields ────────────────────────────────────────────────────────
  final _descCtrl = TextEditingController();
  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _recipientSection = RecipientSectionController();
  late final ValueNotifier<double> _weightNotifier;
  final _categoriesNotifier = ValueNotifier<Set<String>>({});
  // Seedé synchrone avec le catalogue embarqué (fallbackCatalog) — jamais
  // vide au premier frame — puis remplacé par le catalogue live du
  // repository dès qu'il répond (avec repli automatique hors ligne, voir
  // ContentCategoryRepository.getCategories()). Catégories complètes (emoji
  // inclus) pour alimenter le combobox de contenu.
  final _catalogNotifier = ValueNotifier<List<ContentCategory>>(
    fallbackCatalog,
  );
  final _disclaimerNotifier = ValueNotifier<bool>(false);
  final _gridQuantitiesNotifier = ValueNotifier<Map<String, int>>({});

  // ── Garde-fou de sortie ─────────────────────────────────────────────────────
  /// Signature du formulaire à l'ouverture. Nulle tant que les post-frames
  /// d'initialisation n'ont pas été purgés (cf. `_captureInitialSignature`).
  String? _initialSignature;

  /// Évite d'empiler deux dialogues si le retour système est répété.
  bool _confirmingExit = false;

  /// État saisissable de l'offre. Exclut la mécanique interne (étape courante,
  /// devis calculé, catalogue chargé en asynchrone).
  String get _formSignature => [
    _descCtrl.text,
    _recipientNameCtrl.text,
    _recipientPhoneCtrl.text,
    _promoCtrl.text,
    _weightNotifier.value,
    (_categoriesNotifier.value.toList()..sort()).join(','),
    _disclaimerNotifier.value,
    (_gridQuantitiesNotifier.value.entries
            .map((e) => '${e.key}:${e.value}')
            .toList()
          ..sort())
        .join(','),
    _methodNotifier.value,
    _photosCubit.state.length,
  ].join('|');

  // ── Multi-step state ────────────────────────────────────────────────────────
  final _stepNotifier = ValueNotifier<_FormStep>(_FormStep.form);
  _CollectedFormData? _formData;

  // ── Code promo ──────────────────────────────────────────────────────────────
  final _promoCtrl = TextEditingController();
  final _quoteNotifier = ValueNotifier<Object?>(null);

  // ── Picker step fields ──────────────────────────────────────────────────────
  // Initialisé dans initState : le défaut dépend de widget.announcement
  // (cash si le trajet n'accepte pas Stripe).
  late final ValueNotifier<BidPaymentMethod> _methodNotifier;

  double get _maxKg => widget.announcement.availableKg;

  /// Net voyageur. `null` seulement pour un lecteur anonyme (le backend
  /// masque le net) ; cet écran de création d'offre exige d'être connecté,
  /// donc `null` n'arrive pas en pratique, mais le type suit le modèle.
  double? get _pricePerKg => widget.announcement.pricePerKg;

  /// Grille pure (pas de prix/kg) : le contenu se déduit des articles
  /// choisis, l'expéditeur ne saisit plus de catégorie à la main. Un net
  /// absent compte comme « pas de tarif au kilo », même bucket que `0.0`.
  bool get _isGridOnly {
    final price = _pricePerKg;
    return widget.announcement.priceGridItems.isNotEmpty &&
        (price == null || price <= 0);
  }

  /// Libellés des articles de grille sélectionnés (quantité > 0), utilisés
  /// comme `contentCategory` en grille pure — remplace le combobox masqué.
  Set<String> get _gridDerivedCategories {
    final q = _gridQuantitiesNotifier.value;
    return {
      for (final item in widget.announcement.priceGridItems)
        if ((q[item.id] ?? 0) > 0) item.label,
    };
  }

  String get _contentCategoryValue =>
      (_isGridOnly ? _gridDerivedCategories : _categoriesNotifier.value).join(
        ', ',
      );

  List<String> get _acceptedCategories {
    final accepted = widget.announcement.acceptedContentTypes;
    if (accepted != null && accepted.isNotEmpty) return accepted;
    return _catalogNotifier.value.map((c) => c.label).toList();
  }

  List<String> get _refusedCategories =>
      widget.announcement.refusedTypes ?? const [];

  /// Mobile money ne compte comme « alternative » qu'en mode direct : le
  /// backend rejette toute négociation en mobile money (422
  /// mobile-money-negotiation-unsupported, `BidNegotiationService`) — en
  /// mode négociation, seul le cash reste une alternative à Stripe, comme
  /// avant la task 10 mobile money.
  bool get _hasAlternativePaymentMethods =>
      _isCashAvailable || (!widget.negotiation && _isMobileMoneyAvailable);

  @override
  void initState() {
    super.initState();
    _btnConfigNotifier = ValueNotifier<_BtnConfig?>(
      const _BtnConfig(label: 'Envoyer', iconAsset: 'send'),
    );
    _bidBloc = getIt<BidBloc>();
    _paymentBloc = getIt<PaymentBloc>();
    _photosCubit = getIt<BidPhotosCubit>();
    _negotiationBloc = widget.negotiation ? getIt<BidNegotiationBloc>() : null;

    // Une annonce n'offre que les moyens que sa devise autorise (pas de carte en
    // zone CFA, pas de mobile money ailleurs) : le backend filtre à l'écriture,
    // l'app n'affiche jamais un moyen qu'une demande ne pourra pas honorer.
    final accepted = widget.announcement.acceptedPaymentMethods;
    final currency = widget.announcement.currency;
    _isCashAvailable = accepted.contains(BidPaymentMethod.cash);
    _isStripeAvailable =
        accepted.contains(BidPaymentMethod.stripe) &&
        BidPaymentMethod.stripe.isAllowedIn(currency);
    _isMobileMoneyAvailable =
        accepted.contains(BidPaymentMethod.mobileMoney) &&
        BidPaymentMethod.mobileMoney.isAllowedIn(currency);
    _methodNotifier = ValueNotifier<BidPaymentMethod>(
      // En négociation, le mobile money n'est jamais un choix possible
      // (rejeté par le backend) : le défaut reste celui d'avant la task 10
      // mobile money, stripe sinon cash, jamais mobileMoney.
      widget.negotiation
          ? (_isStripeAvailable
                ? BidPaymentMethod.stripe
                : BidPaymentMethod.cash)
          : (_isStripeAvailable
                ? BidPaymentMethod.stripe
                : _isCashAvailable
                ? BidPaymentMethod.cash
                : BidPaymentMethod.mobileMoney),
    );
    final initialPayerPhone = _initialPayerPhone();
    _payerPhoneEmpty = initialPayerPhone.isEmpty;
    _payerPhoneCtrl = TextEditingController(text: initialPayerPhone);

    // Toujours 0 au départ, y compris en tarification kilo pure : la
    // grille et le kilo-libre partent aussi de 0 désormais. Sur un trajet
    // sans grille (kilo pur), le CTA reste désactivé tant que le poids n'est
    // pas > 0 — cf. `_syncFormButtonState` (weightOk = hasKgPricing &&
    // weight > 0) qui ne dépend pas de cette valeur de départ.
    _weightNotifier = ValueNotifier<double>(0.0);

    _weightNotifier.addListener(_syncFormButtonState);
    _categoriesNotifier.addListener(_syncFormButtonState);
    _disclaimerNotifier.addListener(_syncFormButtonState);
    _gridQuantitiesNotifier.addListener(_syncFormButtonState);

    _weightNotifier.addListener(_invalidateQuote);
    _gridQuantitiesNotifier.addListener(_invalidateQuote);

    _stepNotifier.addListener(_onStepChanged);
    _methodNotifier.addListener(_syncPickerButtonState);

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFormButtonState());

    if (widget.negotiation) {
      _customItemsNotifier.addListener(_syncProposal);
      _weightNotifier.addListener(_syncProposal);
      _gridQuantitiesNotifier.addListener(_syncProposal);
      _quoteNotifier.addListener(_syncProposal);
      _syncProposal();
      // L'ouverture du mode est un début d'entonnoir : elle se mesure même si
      // aucune proposition n'est finalement envoyée.
      _negotiationBloc!.add(
        BidNegotiationOpenRequested(widget.announcement.id),
      );
    }

    unawaited(_loadCatalog());
    for (final l in _dirtySources) {
      l.addListener(_recomputeDirty);
    }
    _photosSub = _photosCubit.stream.listen((_) => _recomputeDirty());
    _captureInitialSignature();
  }

  /// Numéro de l'utilisateur connecté, si `AuthBloc` est accessible depuis ce
  /// contexte. Dans l'app réelle il l'est toujours (fourni à la racine de
  /// `app.dart`) ; certains harnais de test ne le fournissent pas — dans ce
  /// cas (`ProviderNotFoundException`) le champ démarre simplement vide,
  /// jamais de plantage.
  String _initialPayerPhone() {
    try {
      return context.read<AuthBloc>().state.currentUser?.phoneNumber ?? '';
    } on ProviderNotFoundException {
      return '';
    }
  }

  /// Prend la référence de comparaison une fois les post-frames
  /// d'initialisation passés (le premier build en enregistre lui-même), pour
  /// qu'une feuille fraîchement ouverte ne soit jamais considérée comme
  /// saisie. Aucune saisie utilisateur ne tient en deux frames.
  void _captureInitialSignature() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initialSignature = _formSignature;
        _recomputeDirty();
      });
    });
  }

  /// Saleté observable. `PopScope.canPop` est lu au build : taper dans un
  /// champ ne provoquant aucun rebuild, sans ce notifier le garde-fou
  /// resterait figé sur sa valeur d'ouverture.
  final _isDirtyNotifier = ValueNotifier<bool>(false);

  void _recomputeDirty() {
    _isDirtyNotifier.value =
        _initialSignature != null && _formSignature != _initialSignature;
  }

  /// Tout ce que l'utilisateur peut saisir, pour brancher `_recomputeDirty`.
  List<Listenable> get _dirtySources => [
    _descCtrl,
    _recipientNameCtrl,
    _recipientPhoneCtrl,
    _promoCtrl,
    _weightNotifier,
    _categoriesNotifier,
    _disclaimerNotifier,
    _gridQuantitiesNotifier,
    _methodNotifier,
  ];

  /// Les photos vivent dans un `Cubit`, pas un `Listenable` : on suit son flux.
  StreamSubscription<void>? _photosSub;

  /// Sortie demandée depuis l'étape formulaire (croix ou retour système).
  Future<void> _handleExitRequest() async {
    if (!_isDirtyNotifier.value) {
      if (mounted) context.pop();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed = await DonyDialog.confirmDiscard(context);
    _confirmingExit = false;
    if (!mounted || confirmed != true) return;
    context.pop();
  }

  Future<void> _loadCatalog() async {
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (!mounted) return;
    _catalogNotifier.value = categories;
  }

  @override
  void dispose() {
    for (final l in _dirtySources) {
      l.removeListener(_recomputeDirty);
    }
    unawaited(_photosSub?.cancel());
    if (widget.negotiation) {
      _customItemsNotifier.removeListener(_syncProposal);
      _weightNotifier.removeListener(_syncProposal);
      _gridQuantitiesNotifier.removeListener(_syncProposal);
      _quoteNotifier.removeListener(_syncProposal);
      _negotiationBloc?.close();
    }
    _customItemsNotifier.dispose();
    _proposalCtrl.dispose();
    _isDirtyNotifier.dispose();
    _btnConfigNotifier.dispose();
    _bidBloc.close();
    _paymentBloc.close();
    _photosCubit.close();
    _descCtrl.dispose();
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _promoCtrl.dispose();
    _payerPhoneCtrl.dispose();
    _weightNotifier.removeListener(_syncFormButtonState);
    _categoriesNotifier.removeListener(_syncFormButtonState);
    _disclaimerNotifier.removeListener(_syncFormButtonState);
    _gridQuantitiesNotifier.removeListener(_syncFormButtonState);
    _weightNotifier.removeListener(_invalidateQuote);
    _gridQuantitiesNotifier.removeListener(_invalidateQuote);
    _stepNotifier.removeListener(_onStepChanged);
    _methodNotifier.removeListener(_syncPickerButtonState);
    _quoteNotifier.dispose();
    _weightNotifier.dispose();
    _categoriesNotifier.dispose();
    _catalogNotifier.dispose();
    _disclaimerNotifier.dispose();
    _gridQuantitiesNotifier.dispose();
    _stepNotifier.dispose();
    _methodNotifier.dispose();
    super.dispose();
  }

  // ── Button state sync ───────────────────────────────────────────────────────

  void _onStepChanged() {
    if (_stepNotifier.value == _FormStep.paymentPicker) {
      _syncPickerButtonState();
    } else {
      _syncFormButtonState();
    }
  }

  void _syncFormButtonState() {
    if (_stepNotifier.value != _FormStep.form) return;
    final kgPrice = widget.announcement.pricePerKg;
    final hasKgPricing = kgPrice != null && kgPrice > 0;
    final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
    final weightOk = hasKgPricing && _weightNotifier.value > 0;
    final gridOk = hasGridPricing && _gridQuantitiesNotifier.value.isNotEmpty;
    // En grille pure, le contenu se déduit des articles choisis (gridOk le
    // couvre déjà) — pas de combobox à remplir séparément.
    final categoriesOk = _isGridOnly || _categoriesNotifier.value.isNotEmpty;
    final canSubmit =
        (weightOk || gridOk) && categoriesOk && _disclaimerNotifier.value;

    if (widget.negotiation) {
      _btnConfigNotifier.value = _BtnConfig(
        label: 'Envoyer ma proposition',
        iconAsset: 'send',
        onPressed: canSubmit ? _submitNegotiation : null,
      );
      return;
    }

    _btnConfigNotifier.value = _BtnConfig(
      label: 'Envoyer',
      iconAsset: 'send',
      onPressed: canSubmit ? _goToPicker : null,
    );
  }

  void _syncPickerButtonState() {
    if (_stepNotifier.value != _FormStep.paymentPicker) return;
    final method = _methodNotifier.value;

    final String label;
    final String iconAsset;
    final total = _computeStripeTotal();
    if (method == BidPaymentMethod.cash) {
      // Le montant figure aussi sur le bouton espèces : c'est exactement la
      // somme à remettre en main propre, et la masquer laissait l'expéditeur
      // confirmer sans savoir combien il devra sortir. Même total qu'en carte —
      // en espèces le voyageur encaisse le brut, et Yadony prélève ensuite la
      // commission sur son solde.
      label =
          'Confirmer ${formatPriceIn(total, widget.announcement.currency)} en espèces';
      iconAsset = 'banknote';
    } else if (method == BidPaymentMethod.mobileMoney) {
      // Comme en espèces : cette étape ENVOIE seulement l'offre
      // (BidCreateRequested) — aucun paiement n'est bloqué avant que le
      // voyageur accepte. Le CTA ne doit donc jamais dire « Bloquer & payer »,
      // réservé au checkout Stripe immédiat.
      label =
          'Confirmer ${formatPriceIn(total, widget.announcement.currency)} par mobile money';
      iconAsset = 'smartphone';
    } else {
      label =
          'Bloquer ${formatPriceIn(total, widget.announcement.currency)} & payer';
      iconAsset = 'lock';
    }

    _btnConfigNotifier.value = _BtnConfig(
      label: label,
      iconAsset: iconAsset,
      onPressed: _confirmPayment,
    );
  }

  // ── Mode négociation ────────────────────────────────────────────────────────

  /// Total expéditeur calculé localement, sans attendre le devis serveur.
  double _localSenderTotal() {
    final price = _pricePerKg;
    final kg = (price != null && price > 0)
        ? netToSenderPrice(_weightNotifier.value * price)
        : 0.0;
    return kg + _gridDisplayTotal();
  }

  /// Prix suggéré : ce que coûterait le colis au tarif du voyageur, plus ce que
  /// l'expéditeur a lui-même chiffré hors grille. Le devis serveur prime dès
  /// qu'il existe (il porte les promos).
  double get _suggestedTotalEur {
    final quote = _quoteNotifier.value;
    final base = quote is BidQuoteResponse
        ? quote.totalEur
        : _localSenderTotal();
    return base + customItemsTotalEur(_customItemsNotifier.value);
  }

  /// Réaligne le champ sur la suggestion, sauf si l'expéditeur y a saisi son
  /// propre montant : sa proposition est le cœur de la négociation, la
  /// recalculer sous ses doigts serait la lui confisquer.
  void _syncProposal() {
    final next = _suggestedTotalEur.toStringAsFixed(2);
    if (_proposalCtrl.text.isNotEmpty &&
        _proposalCtrl.text != _lastWrittenSuggestion) {
      return;
    }
    _lastWrittenSuggestion = next;
    _proposalCtrl.text = next;
  }

  double? _readProposal() => parsePriceInput(_proposalCtrl.text);

  /// Première proposition. Le destinataire et le disclaimer sont demandés dès
  /// maintenant : décision produit assumée, le voyageur doit pouvoir juger le
  /// colis complet avant d'accepter un prix.
  void _submitNegotiation() {
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Description obligatoire');
      return;
    }
    if (_recipientNameCtrl.text.trim().isEmpty) {
      _showError('Nom du destinataire obligatoire');
      return;
    }
    if (_recipientPhoneCtrl.text.trim().isEmpty) {
      _showError('Téléphone du destinataire obligatoire');
      return;
    }
    final proposed = _readProposal();
    if (proposed == null) {
      _showError('Indiquez le prix que vous proposez');
      return;
    }

    _recipientSection.maybeSaveManualEntry();

    final weight = _weightNotifier.value;
    _negotiationBloc!.add(
      BidNegotiationProposeRequested(
        announcementId: widget.announcement.id,
        weightKg: weight > 0 ? weight : null,
        description: _descCtrl.text.trim(),
        contentCategory: _contentCategoryValue,
        recipientName: _recipientNameCtrl.text.trim(),
        recipientPhone: _recipientPhoneCtrl.text.trim(),
        proposedTotalEur: proposed,
        // Figé sur le bid dès la proposition : c'est ce mode que le back
        // appliquera à l'accord (carte → escrow à payer, espèces → commission
        // réglée par le voyageur). Sans lui, tout accord négocié partait en
        // carte, même sur un trajet qui n'acceptait que les espèces.
        paymentMethod: _methodNotifier.value,
        photoKeys: _photosCubit.readyKeys,
        customItems: _customItemsNotifier.value
            .map((item) => item.toJson())
            .toList(),
        gridItems: _selectedGridItems(),
      ),
    );
  }

  void _onNegotiationState(BuildContext context, BidNegotiationState state) {
    if (state is BidNegotiationLoaded &&
        state.action == BidNegotiationAction.proposed) {
      context.pop();
      DonySnackbar.show(
        context,
        message: 'Proposition envoyée, le voyageur va vous répondre.',
        type: DonySnackbarType.success,
      );
    } else if (state is BidNegotiationError) {
      unawaited(ErrorPresenter.show(context, state.error));
    }
  }

  double _computeStripeTotal() {
    final quote = _quoteNotifier.value;
    if (quote is BidQuoteResponse) return quote.totalEur;
    final data = _formData;
    if (data == null) return 0.0;
    final price = _pricePerKg;
    final kg = price == null ? 0.0 : data.weightKg * price;
    return netToSenderPrice(kg) + _gridDisplayTotal();
  }

  // ── Content helpers ─────────────────────────────────────────────────────────

  /// Sélection émise par le combobox de contenu. Les types refusés par le
  /// voyageur sont écartés en silence (le catalogue proposé ne les liste déjà
  /// pas, mais un ajout libre pourrait retomber sur un libellé refusé).
  void _onCategoriesChanged(List<String> labels) {
    final refusedLower = _refusedCategories.map((e) => e.toLowerCase()).toSet();
    _categoriesNotifier.value = labels
        .where((l) => !refusedLower.contains(l.toLowerCase()))
        .toSet();
  }

  List<Map<String, dynamic>>? _selectedGridItems() {
    final q = _gridQuantitiesNotifier.value;
    final items = <Map<String, dynamic>>[];
    for (final item in widget.announcement.priceGridItems) {
      final qty = q[item.id] ?? 0;
      if (qty > 0) {
        items.add({'announcementGridItemId': item.id, 'quantity': qty});
      }
    }
    return items.isEmpty ? null : items;
  }

  double _gridDisplayTotal() {
    final q = _gridQuantitiesNotifier.value;
    return widget.announcement.priceGridItems.fold<double>(
      0,
      (sum, item) => sum + item.unitPriceDisplay * (q[item.id] ?? 0),
    );
  }

  void _applyPromoCode() {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      _quoteNotifier.value = null;
      return;
    }
    final weight = _weightNotifier.value;
    _bidBloc.add(
      BidQuoteRequested(
        announcementId: widget.announcement.id,
        weightKg: weight > 0 ? weight : null,
        promoCode: code,
        gridItems: _selectedGridItems(),
      ),
    );
  }

  void _invalidateQuote() {
    if (_quoteNotifier.value != null) _quoteNotifier.value = null;
  }

  // ── Step navigation ─────────────────────────────────────────────────────────

  void _goToPicker() {
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Description obligatoire');
      return;
    }
    if (_recipientNameCtrl.text.trim().isEmpty) {
      _showError('Nom du destinataire obligatoire');
      return;
    }
    if (_recipientPhoneCtrl.text.trim().isEmpty) {
      _showError('Téléphone du destinataire obligatoire');
      return;
    }

    // Validation passed — save the manually-entered recipient now, while
    // RecipientSection is still mounted. Unlike the single-step hosts, this
    // screen swaps the form step out for the payment-picker step via
    // AnimatedSwitcher when alternative payment methods are available,
    // which disposes RecipientSection (and clears its save hook) before
    // BidCreated/BidCheckoutReady ever arrive.
    _recipientSection.maybeSaveManualEntry();

    final promoCode = _promoCtrl.text.trim().isNotEmpty
        ? _promoCtrl.text.trim()
        : null;
    _formData = _CollectedFormData(
      weightKg: _weightNotifier.value,
      description: _descCtrl.text.trim(),
      contentCategory: _contentCategoryValue,
      recipientName: _recipientNameCtrl.text.trim(),
      recipientPhone: _recipientPhoneCtrl.text.trim(),
      gridItems: _selectedGridItems(),
      promoCode: promoCode,
      photoKeys: _photosCubit.readyKeys,
    );

    if (!_hasAlternativePaymentMethods) {
      _confirmPayment();
      return;
    }

    _stepNotifier.value = _FormStep.paymentPicker;
  }

  void _confirmPayment() {
    final data = _formData;
    if (data == null) return;
    final method = _methodNotifier.value;

    if (method == BidPaymentMethod.cash ||
        method == BidPaymentMethod.mobileMoney) {
      _bidBloc.add(
        BidCreateRequested(
          announcementId: widget.announcement.id,
          weightKg: data.weightKg,
          description: data.description,
          contentCategory: data.contentCategory,
          recipientName: data.recipientName,
          recipientPhone: data.recipientPhone,
          paymentMethod: method,
          phoneNumber: method == BidPaymentMethod.mobileMoney
              ? normalizePayerPhone(_payerPhoneCtrl.text)
              : null,
          promoCode: data.promoCode,
          gridItems: data.gridItems,
          photoKeys: data.photoKeys,
        ),
      );
    } else {
      _bidBloc.add(
        BidCheckoutRequested(
          announcementId: widget.announcement.id,
          weightKg: data.weightKg,
          description: data.description,
          contentCategory: data.contentCategory,
          recipientName: data.recipientName,
          recipientPhone: data.recipientPhone,
          gridItems: data.gridItems,
          photoKeys: data.photoKeys,
        ),
      );
    }
  }

  void _showError(String message) {
    DonySnackbar.show(context, message: message, type: DonySnackbarType.error);
  }

  // ── BLoC listeners ──────────────────────────────────────────────────────────

  void _onBidState(BuildContext context, BidState state) {
    if (state is BidCreated) {
      context.pop();
      if (context.mounted) {
        _showOfflinePaymentSuccess(context, state.bid);
      }
    } else if (state is BidCheckoutReady) {
      context.read<PaymentBloc>().add(
        BidCheckoutPaymentRequested(
          clientSecret: state.response.clientSecret,
          publishableKey: state.response.publishableKey,
          bidId: state.response.bidId,
          amountEur: _computeStripeTotal(),
          currencyCode: state.response.currency,
          paymentMethodTypes: state.response.paymentMethodTypes,
        ),
      );
    } else if (state is BidQuoteLoaded) {
      _quoteNotifier.value = state.quote;
    } else if (state is BidPromoError) {
      _quoteNotifier.value = state.error.message;
      ErrorPresenter.show(context, state.error);
    } else if (state is BidError) {
      ErrorPresenter.show(context, state.error);
    }
  }

  /// Affiche l'écran de succès pour une offre créée en CASH/Wave/Orange Money.
  ///
  /// À ce stade le bid est PENDING : le voyageur n'a pas encore accepté.
  /// Le message doit donc parler d'une offre ENVOYÉE, pas d'un paiement
  /// effectué, et expliquer ce qui se passera pour le moyen de paiement choisi.
  void _showOfflinePaymentSuccess(BuildContext context, BidModel bid) {
    const title = 'Offre envoyée !';
    final subtitle = switch (bid.paymentMethod) {
      BidPaymentMethod.cash =>
        'Paiement en espèces : si le voyageur accepte, tu remets le montant '
            'en main propre à la remise du colis. En cas d\'annulation après la '
            'remise, Yadony ne peut pas te rembourser immédiatement mais '
            's\'assurera que le voyageur te restitue ton argent.',
      BidPaymentMethod.mobileMoney =>
        'Paiement mobile money : si le voyageur accepte, tu recevras une '
            'notification et auras 30 minutes pour valider le paiement sur '
            'ton téléphone. Le montant est gardé en sécurité par Yadony '
            'jusqu\'à la livraison.',
      _ => 'Le voyageur va examiner ta demande.',
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        // Le contexte de CreateBidScreen vient d'être poppé — au moment
        // du tap CTA son element est désactivé et GoRouter.of(context)
        // jetterait « Looking up a deactivated widget's ancestor is
        // unsafe ». On navigue donc via le contexte de la route succès,
        // toujours monté sous le Navigator racine.
        builder: (routeContext) => DonySuccessScreen(
          mascotteType: DonyMascotteType.succes,
          title: title,
          subtitle: subtitle,
          ctaLabel: 'Voir mon envoi',
          onCta: () => routeContext.go('/bids/${bid.id}?from=payment'),
          analyticsContext: 'bid_created_offline_payment',
        ),
      ),
    );
  }

  Future<void> _onPaymentState(BuildContext context, PaymentState state) async {
    if (state is CheckoutPaymentSheetReady) {
      await _presentPaymentSheet(context, state);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return MultiBlocProvider(
      providers: [
        BlocProvider<BidBloc>.value(value: _bidBloc),
        BlocProvider<PaymentBloc>.value(value: _paymentBloc),
        BlocProvider<BidPhotosCubit>.value(value: _photosCubit),
      ],
      // Un seul builder pour les deux signaux : le fichier utilise déjà cet
      // idiome plus bas, et deux ValueListenableBuilder imbriqués ajoutaient
      // un niveau d'indentation sans rien apporter.
      child: ListenableBuilder(
        listenable: Listenable.merge([_stepNotifier, _isDirtyNotifier]),
        builder: (context, _) {
          final step = _stepNotifier.value;
          return PopScope(
            // À l'étape paiement, le retour revient au formulaire. À l'étape
            // formulaire il ferme la feuille : on ne l'autorise directement que
            // si rien n'a été saisi.
            canPop: step == _FormStep.form && !_isDirtyNotifier.value,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (step != _FormStep.form) {
                _stepNotifier.value = _FormStep.form;
              } else {
                unawaited(_handleExitRequest());
              }
            },
            child: Scaffold(
              backgroundColor: cs.surface,
              appBar: AppBar(
                backgroundColor: cs.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: DonyAppBarBackButton(
                  onBack: () {
                    if (step == _FormStep.paymentPicker) {
                      _stepNotifier.value = _FormStep.form;
                    } else {
                      unawaited(_handleExitRequest());
                    }
                  },
                ),
                title: Text(
                  // « Faire une demande », comme le bouton qui ouvre cette
                  // feuille. « Publier un colis » désigne ailleurs la
                  // publication d'une demande publique, ouverte à tous les
                  // voyageurs — pas l'envoi d'une demande à celui-ci.
                  step == _FormStep.paymentPicker
                      ? 'Paiement'
                      : 'Faire une demande',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: false,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(height: 1, color: cs.outlineVariant),
                ),
              ),
              resizeToAvoidBottomInset: true,
              // La CTA sticky est dans `body` (pas `bottomNavigationBar`) :
              // Flutter ne remonte pas fiablement `bottomNavigationBar`
              // au-dessus du clavier, ce qui la cachait derrière sur ce
              // formulaire (description, destinataire...). Même fix que
              // phone_auth_screen.dart.
              body: Column(
                children: [
                  Expanded(
                    child: MultiBlocListener(
                      listeners: [
                        BlocListener<BidBloc, BidState>(listener: _onBidState),
                        BlocListener<PaymentBloc, PaymentState>(
                          listener: _onPaymentState,
                        ),
                        if (_negotiationBloc != null)
                          BlocListener<BidNegotiationBloc, BidNegotiationState>(
                            bloc: _negotiationBloc,
                            listener: _onNegotiationState,
                          ),
                      ],
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.xl,
                          DonySpacing.lg,
                          DonySpacing.xxl,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: step == _FormStep.paymentPicker
                              ? _buildPickerStep(context)
                              : _buildFormStep(context),
                        ),
                      ),
                    ),
                  ),
                  _StickyBottom(
                    btnConfigNotifier: _btnConfigNotifier,
                    bidBloc: _bidBloc,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Form step ───────────────────────────────────────────────────────────────

  Widget _buildFormStep(BuildContext context) {
    return ListenableBuilder(
      key: const ValueKey('form'),
      listenable: Listenable.merge([
        _weightNotifier,
        _categoriesNotifier,
        _disclaimerNotifier,
        _gridQuantitiesNotifier,
      ]),
      builder: (context, _) {
        final weightKg = _weightNotifier.value;
        final disclaimerAccepted = _disclaimerNotifier.value;
        final gridQuantities = _gridQuantitiesNotifier.value;
        final hasGridPricing = widget.announcement.priceGridItems.isNotEmpty;
        final kgPrice = widget.announcement.pricePerKg;
        final hasKgPricing = kgPrice != null && kgPrice > 0;

        final gridTotal = hasGridPricing
            ? widget.announcement.priceGridItems.fold<double>(
                0,
                (sum, item) =>
                    sum +
                    item.unitPriceDisplay * (gridQuantities[item.id] ?? 0),
              )
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Articles grille ───────────────────────────────────────────
            if (hasGridPricing) ...[
              const _SectionLabel(label: 'ARTICLES'),
              const SizedBox(height: DonySpacing.sm),
              ValueListenableBuilder<Map<String, int>>(
                valueListenable: _gridQuantitiesNotifier,
                builder: (context, quantities, _) {
                  final totalSelected = quantities.values.fold<int>(
                    0,
                    (s, q) => s + q,
                  );
                  final subtotal = widget.announcement.priceGridItems
                      .fold<double>(
                        0.0,
                        (s, item) =>
                            s +
                            item.unitPriceDisplay * (quantities[item.id] ?? 0),
                      );
                  final hasSelection = quantities.isNotEmpty;
                  final cs = Theme.of(context).colorScheme;
                  final tt = Theme.of(context).textTheme;

                  return GestureDetector(
                    onTap: () async {
                      final result = await GridItemSelectionSheet.show(
                        context,
                        items: widget.announcement.priceGridItems,
                        initialQuantities: quantities,
                        corridor:
                            '${widget.announcement.departureCity} → ${widget.announcement.arrivalCity}',
                        currency: widget.announcement.currency,
                      );
                      if (result != null) {
                        _gridQuantitiesNotifier.value = result;
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: double.infinity,
                      padding: const EdgeInsets.all(DonySpacing.base),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(DonyRadius.card),
                        border: hasSelection
                            ? Border.all(color: cs.success, width: 1.5)
                            : Border.all(color: cs.warning, width: 1.5),
                      ),
                      child: hasSelection
                          ? Row(
                              children: [
                                DonyIcon(
                                  'circle-check',
                                  color: cs.success,
                                  size: 18,
                                ),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$totalSelected article${totalSelected > 1 ? 's' : ''} sélectionné${totalSelected > 1 ? 's' : ''}',
                                        style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Sous-total : ${formatPriceIn(subtotal, widget.announcement.currency)}',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Modifier',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const DonyEmoji.parcel(size: 18),
                                const SizedBox(width: DonySpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Choisir mes articles',
                                        key: const Key('choose-articles-btn'),
                                        style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Requis : au moins 1 article',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DonyIcon(
                                  'chevron-right',
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: DonySpacing.xxl),
            ],

            // ── Poids ─────────────────────────────────────────────────────
            if (hasKgPricing) ...[
              _WeightSection(
                weightKg: weightKg,
                maxKg: _maxKg,
                isMixed: hasGridPricing,
                isKgFree: widget.announcement.isKgFree,
                onChanged: (v) => _weightNotifier.value = v,
              ).animate().fadeIn(duration: 250.ms),
              const SizedBox(height: DonySpacing.xxl),
            ],

            // ── Contenu ───────────────────────────────────────────────────
            // Masqué en grille pure : le contenu se déduit des articles
            // choisis ci-dessus (cf. `_contentCategoryValue`), pas besoin de
            // le ressaisir dans un combobox séparé.
            if (!_isGridOnly) ...[
              ListenableBuilder(
                listenable: Listenable.merge([
                  _categoriesNotifier,
                  _catalogNotifier,
                ]),
                builder: (_, _) =>
                    _buildContentSection(context, _categoriesNotifier.value),
              ),
              const SizedBox(height: DonySpacing.xxl),
            ],

            // ── Photos ────────────────────────────────────────────────────
            const _SectionLabel(label: 'PHOTOS DU COLIS (OPTIONNEL)'),
            const SizedBox(height: DonySpacing.md),
            const PhotoSection(),
            const SizedBox(height: DonySpacing.xxl),

            // ── Description ───────────────────────────────────────────────
            const _SectionLabel(label: 'DESCRIPTION (AU VOYAGEUR)'),
            const SizedBox(height: DonySpacing.sm),
            DonyTextField(
              controller: _descCtrl,
              hint: 'Médicaments pour diabète + 2 tee-shirts enfants',
              maxLines: 4,
              minLines: 2,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Politique de remboursement ────────────────────────────────
            const ReimbursementInfoBanner().animate().fadeIn(delay: 140.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Destinataire ──────────────────────────────────────────────
            const _SectionLabel(label: 'DESTINATAIRE'),
            const SizedBox(height: DonySpacing.md),
            RecipientSection(
              controller: _recipientSection,
              nameCtrl: _recipientNameCtrl,
              phoneCtrl: _recipientPhoneCtrl,
              fallbackCity: widget.announcement.arrivalCity,
              fallbackCountry: widget.announcement.arrivalCountryCode,
              children: [
                DonyTextField(
                  controller: _recipientNameCtrl,
                  label: 'Prénom et nom du destinataire',
                  hint: 'ex: Amadou Diallo',
                ).animate().fadeIn(delay: 160.ms),
                const SizedBox(height: DonySpacing.md),
                DonyTextField(
                  controller: _recipientPhoneCtrl,
                  label: 'Téléphone du destinataire',
                  hint: 'ex: +221 77 000 00 00',
                  keyboardType: TextInputType.phone,
                ).animate().fadeIn(delay: 180.ms),
              ],
            ),
            const SizedBox(height: DonySpacing.xxl),

            // ── Disclaimer ────────────────────────────────────────────────
            _DisclaimerCard(
              accepted: disclaimerAccepted,
              onChanged: (v) => _disclaimerNotifier.value = v,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Code promo ────────────────────────────────────────────────
            const _SectionLabel(label: 'CODE PROMO (OPTIONNEL)'),
            const SizedBox(height: DonySpacing.sm),
            BlocBuilder<BidBloc, BidState>(
              bloc: _bidBloc,
              builder: (context, bidState) {
                final isQuoteLoading = bidState is BidQuoteLoading;
                return ValueListenableBuilder<Object?>(
                  valueListenable: _quoteNotifier,
                  builder: (_, quoteVal, _) {
                    final quote = quoteVal is BidQuoteResponse
                        ? quoteVal
                        : null;
                    final promoError = quoteVal is String ? quoteVal : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _promoCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Ex: WELCOME10',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: DonySpacing.base,
                                    vertical: DonySpacing.md,
                                  ),
                                  suffixIcon: isQuoteLoading
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                onFieldSubmitted: (_) => _applyPromoCode(),
                              ),
                            ),
                            const SizedBox(width: DonySpacing.sm),
                            SizedBox(
                              height: 52,
                              width: 110,
                              child: FilledButton(
                                onPressed: isQuoteLoading
                                    ? null
                                    : _applyPromoCode,
                                child: const Text('Appliquer'),
                              ),
                            ),
                          ],
                        ),
                        if (quote != null && quote.promoApplied) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Row(
                            children: [
                              const DonyIcon(
                                'circle-check',
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  quote.promoLabel ?? 'Code appliqué',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (promoError != null) ...[
                          const SizedBox(height: DonySpacing.xs),
                          Row(
                            children: [
                              const DonyIcon(
                                'circle-alert',
                                size: 16,
                                color: Color(0xFFE53935),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  promoError,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFE53935),
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ).animate().fadeIn(delay: 220.ms),
            const SizedBox(height: DonySpacing.xxl),

            // ── Prix live ─────────────────────────────────────────────────
            ValueListenableBuilder<Object?>(
              valueListenable: _quoteNotifier,
              builder: (_, quoteVal, _) {
                final quote = quoteVal is BidQuoteResponse ? quoteVal : null;
                final kgDisplayLocal = hasKgPricing
                    ? netToSenderPrice(weightKg * kgPrice)
                    : 0.0;
                final localTotal = kgDisplayLocal + gridTotal;

                // Tout le récapitulatif est exprimé du point de vue de
                // l'EXPÉDITEUR, commission comprise. C'est la somme qu'il
                // remettra dans les deux modes : en carte il règle le brut à
                // Yadony, en espèces il remet ce même brut au voyageur, sur le
                // solde duquel Yadony prélève ensuite sa commission. Le net du
                // voyageur ne doit apparaître nulle part ici — il n'appartient
                // qu'au voyageur.
                double kgNet = hasKgPricing ? weightKg * kgPrice : 0.0;
                double gridNet = hasGridPricing
                    ? gridTotal / donyCommissionMultiplier
                    : 0.0;
                double total = localTotal;
                double? original;
                bool promoApplied = false;
                if (quote != null) {
                  kgNet = quote.kgNetEur;
                  gridNet = quote.gridNetEur;
                  total = quote.totalEur;
                  promoApplied = quote.promoApplied;
                  original = promoApplied ? localTotal : null;
                }
                // Les lignes se répartissent le TOTAL au prorata des parts
                // nettes, plutôt que d'appliquer un taux : sous promo, le taux
                // porté par le devis n'est pas toujours celui qui produit le
                // total, et les lignes ne sommeraient plus au montant annoncé.
                // Partir du total garantit l'égalité dans tous les cas.
                final netTotal = kgNet + gridNet;
                final kgLine = netTotal > 0 ? total * (kgNet / netTotal) : 0.0;
                final gridLine = netTotal > 0
                    ? total * (gridNet / netTotal)
                    : 0.0;
                if (total <= 0) return const SizedBox.shrink();
                return _PriceBreakdown(
                  weightKg: weightKg,
                  // Tarif/kg dérivé de la ligne expéditeur, jamais lu sur
                  // l'annonce : sous promo le taux diffère du taux global, et
                  // « 5 kg × tarif » doit toujours valoir la ligne affichée.
                  // Miroir de pricePerKgSenderEur côté backend (brut / poids).
                  // Repli jamais rendu : `_PriceBreakdown` n'affiche cette
                  // valeur que si `weightKg > 0` (cf. sa méthode `build`), donc
                  // `0` ici ne mentira jamais à l'écran.
                  pricePerKg: weightKg > 0
                      ? kgLine / weightKg
                      : (widget.announcement.senderPricePerKg ?? 0),
                  kgDisplay: kgLine,
                  gridDisplay: gridLine,
                  totalPrice: total,
                  originalTotal: original,
                  promoApplied: promoApplied,
                  currency: widget.announcement.currency,
                );
              },
            ),
            if (widget.negotiation) ...[
              const SizedBox(height: DonySpacing.xxl),
              CustomItemsSection(
                notifier: _customItemsNotifier,
                currencyCode: widget.announcement.currency,
              ),
              const SizedBox(height: DonySpacing.xxl),
              _buildProposalSection(context),
              if (_hasAlternativePaymentMethods) ...[
                const SizedBox(height: DonySpacing.xxl),
                _buildNegotiationPaymentSection(context),
              ],
            ],
            const SizedBox(height: DonySpacing.md),
          ],
        );
      },
    );
  }

  /// Champ de prix proposé, avec le rappel de la suggestion juste en dessous :
  /// l'expéditeur doit voir en permanence de quoi il s'écarte.
  Widget _buildProposalSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'VOTRE PROPOSITION'),
        const SizedBox(height: DonySpacing.sm),
        DonyTextField(
          key: const Key('negotiation-proposal-field'),
          controller: _proposalCtrl,
          label:
              'Prix proposé (${SupportedCurrency.symbolOf(widget.announcement.currency)})',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: DonySpacing.xs),
        ListenableBuilder(
          listenable: Listenable.merge([
            _customItemsNotifier,
            _weightNotifier,
            _gridQuantitiesNotifier,
            _quoteNotifier,
          ]),
          builder: (context, _) => Text(
            'Suggéré : ${formatPriceIn(_suggestedTotalEur, widget.announcement.currency)}',
            key: const Key('negotiation-suggested-hint'),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Choix du mode de paiement en mode négociation.
  ///
  /// Le flux ferme passe par l'étape « Paiement » (montants, promo, wallet),
  /// sans objet ici : le prix n'est pas encore connu. Le mode, lui, doit être
  /// figé dès la proposition, parmi ceux que le trajet accepte. Affiché
  /// seulement quand il y a un vrai choix (carte ET espèces).
  Widget _buildNegotiationPaymentSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'MODE DE PAIEMENT'),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Si le voyageur accepte votre prix, vous réglerez de cette façon.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
        ValueListenableBuilder<BidPaymentMethod>(
          valueListenable: _methodNotifier,
          builder: (context, method, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // R13 : le backend rejette toute négociation en mobile money
              // (422 mobile-money-negotiation-unsupported,
              // BidNegotiationService) — décision produit « offres
              // classiques seulement ». `isMobileMoneyAvailable` n'est donc
              // jamais passé ici (garde son défaut `false`), contrairement au
              // site direct (_buildPickerStep) qui passe
              // _isMobileMoneyAvailable.
              _PaymentMethodSelector(
                selectedMethod: method,
                onChanged: (m) => _methodNotifier.value = m,
                isCashAvailable: _isCashAvailable,
                isStripeAvailable: _isStripeAvailable,
              ),
              if (method == BidPaymentMethod.cash) ...[
                const SizedBox(height: DonySpacing.sm),
                const _CashEscrowWarning(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context, Set<String> categories) {
    final accepted = _acceptedCategories;
    final refused = _refusedCategories;
    // Catalogue proposé = uniquement ce que CE voyageur accepte (avec emoji).
    // Un libellé accepté hors catalogue embarqué retombe sur 📦.
    final catalog = _catalogNotifier.value;
    final acceptedCatalog = [
      for (final label in accepted)
        catalog.firstWhere(
          (c) => c.label == label,
          orElse: () => ContentCategory(
            code: 'CUSTOM',
            label: label,
            emoji: emojiForLabel(label),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'CONTENU DU COLIS'),
        const SizedBox(height: DonySpacing.md),
        // Auto-suggestion (même composant que la feuille de filtres) : le
        // voyageur choisit le contenu de son colis avant la demande. Multi-
        // sélection, ajout libre autorisé, tags supprimables au-dessus.
        ContentCategoryComboBox(
          catalog: acceptedCatalog,
          selected: categories.toList(),
          onChanged: _onCategoriesChanged,
          hint: 'Rechercher un type de contenu…',
          keyPrefix: 'bid-content',
          // L'expéditeur peut toujours saisir un contenu hors de la liste
          // proposée par le voyageur (sauf types explicitement refusés).
          alwaysAllowCustom: true,
        ).animate().fadeIn(delay: 60.ms),
        const SizedBox(height: DonySpacing.sm),
        const _ContentHint(
          text:
              'Ces suggestions sont les contenus acceptés par le '
              'voyageur. Si le contenu de votre colis n\'y figure pas, '
              'ajoutez-le : ce sera au voyageur de décider s\'il accepte '
              'votre colis ou non.',
        ).animate().fadeIn(delay: 90.ms),
        if (refused.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.md),
          const _SectionLabel(label: 'REFUSÉ PAR LE VOYAGEUR'),
          const SizedBox(height: DonySpacing.sm),
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: [for (final cat in refused) _RefusedChip(label: cat)],
          ),
        ],
      ],
    );
  }

  // ── Picker step ─────────────────────────────────────────────────────────────

  Widget _buildPickerStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Même somme que sur le bouton collant (_syncPickerButtonState) : la carte
    // ouverte et le CTA ne doivent jamais annoncer deux montants différents.
    final total = _computeStripeTotal();

    return Column(
      key: const ValueKey('picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment veux-tu payer ?',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Choisis le mode de paiement pour cette demande.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.lg),

        // Une carte par mode ; celle qu'on touche s'ouvre sur sa conséquence
        // (montant, ce qu'il advient de l'argent, champs propres au mode).
        ValueListenableBuilder<BidPaymentMethod>(
          valueListenable: _methodNotifier,
          builder: (context, method, _) => _PaymentMethodSelector(
            selectedMethod: method,
            onChanged: (m) => _methodNotifier.value = m,
            isCashAvailable: _isCashAvailable,
            isStripeAvailable: _isStripeAvailable,
            isMobileMoneyAvailable: _isMobileMoneyAvailable,
            total: total,
            currency: widget.announcement.currency,
            payerPhoneController: _payerPhoneCtrl,
            hasProfilePhone: !_payerPhoneEmpty,
          ),
        ),

        const SizedBox(height: DonySpacing.md),
      ],
    ).animate().fadeIn(duration: 220.ms);
  }

  // ── Stripe payment sheet ────────────────────────────────────────────────────

  Future<void> _presentPaymentSheet(
    BuildContext context,
    CheckoutPaymentSheetReady state,
  ) async {
    final authenticated = await requirePaymentAuth(
      context,
      authService: getIt<LocalAuthService>(),
      userPrefs: getIt<HiveService>().userPrefs,
    );
    if (!context.mounted) return;
    if (!authenticated) {
      _showError('Paiement non confirmé, réessayez');
      return;
    }

    await DonyPaymentSheet.show(
      context,
      config: PaymentSheetConfig(
        clientSecret: state.clientSecret,
        amountEur: state.amountEur,
        currencyCode: state.currencyCode,
        paymentMethodTypes: state.paymentMethodTypes,
      ),
      contextLabel: 'Envoi vers ${widget.announcement.arrivalCity}',
      onSuccess: () async {
        // AUCUNE garde `context.mounted` avant la confirmation : elle ne
        // dépend d'aucun BuildContext, et la subordonner au montage de l'écran
        // rejouerait le bug corrigé ici (bid resté AWAITING_PAYMENT côté
        // serveur alors que l'escrow Stripe est actif). Seul le `pop` est
        // conditionné au montage, juste en dessous.
        await confirmBidPaymentSafely(state.bidId);
        if (!context.mounted) return;
        context.pop();
        if (context.mounted) {
          // unawaited : l'écran de succès vit sa propre vie, on ne bloque pas
          // la fermeture de la feuille de paiement sur sa durée d'affichage.
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute(
                // Le contexte de CreateBidScreen vient d'être poppé — au moment
                // du tap CTA son element est désactivé et GoRouter.of(context)
                // jetterait « Looking up a deactivated widget's ancestor is
                // unsafe ». On navigue donc via le contexte de la route succès,
                // toujours monté sous le Navigator racine.
                builder: (routeContext) => DonySuccessScreen(
                  mascotteType: DonyMascotteType.securise,
                  title: 'Offre payée !',
                  subtitle:
                      'Ton paiement est bloqué et sécurisé jusqu\'à la livraison confirmée. Le voyageur est notifié de ta demande.',
                  ctaLabel: 'Voir mon envoi',
                  onCta: () =>
                      routeContext.go('/bids/${state.bidId}?from=payment'),
                  analyticsContext: 'bid_payment',
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

// ── Sticky bottom (bottomNavigationBar) ────────────────────────────────────────

class _StickyBottom extends StatelessWidget {
  const _StickyBottom({required this.btnConfigNotifier, required this.bidBloc});

  final ValueNotifier<_BtnConfig?> btnConfigNotifier;
  final BidBloc bidBloc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return ValueListenableBuilder<_BtnConfig?>(
      valueListenable: btnConfigNotifier,
      builder: (ctx, config, _) => BlocBuilder<BidBloc, BidState>(
        bloc: bidBloc,
        builder: (ctx, state) {
          final isLoading = state is BidLoading;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.lg,
              bottomInset + DonySpacing.md,
            ),
            child: DonyButton(
              key: const Key('bid-submit-btn'),
              label: config?.label ?? 'Envoyer',
              iconAsset: config?.iconAsset ?? 'send',
              isLoading: isLoading,
              onPressed: isLoading ? null : config?.onPressed,
            ),
          );
        },
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}

// ── Content hint ───────────────────────────────────────────────────────────────

/// Note explicative sous le sélecteur de contenu : rappelle que les
/// suggestions sont les contenus acceptés par le voyageur, et qu'un contenu
/// libre reste possible (soumis à l'accord du voyageur).
class _ContentHint extends StatelessWidget {
  const _ContentHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyIcon('info', size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Weight section with slider ─────────────────────────────────────────────────

class _WeightSection extends StatefulWidget {
  const _WeightSection({
    required this.weightKg,
    required this.maxKg,
    required this.onChanged,
    this.isMixed = false,
    this.isKgFree = false,
  });

  final double weightKg;
  final double maxKg;
  final ValueChanged<double> onChanged;
  final bool isMixed;
  final bool isKgFree;

  @override
  State<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<_WeightSection> {
  TextEditingController? _kgCtrl;
  FocusNode? _kgFocus;

  // Le plancher de saisie est toujours 0 : sur un trajet kilo pur (non
  // mixte), le poids reste obligatoire pour envoyer (cf. `weightOk` dans
  // `_syncFormButtonState`), mais c'est le CTA qui l'impose, pas le champ —
  // l'utilisateur doit pouvoir revenir à 0 en le vidant/décrémentant.
  double get _min => 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.isKgFree) {
      _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(0));
      _kgFocus = FocusNode()..addListener(_onFocusChanged);
    }
  }

  @override
  void didUpdateWidget(covariant _WeightSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = _kgCtrl;
    if (ctrl != null && !(_kgFocus?.hasFocus ?? false)) {
      final current = double.tryParse(ctrl.text.trim());
      if (current == null || current != widget.weightKg) {
        final text = widget.weightKg.toStringAsFixed(0);
        ctrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _kgFocus?.removeListener(_onFocusChanged);
    _kgFocus?.dispose();
    _kgCtrl?.dispose();
    super.dispose();
  }

  void _setWeight(double value) {
    final clamped = value < _min ? _min : value;
    widget.onChanged(clamped);
  }

  void _onFocusChanged() {
    if (_kgFocus?.hasFocus ?? false) return;
    final ctrl = _kgCtrl;
    if (ctrl == null) return;
    final parsed = double.tryParse(ctrl.text.trim());
    final value = parsed == null ? _min : (parsed < _min ? _min : parsed);
    if (value != widget.weightKg) widget.onChanged(value);
    final text = value.toStringAsFixed(0);
    if (ctrl.text != text) {
      ctrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onFieldChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    final value = parsed < _min ? _min : parsed;
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return widget.isKgFree ? _buildKgFree(context) : _buildSlider(context);
  }

  Widget _buildKgFree(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final weightKg = widget.weightKg;
    final canDecrement = weightKg > _min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          'Kilo libre : choisissez votre poids',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        Row(
          children: [
            _StepperButton(
              key: const Key('weight-decrement'),
              iconAsset: 'minus',
              onPressed: canDecrement ? () => _setWeight(weightKg - 1) : null,
            ),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      key: const Key('weight-field'),
                      controller: _kgCtrl,
                      focusNode: _kgFocus,
                      onChanged: _onFieldChanged,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: tt.displayLarge?.copyWith(color: cs.onSurface),
                      cursorColor: cs.primary,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: DonySpacing.sm),
                    child: Text(
                      'kg',
                      style: tt.headlineMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.base),
            _StepperButton(
              key: const Key('weight-increment'),
              iconAsset: 'plus',
              onPressed: () => _setWeight(weightKg + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlider(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isMixed = widget.isMixed;
    final maxKg = widget.maxKg;
    final weightKg = widget.weightKg;
    final onChanged = widget.onChanged;
    // Toujours 0 : sur un trajet kilo pur (non mixte), le poids reste
    // obligatoire pour envoyer (le CTA l'impose, cf. `_syncFormButtonState`),
    // mais le slider doit pouvoir afficher sa valeur de départ à 0.
    const sliderMin = 0.0;

    if (maxKg <= sliderMin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Aucune capacité disponible',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    final divisions = (maxKg - sliderMin).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isMixed ? 'Poids du colis (optionnel)' : 'Poids du colis',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              weightKg.toStringAsFixed(0),
              style: tt.displayLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(width: DonySpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Text(
                'kg',
                style: tt.headlineMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            // Expanded+Align plutôt que Spacer + Text non contraint : à
            // 200 %, le gros chiffre de poids peut à lui seul approcher la
            // largeur de la ligne. Expanded donne au libellé « max X kg »
            // toute la place réellement restante (identique à Spacer quand
            // il y en a assez) et l'aligne à droite ; s'il n'y en a plus, il
            // passe à la ligne au lieu de déborder.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'max ${maxKg.toStringAsFixed(0)} kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cs.primary,
            inactiveTrackColor: cs.outline,
            thumbColor: cs.primary,
            overlayColor: cs.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(),
          ),
          child: Slider(
            value: weightKg,
            max: maxKg,
            divisions: divisions > 0 ? divisions : null,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0 kg',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              '${maxKg.toStringAsFixed(0)} kg',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stepper button ─────────────────────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.iconAsset,
    required this.onPressed,
  });

  final String iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: DonyIcon(
                iconAsset,
                size: 22,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Disclaimer card ────────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(DonyRadius.card)),
        border: Border(
          left: BorderSide(color: cs.secondary, width: _kAccentBorder),
        ),
      ),
      padding: const EdgeInsets.all(DonySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon('triangle-alert', size: 20, color: cs.secondary),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer douane.',
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xxs),
                    Text(
                      'Pas d\'armes, drogues, liquides inflammables ou espèces. '
                      'Le voyageur peut refuser au contrôle douanier.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          GestureDetector(
            onTap: () => onChanged(!accepted),
            child: Row(
              children: [
                Checkbox(
                  value: accepted,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: cs.secondary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Je signe & j\'accepte',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
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

// ── Payment method selector ────────────────────────────────────────────────────

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selectedMethod,
    required this.onChanged,
    this.isCashAvailable = false,
    this.isStripeAvailable = true,
    this.isMobileMoneyAvailable = false,
    this.total,
    this.currency,
    this.payerPhoneController,
    this.hasProfilePhone = true,
  });

  final BidPaymentMethod selectedMethod;
  final ValueChanged<BidPaymentMethod> onChanged;
  final bool isCashAvailable;
  final bool isStripeAvailable;
  final bool isMobileMoneyAvailable;

  /// Montant à afficher dans la carte ouverte. Absent en négociation : le
  /// prix n'y est pas encore connu, la carte n'explique alors que le mode.
  final double? total;
  final String? currency;

  /// Champ numéro payeur, révélé dans la carte mobile money ouverte.
  final TextEditingController? payerPhoneController;
  final bool hasProfilePhone;

  @override
  Widget build(BuildContext context) {
    // Du plus immédiat au plus manuel : carte, mobile money, espèces. Les
    // clés vivent sur les en-têtes : tests et accessibilité s'y attachent.
    final choices = <DonyChoice<BidPaymentMethod>>[
      if (isStripeAvailable)
        DonyChoice(
          value: BidPaymentMethod.stripe,
          title: 'Carte',
          subtitle: 'Bloqué jusqu\'à la livraison',
          iconAsset: 'credit-card',
          key: const Key('payment-method-stripe'),
          expanded: (context) =>
              _CardModeContent(total: total, currency: currency),
        ),
      if (isMobileMoneyAvailable)
        DonyChoice(
          value: BidPaymentMethod.mobileMoney,
          title: 'Mobile money',
          subtitle: 'Orange Money, Wave, MTN',
          iconAsset: 'smartphone',
          key: const Key('payment-method-mobile-money'),
          expanded: (context) => _MobileMoneyModeContent(
            total: total,
            currency: currency,
            payerPhoneController: payerPhoneController,
            hasProfilePhone: hasProfilePhone,
          ),
        ),
      if (isCashAvailable)
        DonyChoice(
          value: BidPaymentMethod.cash,
          title: 'Espèces',
          subtitle: 'En main propre, à la remise',
          iconAsset: 'banknote',
          key: const Key('payment-method-cash'),
          expanded: (context) =>
              _CashModeContent(total: total, currency: currency),
        ),
    ];
    if (choices.isEmpty) return const SizedBox.shrink();
    return DonyExpandableChoice<BidPaymentMethod>(
      choices: choices,
      value: selectedMethod,
      onChanged: onChanged,
    );
  }
}

// ── Cash escrow warning (D5) ────────────────────────────────────────────────────
//
// Contenu informatif uniquement (jamais de DonyButton ici) — reste dans le
// `child` scrollable du picker, jamais dans le _StickyBottom.
class _CashEscrowWarning extends StatelessWidget {
  const _CashEscrowWarning();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyIcon('triangle-alert', size: 16, color: cs.warning),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Text(
            'Paiement en espèces : pas de séquestre, vous payez le voyageur '
            'directement, sans garantie de remboursement par Yadony.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Numéro payeur mobile money ──────────────────────────────────────────────
//
// Affiché uniquement quand le mode mobile money est sélectionné. Le numéro
// reste modifiable/effaçable par l'expéditeur (jamais requis pour
// soumettre) : un champ vide envoie `phoneNumber: null`, et le backend
// replie alors sur le téléphone Firebase de l'expéditeur. Un champ de saisie
// et un texte d'aide, jamais de DonyButton ici — reste dans le `child`
// scrollable du picker, jamais dans le _StickyBottom.
class _PayerPhoneField extends StatelessWidget {
  const _PayerPhoneField({
    required this.controller,
    required this.hasProfilePhone,
  });

  final TextEditingController controller;

  /// Faux quand `_initialPayerPhone()` était vide (compte Yadony sans
  /// numéro de téléphone) : le texte d'aide ne peut alors plus affirmer un
  /// pré-remplissage qui n'a pas eu lieu.
  final bool hasProfilePhone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyTextField(
          key: const Key('payer-phone-field'),
          controller: controller,
          label: 'Numéro qui paiera (facultatif)',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyIcon('smartphone', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                hasProfilePhone
                    ? 'Par défaut, ton numéro Yadony. Tu recevras la '
                          'demande de paiement sur ce numéro.'
                    : "Ton compte n'a pas de numéro : indique celui qui "
                          'paiera. Tu recevras la demande de paiement '
                          'dessus.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Contenu des cartes ouvertes ────────────────────────────────────────────────
//
// Du contenu et des champs seulement — jamais de DonyButton ici, le CTA reste
// dans le _StickyBottom. Le montant n'est rendu que s'il est connu (pas en
// négociation).

class _CardModeContent extends StatelessWidget {
  const _CardModeContent({required this.total, required this.currency});

  final double? total;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total != null && currency != null) ...[
          _ModeAmountRow(total: total!, currency: currency!, tag: 'Séquestre'),
          const SizedBox(height: DonySpacing.sm),
        ],
        Text(
          'Bloqué par Yadony dès maintenant, versé au voyageur quand le '
          'destinataire confirme la livraison.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        const PaymentMethodNames(compact: true),
        const SizedBox(height: DonySpacing.md),
        const _PanelAssurance(text: 'Remboursé si le colis n\'arrive pas'),
      ],
    );
  }
}

class _MobileMoneyModeContent extends StatelessWidget {
  const _MobileMoneyModeContent({
    required this.total,
    required this.currency,
    required this.payerPhoneController,
    required this.hasProfilePhone,
  });

  final double? total;
  final String? currency;
  final TextEditingController? payerPhoneController;
  final bool hasProfilePhone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total != null && currency != null) ...[
          _ModeAmountRow(total: total!, currency: currency!, tag: 'Séquestre'),
          const SizedBox(height: DonySpacing.sm),
        ],
        Text(
          'Après l\'accord du voyageur, tu reçois une demande de paiement '
          'sur ton téléphone. Le montant est bloqué par Yadony jusqu\'à la '
          'livraison.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        const _OperatorChips(),
        if (payerPhoneController != null) ...[
          const SizedBox(height: DonySpacing.md),
          _PayerPhoneField(
            controller: payerPhoneController!,
            hasProfilePhone: hasProfilePhone,
          ),
        ],
        const SizedBox(height: DonySpacing.md),
        const _PanelAssurance(text: 'Remboursé si le colis n\'arrive pas'),
      ],
    );
  }
}

class _CashModeContent extends StatelessWidget {
  const _CashModeContent({required this.total, required this.currency});

  final double? total;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total != null && currency != null) ...[
          _ModeAmountRow(
            total: total!,
            currency: currency!,
            tag: 'En main propre',
            amber: true,
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
        Text(
          'Tu remets la somme au voyageur le jour où tu lui confies le colis.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        // L'avertissement (D5) en encart ambré, dans la carte, jamais détaché.
        Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: cs.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: const _CashEscrowWarning(),
        ),
      ],
    );
  }
}

/// Montant en grand, et un tag qui dit l'essentiel en un mot : « Séquestre »
/// (l'argent est bloqué chez Yadony) ou « En main propre ».
class _ModeAmountRow extends StatelessWidget {
  const _ModeAmountRow({
    required this.total,
    required this.currency,
    required this.tag,
    this.amber = false,
  });

  final double total;
  final String currency;
  final String tag;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tagColor = amber ? cs.warning : cs.primary;
    return Row(
      children: [
        Expanded(
          child: Text(
            formatPriceIn(total, currency),
            key: const Key('payment-panel-amount'),
            style: tt.headlineLarge?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: cs.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.sm + 1,
            vertical: DonySpacing.xs,
          ),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Text(
            tag.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: tagColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

// Couleurs de marque des opérateurs (comme _payPalGold dans la feuille de
// paiement) : reconnues avant d'être lues, jamais sémantiques.
const _orangeMoneyBrand = Color(0xFFFF7900);
const _waveBrand = Color(0xFF1DC3F5);
const _mtnBrand = Color(0xFFFFCC00);

class _OperatorChips extends StatelessWidget {
  const _OperatorChips();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: DonySpacing.xs + 2,
      runSpacing: DonySpacing.xs + 2,
      children: [
        _OperatorChip(label: 'Orange Money', brand: _orangeMoneyBrand),
        _OperatorChip(label: 'Wave', brand: _waveBrand),
        _OperatorChip(label: 'MTN', brand: _mtnBrand),
      ],
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({required this.label, required this.brand});

  final String label;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.xs + 2,
        DonySpacing.xs + 1,
        DonySpacing.sm + 2,
        DonySpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: brand),
          ),
          const SizedBox(width: DonySpacing.xs + 2),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelAssurance extends StatelessWidget {
  const _PanelAssurance({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        DonyIcon('shield-check', size: 14, color: cs.success),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(
              color: cs.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Price breakdown ────────────────────────────────────────────────────────────

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.weightKg,
    required this.pricePerKg,
    required this.kgDisplay,
    required this.gridDisplay,
    required this.totalPrice,
    required this.currency,
    this.originalTotal,
    this.promoApplied = false,
  });

  final double weightKg;

  /// Tarif au kilo **payé par l'expéditeur**, commission comprise. Jamais le
  /// net du voyageur, qui n'appartient qu'à lui.
  final double pricePerKg;

  /// Ligne poids, du point de vue de l'expéditeur (= [weightKg] × [pricePerKg]).
  final double kgDisplay;

  /// Ligne articles, du point de vue de l'expéditeur.
  final double gridDisplay;

  final double totalPrice;
  final double? originalTotal;
  final bool promoApplied;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final resolvedCurrency = SupportedCurrency.fromCodeOrDefault(currency);
    // Récap comptable : décimales toujours visibles, contrairement au compact
    // de [formatPriceIn] utilisé pour les prix unitaires de la même sheet.
    String fmt(num v) => CurrencyFormatter.format(v, resolvedCurrency);
    // L'économie n'est réelle que si le taux promo est strictement inférieur
    // au taux "sans promo" (originalTotal) — un code promo au même taux que
    // le taux global courant (ex. WELCOME05 = 5 % = taux par défaut actuel)
    // ne fait gagner rien, et l'afficher comme une remise serait trompeur.
    final savings = (promoApplied && originalTotal != null)
        ? originalTotal! - totalPrice
        : 0.0;
    final hasRealSavings = savings > 0.005;

    final lines = <Widget>[];
    if (weightKg > 0 && kgDisplay > 0) {
      lines.add(
        _line(
          tt,
          '${formatKgPrice(weightKg)} kg × ${formatPriceIn(pricePerKg, currency)}',
          fmt(kgDisplay),
        ),
      );
    }
    if (gridDisplay > 0) {
      lines.add(_line(tt, 'Articles', fmt(gridDisplay)));
    }
    // Pas de ligne « Commission » en addition : elle est déjà comprise dans les
    // lignes ci-dessus, l'ajouter la compterait deux fois. Sa présence reste
    // annoncée sous le total (« Commission Yadony incluse »).
    if (hasRealSavings) {
      lines.add(
        _line(
          tt,
          'Réduction code promo',
          '−${fmt(savings)}',
          valueColor: const Color(0xFF16A34A),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) ...[l, const SizedBox(height: DonySpacing.xs)],
          if (lines.isNotEmpty) ...[
            Divider(color: cs.outline),
            const SizedBox(height: DonySpacing.xs),
          ],
          // Wrap plutôt que Row spaceBetween : ni le libellé (avec badge
          // promo) ni le prix (avec original barré) n'étaient contraints —
          // à 200 % leur somme peut dépasser la largeur de la carte. Sur
          // une ligne quand ça tient (rendu identique à 100 %), le prix
          // passe sous le libellé sinon.
          // SizedBox(width: double.infinity) : un Wrap seul ne s'étire pas
          // à la largeur du parent (Column crossAxisAlignment.start), donc
          // spaceBetween n'avait aucun espace libre à répartir et "Total"
          // se retrouvait collé au prix.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: DonySpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: tt.titleLarge),
                    // Le badge "Promo" ne s'affiche que si le code a
                    // réellement fait baisser le prix — sinon il
                    // annoncerait une remise qui n'existe pas.
                    if (hasRealSavings) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Promo',
                          style: tt.labelSmall?.copyWith(
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasRealSavings) ...[
                      Text(
                        fmt(originalTotal!),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      fmt(totalPrice),
                      key: const Key('bid-total-amount'),
                      style: tt.titleLarge?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            'Commission Yadony incluse',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // Expanded sur le libellé (variable, ex: "5.0 kg × 8.00€") plutôt qu'un
  // Row spaceBetween non contraint : à 200 % il passe à la ligne au lieu de
  // pousser le montant hors de la carte.
  Widget _line(TextTheme tt, String label, String value, {Color? valueColor}) =>
      Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyMedium)),
          const SizedBox(width: DonySpacing.sm),
          Text(value, style: tt.titleMedium?.copyWith(color: valueColor)),
        ],
      );

  /// Libellé pourcentage : entier si rond, sinon 1 décimale virgule FR
  /// (ex. 0.05 → « 5 », 0.065 → « 6,5 »).
}

// ── Refused chip ───────────────────────────────────────────────────────────────

class _RefusedChip extends StatelessWidget {
  const _RefusedChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          decoration: TextDecoration.lineThrough,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
