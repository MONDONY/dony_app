import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/screens/create_trip_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/locked_trip_context.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';
import 'package:dony/features/package_request/data/price_estimation_repository.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/widgets/request_corridor.dart';
import 'package:dony/features/package_request/presentation/widgets/trip_picker_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Feuille « Faire une offre » / « Prendre ce colis » du voyageur, en trois
/// étapes : le trajet qui portera le colis, le prix et la capacité, puis le
/// récapitulatif et un message facultatif.
///
/// Le bouton principal vit dans la zone fixe du bas (`stickyBottom`) : il
/// passe de « Continuer » à « Envoyer l'offre » (ou « Prendre à … », ou
/// « Créer un nouveau trajet » quand le trajet reste à créer) à la dernière
/// étape.
class MakeOfferBottomSheet {
  const MakeOfferBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String packageRequestId,
    double? targetPriceEur,
    required double weightKg,
    required String departureCity,
    required String arrivalCity,
    required DateTime? desiredDate,
    required int dateToleranceDays,
    required TransportMode transportMode,
    DateTime? initialDate,
    bool isFirmPrice = false,
    String currency = 'EUR',
    double? displayPriceEur,
  }) async {
    PriceEstimate? estimate;
    try {
      estimate = await getIt<PriceEstimationRepository>().estimate(
        from: departureCity,
        to: arrivalCity,
        weight: weightKg,
        currency: currency,
      );
    } catch (_) {
      // estimate optional
    }

    if (!context.mounted) return;

    // Capture root references BEFORE the sheet opens — using `ctx` from
    // inside the listener after pop() would touch a disposed subtree.
    final rootRouter = GoRouter.of(context);

    // Créé ICI (avant `DonyBottomSheet.show`) et non dans l'état du contenu :
    // le `stickyBottom` est construit avant `showModalBottomSheet`, donc avant
    // que `_MakeOfferContentState.initState()` ne s'exécute. Un notifier
    // fabriqué plus tard arriverait trop tard : le bouton resterait accroché à
    // un objet jetable qui ne reçoit jamais aucune mise à jour. Seuls des
    // gestes de l'utilisateur y écrivent (choix du trajet, saisie), jamais un
    // rappel différé après la fermeture : il est libéré à la fermeture.
    final flow = _OfferFlow();

    try {
      final l = context.l10n;
      await DonyBottomSheet.show<void>(
        context,
        analyticsName: 'negotiation/make-offer',
        title: isFirmPrice
            ? l.requestPublicTakePackageCta
            : l.negotiationMakeOfferTitle,
        // Le glissement vers le bas appelle `Navigator.pop()` sans consulter
        // `PopScope` (vérifié sur Flutter 3.44) : il contournerait la
        // confirmation. La barrière et la croix, elles, passent par
        // `maybePop` et honorent donc le garde.
        enableDrag: false,
        wrapper: (child) =>
            BlocProvider(create: (_) => getIt<NegotiationBloc>(), child: child),
        child: _MakeOfferContent(
          packageRequestId: packageRequestId,
          targetPriceEur: targetPriceEur,
          weightKg: weightKg,
          departureCity: departureCity,
          arrivalCity: arrivalCity,
          requestDesiredDate: desiredDate,
          requestDateToleranceDays: dateToleranceDays,
          transportMode: transportMode,
          estimate: estimate,
          rootRouter: rootRouter,
          flow: flow,
          initialDate: initialDate,
          isFirmPrice: isFirmPrice,
          currency: currency,
          displayPriceEur: displayPriceEur,
        ),
        stickyBottom: ListenableBuilder(
          listenable: flow,
          builder: (_, _) => BlocBuilder<NegotiationBloc, NegotiationState>(
            builder: (ctx, state) => _OfferFooter(
              flow: flow,
              loading: state is NegotiationLoading,
              isFirmPrice: isFirmPrice,
              firmShownPrice: displayPriceEur ?? targetPriceEur,
              currency: currency,
            ),
          ),
        ),
      );
    } finally {
      flow.dispose();
    }
  }
}

/// Les trois étapes de la feuille, dans l'ordre. Le nom sert aussi de valeur à
/// la propriété `step` de l'événement d'analytics.
enum _OfferStep { trip, price, recap }

/// Ce qui empêche de passer l'étape « Prix » (affiché sous le bouton).
enum _DetailsIssue { price, capacity, date }

/// État partagé entre le contenu de la feuille et son pied fixe : l'étape, le
/// trajet choisi (ou le choix d'en créer un) et ce qui bloque l'étape « Prix ».
class _OfferFlow extends ChangeNotifier {
  _OfferStep _step = _OfferStep.trip;
  AnnouncementModel? _trip;
  bool _newTrip = false;
  _DetailsIssue? _issue;

