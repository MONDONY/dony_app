enum BidPhotoUploadStatus { uploading, ready, failed }

/// Une photo locale en cours/terminée d'upload dans le formulaire de bid.
class BidPhotoUpload {
  final String localId;
  final String localPath;
  final BidPhotoUploadStatus status;
  final String? remoteKey;

  const BidPhotoUpload({
    required this.localId,
    required this.localPath,
    this.status = BidPhotoUploadStatus.uploading,
    this.remoteKey,
  });

  BidPhotoUpload copyWith({BidPhotoUploadStatus? status, String? remoteKey}) =>
      BidPhotoUpload(
        localId: localId,
        localPath: localPath,
        status: status ?? this.status,
        remoteKey: remoteKey ?? this.remoteKey,
      );
}
