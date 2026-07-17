/// Seuil d'urgence (jours) : une publication est « urgente » si sa date clé
/// tombe dans les [urgencyThresholdDays] prochains jours (aujourd'hui inclus).
/// SOURCE UNIQUE du seuil : backend (`dony.urgency.threshold-days`), chargé au
/// démarrage. Repli sur [kUrgencyThresholdDaysDefault] tant qu'il n'est pas chargé.
const int kUrgencyThresholdDaysDefault = 3;

int _urgencyThresholdDays = kUrgencyThresholdDaysDefault;

int get urgencyThresholdDays => _urgencyThresholdDays;

/// Met à jour le seuil au démarrage. Ignore les valeurs aberrantes (hors ]0,60]).
void setUrgencyThresholdDays(int days) {
  if (days > 0 && days <= 60) _urgencyThresholdDays = days;
}

/// Vrai si [date] tombe entre aujourd'hui et aujourd'hui + seuil (bornes incluses).
bool isUrgentDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(today).inDays;
  return diff >= 0 && diff <= _urgencyThresholdDays;
}
