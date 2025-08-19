// ---------- IMPORTS AL INICIO ----------
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_manager.dart';

// ---------- SERVICIO ODOO ----------
class OdooService {
  OdooService();

  // Asegúrate que ODOO_URL NO termine con "/"
  final String baseUrl = dotenv.get('ODOO_URL');
  final String db = dotenv.get('ODOO_DB');

  final http.Client _client = http.Client();

  Future<int?> login({
    required String login,
    String? password,
    String? apiKeyOverride,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final pass =
        apiKeyOverride ?? password ?? dotenv.maybeGet('ODOO_DEFAULT_API_KEY');
    if (pass == null || pass.isEmpty) {
      throw Exception('Proporciona contraseña');
    }

    final uri = Uri.parse('$baseUrl/web/session/authenticate');
    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {'db': db, 'login': login, 'password': pass},
    };

    final resp = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception(decoded['error'].toString());
    }

    final result = decoded['result'] as Map<String, dynamic>?;
    final uid = result?['uid'] as int?;

    String? sessionId;
    final setCookie = resp.headers['set-cookie'];
    if (setCookie != null) {
      final m = RegExp(r'session_id=([^;]+)').firstMatch(setCookie);
      if (m != null) sessionId = m.group(1);
    }
    sessionId ??= result?['session_id'] as String?;

