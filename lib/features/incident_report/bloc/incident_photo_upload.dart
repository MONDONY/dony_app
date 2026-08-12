enum IncidentPhotoUploadStatus { uploading, ready, failed }

/// Une capture d'écran locale en cours/terminée d'upload dans le formulaire.
class IncidentPhotoUpload {
  final String localId;
  final String localPath;
  final IncidentPhotoUploadStatus status;
  final String? remoteKey;

  const IncidentPhotoUpload({
    required this.localId,
    required this.localPath,
    this.status = IncidentPhotoUploadStatus.uploading,
    this.remoteKey,
  });

  IncidentPhotoUpload copyWith({IncidentPhotoUploadStatus? status, String? remoteKey}) =>
      IncidentPhotoUpload(
        localId: localId,
        localPath: localPath,
        status: status ?? this.status,
        remoteKey: remoteKey ?? this.remoteKey,
      );
}
