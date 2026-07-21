import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import 'unified_inbox_screen.dart';
import 'account_form_screen.dart';
import 'domains_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'messages_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;

  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _serverOnline = false;
  final _homeKey = GlobalKey<_HomeTabState>();

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    final ok = await widget.api.checkHealth();
    if (mounted) setState(() => _serverOnline = ok);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(key: _homeKey, api: widget.api),
      DomainsScreen(api: widget.api),
      SearchScreen(api: widget.api),
      SettingsScreen(api: widget.api, onServerChanged: _checkHealth),
    ];

    final labels = ['メール', 'ドメイン', '検索', '設定'];
    final icons = [
      Icons.mail_outline,
      Icons.dns_outlined,
      Icons.search,
      Icons.settings_outlined,
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            extended: MediaQuery.of(context).size.width > 1000,
            leading: Column(
              children: [
                const SizedBox(height: 16),
                Icon(Icons.mail, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _serverOnline ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_serverOnline ? Icons.cloud_done : Icons.cloud_off,
                        size: 12, color: _serverOnline ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(_serverOnline ? 'オンライン' : 'オフライン',
                        style: TextStyle(fontSize: 10,
                          color: _serverOnline ? Colors.green : Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            destinations: List.generate(labels.length, (i) =>
              NavigationRailDestination(
                icon: Icon(icons[i]),
                selectedIcon: Icon(icons[i]),
                label: Text(labels[i]),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }
}

/// Unified home tab: all-inbox + account list combined.
class HomeTab extends StatefulWidget {
  final ApiService api;
  const HomeTab({super.key, required this.api});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Account> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _accounts = await widget.api.listAccounts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadData();
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _accounts.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('接続エラー', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _refresh, child: const Text('再試行')),
        ],
      ));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text('メール', style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      tooltip: '更新',
                    ),
                  ],
                ),
              ),
            ),
            // All-inbox shortcut
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.inbox, color: Theme.of(context).colorScheme.primary),
                    title: const Text('すべてのメール', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${_accounts.length}個のアカウント'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UnifiedInboxScreen(api: widget.api),
                      ));
                    },
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Account list header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Text('アカウント', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverList.builder(
              itemCount: _accounts.length,
              itemBuilder: (ctx, i) {
                final a = _accounts[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
                          final domains = await widget.api.listDomains();
                          if (!context.mounted) return;
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AccountFormScreen(api: widget.api, account: a, domains: domains),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final domains = await widget.api.listDomains();
          if (!context.mounted) return;
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AccountFormScreen(api: widget.api, domains: domains),
          ));
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('アカウント追加'),
      ),
    );
  }
}
