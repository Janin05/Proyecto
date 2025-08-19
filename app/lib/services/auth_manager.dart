import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthManager {
  AuthManager._();
  static final AuthManager instance = AuthManager._();

  final _storage = const FlutterSecureStorage();

  int? _uidCache;
  String? _sessionIdCache;
  String? _tokenCache;
  String? _nameCache;
  String? _emailCache;

  Future<void> hydrate() async {
    final uidStr = await _storage.read(key: 'odoo_uid');
    final sess = await _storage.read(key: 'odoo_session_id');
    final tok = await _storage.read(key: 'odoo_token');
    final name = await _storage.read(key: 'odoo_name');
    final email = await _storage.read(key: 'odoo_email');

    _uidCache = uidStr != null ? int.tryParse(uidStr) : null;
    _sessionIdCache = sess;
    _tokenCache = tok;
    _nameCache = name;
    _emailCache = email;
  }

  Future<void> setSession({
    required int uid,
    required String sessionId,
    String? token,
    String? name,
    String? email,
  }) async {
    _uidCache = uid;
    _sessionIdCache = sessionId;
    _tokenCache = token;
    _nameCache = name;
    _emailCache = email;

    await _storage.write(key: 'odoo_uid', value: uid.toString());
    await _storage.write(key: 'odoo_session_id', value: sessionId);
    if (token != null) await _storage.write(key: 'odoo_token', value: token);
    if (name != null) await _storage.write(key: 'odoo_name', value: name);
    if (email != null) await _storage.write(key: 'odoo_email', value: email);
  }

  Future<void> setToken(String token) async {
    _tokenCache = token;
    await _storage.write(key: 'odoo_token', value: token);
  }

  Future<void> clear() async {
    _uidCache = null;
    _sessionIdCache = null;
    _tokenCache = null;
    _nameCache = null;
    _emailCache = null;

    await _storage.delete(key: 'odoo_uid');
    await _storage.delete(key: 'odoo_session_id');
    await _storage.delete(key: 'odoo_token');
    await _storage.delete(key: 'odoo_name');
    await _storage.delete(key: 'odoo_email');
  }

  Future<int?> get uid async {
    if (_uidCache != null) return _uidCache;
    final uidStr = await _storage.read(key: 'odoo_uid');
    _uidCache = uidStr != null ? int.tryParse(uidStr) : null;
    return _uidCache;
  }

  Future<String?> get sessionId async {
    if (_sessionIdCache != null) return _sessionIdCache;
    _sessionIdCache = await _storage.read(key: 'odoo_session_id');
    return _sessionIdCache;
  }

  Future<String?> get token async {
    if (_tokenCache != null) return _tokenCache;
    _tokenCache = await _storage.read(key: 'odoo_token');
    return _tokenCache;
  }

  Future<String?> get name async {
    if (_nameCache != null) return _nameCache;
    _nameCache = await _storage.read(key: 'odoo_name');
    return _nameCache;
  }

  Future<String?> get email async {
    if (_emailCache != null) return _emailCache;
    _emailCache = await _storage.read(key: 'odoo_email');
    return _emailCache;
  }

  Future<Map<String, String>> authHeaders() async {
    final sid = await sessionId;
    return {
      'Content-Type': 'application/json',
      if (sid != null) 'Cookie': 'session_id=$sid',
    };
  }
}
