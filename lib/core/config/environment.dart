/// Environnement de build (`--dart-define=ENVIRONMENT=...`) : `development`,
/// `staging` ou `production`.
const String kEnvironment = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'development',
);
