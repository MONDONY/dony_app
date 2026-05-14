enum ParcelSize {
  small('SMALL'),
  medium('MEDIUM'),
  large('LARGE');

  final String wireName;
  const ParcelSize(this.wireName);

  static ParcelSize fromJson(String s) =>
      ParcelSize.values.firstWhere((e) => e.wireName == s);
}
