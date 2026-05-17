import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Mapping sémantique des icônes dony → Phosphor.
/// L'app ne référence jamais Phosphor directement : toujours via DonyIcons.
class DonyIcons {
  DonyIcons._();

  // Trajet
  static const IconData departureCity = PhosphorIconsRegular.airplaneTakeoff;
  static const IconData arrivalCity = PhosphorIconsRegular.airplaneLanding;
  static const IconData time = PhosphorIconsRegular.clock;
  static const IconData date = PhosphorIconsRegular.calendarBlank;

  // Lieux
  static const IconData mapPin = PhosphorIconsRegular.mapPin;
  static const IconData locate = PhosphorIconsRegular.crosshair;

  // Capacité
  static const IconData suitcase = PhosphorIconsRegular.suitcaseRolling;
  static const IconData infinity = PhosphorIconsRegular.infinity;

  // Prix & paiement
  static const IconData editPrice = PhosphorIconsRegular.pencilSimple;
  static const IconData card = PhosphorIconsRegular.creditCard;
  static const IconData cash = PhosphorIconsRegular.money;
  static const IconData escrow = PhosphorIconsRegular.lockKey;
  static const IconData transfer = PhosphorIconsRegular.lightning;
  static const IconData bank = PhosphorIconsRegular.bank;
  static const IconData tip = PhosphorIconsRegular.lightbulb;

  // Navigation & actions
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData back = PhosphorIconsRegular.caretLeft;
  static const IconData chevron = PhosphorIconsRegular.caretRight;
  static const IconData arrowRight = PhosphorIconsRegular.arrowRight;
  static const IconData check = PhosphorIconsRegular.check;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData publish = PhosphorIconsRegular.rocketLaunch;
  // Fill intentionnel — la variante outline manque de poids visuel pour un badge de vérification.
  static const IconData confirmed = PhosphorIconsFill.sealCheck;

  // Modes de transport
  static const IconData transportPlane = PhosphorIconsRegular.airplaneTilt;
  static const IconData transportCar = PhosphorIconsRegular.car;
  static const IconData transportTrain = PhosphorIconsRegular.train;
  static const IconData transportBus = PhosphorIconsRegular.bus;
  static const IconData transportBoat = PhosphorIconsRegular.boat;
  static const IconData transportOther = PhosphorIconsRegular.dotsThreeOutline;
}
