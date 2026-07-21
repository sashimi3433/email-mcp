import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import 'accounts_screen.dart';
import 'domains_screen.dart';
import 'messages_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;

  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _serverOnline = false;

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
      _DashboardScreen(api: widget.api),
      AccountsScreen(api: widget.api),
      DomainsScreen(api: widget.api),
      SearchScreen(api: widget.api),
      SettingsScreen(api: widget.api, onServerChanged: _checkHealth),
    ];

    final labels = ['ダッシュボード', 'アカウント', 'ドメイン', '検索', '設定'];
    final icons = [
      Icons.dashboard_outlined,
      Icons.mail_outline,
      Icons.dns_outlined,
      Icons.search,
      Icons.settings_outlined,
    ];

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail (desktop/macOS)
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
          Expanded(
            child: screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

/// Dashboard screen — overview of accounts, recent messages.
class _DashboardScreen extends StatefulWidget {
  final ApiService api;
  const _DashboardScreen({required this.api});

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  List<Account> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      _accounts = await widget.api.listAccounts();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('接続エラー', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _loadData, child: const Text('再試行')),
        ],
      ));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Text('Email MCP', style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  _StatCard(
                    icon: Icons.mail_outline,
                    label: 'アカウント数',
                    value: '${_accounts.length}',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _StatCard(
                    icon: Icons.sync,
                    label: '最終同期',
                    value: _accounts.isNotEmpty
                      ? (_accounts.first.lastSync ?? '未同期')
                      : '-',
                    color: Colors.green,
                    small: true,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
                  trailing: a.lastSync != null
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : const Icon(Icons.warning, color: Colors.orange, size: 20),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadData,
        icon: const Icon(Icons.refresh),
        label: const Text('更新'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool small;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: small ? 200 : 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 8),
            Text(value,
              style: TextStyle(fontSize: small ? 14 : 24, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
