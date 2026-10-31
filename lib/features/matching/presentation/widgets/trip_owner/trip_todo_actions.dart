import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/notify_recipients_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_activity_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_parcels_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_sheets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouvre le geste de l'action « À traiter » [item] de l'écran du trajet,
/// depuis [context] (l'écran : corps ou pied collant, sous ses blocs et son
/// `TripBidAnswerScope`). Seul point d'entrée de la grosse carte, de la file
/// et du pied : un même type ouvre toujours le même geste. [live] : données
/// affichées, dont les derniers colis repris par les sheets.
///
/// - [TripTodoKind.requests] : le sheet des demandes (`openTripActivitySheet`,
///   Refuser et Accepter par ligne, comme le lien « Voir les N demandes » de
///   la carte de réponse directe) ;
/// - [TripTodoKind.depart], [TripTodoKind.addCard] : leur sheet
///   ([openTripTodoSheet]) ;
/// - [TripTodoKind.arrive] : « Arrivé à destination »
///   (`ArrivalInstructionsBottomSheet`, `isEditing: false`), l'écran ouvre
///   ensuite « Prévenir les destinataires » de lui-même ;
/// - [TripTodoKind.notify] : « Prévenir les destinataires »
///   (`NotifyRecipientsSheet`, `source: manual`) ;
/// - [TripTodoKind.instructions] : l'édition des instructions de retrait
///   (`ArrivalInstructionsBottomSheet`, `isEditing: true`), celle de la tuile
///   « Arrivée » ;
/// - [TripTodoKind.publish] : `AnnouncementPublishRequested` (KYC, date
///   passée, limite PRO et écran de succès restent gérés par l'écouteur de
///   l'écran) ;
/// - les actions par colis ([TripTodoKind.perParcel]) : le sheet qui liste
///   les colis concernés ([openTripTodoParcelsSheet]).
///
/// Mesure : `bid_detail_tile_opened` (`tile` = nom du type, `role:
/// trip_owner`, `source` = [source]) à l'ouverture de chaque sheet. Les
/// sheets des demandes, de « Je pars », de la carte et des colis la posent
/// eux-mêmes ; elle est posée ici pour « Arrivé à destination », « Prévenir
/// les destinataires » et les instructions de retrait, dont les feuilles
/// gardent en plus leurs propres événements. « Publier » n'ouvre pas de
/// sheet : rien de plus que les événements de la publication.
Future<void> openTripTodoAction(
  BuildContext context,
  TripTodoLiveData live,
  TripTodoItem item, {
  required TripTodoSource source,
}) async {
  final trip = live.trip;
  final bids = live.bids;
  void log() => logBidDetailTileOpened(
    tile: item.kind.name,
    role: 'trip_owner',
    source: source.name,
  );
  switch (item.kind) {
    case TripTodoKind.requests:
      await openTripActivitySheet(
        context,
        trip,
        TripActivity.requests,
        bids: bids,
        source: switch (source) {
          TripTodoSource.card => TripActivitySource.card,
          TripTodoSource.list => TripActivitySource.list,
          TripTodoSource.footer => TripActivitySource.footer,
        },
      );
    case TripTodoKind.depart || TripTodoKind.addCard:
      await openTripTodoSheet(
        context,
        trip,
        item.kind,
        source: source,
        bids: bids,
      );
    case TripTodoKind.arrive:
      log();
      await ArrivalInstructionsBottomSheet.show(
        context,
        announcementId: trip.id,
        initialInstructions: trip.arrivalInstructions,
      );
    case TripTodoKind.notify:
      log();
      await NotifyRecipientsSheet.show(
        context,
        bids: bids ?? const [],
        source: NotifyRecipientsSource.manual,
        instructions: trip.arrivalInstructions,
      );
    case TripTodoKind.instructions:
      log();
      await ArrivalInstructionsBottomSheet.show(
        context,
        announcementId: trip.id,
        initialInstructions: trip.arrivalInstructions,
        isEditing: true,
      );
    case TripTodoKind.publish:
      context.read<AnnouncementBloc>().add(
        AnnouncementPublishRequested(trip.id),
      );
    case TripTodoKind.presence ||
        TripTodoKind.scan ||
        TripTodoKind.amendment ||
        TripTodoKind.supplement ||
        TripTodoKind.senderAbsence ||
        TripTodoKind.returnParcel ||
        TripTodoKind.deliver ||
        TripTodoKind.recipientDeclined ||
        TripTodoKind.rate:
      await openTripTodoParcelsSheet(
        context,
        trip,
        item.kind,
        source: source,
        bids: bids,
      );
  }
}
