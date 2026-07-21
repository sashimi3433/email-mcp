import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/server_domain.dart';

class AccountFormScreen extends StatefulWidget {
  final ApiService api;
  final Account? account; // null = create new
  final List<ServerDomain> domains;

  const AccountFormScreen({
    super.key,
    required this.api,
    this.account,
    this.domains = const [],
  });

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _label;
  late TextEditingController _email;
  late TextEditingController _username;
  late TextEditingController _password;
  late TextEditingController _imapHost;
  late TextEditingController _imapPort;
  late TextEditingController _smtpHost;
  late TextEditingController _smtpPort;
  bool _imapSsl = true;
  bool _smtpSsl = true;
  int? _selectedDomainId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _label = TextEditingController(text: a?.label ?? '');
    _email = TextEditingController(text: a?.emailAddress ?? '');
    _username = TextEditingController(text: a?.username ?? '');
    _password = TextEditingController();
    _imapHost = TextEditingController(text: a?.imapHost ?? '');
    _imapPort = TextEditingController(text: (a?.imapPort ?? 993).toString());
    _smtpHost = TextEditingController(text: a?.smtpHost ?? '');
    _smtpPort = TextEditingController(text: (a?.smtpPort ?? 587).toString());
    _imapSsl = a?.imapSsl ?? true;
    _smtpSsl = a?.smtpSsl ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _imapHost.dispose();
    _imapPort.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    super.dispose();
  }

  Future<void> _autoFillFromDomain(String email) async {
    if (!email.contains('@')) return;
    final domain = email.split('@')[1];
    // Check local domains first
    for (final d in widget.domains) {
      if (d.domain == domain) {
        setState(() {
          _imapHost.text = d.imapHost;
          _imapPort.text = d.imapPort.toString();
          _smtpHost.text = d.smtpHost;
          _smtpPort.text = d.smtpPort.toString();
          _imapSsl = d.imapSsl;
          _smtpSsl = d.smtpSsl;
          _selectedDomainId = d.id;
        });
        return;
      }
    }
    // Try API lookup
    try {
      final config = await widget.api.lookupDomain(domain);
      if (config != null && mounted) {
        setState(() {
          _imapHost.text = config['imap_host'] ?? _imapHost.text;
          _imapPort.text = (config['imap_port'] ?? 993).toString();
          _smtpHost.text = config['smtp_host'] ?? _smtpHost.text;
          _smtpPort.text = (config['smtp_port'] ?? 587).toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.account == null && _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを入力してください'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'label': _label.text,
        'email_address': _email.text,
        'username': _username.text.isEmpty ? null : _username.text,
        'imap_host': _imapHost.text,
        'imap_port': int.tryParse(_imapPort.text) ?? 993,
        'imap_ssl': _imapSsl,
        'smtp_host': _smtpHost.text,
        'smtp_port': int.tryParse(_smtpPort.text) ?? 587,
        'smtp_ssl': _smtpSsl,
        if (_selectedDomainId != null) 'server_domain_id': _selectedDomainId,
      };
      if (_password.text.isNotEmpty) data['password'] = _password.text;

      if (widget.account != null) {
        await widget.api.updateAccount(widget.account!.id!, data);
      } else {
        await widget.api.createAccount(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'アカウント編集' : 'アカウント追加')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Domain selector
            if (widget.domains.isNotEmpty && !isEdit) ...[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'サーバー設定（ドメイン）',
                  border: OutlineInputBorder(),
                  helperText: '選択すると自動入力されます',
                ),
                initialValue: _selectedDomainId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('手動入力')),
                  ...widget.domains.map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text('${d.domain} (${d.imapHost})'),
                  )),
                ],
                onChanged: (id) {
                  setState(() => _selectedDomainId = id);
                  if (id != null) {
                    for (final d in widget.domains) {
                      if (d.id == id) {
                        _imapHost.text = d.imapHost;
                        _imapPort.text = d.imapPort.toString();
                        _smtpHost.text = d.smtpHost;
                        _smtpPort.text = d.smtpPort.toString();
                        _imapSsl = d.imapSsl;
                        _smtpSsl = d.smtpSsl;
                      }
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'ラベル *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? '必須' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'メールアドレス *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? '必須' : null,
              onChanged: _autoFillFromDomain,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'ユーザー名（空欄=メールアドレス使用）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: isEdit ? 'パスワード（変更時のみ入力）' : 'パスワード *',
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            Text('IMAP（受信）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(
                controller: _imapHost,
                decoration: const InputDecoration(labelText: 'IMAPホスト', border: OutlineInputBorder()),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _imapPort,
                decoration: const InputDecoration(labelText: 'ポート', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              )),
            ]),
            CheckboxListTile(
              title: const Text('SSL/TLS'),
              value: _imapSsl,
              onChanged: (v) => setState(() => _imapSsl = v ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Text('SMTP（送信）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(
                controller: _smtpHost,
                decoration: const InputDecoration(labelText: 'SMTPホスト', border: OutlineInputBorder()),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: _smtpPort,
                decoration: const InputDecoration(labelText: 'ポート', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              )),
            ]),
            CheckboxListTile(
              title: const Text('SSL/TLS'),
              value: _smtpSsl,
              onChanged: (v) => setState(() => _smtpSsl = v ?? true),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
              label: Text(_saving ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