    if (uid != null && sessionId != null) {
      await AuthManager.instance.setSession(
        uid: uid,
        sessionId: sessionId,
        token: pass,
      );
      return uid;
    }
    return null;
  }

  Future<dynamic> callJsonRpc(
    String path,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final auth = await AuthManager.instance.authHeaders();
    final headers = {...auth, 'Content-Type': 'application/json'};
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params,
    });

    final resp = await _client
        .post(uri, headers: headers, body: body)
        .timeout(timeout);

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded['error'] != null) {
      throw Exception(decoded['error'].toString());
    }
    return decoded['result'];
  }

  Future<List<Map<String, dynamic>>> _safeRead({
    required String model,
    required List<int> ids,
    required List<String> wantedFields,
  }) async {
    final meta = await callJsonRpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'fields_get',
      'args': [
        [],
        ['type'],
      ],
      'kwargs': {},
    });

    final exists = <String>{};
    if (meta is Map) {
      for (final k in meta.keys) {
        exists.add(k.toString());
      }
    }

    final safeFields = wantedFields.where(exists.contains).toList();

    final args = <dynamic>[ids];
    if (safeFields.isNotEmpty) args.add(safeFields);

    final res = await callJsonRpc('/web/dataset/call_kw', {
      'model': model,
      'method': 'read',
      'args': args,
      'kwargs': {'context': {}},
    });

    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> getCurrentUserFullProfile() async {
    final uid = await AuthManager.instance.uid;
    if (uid == null) throw Exception("Sin sesión");

    final users = await _safeRead(
      model: 'res.users',
      ids: [uid],
      wantedFields: [
        'id',
        'name',
        'login',
        'partner_id',
        'company_id',
        'lang',
        'tz',
        'groups_id',
        'signature',
        'create_date',
        'last_login',
      ],
    );
    if (users.isEmpty) throw Exception("No se encontró el usuario");
    final user = users.first;

    int? partnerId;
    final partnerRaw = user['partner_id'];
    if (partnerRaw is List && partnerRaw.isNotEmpty) {
      final maybeId = partnerRaw.first;
      if (maybeId is int) partnerId = maybeId;
    }

    Map<String, dynamic> partner = {};
    if (partnerId != null) {
      final partners = await _safeRead(
        model: 'res.partner',
        ids: [partnerId],
        wantedFields: [
          'name',
          'email',
          'phone',
          'mobile',
          'function',
          'street',
          'street2',
          'city',
          'zip',
          'state_id',
          'country_id',
          'image_1920',
        ],
      );
      if (partners.isNotEmpty) partner = partners.first;
    }

    final adminEmail = dotenv.env['ADMIN_EMAIL'] ?? '';
    final adminPhone = dotenv.env['ADMIN_PHONE'] ?? '';

    return {
      'user': user,
      'partner': partner,
      'admin': {'email': adminEmail, 'phone': adminPhone},
    };
  }

  Future<int?> getEmployeeId(int userId) async {
    final res = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.employee',
      'method': 'search_read',
      'args': [
        [
          ['user_id', '=', userId],
          ['active', '=', true],
        ],
        ['id', 'name'],
      ],
      'kwargs': {'limit': 1},
    });

    if (res is List && res.isNotEmpty) {
      final first = Map<String, dynamic>.from(res.first as Map);
      return first['id'] as int?;
    }
    return null;
  }

  String _odooTs(DateTime dt) {
    final utc = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }

  Future<Map<String, dynamic>?> _getLastAttendance(int employeeId) async {
    final res = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
        ],
        ['id', 'check_in', 'check_out'],
      ],
      'kwargs': {'limit': 1, 'order': 'check_in desc'},
    });

    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    return null;
  }

  Future<bool> _checkIn(int employeeId) async {
    final now = _odooTs(DateTime.now());
    final createdId = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.attendance',
      'method': 'create',
      'args': [
        {'employee_id': employeeId, 'check_in': now},
      ],
      'kwargs': {},
    });
    return createdId is int && createdId > 0;
  }

  Future<bool> _checkOut(int attendanceId) async {
    final now = _odooTs(DateTime.now());
    final ok = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.attendance',
      'method': 'write',
      'args': [
        [attendanceId],
        {'check_out': now},
      ],
      'kwargs': {},
    });
    return ok == true;
  }

  Future<String> marcarAccionAsistencia({
    required int employeeId,
    required String action,
  }) async {
    final last = await _getLastAttendance(employeeId);
    final hasOpen =
        last != null &&
        (last['check_out'] == null ||
            last['check_out'] == '' ||
            last['check_out'] == false);

    switch (action) {
      case 'entrada':
        if (hasOpen) {
          final id = last['id'] as int;
          return 'Ya tenías una asistencia abierta (id=$id).';
        }
        final inOk = await _checkIn(employeeId);
        if (!inOk) throw Exception('No se pudo registrar ENTRADA');
        return 'Entrada registrada';

      case 'salida_comida':
        if (!hasOpen)
          return 'No tienes asistencia abierta para cerrar (salida a comer).';
        final outOk = await _checkOut(last['id'] as int);
        if (!outOk) throw Exception('No se pudo registrar SALIDA A COMER');
        return 'Salida a comer registrada';

      case 'regreso_comida':
        if (hasOpen)
          return 'Aún tienes asistencia abierta, cierra antes de regresar.';
        final backOk = await _checkIn(employeeId);
        if (!backOk) throw Exception('No se pudo registrar REGRESO DE COMER');
        return 'Regreso de comer registrado';

      case 'salida_final':
        if (!hasOpen)
          return 'No tienes asistencia abierta para cerrar (salida final).';
        final outFinalOk = await _checkOut(last['id'] as int);
        if (!outFinalOk) throw Exception('No se pudo registrar SALIDA FINAL');
        return 'Salida final registrada';

      default:
        throw Exception('Acción desconocida: $action');
    }
  }

  Future<String> marcarAsistencia(int employeeId) async {
    final now = _odooTs(DateTime.now());

    final lastList = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.attendance',
      'method': 'search_read',
      'args': [
        [
          ['employee_id', '=', employeeId],
        ],
        ['id', 'check_in', 'check_out'],
      ],
      'kwargs': {'limit': 1, 'order': 'check_in desc'},
    });

    if (lastList is List && lastList.isNotEmpty) {
      final last = Map<String, dynamic>.from(lastList.first as Map);
      final checkOut = last['check_out'];
      final isOpen = (checkOut == null || checkOut == '' || checkOut == false);

      if (isOpen) {
        final id = last['id'] as int;
        final ok = await callJsonRpc('/web/dataset/call_kw', {
          'model': 'hr.attendance',
          'method': 'write',
          'args': [
            [id],
            {'check_out': now},
          ],
          'kwargs': {},
        });
        if (ok == true) return 'salida';
        throw Exception('No se pudo registrar la salida');
      }
    }

    final createdId = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'hr.attendance',
      'method': 'create',
      'args': [
        {'employee_id': employeeId, 'check_in': now},
      ],
      'kwargs': {},
    });

    if (createdId is int && createdId > 0) return 'entrada';
    throw Exception('No se pudo registrar la entrada');
  }

  Future<String> marcarAsistenciaPorUsuario(int userId) async {
    final empId = await getEmployeeId(userId);
    if (empId == null)
      throw Exception('Empleado no encontrado para user_id=$userId');
    return marcarAsistencia(empId);
  }

  Future<String> marcarAccionAsistenciaPorUsuario({
    required int userId,
    required String action,
  }) async {
    final empId = await getEmployeeId(userId);
    if (empId == null)
      throw Exception('Empleado no encontrado para user_id=$userId');
    return marcarAccionAsistencia(employeeId: empId, action: action);
  }

  Future<bool> ping({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final headers = await AuthManager.instance.authHeaders();

      Future<bool> hit(Uri uri) async {
        final r = await _client.get(uri, headers: headers).timeout(timeout);
        return r.statusCode >= 200 && r.statusCode < 300;
      }

      final u1 = Uri.parse('$baseUrl/web/session/check');
      if (await hit(u1)) return true;

      final u2 = Uri.parse('$baseUrl/web/webclient/version_info');
      return await hit(u2);
    } catch (_) {
      return false;
    }
  }

  Future<List<List>> _nameSearchProducts(String q, {int limit = 30}) async {
    final res = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'name_search',
      'args': [q, [], 'ilike', limit],
      'kwargs': {'context': {}},
    }, timeout: const Duration(seconds: 6));
    if (res is List) return res.cast<List>();
    return const [];
  }

  Future<List<Map<String, dynamic>>> _readProductsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final res = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'read',
      'args': [
        ids,
        ['id', 'name', 'default_code', 'barcode', 'type'],
      ],
      'kwargs': {'context': {}},
    }, timeout: const Duration(seconds: 6));
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> searchProductsSmart(
    String q, {
    int limit = 30,
  }) async {
    final qq = q.trim();

    if (qq.isNotEmpty) {
      final byBarcode = await callJsonRpc('/web/dataset/call_kw', {
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [
            ['barcode', '=', qq],
          ],
          ['id', 'name', 'default_code', 'barcode', 'type'],
        ],
        'kwargs': {'limit': limit, 'order': 'name asc'},
      }, timeout: const Duration(seconds: 5));
      if (byBarcode is List && byBarcode.isNotEmpty) {
        return byBarcode
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      final bySku = await callJsonRpc('/web/dataset/call_kw', {
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [
            ['default_code', '=', qq],
          ],
          ['id', 'name', 'default_code', 'barcode', 'type'],
        ],
        'kwargs': {'limit': limit, 'order': 'name asc'},
      }, timeout: const Duration(seconds: 5));
      if (bySku is List && bySku.isNotEmpty) {
        return bySku.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    final pairs = await _nameSearchProducts(qq, limit: limit);
    final ids = pairs.map((e) => (e[0] as num).toInt()).toList();
    return _readProductsByIds(ids);
  }

  Future<int> createProductMinimal({
    required String name,
    String? defaultCode,
    String? barcode,
  }) async {
    try {
      final id = await callJsonRpc('/web/dataset/call_kw', {
        'model': 'product.product',
        'method': 'create',
        'args': [
          {
            'name': name,
            if (defaultCode != null && defaultCode.isNotEmpty)
              'default_code': defaultCode,
            if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
            'type': 'product', // storable
          },
        ],
        'kwargs': {},
      }, timeout: const Duration(seconds: 8));
      if (id is int) return id;
    } catch (_) {}

    final id2 = await callJsonRpc('/web/dataset/call_kw', {
      'model': 'product.product',
      'method': 'create',
      'args': [
        {
          'name': name,
          if (defaultCode != null && defaultCode.isNotEmpty)
            'default_code': defaultCode,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          'detailed_type': 'product',
        },
      ],
      'kwargs': {},
    }, timeout: const Duration(seconds: 8));
    if (id2 is int) return id2;

    throw Exception('No se pudo crear el producto');
  }
}

