import 'package:flutter/material.dart';

/// Mapping sémantique des icônes Yadony → Material Icons.
/// L'app ne référence jamais Material directement : toujours via DonyIcons.
///
/// NB : phosphor_flutter a été retiré car il étend `IconData`, devenu une
/// classe `final` à partir de Flutter 3.44 (erreur de compilation du kernel).
/// Pour revenir à Phosphor plus tard, restaurer l'ancien mapping avec une
/// version compatible du package.
class DonyIcons {
  DonyIcons._();

  // Trajet
  static const IconData departureCity = Icons.flight_takeoff_rounded;
  static const IconData arrivalCity = Icons.flight_land_rounded;
  static const IconData time = Icons.access_time_rounded;
  static const IconData date = Icons.calendar_today_rounded;

  // Lieux
  static const IconData mapPin = Icons.location_on_rounded;
  static const IconData locate = Icons.my_location_rounded;

  // Capacité
  static const IconData suitcase = Icons.luggage_rounded;
  static const IconData infinity = Icons.all_inclusive_rounded;

  // Prix & paiement
  static const IconData editPrice = Icons.edit_rounded;
  static const IconData card = Icons.credit_card_rounded;
  static const IconData cash = Icons.payments_rounded;
  static const IconData escrow = Icons.lock_rounded;
  static const IconData transfer = Icons.bolt_rounded;
  static const IconData bank = Icons.account_balance_rounded;
  static const IconData tip = Icons.lightbulb_rounded;

  // Navigation & actions
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.chevron_left_rounded;
  static const IconData chevron = Icons.chevron_right_rounded;
  static const IconData arrowRight = Icons.arrow_forward_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData minus = Icons.remove_rounded;
  static const IconData publish = Icons.rocket_launch_rounded;
  static const IconData confirmed = Icons.verified_rounded;

  // Modes de transport
  static const IconData transportPlane = Icons.flight_rounded;
  static const IconData transportCar = Icons.directions_car_rounded;
  static const IconData transportTrain = Icons.train_rounded;
  static const IconData transportBus = Icons.directions_bus_rounded;
  static const IconData transportBoat = Icons.directions_boat_rounded;
  static const IconData transportOther = Icons.more_horiz_rounded;
}
