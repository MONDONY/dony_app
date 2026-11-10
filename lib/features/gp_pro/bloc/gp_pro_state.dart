import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:equatable/equatable.dart';

/// Chargement du statut GP Pro.
enum GpProLoadStatus { loading, ready, failure, unavailable }

/// Avancement de l'envoi d'un justificatif.
enum GpProUploadStatus { uploading, ready, failed }

/// Justificatif affiché dans le formulaire. [localPath] est nul pour une pièce
/// venue de `status.documents` (aucune image locale).
class GpProPiece extends Equatable {
  const GpProPiece({
    required this.localId,
    required this.type,
    this.localPath,
    this.remoteId,
    this.status = GpProUploadStatus.uploading,
  });

  final String localId;
  final GpProDocType type;
  final String? localPath;
  final String? remoteId;
  final GpProUploadStatus status;

  GpProPiece copyWith({String? remoteId, GpProUploadStatus? status}) =>
      GpProPiece(
        localId: localId,
        type: type,
        localPath: localPath,
        remoteId: remoteId ?? this.remoteId,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [localId, type, localPath, remoteId, status];
}

class GpProCubitState extends Equatable {
  const GpProCubitState({
    this.load = GpProLoadStatus.loading,
    this.status,
    this.frequency,
    this.pieces = const [],
    this.submitting = false,
    this.cancelling = false,
    this.restarting = false,
    this.resigning = false,
    this.resigned = false,
    this.errorCode,
  });

  static const maxPieces = 4;

  final GpProLoadStatus load;
  final GpProStatus? status;
  final GpProFrequency? frequency;
  final List<GpProPiece> pieces;
  final bool submitting;
  final bool cancelling;

  /// « Refaire une demande » : le statut reste REJECTED/REVOKED mais l'écran
  /// montre le formulaire.
  final bool restarting;

  /// « Redevenir particulier » en cours d'envoi.
  final bool resigning;

  /// Le voyageur a quitté le statut GP Pro (ou n'y était déjà plus) : l'écran
  /// recharge le profil et le dit.
  final bool resigned;

  /// Code d'erreur de la dernière action (`GpProException.code`), à traduire.
  final String? errorCode;

  bool get canAddPiece => pieces.length < maxPieces;

  bool get hasUploading =>
      pieces.any((p) => p.status == GpProUploadStatus.uploading);

  bool get canSubmit => frequency != null && !hasUploading && !submitting;

  GpProCubitState copyWith({
    GpProLoadStatus? load,
    GpProStatus? status,
    GpProFrequency? frequency,
    List<GpProPiece>? pieces,
    bool? submitting,
    bool? cancelling,
    bool? restarting,
    bool? resigning,
    bool? resigned,
    String? errorCode,
    bool clearError = false,
  }) => GpProCubitState(
    load: load ?? this.load,
    status: status ?? this.status,
    frequency: frequency ?? this.frequency,
    pieces: pieces ?? this.pieces,
    submitting: submitting ?? this.submitting,
    cancelling: cancelling ?? this.cancelling,
    restarting: restarting ?? this.restarting,
    resigning: resigning ?? this.resigning,
    resigned: resigned ?? this.resigned,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );

  @override
  List<Object?> get props => [
    load,
    status,
    frequency,
    pieces,
    submitting,
    cancelling,
    restarting,
    resigning,
    resigned,
    errorCode,
  ];
}
