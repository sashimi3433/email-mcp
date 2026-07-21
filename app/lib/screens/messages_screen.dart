import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/email_message.dart';
import 'message_detail_screen.dart';
import 'compose_screen.dart';

class MessagesScreen extends StatefulWidget {
  final ApiService api;
  final Account account;

  const MessagesScreen({super.key, required this.api, required this.account});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<EmailMessage> _messages = [];
  List<Map<String, dynamic>> _folders = [];
  String _selectedFolder = 'INBOX';
  bool _loading = true;
  bool _syncing = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      _folders = await widget.api.listFolders(widget.account.id!);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      _messages = await widget.api.listMessages(widget.account.id!, folder: _selectedFolder);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadMessages();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final result = await widget.api.syncAccount(widget.account.id!);
      if (mounted) {
        final synced = result['messages_synced'] ?? 0;
        final errors = result['errors'] as List?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errors != null && errors.isNotEmpty
              ? '$synced件同期（エラー: ${errors.length}件）'
              : '$synced件同期完了'),
            backgroundColor: errors != null && errors.isNotEmpty ? Colors.orange : Colors.green,
          ),
        );
      }
      await _loadFolders();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同期エラー: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.label),
        actions: [
          IconButton(
            icon: _syncing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
            onPressed: _syncing ? null : _sync,
            tooltip: '同期',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '新規メール',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ComposeScreen(api: widget.api, account: widget.account),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Folder selector
          if (_folders.isNotEmpty || _selectedFolder != 'INBOX')
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _folderChip('INBOX'),
                  ..._folders.map((f) => f['name'] as String)
                    .where((f) => f != 'INBOX')
                    .map(_folderChip),
                ],
              ),
            ),
          const Divider(height: 1),
          // Message list
          Expanded(
            child: _loading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? RefreshIndicator(
                    onRefresh: _sync,
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('メールがありません'),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _sync,
                                icon: const Icon(Icons.sync),
                                label: const Text('同期する'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final m = _messages[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: m.isUnread
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                            child: Text(
                              m.fromAddr.isNotEmpty ? m.fromAddr[0].toUpperCase() : '?',
                              style: TextStyle(color: m.isUnread ? Colors.white : Colors.grey.shade700),
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
                          subtitle: Text(
                            '${m.fromAddr}  •  ${_formatDate(m.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: m.isUnread
                            ? Container(width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle))
                            : null,
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MessageDetailScreen(
                                api: widget.api,
                                account: widget.account,
                                message: m,
                              ),
                            ));
                            if (!mounted) return;
                            _loadMessages();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _folderChip(String folder) {
    final isSelected = folder == _selectedFolder;
    final count = _folders
      .where((f) => f['name'] == folder)
      .map((f) => f['cached_count'] as int?)
      .firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(count != null ? '$folder ($count)' : folder),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedFolder = folder;
            _loading = true;
          });
          _loadMessages();
        },
      ),
    );
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
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }
}
