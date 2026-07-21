/// Reusable server domain configuration model.
class ServerDomain {
  final int? id;
  final String domain;
  final String imapHost;
  final int imapPort;
  final bool imapSsl;
  final String smtpHost;
  final int smtpPort;
  final bool smtpSsl;
  final String? createdAt;

  ServerDomain({
    this.id,
    required this.domain,
    required this.imapHost,
    this.imapPort = 993,
    this.imapSsl = true,
    required this.smtpHost,
    this.smtpPort = 587,
    this.smtpSsl = true,
    this.createdAt,
  });

  factory ServerDomain.fromJson(Map<String, dynamic> json) {
    return ServerDomain(
      id: json['id'] as int?,
      domain: json['domain'] as String? ?? '',
      imapHost: json['imap_host'] as String? ?? '',
      imapPort: json['imap_port'] as int? ?? 993,
      imapSsl: json['imap_ssl'] == null ? true : (json['imap_ssl'] == 1 || json['imap_ssl'] == true),
      smtpHost: json['smtp_host'] as String? ?? '',
      smtpPort: json['smtp_port'] as int? ?? 587,
      smtpSsl: json['smtp_ssl'] == null ? true : (json['smtp_ssl'] == 1 || json['smtp_ssl'] == true),
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'imap_host': imapHost,
    'imap_port': imapPort,
    'imap_ssl': imapSsl,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
    'smtp_ssl': smtpSsl,
  };
}
