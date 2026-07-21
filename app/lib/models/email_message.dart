/// Email message model.
class EmailMessage {
  final int id;
  final String folder;
  final String messageUid;
  final String fromAddr;
  final String toAddr;
  final String? ccAddr;
  final String subject;
  final String date;
  final String? bodyText;
  final String? bodyHtml;
  final String flags;
  final String? fetchedAt;

  EmailMessage({
    required this.id,
    this.folder = 'INBOX',
    this.messageUid = '',
    this.fromAddr = '',
    this.toAddr = '',
    this.ccAddr,
    this.subject = '',
    this.date = '',
    this.bodyText,
    this.bodyHtml,
    this.flags = '',
    this.fetchedAt,
  });

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: json['id'] as int? ?? 0,
      folder: json['folder'] as String? ?? 'INBOX',
      messageUid: json['message_uid'] as String? ?? '',
      fromAddr: json['from_addr'] as String? ?? '',
      toAddr: json['to_addr'] as String? ?? '',
      ccAddr: json['cc_addr'] as String?,
      subject: json['subject'] as String? ?? '',
      date: json['date'] as String? ?? '',
      bodyText: json['body_text'] as String?,
      bodyHtml: json['body_html'] as String?,
      flags: json['flags'] as String? ?? '',
      fetchedAt: json['fetched_at'] as String?,
    );
  }

  bool get isUnread => !flags.contains('\\Seen');
  bool get isFlagged => flags.contains('\\Flagged');
}