  /// Action du bouton principal, posée par le contenu à son ouverture (le pied
  /// et le contenu sont construits séparément).
  VoidCallback? onPrimary;

  _OfferStep get step => _step;
  AnnouncementModel? get trip => _trip;

  /// « Créer un nouveau trajet » choisi : le trajet n'existe pas encore, il se
  /// crée à la dernière étape avec le prix et la capacité saisis.
  bool get newTrip => _newTrip;

  /// `null` quand le prix, la capacité (et la date d'un nouveau trajet) sont
  /// valides.
  _DetailsIssue? get issue => _issue;

  bool get hasTripChoice => _trip != null || _newTrip;

  void setStep(_OfferStep step) {
    if (_step == step) return;
    _step = step;
    notifyListeners();
  }

  void selectTrip(AnnouncementModel trip) {
    _trip = trip;
    _newTrip = false;
    notifyListeners();
  }

  void chooseNewTrip() {
    _trip = null;
    _newTrip = true;
    notifyListeners();
  }

  void setIssue(_DetailsIssue? issue) {
    if (_issue == issue) return;
    _issue = issue;
    notifyListeners();
  }
}

/// Pied fixe : l'aide qui explique un bouton grisé, puis le bouton principal.
class _OfferFooter extends StatelessWidget {
  const _OfferFooter({
    required this.flow,
    required this.loading,
    required this.isFirmPrice,
    required this.firmShownPrice,
    required this.currency,
  });

  final _OfferFlow flow;
  final bool loading;
  final bool isFirmPrice;
  final double? firmShownPrice;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final String label;
    final String? hint;
    final bool enabled;
    switch (flow.step) {
      case _OfferStep.trip:
        label = l.commonContinue;
        enabled = flow.hasTripChoice;
        hint = enabled ? null : l.negotiationMakeOfferSelectTripHint;
      case _OfferStep.price:
        label = l.commonContinue;
        enabled = flow.issue == null;
        hint = switch (flow.issue) {
          _DetailsIssue.price => l.negotiationMakeOfferEnterValidPrice,
          _DetailsIssue.capacity => l.negotiationMakeOfferEnterValidCapacity,
          _DetailsIssue.date => l.negotiationMakeOfferPickDateToContinue,
          null => null,
        };
      case _OfferStep.recap:
        enabled = flow.issue == null;
        hint = null;
        if (loading) {
          label = l.requestCreateSendingLabel;
        } else if (flow.newTrip) {
          label = l.requestPickerCreateTripCta;
        } else if (isFirmPrice) {
          label = firmShownPrice != null
              ? l.negotiationMakeOfferTakeAtLabel(
                  PriceDisplay.money(firmShownPrice!, currency),
                )
              : l.requestPublicTakePackageCta;
        } else {
          label = l.negotiationMakeOfferSendButtonLabel;
        }
    }
    final button = DonyButton(
      label: label,
      isLoading: loading,
      onPressed: loading || !enabled ? null : () => flow.onPrimary?.call(),
    );
    if (hint == null) return button;
    // Bouton grisé : dire pourquoi, au lieu d'un bouton muet (FLUTTER-4W).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hint,
          key: const Key('make-offer-select-trip-hint'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        button,
      ],
    );
  }
}

class _MakeOfferContent extends StatefulWidget {
  const _MakeOfferContent({
    required this.packageRequestId,
    required this.targetPriceEur,
    required this.weightKg,
    required this.departureCity,
    required this.arrivalCity,
    required this.requestDesiredDate,
    required this.requestDateToleranceDays,
    required this.transportMode,
    required this.estimate,
    required this.rootRouter,
    required this.flow,
    this.initialDate,
    this.isFirmPrice = false,
    this.currency = 'EUR',
    this.displayPriceEur,
  });

  final String packageRequestId;
  final double? targetPriceEur;
  final double weightKg;
  final String departureCity;
  final String arrivalCity;

  /// Fenêtre de dates de la demande — sert à filtrer `TripPickerSection` et à
  /// borner la création d'un trajet dédié. Distincte de [initialDate] (date
  /// pré-remplie du champ « Date de voyage », propre au voyageur).
  /// Null : demande « Date flexible », la date de voyage est libre.
  final DateTime? requestDesiredDate;
  final int requestDateToleranceDays;
  final TransportMode transportMode;
  final PriceEstimate? estimate;
  final GoRouter rootRouter;
  final _OfferFlow flow;
  final DateTime? initialDate;
  final bool isFirmPrice;
  final String currency;

