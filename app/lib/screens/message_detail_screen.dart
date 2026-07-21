import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/email_message.dart';
import 'compose_screen.dart';

class MessageDetailScreen extends StatefulWidget {
  final ApiService api;
  final Account account;
  final EmailMessage message;

  const MessageDetailScreen({
    super.key,
    required this.api,
    required this.account,
    required this.message,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  EmailMessage? _fullMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFullMessage();
  }

  Future<void> _loadFullMessage() async {
    try {
      _fullMessage = await widget.api.getMessage(widget.account.id!, widget.message.id);
    } catch (_) {
      _fullMessage = widget.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = _fullMessage ?? widget.message;
    return Scaffold(
      appBar: AppBar(
        title: const Text('メール詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reply),
            tooltip: '返信',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ComposeScreen(
                  api: widget.api,
                  account: widget.account,
                  replyTo: m,
                ),
              ));
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Headers
              Text(
                m.subject.isNotEmpty ? m.subject : '(件名なし)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _headerRow('From', m.fromAddr),
              _headerRow('To', m.toAddr),
              if (m.ccAddr != null && m.ccAddr!.isNotEmpty)
                _headerRow('Cc', m.ccAddr!),
              _headerRow('日付', m.date),
              const Divider(height: 32),
              // Body
              SelectableText(
                m.bodyText ?? '(本文なし)',
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ],
          ),
    );
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
