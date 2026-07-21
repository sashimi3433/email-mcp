import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/server_domain.dart';
import 'domain_form_screen.dart';

class DomainsScreen extends StatefulWidget {
  final ApiService api;
  const DomainsScreen({super.key, required this.api});

  @override
  State<DomainsScreen> createState() => _DomainsScreenState();
}

class _DomainsScreenState extends State<DomainsScreen> {
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
      _domains = await widget.api.listDomains();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('サーバードメイン管理')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _domains.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dns_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('ドメイン設定がありません'),
                  const SizedBox(height: 8),
                  const Text('サーバー設定を登録すると、アカウント追加時に自動入力できます',
                    style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _domains.length,
              itemBuilder: (ctx, i) {
                final d = _domains[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ExpansionTile(
                    leading: const CircleAvatar(child: Icon(Icons.dns)),
                    title: Text(d.domain),
                    subtitle: Text('IMAP: ${d.imapHost}:${d.imapPort}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow('ドメイン', d.domain),
                            _detailRow('IMAPホスト', d.imapHost),
                            _detailRow('IMAPポート', d.imapPort.toString()),
                            _detailRow('IMAP SSL', d.imapSsl ? 'あり' : 'なし'),
                            _detailRow('SMTPホスト', d.smtpHost),
                            _detailRow('SMTPポート', d.smtpPort.toString()),
                            _detailRow('SMTP SSL', d.smtpSsl ? 'あり' : 'なし'),
                            const SizedBox(height: 16),
                            Row(children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text('編集'),
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => DomainFormScreen(api: widget.api, domain: d),
                                  ));
                                  _loadData();
                                },
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                icon: const Icon(Icons.delete),
                                label: const Text('削除'),
                                onPressed: () => _confirmDelete(d),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => DomainFormScreen(api: widget.api),
          ));
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('ドメイン追加'),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(ServerDomain d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ドメイン削除'),
        content: Text('「${d.domain}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.api.deleteDomain(d.id!);
              _loadData();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
