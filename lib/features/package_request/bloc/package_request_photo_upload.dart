enum PackageRequestPhotoUploadStatus { uploading, ready, failed }

/// Une photo colis locale en cours/terminée d'upload dans le wizard de demande.
class PackageRequestPhotoUpload {
  final String localId;
  final String localPath;
  final PackageRequestPhotoUploadStatus status;
  final String? remoteKey;

  /// URL présignée pour une photo déjà attachée (mode édition). Null pour
  /// une photo locale en cours d'upload (affichée depuis [localPath]).
  final String? remoteUrl;

  /// Message d'erreur si [status] == failed (pour diagnostic / affichage).
  final String? error;

  const PackageRequestPhotoUpload({
    required this.localId,
    required this.localPath,
    this.status = PackageRequestPhotoUploadStatus.uploading,
    this.remoteKey,
    this.remoteUrl,
    this.error,
  });

  /// true si la photo provient du serveur (mode édition) — rendu réseau au
  /// lieu d'un fichier local.
  bool get isRemote => localPath.isEmpty && remoteUrl != null;

  PackageRequestPhotoUpload copyWith({
    PackageRequestPhotoUploadStatus? status,
    String? remoteKey,
    String? remoteUrl,
    String? error,
  }) => PackageRequestPhotoUpload(
    localId: localId,
    localPath: localPath,
    status: status ?? this.status,
    remoteKey: remoteKey ?? this.remoteKey,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    error: error ?? this.error,
  );
}
