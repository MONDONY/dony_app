enum SuiviLayout { senderOnly, occasionalTraveler, proTraveler }

SuiviLayout suiviLayoutFor({required bool isTraveler, required bool isPro}) {
  if (!isTraveler) return SuiviLayout.senderOnly;
  if (isPro) return SuiviLayout.proTraveler;
  return SuiviLayout.occasionalTraveler;
}
