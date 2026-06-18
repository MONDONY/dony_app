enum PackageRequestPhotoUploadStatus { uploading, ready, failed }

/// Une photo colis locale en cours/terminée d'upload dans le wizard de demande.
class PackageRequestPhotoUpload {
  final String localId;
  final String localPath;
  final PackageRequestPhotoUploadStatus status;
  final String? remoteKey;

  /// Message d'erreur si [status] == failed (pour diagnostic / affichage).
  final String? error;

  const PackageRequestPhotoUpload({
    required this.localId,
    required this.localPath,
    this.status = PackageRequestPhotoUploadStatus.uploading,
    this.remoteKey,
    this.error,
  });

  PackageRequestPhotoUpload copyWith({
    PackageRequestPhotoUploadStatus? status,
    String? remoteKey,
    String? error,
  }) =>
      PackageRequestPhotoUpload(
        localId: localId,
        localPath: localPath,
        status: status ?? this.status,
        remoteKey: remoteKey ?? this.remoteKey,
        error: error ?? this.error,
      );
}
