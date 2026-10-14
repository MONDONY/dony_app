import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/referral/data/models/referee.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';

abstract class ReferralState {
  const ReferralState();
}

class ReferralInitial extends ReferralState {
  const ReferralInitial();
}

class ReferralLoading extends ReferralState {
  const ReferralLoading();
}

/// Chargement de la liste des filleuls, indépendant du reste de l'écran.
enum RefereesStatus {
  /// Jamais demandée (profil) : rien à afficher.
  idle,
  loading,
  loaded,

  /// Back antérieur à #528 (404) : la section est masquée.
  unavailable,
  error,
}

class ReferralLoaded extends ReferralState {
  const ReferralLoaded(
    this.info, {
    this.referees = const [],
    this.refereesStatus = RefereesStatus.idle,
    this.refereesPage = 0,
    this.refereesLast = true,
    this.loadingMoreReferees = false,
    this.choosingInvitationId,
    this.rewardResult,
    this.rewardError,
  });

  final ReferralInfo info;
  final List<Referee> referees;
  final RefereesStatus refereesStatus;

  /// Dernière page chargée.
  final int refereesPage;
  final bool refereesLast;
  final bool loadingMoreReferees;

  /// Invitation dont le choix de récompense est en cours d'envoi.
  final String? choosingInvitationId;

  /// Filleul mis à jour par un choix qui vient d'aboutir. Événement ponctuel :
  /// [copyWith] ne le reporte jamais sur l'état suivant.
  final Referee? rewardResult;

  /// Échec d'un choix de récompense, ponctuel comme [rewardResult].
  final AppException? rewardError;

  bool get isChoosingReward => choosingInvitationId != null;

  /// Filleuls dont la récompense attend un choix.
  List<Referee> get availableRewards =>
      referees.where((r) => r.isRewardAvailable).toList();

  /// Somme des crédits wallet choisis parmi les filleuls chargés.
  double get earnedWalletAmount =>
      referees.fold(0, (sum, r) => sum + r.earnedWalletAmount);

  ReferralLoaded copyWith({
    ReferralInfo? info,
    List<Referee>? referees,
    RefereesStatus? refereesStatus,
    int? refereesPage,
    bool? refereesLast,
    bool? loadingMoreReferees,
    String? choosingInvitationId,
    bool clearChoosing = false,
    Referee? rewardResult,
    AppException? rewardError,
  }) => ReferralLoaded(
    info ?? this.info,
    referees: referees ?? this.referees,
    refereesStatus: refereesStatus ?? this.refereesStatus,
    refereesPage: refereesPage ?? this.refereesPage,
    refereesLast: refereesLast ?? this.refereesLast,
    loadingMoreReferees: loadingMoreReferees ?? this.loadingMoreReferees,
    choosingInvitationId: clearChoosing
        ? null
        : (choosingInvitationId ?? this.choosingInvitationId),
    rewardResult: rewardResult,
    rewardError: rewardError,
  );
}

class ReferralError extends ReferralState {
  const ReferralError(this.error);
  final AppException error;
}

class ReferralRedeemLoading extends ReferralState {
  const ReferralRedeemLoading();
}

class ReferralRedeemed extends ReferralState {
  const ReferralRedeemed();
}

class ReferralRedeemError extends ReferralState {
  const ReferralRedeemError(this.error);
  final AppException error;
}
