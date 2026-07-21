/// Email account model.
class Account {
  final int? id;
  final String label;
  final String emailAddress;
  final String? username;
  final String? imapHost;
  final int? imapPort;
  final bool? imapSsl;
  final String? smtpHost;
  final int? smtpPort;
  final bool? smtpSsl;
  final String? lastSync;
  final String? createdAt;
  final String? serverDomain;
  final int? serverDomainId;

  Account({
    this.id,
    required this.label,
    required this.emailAddress,
    this.username,
    this.imapHost,
    this.imapPort,
    this.imapSsl,
    this.smtpHost,
    this.smtpPort,
    this.smtpSsl,
    this.lastSync,
    this.createdAt,
    this.serverDomain,
    this.serverDomainId,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int?,
      label: json['label'] as String? ?? '',
      emailAddress: json['email_address'] as String? ?? '',
      username: json['username'] as String?,
      imapHost: json['imap_host'] as String?,
      imapPort: json['imap_port'] as int?,
      imapSsl: json['imap_ssl'] == null ? null : (json['imap_ssl'] == 1 || json['imap_ssl'] == true),
      smtpHost: json['smtp_host'] as String?,
      smtpPort: json['smtp_port'] as int?,
      smtpSsl: json['smtp_ssl'] == null ? null : (json['smtp_ssl'] == 1 || json['smtp_ssl'] == true),
      lastSync: json['last_sync'] as String?,
      createdAt: json['created_at'] as String?,
      serverDomain: json['server_domain'] as String?,
      serverDomainId: json['server_domain_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'email_address': emailAddress,
    'username': username,
    'imap_host': imapHost,
    'imap_port': imapPort,
    'imap_ssl': imapSsl,
    'smtp_host': smtpHost,
    'smtp_port': smtpPort,
    'smtp_ssl': smtpSsl,
    if (serverDomainId != null) 'server_domain_id': serverDomainId,
  };

  Account copyWith({
    int? id,
    String? label,
    String? emailAddress,
    String? username,
    String? imapHost,
    int? imapPort,
    bool? imapSsl,
    String? smtpHost,
    int? smtpPort,
    bool? smtpSsl,
    String? lastSync,
    String? createdAt,
    String? serverDomain,
    int? serverDomainId,
  }) {
    return Account(
      id: id ?? this.id,
      label: label ?? this.label,
      emailAddress: emailAddress ?? this.emailAddress,
      username: username ?? this.username,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      imapSsl: imapSsl ?? this.imapSsl,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpSsl: smtpSsl ?? this.smtpSsl,
      lastSync: lastSync ?? this.lastSync,
      createdAt: createdAt ?? this.createdAt,
      serverDomain: serverDomain ?? this.serverDomain,
      serverDomainId: serverDomainId ?? this.serverDomainId,
    );
  }
}
