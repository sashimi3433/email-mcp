import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/server_domain.dart';

class DomainFormScreen extends StatefulWidget {
  final ApiService api;
  final ServerDomain? domain;

  const DomainFormScreen({super.key, required this.api, this.domain});

  @override
  State<DomainFormScreen> createState() => _DomainFormScreenState();
}

class _DomainFormScreenState extends State<DomainFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _domain;
  late TextEditingController _imapHost;
  late TextEditingController _imapPort;
  late TextEditingController _smtpHost;
  late TextEditingController _smtpPort;
  bool _imapSsl = true;
  bool _smtpSsl = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.domain;
    _domain = TextEditingController(text: d?.domain ?? '');
    _imapHost = TextEditingController(text: d?.imapHost ?? '');
    _imapPort = TextEditingController(text: (d?.imapPort ?? 993).toString());
    _smtpHost = TextEditingController(text: d?.smtpHost ?? '');
    _smtpPort = TextEditingController(text: (d?.smtpPort ?? 587).toString());
    _imapSsl = d?.imapSsl ?? true;
    _smtpSsl = d?.smtpSsl ?? true;
  }

  @override
  void dispose() {
    _domain.dispose();
    _imapHost.dispose();
    _imapPort.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.upsertDomain({
        'domain': _domain.text,
        'imap_host': _imapHost.text,
        'imap_port': int.tryParse(_imapPort.text) ?? 993,
        'imap_ssl': _imapSsl,
        'smtp_host': _smtpHost.text,
        'smtp_port': int.tryParse(_smtpPort.text) ?? 587,
        'smtp_ssl': _smtpSsl,
      });
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
    final isEdit = widget.domain != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'ドメイン編集' : 'ドメイン追加')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _domain,
              decoration: const InputDecoration(
                labelText: 'ドメイン名 *',
                hintText: 'example.com',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? '必須' : null,
            ),
            const SizedBox(height: 24),
            Text('IMAP（受信）', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 2, child: TextFormField(
                controller: _imapHost,
                decoration: const InputDecoration(labelText: 'IMAPホスト', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? '必須' : null,
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
                validator: (v) => v!.isEmpty ? '必須' : null,
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
