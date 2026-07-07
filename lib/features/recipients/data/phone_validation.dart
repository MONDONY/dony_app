/// E.164 phone regex shared across the recipients feature: `+` followed by
/// 7 to 15 digits total (country code + subscriber number), first digit
/// non-zero. A 2-7 digit number isn't a reachable phone number, so both
/// call sites use this stricter form (matches `complete_details_screen`'s
/// inline validator).
final RegExp kRecipientPhoneE164 = RegExp(r'^\+[1-9]\d{6,14}$');
