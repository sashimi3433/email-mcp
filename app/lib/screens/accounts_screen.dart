import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/server_domain.dart';
import 'account_form_screen.dart';
import 'messages_screen.dart';

class AccountsScreen extends StatefulWidget {
  final ApiService api;
  const AccountsScreen({super.key, required this.api});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  List<ServerDomain> _domains = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _accounts = await widget.api.listAccounts();
      _domains = await widget.api.listDomains();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アカウント管理')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (ctx, i) {
                final a = _accounts[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(a.label.isNotEmpty ? a.label[0].toUpperCase() : '?'),
                    ),
                    title: Text(a.label),
                    subtitle: Text(a.emailAddress),
                    trailing: PopupMenuButton(
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'view', child: Text('メールを見る')),
                        const PopupMenuItem(value: 'edit', child: Text('編集')),
                        const PopupMenuItem(value: 'delete', child: Text('削除')),
                      ],
                      onSelected: (val) async {
                        if (val == 'view') {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MessagesScreen(api: widget.api, account: a),
                          ));
                        } else if (val == 'edit') {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AccountFormScreen(api: widget.api, account: a, domains: _domains),
                          ));
                          _loadData();
                        } else if (val == 'delete') {
                          _confirmDelete(a);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MessagesScreen(api: widget.api, account: a),
                      ));
                    },
                  ),
                );
              },
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AccountFormScreen(api: widget.api, domains: _domains),
          ));
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('アカウント追加'),
      ),
    );
  }

  void _confirmDelete(Account account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウント削除'),
        content: Text('「${account.label}」(${account.emailAddress}) を削除しますか？\nキャッシュされたメールも全て削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.api.deleteAccount(account.id!);
              _loadData();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
