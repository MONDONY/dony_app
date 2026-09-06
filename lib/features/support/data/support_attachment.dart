import 'package:equatable/equatable.dart';

/// Image jointe à un message support. L'URL est présignée par le backend et
/// expire au bout d'une heure : ne jamais la mettre en cache sur disque.
class SupportAttachment extends Equatable {
  const SupportAttachment({
    required this.id,
    required this.url,
    required this.contentType,
  });

  final String id;
  final String url;
  final String contentType;

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['id'] as String,
      url: json['url'] as String,
      contentType: json['contentType'] as String? ?? 'image/jpeg',
    );
  }

  @override
  List<Object?> get props => [id, url, contentType];
}

enum SupportUploadStatus { uploading, ready, failed }

/// État local d'une image en cours d'envoi, avant qu'elle ne rejoigne un
/// message. `remoteKey` n'est rempli qu'une fois l'upload terminé.
class SupportAttachmentUpload extends Equatable {
  const SupportAttachmentUpload({
    required this.localId,
    required this.localPath,
    required this.status,
    this.remoteKey,
  });

  final String localId;
  final String localPath;
  final SupportUploadStatus status;
  final String? remoteKey;

  SupportAttachmentUpload copyWith({
    SupportUploadStatus? status,
    String? remoteKey,
  }) {
    return SupportAttachmentUpload(
      localId: localId,
      localPath: localPath,
      status: status ?? this.status,
      remoteKey: remoteKey ?? this.remoteKey,
    );
  }

  @override
  List<Object?> get props => [localId, localPath, status, remoteKey];
}
