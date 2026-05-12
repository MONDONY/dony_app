part of 'support_contact_bloc.dart';

abstract class SupportContactEvent {
  const SupportContactEvent();
}

class SupportCategorySelected extends SupportContactEvent {
  const SupportCategorySelected(this.category);
  final String category;
}

class SupportSubjectChanged extends SupportContactEvent {
  const SupportSubjectChanged(this.subject);
  final String subject;
}

class SupportMessageChanged extends SupportContactEvent {
  const SupportMessageChanged(this.message);
  final String message;
}

class SupportSubmitRequested extends SupportContactEvent {
  const SupportSubmitRequested();
}
