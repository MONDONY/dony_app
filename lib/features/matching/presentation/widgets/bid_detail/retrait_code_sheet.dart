import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bottom sheet affichant le code de retrait du colis pour l'expéditeur.
///
/// Même comportement que [QrSheet] : un bouton du talon l'ouvre. Le contenu
/// (digits, copier, régénérer, explication) est rendu par [TalonRetraitCodeView],
/// qui consomme [TrackingBloc] (régénération) et [BidBloc] (rechargement du bid
/// après régénération). Ces deux BLoCs sont fournis par valeur depuis l'écran
/// appelant afin que la régénération mette à jour l'état réel de l'écran.
abstract final class RetraitCodeSheet {
  static Future<void> show(
    BuildContext context, {
    required BidModel bid,
    TrackingBloc? trackingBloc,
    BidBloc? bidBloc,
  }) async {
    // Haptic feedback best-effort (non-blocking)
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));

    // Analytics best-effort
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.bidRetraitCodeOpened,
        properties: {'status': bid.status},
      ),
    );

    // Capture des BLoCs de l'écran AVANT toute suspension asynchrone.
    final tracking = trackingBloc ?? context.read<TrackingBloc>();
    final bidB = bidBloc ?? context.read<BidBloc>();

    await DonyBottomSheet.show<void>(
      context,
      title: 'Code de retrait',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: tracking),
          BlocProvider<BidBloc>.value(value: bidB),
        ],
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: TalonRetraitCodeView(
          bidId: bid.id,
          initialCode: bid.confirmationCode!,
          refreshCount: bid.confirmationCodeRefreshCount,
          refreshWindowStart: bid.confirmationCodeRefreshWindowStart,
        ),
      ),
    );
  }
}
