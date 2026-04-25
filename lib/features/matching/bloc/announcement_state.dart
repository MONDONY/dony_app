import 'package:dony/features/matching/data/models/announcement_model.dart';

abstract class AnnouncementState {}

class AnnouncementInitial extends AnnouncementState {}

class AnnouncementLoading extends AnnouncementState {}

class AnnouncementCreated extends AnnouncementState {
  final AnnouncementModel announcement;

  AnnouncementCreated(this.announcement);
}

class AnnouncementError extends AnnouncementState {
  final String message;

  AnnouncementError(this.message);
}

class AnnouncementListLoaded extends AnnouncementState {
  final List<AnnouncementModel> announcements;
  final int totalElements;
  AnnouncementListLoaded(this.announcements, {this.totalElements = 0});
}

class AnnouncementDetailLoaded extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementDetailLoaded(this.announcement);
}

class AnnouncementUpdated extends AnnouncementState {
  final AnnouncementModel announcement;
  AnnouncementUpdated(this.announcement);
}

class AnnouncementDeleted extends AnnouncementState {}

class AnnouncementSearchLoaded extends AnnouncementState {
  final List<AnnouncementModel> results;
  final bool isEmpty;
  AnnouncementSearchLoaded(this.results) : isEmpty = results.isEmpty;
}
