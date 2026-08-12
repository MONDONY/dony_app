class FavoriteIds {
  final Set<String> trips;
  final Set<String> packageRequests;

  const FavoriteIds({required this.trips, required this.packageRequests});

  factory FavoriteIds.fromJson(Map<String, dynamic> json) => FavoriteIds(
        trips: (json['trips'] as List? ?? []).map((e) => e.toString()).toSet(),
        packageRequests: (json['packageRequests'] as List? ?? [])
            .map((e) => e.toString())
            .toSet(),
      );

  factory FavoriteIds.empty() =>
      const FavoriteIds(trips: {}, packageRequests: {});
}
