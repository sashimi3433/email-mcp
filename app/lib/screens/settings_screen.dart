import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  final ApiService api;
  final VoidCallback onServerChanged;

  const SettingsScreen({
    super.key,
    required this.api,
    required this.onServerChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _testing = false;
  bool? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await widget.api.getBaseUrl();
    _urlController.text = url;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    await widget.api.setBaseUrl(_urlController.text.trim());
    setState(() => _testResult = null);
    widget.onServerChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('サーバーURLを保存しました'), backgroundColor: Colors.green));
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _testResult = null; });
    await widget.api.setBaseUrl(_urlController.text.trim());
    final ok = await widget.api.checkHealth();
    setState(() { _testing = false; _testResult = ok; });
    widget.onServerChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('サーバー接続', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Email MCPバックエンドのURLを指定します。\n'
            'ローカル: http://localhost:5858\n'
            'Headscale: http://100.64.0.4:5858',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'サーバーURL',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            FilledButton.icon(
              onPressed: _saveUrl,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find),
              label: Text(_testing ? 'テスト中...' : '接続テスト'),
            ),
          ]),
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _testResult! ? Colors.green.shade50 : Colors.red.shade50,
              child: ListTile(
                leading: Icon(
                  _testResult! ? Icons.check_circle : Icons.error,
                  color: _testResult! ? Colors.green : Colors.red,
                ),
                title: Text(_testResult! ? '接続成功' : '接続失敗'),
                subtitle: Text(_testResult!
                  ? 'サーバーが応答しています'
                  : 'サーバーに接続できません。URLを確認してください。'),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Text('アプリ情報', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('バージョン'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  leading: Icon(Icons.code),
                  title: Text('バックエンド'),
                  trailing: Text('Email MCP v0.2.0'),
                ),
                ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('プロジェクト'),
                  trailing: Text('github.com/sashimi3433/email-mcp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
