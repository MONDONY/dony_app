enum AnnoncesLayout { senderOnly, occasionalTraveler, proTraveler }

AnnoncesLayout annoncesLayoutFor({
  required bool isTraveler,
  required bool isPro,
}) {
  if (!isTraveler) return AnnoncesLayout.senderOnly;
  if (isPro) return AnnoncesLayout.proTraveler;
  return AnnoncesLayout.occasionalTraveler;
}
