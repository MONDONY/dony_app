import 'package:dony/features/package_request/data/models/package_request.dart';

/// Création pré-remplie depuis une demande existante (dupliquer, republier).
class PackageRequestDuplicate {
  const PackageRequestDuplicate(this.source, {this.clearDate = false});
  final PackageRequest source;
  final bool clearDate;
}
