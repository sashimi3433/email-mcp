import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/email_message.dart';

class ComposeScreen extends StatefulWidget {
  final ApiService api;
  final Account account;
  final EmailMessage? replyTo;

  const ComposeScreen({
    super.key,
    required this.api,
    required this.account,
    this.replyTo,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late TextEditingController _to;
  late TextEditingController _cc;
  late TextEditingController _subject;
  late TextEditingController _body;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.replyTo != null) {
      final r = widget.replyTo!;
      _to = TextEditingController(text: _extractAddr(r.fromAddr));
      _cc = TextEditingController();
      _subject = TextEditingController(
        text: r.subject.startsWith('Re:') ? r.subject : 'Re: ${r.subject}');
      _body = TextEditingController(text: '\n\n---\n\n${r.bodyText ?? ''}');
    } else {
      _to = TextEditingController();
      _cc = TextEditingController();
      _subject = TextEditingController();
      _body = TextEditingController();
    }
  }

  String _extractAddr(String from) {
    // Extract email from "Name <email>" format
    final match = RegExp(r'<(.+?)>').firstMatch(from);
    return match?.group(1) ?? from;
  }

  @override
  void dispose() {
    _to.dispose();
    _cc.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_to.text.isEmpty || _subject.text.isEmpty || _body.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('宛先・件名・本文は必須です'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _sending = true);
    try {
      if (widget.replyTo != null) {
        // Use reply API
        await widget.api.replyMessage(
          widget.account.id!,
          widget.replyTo!.id,
          body: _body.text,
          replyAll: _cc.text.isNotEmpty,
        );
      } else {
        // Use send API
        await widget.api.sendMail(
          widget.account.id!,
          to: _to.text,
          subject: _subject.text,
          body: _body.text,
          cc: _cc.text.isEmpty ? null : _cc.text,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信完了'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信エラー: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replyTo != null ? '返信' : '新規メール'),
        actions: [
          IconButton(
            icon: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
            onPressed: _sending ? null : _send,
            tooltip: '送信',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _to,
            decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cc,
            decoration: const InputDecoration(labelText: 'Cc', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: '件名', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            decoration: const InputDecoration(
              labelText: '本文',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 20,
            minLines: 10,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_sending ? '送信中...' : '送信'),
          ),
        ],
      ),
    );
  }
}
