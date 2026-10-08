import 'dart:async';

import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Départ connu d'un trajet, vu de la confirmation de livraison.
///
/// Le back refuse `POST /tracking/{bidId}/confirm-delivery` (422
/// `trip-not-departed`, yadony-back #419, FLUTTER-CB) tant que le trajet n'est
/// pas parti : date et heure dans le fuseau du trajet, ou, sans heure, à
/// partir du lendemain du jour de départ. L'app ne fait que refléter cette
/// règle pour ne pas proposer un bouton voué à l'échec : le serveur fait foi.
class DeliveryWindow {
  const DeliveryWindow({required this.departure, required this.hasTime});

  /// Instant de départ si [hasTime], sinon le jour de départ (minuit local).
  final DateTime departure;

  /// L'heure de départ est connue.
  final bool hasTime;

  /// Premier instant où la livraison peut être confirmée.
  DateTime get opensAt => hasTime
      ? departure
      : DateTime(departure.year, departure.month, departure.day + 1);

  /// Fenêtre d'un bid, ou `null` si aucune date de départ n'est connue : le
  /// bouton reste alors actif et seul le serveur tranche.
  ///
  /// `departureAt` (instant canonique servi par le back, fuseau du trajet) est
  /// la source fiable. Le repli `departureDate` + `departureTime` de
  /// [BidModel.resolvedDepartureAt] lit l'heure dans le fuseau de l'appareil :
  /// approximatif pour un voyageur hors du fuseau du trajet, il ne sert que de
  /// garde-fou d'affichage.
  static DeliveryWindow? fromBid(BidModel bid) {
    final at = bid.resolvedDepartureAt;
    if (at != null) return DeliveryWindow(departure: at, hasTime: true);
    final day = bid.departureDate;
    if (day == null) return null;
    return DeliveryWindow(departure: day, hasTime: false);
  }
}

/// Verrouille la confirmation de livraison jusqu'au départ du trajet.
///
/// [builder] reçoit `null` quand la livraison est ouverte (ou le départ
/// inconnu), sinon l'explication à afficher sous le bouton désactivé. Le
/// verrou tombe tout seul à l'heure du départ (minuterie annulée à la
/// destruction) et se réévalue au retour de l'app au premier plan : jamais
/// besoin de relancer l'app. L'état vit dans un [ValueNotifier], pas de
/// `setState`.
class DeliveryDepartureGate extends StatefulWidget {
  const DeliveryDepartureGate({
    super.key,
    required this.window,
    required this.builder,
    this.now = DateTime.now,
  });

  final DeliveryWindow? window;
  final Widget Function(BuildContext context, String? lockedHint) builder;

  /// Horloge injectable pour les tests.
  final DateTime Function() now;

  /// Réveil maximal entre deux vérifications : une minuterie de plusieurs
  /// jours dériverait pendant la mise en veille de l'appareil.
  static const maxWait = Duration(hours: 1);

  @override
  State<DeliveryDepartureGate> createState() => _DeliveryDepartureGateState();
}

class _DeliveryDepartureGateState extends State<DeliveryDepartureGate>
    with WidgetsBindingObserver {
  late final ValueNotifier<bool> _locked = ValueNotifier(_computeLocked());
  Timer? _timer;

  bool _computeLocked() {
    final window = widget.window;
    if (window == null) return false;
    return widget.now().isBefore(window.opensAt);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant DeliveryDepartureGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    _locked.value = _computeLocked();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final window = widget.window;
    if (window == null || !_locked.value) return;
    var wait = window.opensAt.difference(widget.now());
    if (wait.isNegative) wait = Duration.zero;
    if (wait > DeliveryDepartureGate.maxWait) {
      wait = DeliveryDepartureGate.maxWait;
    }
    // Une seconde de marge : réveillé pile à l'heure, l'horloge peut encore
    // lire l'instant d'avant.
    _timer = Timer(wait + const Duration(seconds: 1), () {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locked.dispose();
    super.dispose();
  }

  String _hint(BuildContext context, DeliveryWindow window) {
    final l = context.l10n;
    // Un jour seul se lit tel quel : converti, minuit UTC basculerait sur la
    // veille à l'ouest de Greenwich.
    final local = window.hasTime
        ? window.departure.toLocal()
        : window.departure;
    final date = DateFormat.yMMMd(l.localeName).format(local);
    if (!window.hasTime) return l.deliveryLockedUntilDepartureDay(date);
    final time = DateFormat.Hm(l.localeName).format(local);
    return l.deliveryLockedUntilDeparture(date, time);
  }

  @override
  Widget build(BuildContext context) {
    // Mode recette (FLUTTER-FA, staging) : le back accepte la livraison avant
    // le départ pour un compte testeur, le bouton ne doit donc pas la bloquer.
    final recette = recetteModeOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _locked,
      builder: (context, locked, _) {
        final window = widget.window;
        return widget.builder(
          context,
          locked && !recette && window != null ? _hint(context, window) : null,
        );
      },
    );
  }
}

/// Mode recette ouvert pour l'utilisateur connecté (`recetteMode` de
/// `GET /auth/me`, FLUTTER-FA/FB). Faux sans session ou hors d'un arbre muni
/// d'[AuthBloc] (écran isolé, test) : le comportement normal s'applique.
bool recetteModeOf(BuildContext context) {
  try {
    return context.read<AuthBloc>().state.currentUser?.recetteMode ?? false;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Explication affichée sous un bouton de livraison verrouillé.
class DeliveryLockedHint extends StatelessWidget {
  const DeliveryLockedHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      key: const Key('delivery-locked-hint'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
