import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/email_message.dart';

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
      appBar: AppBar(title: const Text('メール詳細')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
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

/// Message detail for unified inbox (cross-account, uses /api/messages/<id>).
class UnifiedMessageDetailScreen extends StatefulWidget {
  final ApiService api;
  final EmailMessage message;

  const UnifiedMessageDetailScreen({
    super.key,
    required this.api,
    required this.message,
  });

  @override
  State<UnifiedMessageDetailScreen> createState() => _UnifiedMessageDetailScreenState();
}

class _UnifiedMessageDetailScreenState extends State<UnifiedMessageDetailScreen> {
  EmailMessage? _fullMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFullMessage();
  }

  Future<void> _loadFullMessage() async {
    try {
      _fullMessage = await widget.api.getUnifiedMessage(widget.message.id);
    } catch (_) {
      _fullMessage = widget.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = _fullMessage ?? widget.message;
    return Scaffold(
      appBar: AppBar(title: const Text('メール詳細')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (m.accountLabel != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(m.accountLabel!,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                ),
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
