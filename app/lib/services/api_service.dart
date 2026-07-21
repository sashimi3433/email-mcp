/// API client for the Email MCP backend.
library;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/server_domain.dart';
import '../models/email_message.dart';

class ApiService {
  late Dio _dio;
  static const _baseUrlKey = 'api_base_url';

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? 'http://localhost:5858';
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<String> getBaseUrl() async => _getBaseUrl();

  Future<Response> _get(String path) async {
    final base = await _getBaseUrl();
    return _dio.get('$base$path');
  }

  Future<Response> _post(String path, {dynamic data}) async {
    final base = await _getBaseUrl();
    return _dio.post('$base$path', data: data);
  }

  Future<Response> _patch(String path, {dynamic data}) async {
    final base = await _getBaseUrl();
    return _dio.patch('$base$path', data: data);
  }

  Future<Response> _delete(String path) async {
    final base = await _getBaseUrl();
    return _dio.delete('$base$path');
  }

  // ─── Health ──────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final res = await _get('/api/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Accounts ────────────────────────────────────────────

  Future<List<Account>> listAccounts() async {
    final res = await _get('/api/accounts');
    final list = res.data as List;
    return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Account> getAccount(int id) async {
    final res = await _get('/api/accounts/$id');
    return Account.fromJson(res.data as Map<String, dynamic>);
  }

  Future<int> createAccount(Map<String, dynamic> data) async {
    final res = await _post('/api/accounts', data: data);
    return res.data['id'] as int;
  }

  Future<void> updateAccount(int id, Map<String, dynamic> data) async {
    await _patch('/api/accounts/$id', data: data);
  }

  Future<void> deleteAccount(int id) async {
    await _delete('/api/accounts/$id');
  }

  // ─── Server Domains ──────────────────────────────────────

  Future<List<ServerDomain>> listDomains() async {
    final res = await _get('/api/domains');
    final list = res.data as List;
    return list.map((e) => ServerDomain.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> upsertDomain(Map<String, dynamic> data) async {
    final res = await _post('/api/domains', data: data);
    return res.data['id'] as int;
  }

  Future<void> deleteDomain(int id) async {
    await _delete('/api/domains/$id');
  }

  Future<Map<String, dynamic>?> lookupDomain(String domain) async {
    final res = await _post('/api/domains/lookup', data: {'domain': domain});
    if (res.data['found'] == true) {
      return res.data['config'] as Map<String, dynamic>;
    }
    return null;
  }

  // ─── Messages ────────────────────────────────────────────

  Future<List<EmailMessage>> listMessages(int accountId,
      {String folder = 'INBOX', int limit = 50, int offset = 0}) async {
    final res = await _get(
      '/api/accounts/$accountId/messages?folder=${Uri.encodeComponent(folder)}&limit=$limit&offset=$offset',
    );
    final list = res.data['messages'] as List;
    return list.map((e) => EmailMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmailMessage> getMessage(int accountId, int messageId) async {
    final res = await _get('/api/accounts/$accountId/messages/$messageId');
    return EmailMessage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<EmailMessage>> searchMessages(int accountId, String query,
      {String? folder, int limit = 20}) async {
    var path = '/api/accounts/$accountId/search?q=${Uri.encodeComponent(query)}&limit=$limit';
    if (folder != null) path += '&folder=${Uri.encodeComponent(folder)}';
    final res = await _get(path);
    final list = res.data['results'] as List;
    return list.map((e) => EmailMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Folders ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listFolders(int accountId) async {
    final res = await _get('/api/accounts/$accountId/folders');
    final list = res.data['folders'] as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ─── Sync ────────────────────────────────────────────────

  Future<Map<String, dynamic>> syncAccount(int accountId,
      {List<String>? folders, int limit = 100}) async {
    final res = await _post('/api/accounts/$accountId/sync', data: {
      if (folders != null) 'folders': folders,
      'limit': limit,
    });
    return res.data as Map<String, dynamic>;
  }

  // ─── Send / Reply ────────────────────────────────────────

  Future<Map<String, dynamic>> sendMail(int accountId,
      {required String to, required String subject, required String body, String? cc}) async {
    final res = await _post('/api/accounts/$accountId/send', data: {
      'to': to,
      'subject': subject,
      'body': body,
      if (cc != null) 'cc': cc,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> replyMessage(int accountId, int messageId,
      {required String body, bool replyAll = false}) async {
    final res = await _post('/api/accounts/$accountId/messages/$messageId/reply', data: {
      'body': body,
      'reply_all': replyAll,
    });
    return res.data as Map<String, dynamic>;
  }
}
