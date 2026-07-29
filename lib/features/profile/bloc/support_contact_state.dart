part of 'support_contact_bloc.dart';

enum SupportSubmitStatus { idle, submitting, success, error }

class SupportContactState {
  const SupportContactState({
    this.category = '',
    this.subject = '',
    this.message = '',
    this.submitStatus = SupportSubmitStatus.idle,
    this.errorMessage,
  });

  final String category;
  final String subject;
  final String message;
  final SupportSubmitStatus submitStatus;
  final String? errorMessage;

  bool get isValid =>
      category.isNotEmpty &&
      subject.trim().length >= 5 &&
      message.trim().length >= 20;

  bool get isSubmitting => submitStatus == SupportSubmitStatus.submitting;

  SupportContactState copyWith({
    String? category,
    String? subject,
    String? message,
    SupportSubmitStatus? submitStatus,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SupportContactState(
      category: category ?? this.category,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      submitStatus: submitStatus ?? this.submitStatus,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}
