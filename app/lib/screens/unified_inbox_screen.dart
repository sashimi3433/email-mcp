import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/email_message.dart';
import 'message_detail_screen.dart';

class UnifiedInboxScreen extends StatefulWidget {
  final ApiService api;

  const UnifiedInboxScreen({super.key, required this.api});

  @override
  State<UnifiedInboxScreen> createState() => _UnifiedInboxScreenState();
}

class _UnifiedInboxScreenState extends State<UnifiedInboxScreen> {
  List<EmailMessage> _messages = [];
  bool _loading = true;
  bool _syncing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      _messages = await widget.api.listAllMessages(limit: 200);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadMessages();
  }

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    try {
      final accounts = await widget.api.listAccounts();
      int totalSynced = 0;
      for (final a in accounts) {
        final result = await widget.api.syncAccount(a.id!);
        totalSynced += (result['messages_synced'] ?? 0) as int;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('全アカウント同期完了 ($totalSynced件)'),
            backgroundColor: Colors.green));
      }
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同期エラー: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  Color _avatarColor(String label) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.pink, Colors.indigo, Colors.brown,
    ];
    return colors[label.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('すべてのメール'),
        actions: [
          IconButton(
            icon: _syncing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
            onPressed: _syncing ? null : _syncAll,
            tooltip: '全アカウント同期',
          ),
        ],
      ),
      body: _loading && _messages.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _messages.isEmpty
          ? RefreshIndicator(
              onRefresh: _syncAll,
              child: ListView(children: [
                const SizedBox(height: 100),
                Center(child: Column(children: [
                  const Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('メールがありません'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _syncAll,
                    icon: const Icon(Icons.sync),
                    label: const Text('同期する'),
                  ),
                ])),
              ]),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final m = _messages[i];
                  final label = m.accountLabel ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _avatarColor(label),
                      child: Text(
                        m.fromAddr.isNotEmpty ? m.fromAddr[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      m.subject.isNotEmpty ? m.subject : '(件名なし)',
                      style: TextStyle(
                        fontWeight: m.isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        if (label.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _avatarColor(label).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(label, style: TextStyle(fontSize: 10,
                              color: _avatarColor(label), fontWeight: FontWeight.w600)),
                          ),
                        Expanded(
                          child: Text(
                            '${m.fromAddr}  •  ${_formatDate(m.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    trailing: m.isUnread
                      ? Container(width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue, shape: BoxShape.circle))
                      : null,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UnifiedMessageDetailScreen(
                          api: widget.api, message: m,
                        ),
                      ));
                    },
                  );
                },
              ),
            ),
    );
  }
}