// ---------- DTO PARA SUBIDA ----------
class UploadFoto {
  final String path;
  final String proyecto;
  final String folio;
  final String usuario;
  final String fecha;
  final String lat;
  final String lon;

  UploadFoto({
    required this.path,
    required this.proyecto,
    required this.folio,
    required this.usuario,
    required this.fecha,
    required this.lat,
    required this.lon,
  });
}

// ---------- EXTENSIÓN DE SUBIDAS ----------
extension OdooUploads on OdooService {
  Future<void> uploadPhotoReport({
    required String proyecto,
    required String folio,
    required String notas,
    required List<UploadFoto> fotos,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Evitar doble '/' si baseUrl ya termina con slash
    final uri = Uri.parse(baseUrl).replace(
      path:
          '${Uri.parse(baseUrl).path.replaceAll(RegExp(r"/+$"), "")}/mi_endpoint/reportes_fotos',
    );

    final req = http.MultipartRequest('POST', uri);

    // MUY IMPORTANTE: agregar cookies/headers de sesión
    final authHeaders = await AuthManager.instance.authHeaders();
    req.headers.addAll(authHeaders);

    req.fields['proyecto'] = proyecto;
    req.fields['folio'] = folio;
    req.fields['notas'] = notas;

    for (int i = 0; i < fotos.length; i++) {
      final f = fotos[i];
      final file = File(f.path);
      final length = await file.length();

      // Metadatos por foto
      req.fields['fotos[$i][fecha]'] = f.fecha;
      req.fields['fotos[$i][lat]'] = f.lat;
      req.fields['fotos[$i][lon]'] = f.lon;
      req.fields['fotos[$i][usuario]'] = f.usuario;
      req.fields['fotos[$i][folio]'] = f.folio;
      req.fields['fotos[$i][proyecto]'] = f.proyecto;

      req.files.add(
        http.MultipartFile(
          'fotos[$i][archivo]',
          file.openRead(),
          length,
          filename: p.basename(f.path),
        ),
      );
    }

    final streamed = await req.send().timeout(timeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw Exception('Fallo subida: ${streamed.statusCode} $body');
    }
  }
}