  /// Prix ferme publié, en brut (ce que paie l'expéditeur). [targetPriceEur]
  /// est le net voyageur : seul ce dernier est envoyé au serveur.
  final double? displayPriceEur;

  @override
  State<_MakeOfferContent> createState() => _MakeOfferContentState();
}

class _MakeOfferContentState extends State<_MakeOfferContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceCtrl;
  late final TextEditingController _kgCtrl;
  late final TextEditingController _bodyCtrl;

  /// Date de voyage : saisie seulement quand le trajet reste à créer. Avec un
  /// trajet existant, c'est la date du trajet qui part (le serveur la prend de
  /// toute façon sur le trajet).
  final _dateNotifier = ValueNotifier<DateTime?>(null);

  /// Signature de la saisie à l'ouverture, pour ne demander confirmation de
  /// sortie que si l'utilisateur a modifié quelque chose. Les champs sont
  /// pré-remplis (prix cible, poids), d'où la comparaison plutôt qu'un simple
  /// test de non-vacuité.
  String? _initialSignature;

  /// Évite d'empiler deux dialogues sur retours système répétés.
  bool _confirmingExit = false;

  /// Armé juste avant `context.push('/trips/create')`, désarmé dans le
  /// `finally` qui suit. `/trips/create` (via `LockedTripContext.threadId ==
  /// null`) réutilise CE MÊME `NegotiationBloc` (`negotiationBloc:
  /// context.read&lt;NegotiationBloc&gt;()` dans l'appel) pour créer offre + trajet
  /// dédié atomiquement — la feuille reste montée en dessous, donc son
  /// propre `BlocListener` resterait sinon abonné à la même émission que
  /// celui de `CreateTripScreen` : double traitement (double pop, double
  /// snackbar) sur un seul `NegotiationLoaded`/`NegotiationError`. Tant que
  /// ce drapeau est vrai, le listener de la feuille ignore l'état — seul
  /// `CreateTripScreen` réagit.
  bool _creatingDedicatedTripElsewhere = false;

  _OfferFlow get _flow => widget.flow;

  String get _formSignature => [
    _priceCtrl.text,
    _kgCtrl.text,
    _bodyCtrl.text,
    _dateNotifier.value,
  ].join('|');

  /// Saleté observable : `PopScope.canPop` est lu au build, or taper dans un
  /// `TextFormField` ne provoque aucun rebuild. Sans ce notifier, le garde-fou
  /// resterait figé sur sa valeur d'ouverture et se contournerait tout seul.
  final _isDirtyNotifier = ValueNotifier<bool>(false);

  bool get _isDirty => _isDirtyNotifier.value;

  void _recomputeDirty() {
    _isDirtyNotifier.value =
        _initialSignature != null && _formSignature != _initialSignature;
  }

  Future<void> _handleExitRequest() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    if (_confirmingExit) return;
    _confirmingExit = true;
    final confirmed = await DonyDialog.confirmDiscard(context);
    _confirmingExit = false;
    if (!mounted || confirmed != true) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void initState() {
    super.initState();
    _flow.onPrimary = _onPrimary;
    // Prix ferme : champ verrouillé, purement informatif (le montant envoyé
    // est [targetPriceEur], cf. `_submit`) ; il montre le prix publié.
    final shownPrice = widget.isFirmPrice
        ? widget.displayPriceEur ?? widget.targetPriceEur
        : widget.targetPriceEur;
    _priceCtrl = TextEditingController(
      text: shownPrice != null
          // Prix ferme : valeur EXACTE (pas d'arrondi) — sinon le backend
          // rejette avec negotiation/firm-price-must-match.
          ? shownPrice.toStringAsFixed(widget.isFirmPrice ? 2 : 0)
          : '',
    );
    _kgCtrl = TextEditingController(text: widget.weightKg.toStringAsFixed(1));
    _bodyCtrl = TextEditingController();
    if (widget.initialDate != null) _dateNotifier.value = widget.initialDate;

    _priceCtrl.addListener(_recomputeDirty);
    _kgCtrl.addListener(_recomputeDirty);
    _bodyCtrl.addListener(_recomputeDirty);
    _dateNotifier.addListener(_recomputeDirty);
    _priceCtrl.addListener(_syncIssue);
    _kgCtrl.addListener(_syncIssue);
    _dateNotifier.addListener(_syncIssue);

    // Après le premier build : les champs pré-remplis font partie de la
    // référence, pas d'une saisie utilisateur. Le pied fixe n'est prévenu
    // qu'ici : le notifier ne doit pas être touché pendant un build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncIssue();
      _trackStep(_flow.step);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initialSignature = _formSignature;
        _recomputeDirty();
      });
    });
  }

  /// « vous recevez X » sous un prix ferme publié en brut, comme la grille
  /// de prix d'un trajet. Rien quand brut et net se confondent.
  String? _firmNetHint(AppLocalizations l) {
    final net = widget.targetPriceEur;
    final shown = widget.displayPriceEur;
    if (!widget.isFirmPrice || net == null || shown == null || shown == net) {
      return null;
    }
    return l.priceGridYouReceive(PriceDisplay.money(net, widget.currency));
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_recomputeDirty);
    _kgCtrl.removeListener(_recomputeDirty);
    _bodyCtrl.removeListener(_recomputeDirty);
    _dateNotifier.removeListener(_recomputeDirty);
    _priceCtrl.removeListener(_syncIssue);
    _kgCtrl.removeListener(_syncIssue);
    _dateNotifier.removeListener(_syncIssue);
    _flow.onPrimary = null;
    _priceCtrl.dispose();
    _kgCtrl.dispose();
    _bodyCtrl.dispose();
    _dateNotifier.dispose();
    _isDirtyNotifier.dispose();
    super.dispose();
  }

  // ── Saisie ────────────────────────────────────────────────────────────────

  static double? _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  double? get _price {
    final v = _parse(_priceCtrl.text);
    return v != null && v > 0 ? v : null;
  }

  double? get _kg {
    final v = _parse(_kgCtrl.text);
    return v != null && v > 0 ? v : null;
  }

  /// Recalcule ce qui bloque le passage de l'étape « Prix » et prévient le
  /// pied fixe.
  void _syncIssue() {
    final _DetailsIssue? issue;
    if (_price == null) {
      issue = _DetailsIssue.price;
    } else if (_kg == null) {
      issue = _DetailsIssue.capacity;
    } else if (_flow.newTrip && _dateNotifier.value == null) {
      issue = _DetailsIssue.date;
    } else {
      issue = null;
    }
    _flow.setIssue(issue);
  }

  /// Un pas sur le prix : 1 en dessous de 1 000, 100 au-delà (devises sans
  /// centimes, où un pas de 1 ne change rien à l'œil).
  void _stepPrice(int direction) {
    final current = _price ?? 0;
    final step = current >= 1000 ? 100.0 : 1.0;
    final next = (current + direction * step).clamp(1, double.infinity);
    _setText(
      _priceCtrl,
      next % 1 == 0 ? next.toStringAsFixed(0) : next.toStringAsFixed(2),
    );
  }

  void _stepKg(int direction) {
    final current = _kg ?? 0;
    final next = (current + direction).clamp(0.5, double.infinity);
    _setText(_kgCtrl, next.toStringAsFixed(1));
  }

  static void _setText(TextEditingController c, String text) {
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  // ── Étapes ────────────────────────────────────────────────────────────────

  void _goTo(_OfferStep step) {
    FocusScope.of(context).unfocus();
    _flow.setStep(step);
    _trackStep(step);
  }

  void _trackStep(_OfferStep step) {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.makeOfferStepViewed,
        properties: {
          'step': step.name,
          'price_type': widget.isFirmPrice ? 'firm' : 'negotiable',
          'new_trip': _flow.newTrip,
        },
      ),
    );
  }

  void _goBack() {
    switch (_flow.step) {
      case _OfferStep.trip:
        break;
      case _OfferStep.price:
        _goTo(_OfferStep.trip);
      case _OfferStep.recap:
        _goTo(_OfferStep.price);
    }
  }

  void _onPrimary() {
    switch (_flow.step) {
      case _OfferStep.trip:
        if (_flow.hasTripChoice) _goTo(_OfferStep.price);
      case _OfferStep.price:
        // Fait apparaître les messages d'erreur des champs avant de bloquer.
        if (_formKey.currentState?.validate() ?? false) {
          _goTo(_OfferStep.recap);
        }
      case _OfferStep.recap:
        if (_flow.newTrip) {
          unawaited(_createDedicatedTrip());
        } else {
          _submit();
        }
    }
  }

  /// Fenêtre de dates de la demande (souhaitée ± tolérance, jamais avant
  /// aujourd'hui) : la seule que le back accepte (FLUTTER-E7). Recalculée à
  /// chaque appel pour suivre le changement de jour, feuille ouverte.
  ({DateTime first, DateTime last}) get _travelWindow =>
      LockedTripContext.travelDateWindow(
        desiredDate: widget.requestDesiredDate,
        toleranceDays: widget.requestDateToleranceDays,
      );

  DateTime _clampDate(DateTime d) =>
      LockedTripContext.clampToWindow(d, _travelWindow);

  /// Ligne d'aide sous le champ date : la fenêtre permise, et d'où elle vient.
  String _travelWindowHint(AppLocalizations l) {
    final window = _travelWindow;
    final fmt = DateFormat.yMMMd(l.localeName);
    final desiredDate = widget.requestDesiredDate;
    if (desiredDate == null) {
      return l.negotiationMakeOfferTravelDateHintFlexible;
    }
    final desired = fmt.format(desiredDate);
    if (widget.requestDateToleranceDays <= 0) {
      return l.negotiationMakeOfferTravelDateHintExact(desired);
    }
    return l.negotiationMakeOfferTravelDateHint(
      fmt.format(window.first),
      fmt.format(window.last),
      desired,
      widget.requestDateToleranceDays,
    );
  }

  /// Envoi de l'offre sur un trajet existant.
  void _submit() {
    final trip = _flow.trip;
    final price = _price;
    final kg = _kg;
    if (trip == null) {
      DonySnackbar.show(
        context,
        message: context.l10n.negotiationMakeOfferSelectTrip,
        type: DonySnackbarType.warning,
      );
      return;
    }
    if (price == null || kg == null) return;
    context.read<NegotiationBloc>().add(
      NegotiationStartRequested(
        packageRequestId: widget.packageRequestId,
        // Prix ferme : on envoie la valeur exacte (le champ est verrouillé),
        // jamais le texte arrondi → match garanti côté backend.
        proposedPriceEur: widget.isFirmPrice && widget.targetPriceEur != null
            ? widget.targetPriceEur!
            : price,
        travelerTravelDate: trip.departureDate,
        travelerAvailableKg: kg,
        travelerAnnouncementId: trip.id,
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        isFirmPrice: widget.isFirmPrice,
      ),
    );
  }

  /// Le trajet n'existe pas encore : l'écran de création le fabrique avec
  /// l'offre, atomiquement.
  Future<void> _createDedicatedTrip() async {
    final price = _price;
    final kg = _kg;
    final travelDate = _dateNotifier.value;
    if (price == null || kg == null) return;
    if (travelDate == null) {
      DonySnackbar.show(
        context,
        message: context.l10n.negotiationMakeOfferSelectTravelDate,
        type: DonySnackbarType.warning,
      );
      return;
    }
    final negotiationBloc = context.read<NegotiationBloc>();
    _creatingDedicatedTripElsewhere = true;
    try {
      final result = await context.push<bool>(
        '/trips/create',
        extra: CreateTripArgs(
          lockContext: LockedTripContext(
            // threadId omis (null par défaut) : aucun thread de négociation
            // n'existe encore — l'offre et le trajet seront créés
            // atomiquement (NegotiationStartWithDedicatedTripRequested).
            packageRequestId: widget.packageRequestId,
            departureCity: widget.departureCity,
            arrivalCity: widget.arrivalCity,
            desiredDate: widget.requestDesiredDate,
            dateToleranceDays: widget.requestDateToleranceDays,
            weightKg: widget.weightKg,
            transportMode: widget.transportMode,
            agreedPriceEur: widget.isFirmPrice && widget.targetPriceEur != null
                ? widget.targetPriceEur!
                : price,
            currency: widget.currency,
            offerAvailableKg: kg,
            offerBody: _bodyCtrl.text.trim().isEmpty
                ? null
                : _bodyCtrl.text.trim(),
            // La date choisie ici pré-remplit le trajet dédié, ramenée dans la
            // fenêtre de la demande (FLUTTER-E7).
            preferredDate: _clampDate(travelDate),
          ),
          negotiationBloc: negotiationBloc,
        ),
      );
      // Un trajet a bien été créé (et l'offre envoyée avec) : on ferme la
      // feuille d'offre. Si l'utilisateur annule ou revient en arrière depuis
      // /trips/create (`result` faux ou null), on reste sur le formulaire
      // d'offre en cours, saisie intacte.
      if (mounted && result == true) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } finally {
      _creatingDedicatedTripElsewhere = false;
    }
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDirtyNotifier,
      builder: (context, isDirty, child) => PopScope(
        // Feuille modale : bloque le retour système et le glissement vers le
        // bas tant qu'il y a de la saisie, pour repasser par la confirmation.
        canPop: !isDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_handleExitRequest());
        },
        child: child!,
      ),
      child: BlocListener<NegotiationBloc, NegotiationState>(
        listener: (ctx, state) {
          if (_creatingDedicatedTripElsewhere) return;
          if (state is NegotiationLoaded) {
            DonySnackbar.show(
              ctx,
              message: ctx.l10n.negotiationMakeOfferOfferSentSnackbar,
              type: DonySnackbarType.success,
            );
            Navigator.of(ctx, rootNavigator: true).pop();
            widget.rootRouter.push('/negotiations/${state.thread.id}');
          } else if (state is NegotiationError) {
            ErrorPresenter.show(ctx, state.error);
          }
        },
        child: Form(
          key: _formKey,
          child: ListenableBuilder(
            listenable: _flow,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepHeader(step: _flow.step, onBack: _goBack),
                const SizedBox(height: DonySpacing.base),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: KeyedSubtree(
                    key: ValueKey(_flow.step),
                    child: switch (_flow.step) {
                      _OfferStep.trip => _tripStep(context),
                      _OfferStep.price => _priceStep(context),
                      _OfferStep.recap => _recapStep(context),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Étape 1 — le trajet ───────────────────────────────────────────────────────

  Widget _tripStep(BuildContext context) {
    final l = context.l10n;
    final desired = widget.requestDesiredDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OfferCard(
          key: const Key('make-offer-request-recap'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RequestCorridor(
                departureCity: widget.departureCity,
                arrivalCity: widget.arrivalCity,
              ),
              const SizedBox(height: DonySpacing.md),
              Divider(height: 1, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: DonySpacing.md),
              Text(
                [
                  '${_formatKg(widget.weightKg)} kg',
                  desired == null
                      ? l.requestDateFlexible
                      : l.requestPublicDesiredDate(
                          shortDayMonthYear(l, desired),
                          toleranceCompactLabel(
                            l,
                            widget.requestDateToleranceDays,
                          ),
                        ),
                ].join(' · '),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        TripPickerSection(
          departureCity: widget.departureCity,
          arrivalCity: widget.arrivalCity,
          // Fenêtre de la DEMANDE (pas de la date que le voyageur vient de
          // choisir) : c'est elle que le backend valide
          // (validateAndFetchExistingTrip / date-mismatch) — filtrer sur autre
          // chose masquerait des trajets valides ou en proposerait un que le
          // serveur rejettera en 422.
          desiredDate: widget.requestDesiredDate,
          dateToleranceDays: widget.requestDateToleranceDays,
          weightKg: widget.weightKg,
          currency: widget.currency,
          selected: _flow.trip,
          onSelected: (ann) {
            _flow.selectTrip(ann);
            _syncIssue();
          },
          onCreateDedicated: () {
            _flow.chooseNewTrip();
            _syncIssue();
            _goTo(_OfferStep.price);
          },
        ),
      ],
    );
  }

  // Étape 2 — prix, capacité (et date d'un nouveau trajet) ────────────────────

  Widget _priceStep(BuildContext context) {
    final l = context.l10n;
    final estimate = widget.estimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (estimate != null && estimate.lowEur != null) ...[
          _EstimationBanner(estimate: estimate),
          const SizedBox(height: DonySpacing.base),
        ],
        _OfferCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(
                widget.isFirmPrice
                    ? l.requestPublicFirmPriceBadge
                    : l.negotiationMakeOfferYourPriceLabel,
              ),
              const SizedBox(height: DonySpacing.sm),
              _AmountRow(
                locked: widget.isFirmPrice,
                decreaseTooltip: l.negotiationMakeOfferPriceDecrease,
                increaseTooltip: l.negotiationMakeOfferPriceIncrease,
                onDecrease: () => _stepPrice(-1),
                onIncrease: () => _stepPrice(1),
                field: TextFormField(
                  key: const Key('make-offer-price-field'),
                  controller: _priceCtrl,
                  // Prix ferme : non négociable → champ verrouillé.
                  readOnly: widget.isFirmPrice,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
                  style: _amountStyle(context),
                  decoration: _amountDecoration(
                    context,
                    SupportedCurrency.symbolOf(widget.currency),
                  ),
                  validator: (v) {
                    final d = _parse(v ?? '');
                    // Aucun plafond métier : seul le garde-fou technique du
                    // serveur (1 000 000) subsiste.
                    if (d == null || d <= 0) {
                      return l.negotiationMakeOfferInvalidPrice;
                    }
                    return null;
                  },
                ),
              ),
              if (!widget.isFirmPrice &&
                  estimate != null &&
                  estimate.lowEur != null &&
                  estimate.highEur != null) ...[
                const SizedBox(height: DonySpacing.md),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _priceCtrl,
                  builder: (_, _, _) =>
                      _MarketGauge(estimate: estimate, price: _price),
                ),
              ],
              if (_firmNetHint(l) case final hint?) ...[
                const SizedBox(height: DonySpacing.sm),
                Text(
                  hint,
                  key: const Key('firm-price-you-receive'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        _OfferCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(l.negotiationMakeOfferCapacityLabel),
              const SizedBox(height: DonySpacing.sm),
              _AmountRow(
                decreaseTooltip: l.negotiationMakeOfferCapacityDecrease,
                increaseTooltip: l.negotiationMakeOfferCapacityIncrease,
                onDecrease: () => _stepKg(-1),
                onIncrease: () => _stepKg(1),
                field: TextFormField(
                  key: const Key('make-offer-capacity-field'),
                  controller: _kgCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                  ],
                  style: _amountStyle(context, size: 26),
                  decoration: _amountDecoration(context, 'kg'),
                  validator: (v) {
                    final d = _parse(v ?? '');
                    if (d == null || d <= 0) return '> 0 kg';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        if (_flow.newTrip) ...[
          const SizedBox(height: DonySpacing.md),
          _dateField(context, l),
        ],
      ],
    );
  }

  /// Date de voyage d'un trajet à créer, bornée à la fenêtre de la demande
  /// (hors de celle-ci, le back rejette l'offre : FLUTTER-E7).
  Widget _dateField(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OfferCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(l.negotiationMakeOfferTravelDateLabel),
              const SizedBox(height: DonySpacing.xs),
              ValueListenableBuilder<DateTime?>(
                valueListenable: _dateNotifier,
                builder: (ctx, date, _) => InkWell(
                  key: const Key('make-offer-date-field'),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                  onTap: () async {
                    final window = _travelWindow;
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: _clampDate(
                        date ??
                            widget.requestDesiredDate ??
                            DateTime.now().add(const Duration(days: 1)),
                      ),
                      firstDate: window.first,
                      lastDate: window.last,
                    );
                    if (picked != null) _dateNotifier.value = picked;
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kDonyMinTapTarget,
                    ),
                    child: Row(
                      children: [
                        DonyIcon(
                          'calendar',
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: DonySpacing.sm),
                        Expanded(
                          child: Text(
                            date == null
                                ? l.negotiationMakeOfferSelectDatePlaceholder
                                : DateFormat.yMMMEd(l.localeName).format(date),
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: date == null
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                        DonyIcon(
                          'chevron-right',
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          _travelWindowHint(l),
          key: const Key('make-offer-travel-date-hint'),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  // Étape 3 — récapitulatif et message ────────────────────────────────────────

  Widget _recapStep(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final trip = _flow.trip;
    final date = trip?.departureDate ?? _dateNotifier.value;
    final price = _price;
    final kg = _kg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OfferCard(
          key: const Key('make-offer-recap'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RequestCorridor(
                compact: true,
                departureCity: widget.departureCity,
                arrivalCity: widget.arrivalCity,
              ),
              const SizedBox(height: DonySpacing.sm),
              Divider(height: 1, color: cs.outline),
              if (date != null)
                _RecapRow(
                  label: l.negotiationMakeOfferRecapDeparture,
                  value: DateFormat.yMMMEd(l.localeName).format(date),
                ),
              if (kg != null)
                _RecapRow(
                  label: l.negotiationMakeOfferRecapCapacity,
                  value: '${_formatKg(kg)} kg',
                ),
              if (price != null)
                _RecapRow(
                  label: l.negotiationMakeOfferRecapPrice,
                  value:
                      '${PriceDisplay.money(price, widget.currency)}'
                      '${widget.isFirmPrice ? ' · ${l.negotiationMakeOfferRecapFirm}' : ''}',
                ),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        Row(
          children: [
            _SectionLabel(l.negotiationMakeOfferMessageLabel),
            const SizedBox(width: DonySpacing.xs),
            Text(
              '· ${l.negotiationMakeOfferMessageOptional}',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        TextFormField(
          key: const Key('make-offer-message-field'),
          controller: _bodyCtrl,
          maxLines: 3,
          maxLength: 280,
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: l.negotiationMakeOfferMessageHint,
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              borderSide: BorderSide.none,
            ),
            counterStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  static String _formatKg(double kg) => kg.toStringAsFixed(kg % 1 == 0 ? 0 : 1);

  static TextStyle _amountStyle(BuildContext context, {double size = 36}) {
    final tt = Theme.of(context).textTheme;
    return tt.headlineMedium!.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  static InputDecoration _amountDecoration(
    BuildContext context,
    String suffix,
  ) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      suffixText: suffix,
      suffixStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }
}

// ─── En-tête d'étape ─────────────────────────────────────────────────────────

/// Retour (dès l'étape 2), « Étape n sur 3 · nom » et les trois segments de
/// progression.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});
  final _OfferStep step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final index = step.index;
    final name = switch (step) {
      _OfferStep.trip => l.negotiationMakeOfferStepTrip,
      _OfferStep.price => l.negotiationMakeOfferStepPrice,
      _OfferStep.recap => l.negotiationMakeOfferStepRecap,
    };
    return Column(
      key: const Key('make-offer-step-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (index > 0)
              IconButton(
                key: const Key('make-offer-back'),
                tooltip: l.commonBack,
                onPressed: onBack,
                visualDensity: VisualDensity.standard,
                constraints: const BoxConstraints(
                  minWidth: kDonyMinTapTarget,
                  minHeight: kDonyMinTapTarget,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 24,
                  color: cs.onSurface,
                ),
              )
            else
              const SizedBox(height: kDonyMinTapTarget),
            Expanded(
              child: Text(
                l.negotiationMakeOfferStepProgress(index + 1, name),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < _OfferStep.values.length; i++) ...[
              if (i > 0) const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= index ? cs.primary : cs.outline,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Briques ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Carte de la feuille : fond de surface sombre, bord fin, sans ombre.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: child,
    );
  }
}

/// Une valeur saisie (prix, kilos) entre un « − » et un « + ». Verrouillée
/// (prix ferme) : un cadenas remplace le « − », le « + » disparaît.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.field,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
    this.locked = false,
  });

  final Widget field;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (locked) {
      return Row(
        children: [
          SizedBox(
            width: kDonyMinTapTarget,
            child: DonyIcon('lock', size: 20, color: cs.onSurfaceVariant),
          ),
          Expanded(child: field),
          const SizedBox(width: kDonyMinTapTarget),
        ],
      );
    }
    return Row(
      children: [
        _StepButton(
          icon: 'minus',
          tooltip: decreaseTooltip,
          onPressed: onDecrease,
        ),
        Expanded(child: field),
        _StepButton(
          icon: 'plus',
          tooltip: increaseTooltip,
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final String icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(
        minWidth: kDonyMinTapTarget,
        minHeight: kDonyMinTapTarget,
      ),
      style: IconButton.styleFrom(
        backgroundColor: cs.surface,
        side: BorderSide(color: cs.outline),
        shape: const CircleBorder(),
      ),
      icon: DonyIcon(icon, size: 18, color: cs.onSurface),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: DonySpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estimation du marché ────────────────────────────────────────────────────

/// Position du prix saisi dans la fourchette du marché : piste, plage de
/// l'estimation en vert, repère du prix, puis une phrase qui dit où l'on se
/// situe. Sans prix valide, rien n'est dessiné.
class _MarketGauge extends StatelessWidget {
  const _MarketGauge({required this.estimate, required this.price});
  final PriceEstimate estimate;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final p = price;
    if (p == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final low = estimate.lowEur!;
    final high = estimate.highEur!;
    // Axe : la plage du marché, élargie de 40 % de chaque côté.
    final pad = (high - low) * 0.4;
    final min = (low - pad).clamp(0, double.infinity).toDouble();
    final max = high + pad;
    final span = max - min;
    double frac(double v) => span <= 0 ? 0.5 : ((v - min) / span).clamp(0, 1);
    final (status, color) = p < low
        ? (l.negotiationMakeOfferGaugeBelow, cs.warning)
        : p > high
        ? (l.negotiationMakeOfferGaugeAbove, cs.warning)
        : (l.negotiationMakeOfferGaugeWithin, cs.success);
    return Column(
      key: const Key('make-offer-market-gauge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 5,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.outline.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * frac(low),
                    width: w * (frac(high) - frac(low)),
                    top: 5,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.successLight,
                        border: Border.all(color: cs.success),
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * frac(p) - 9,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatPriceIn(min, estimate.currency),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              formatPriceIn(max, estimate.currency),
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          status,
          key: const Key('make-offer-gauge-status'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Estimation banner ────────────────────────────────────────────────────────

class _EstimationBanner extends StatelessWidget {
  const _EstimationBanner({required this.estimate});
  final PriceEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final confidenceColor = switch (estimate.confidence.wireName
        .toLowerCase()) {
      'high' => cs.success,
      'medium' => cs.warning,
      _ => cs.primary,
    };
    final confidenceBg = switch (estimate.confidence.wireName.toLowerCase()) {
      'high' => cs.successLight,
      'medium' => cs.warningLight,
      _ => cs.primaryContainer,
    };
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: DonyIcon('trending-up', color: cs.primary, size: 18),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.negotiationMakeOfferMarketPriceLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPriceIn(estimate.lowEur!, estimate.currency)} – ${formatPriceIn(estimate.highEur!, estimate.currency)}',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
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
              color: confidenceBg,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              estimate.confidence.confidenceLabel(context.l10n),
              style: tt.labelSmall?.copyWith(
                color: confidenceColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
