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
