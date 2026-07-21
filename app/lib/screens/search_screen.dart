import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/account.dart';
import '../models/email_message.dart';
import 'message_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final ApiService api;

  const SearchScreen({super.key, required this.api});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Account> _accounts = [];
  Account? _selectedAccount;
  List<EmailMessage> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      _accounts = await widget.api.listAccounts();
      if (_accounts.isNotEmpty) {
        _selectedAccount = _accounts.first;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty || _selectedAccount == null) return;
    setState(() { _searching = true; _hasSearched = true; });
    try {
      _results = await widget.api.searchMessages(
        _selectedAccount!.id!,
        _searchController.text,
      );
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メール検索')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Account selector
            DropdownButtonFormField<Account>(
              decoration: const InputDecoration(
                labelText: '検索対象アカウント',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedAccount,
              items: _accounts.map((a) => DropdownMenuItem(
                value: a,
                child: Text('${a.label} (${a.emailAddress})'),
              )).toList(),
              onChanged: (a) => setState(() => _selectedAccount = a),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '検索キーワード',
                hintText: '件名・差出人・本文から検索',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _results = []; _hasSearched = false; });
                      },
                    )
                  : null,
              ),
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _hasSearched && _results.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('該当するメールが見つかりませんでした'),
                        ],
                      ),
                    )
                  : _results.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('キーワードを入力して検索してください'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final m = _results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(m.fromAddr.isNotEmpty ? m.fromAddr[0].toUpperCase() : '?'),
                            ),
                            title: Text(m.subject.isNotEmpty ? m.subject : '(件名なし)',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${m.fromAddr}  •  ${m.folder}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => MessageDetailScreen(
                                  api: widget.api,
                                  account: _selectedAccount!,
                                  message: m,
                                ),
                              ));
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
