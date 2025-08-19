// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

String _toStr(dynamic v) {
  if (v == null || v == false) return '';
  if (v is String) return v;
  return v.toString();
}

String? _toStrOrNull(dynamic v) {
  if (v == null || v == false) return null;
  if (v is String) return v.isEmpty ? null : v;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

double _toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

const List<String> _ubicImageCandidates = [
  'x_studio_binary_field_ezILM',
  'x_studio_binary_field_ezlLM',
];
const List<String> _ubicTextCandidates = [
  'x_studio_ubicacin_fsica',
  'x_studio_ubicacin_fisica',
  'x_studio_ubicación_física',
  'x_studio_ubicacion_fisica',
];

class OdooProductDTO {
  final int id;
  final int tmplId;
  final String name;
  final String sku;
  final String? barcode;
  final double qty;
  final double price;
  final double cost;
  final String? uomName;
  final String? categoryName;
  final String? imageBase64;
  final String? locationName;
  final String? locationImageBase64;

  OdooProductDTO({
    required this.id,
    required this.tmplId,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.qty,
    required this.price,
    required this.cost,
    required this.uomName,
    required this.categoryName,
    required this.imageBase64,
    required this.locationName,
    required this.locationImageBase64,
  });
}

class OdooInventoryService {
  final String baseUrl = (dotenv.env['ODOO_URL'] ?? '').replaceAll(
    RegExp(r'/$'),
    '',
  );
  final String db = dotenv.env['ODOO_DB'] ?? '';
  final String? user = dotenv.env['ODOO_USER'];
  final String? password = dotenv.env['ODOO_PASSWORD'];
  final String? apiKey = dotenv.env['ODOO_DEFAULT_API_KEY'];

  String? _sessionId;

  bool _templateFieldsChecked = false;
  String? _ubicImageFieldName;
  String? _ubicTextFieldName;

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    if (_sessionId != null) 'Cookie': 'session_id=$_sessionId',
  };

  Future<void> ensureSession({String? sessionFromAuthManager}) async {
    if (_sessionId != null && _sessionId!.isNotEmpty) return;

    if (sessionFromAuthManager != null && sessionFromAuthManager.isNotEmpty) {
      _sessionId = sessionFromAuthManager;
      return;
    }
    final loginUser = (user ?? '').trim();
    final pwd = ((password ?? '').trim().isNotEmpty)
        ? password!.trim()
        : (apiKey ?? '').trim();

    if (loginUser.isEmpty) throw Exception('Falta ODOO_USER en .env');
    if (pwd.isEmpty)
      throw Exception('Falta ODOO_DEFAULT_API_KEY (o ODOO_PASSWORD) en .env');

    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {'db': db, 'login': loginUser, 'password': pwd},
    };
    final resp = await http.post(
      Uri.parse('$baseUrl/web/session/authenticate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200) {
      throw Exception(
        'Error autenticando en Odoo: ${resp.statusCode} ${resp.body}',
      );
    }
    final setCookie = resp.headers['set-cookie'];
    final m = setCookie != null
        ? RegExp(r'session_id=([^;]+)').firstMatch(setCookie)
        : null;
    if (m == null) throw Exception('No se encontró session_id en Set-Cookie');
    _sessionId = m.group(1);
  }

  Future<dynamic> _callKw(Map<String, dynamic> params) async {
    await ensureSession();
    final payload = {'jsonrpc': '2.0', 'method': 'call', 'params': params};
    final resp = await http.post(
      Uri.parse('$baseUrl/web/dataset/call_kw'),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );
    if (resp.statusCode != 200)
      throw Exception('Odoo call_kw error: ${resp.statusCode} ${resp.body}');
    final data = jsonDecode(resp.body);
    if (data is Map && data['error'] != null) {
      throw Exception('Odoo error: ${jsonEncode(data['error'])}');
    }
    return data['result'];
  }

  Future<void> _detectTemplateCustomFields() async {
    if (_templateFieldsChecked) return;
    _templateFieldsChecked = true;

    final fields = await _callKw({
      'model': 'product.template',
      'method': 'fields_get',
      'args': [
        [],
        ['type'],
      ],
      'kwargs': {},
    });

    if (fields is Map) {
      for (final c in _ubicImageCandidates) {
        if (fields.containsKey(c)) {
          _ubicImageFieldName = c;
          break;
        }
      }
      for (final c in _ubicTextCandidates) {
        if (fields.containsKey(c)) {
          _ubicTextFieldName = c;
          break;
        }
      }
    }
  }

  Future<Map<int, Map<String, String?>>> _readTemplateExtras(
    Set<int> tmplIds,
  ) async {
    if (tmplIds.isEmpty) return {};
    await _detectTemplateCustomFields();

    final fields = <String>['image_1920'];
    if (_ubicImageFieldName != null) fields.add(_ubicImageFieldName!);
    if (_ubicTextFieldName != null) fields.add(_ubicTextFieldName!);

    final res = await _callKw({
      'model': 'product.template',
      'method': 'read',
      'args': [tmplIds.toList(), fields],
      'kwargs': {},
    });

    final out = <int, Map<String, String?>>{};
    if (res is List) {
      for (final r in res) {
        if (r is! Map || r['id'] is! int) continue;
        out[r['id'] as int] = {
          'prod': _toStrOrNull(r['image_1920']),
          'ubic_img': _ubicImageFieldName == null
              ? null
              : _toStrOrNull(r[_ubicImageFieldName]),
          'ubic_txt': _ubicTextFieldName == null
              ? null
              : _toStrOrNull(r[_ubicTextFieldName]),
        };
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> searchProducts(String q) async {
    final domain = q.trim().isEmpty
        ? []
        : [
            '|',
            '|',
            ['name', 'ilike', q],
            ['default_code', 'ilike', q],
            ['barcode', 'ilike', q],
          ];

    final res = await _callKw({
      'model': 'product.template',
      'method': 'search_read',
      'args': [
        domain,
        [
          'name',
          'default_code',
          'barcode',
          'list_price',
          'standard_price',
          'categ_id',
          'type',
          'detailed_type',
          'image_1920',
        ],
      ],
      'kwargs': {'limit': 50, 'order': 'name asc', 'context': {}},
    });

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<OdooProductDTO>> listProducts({String query = ''}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    List<dynamic> orFields(String t) => [
      '|',
      '|',
      ['name', 'ilike', t],
      ['default_code', 'ilike', t],
      ['barcode', 'ilike', t],
    ];
    List<dynamic> textDomain = [];
    for (final t in tokens) {
      textDomain = textDomain.isNotEmpty
          ? ['&', ...textDomain, ...orFields(t)]
          : orFields(t);
    }

    final idsTextRaw = await _callKw({
      'model': 'product.product',
      'method': 'search',
      'args': [textDomain],
      'kwargs': {'limit': 500},
    });
    final idsText = (idsTextRaw is List) ? idsTextRaw.cast<int>() : <int>[];

    if (idsText.isEmpty) return [];

    // 3) Leer productos en lotes
    const chunk = 200;
    final List<Map<String, dynamic>> allRaw = [];
    for (var i = 0; i < idsText.length; i += chunk) {
      final sub = idsText.sublist(i, math.min(i + chunk, idsText.length));
      final part = await _callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', sub],
          ],
        ],
        'kwargs': {
          'fields': [
            'name',
            'default_code',
            'barcode',
            'qty_available',
            'lst_price',
            'standard_price',
            'uom_id',
            'categ_id',
            'product_tmpl_id',
            'image_128',
          ],
          'limit': sub.length,
          'order': 'name asc',
        },
      });
      if (part is List) {
        for (final r in part) {
          if (r is Map) allRaw.add((r).cast<String, dynamic>());
        }
      }
    }
    if (allRaw.isEmpty) return [];

    final tmplIds = allRaw
        .map(
          (m) =>
              (m['product_tmpl_id'] is List &&
                  (m['product_tmpl_id'] as List).isNotEmpty)
              ? (m['product_tmpl_id'] as List).first as int
              : null,
        )
        .whereType<int>()
        .toSet();

    final tplExtras = await _readTemplateExtras(tmplIds);

    final List<OdooProductDTO> result = [];
    for (final raw in allRaw) {
      final id = raw['id'] as int;
      final tmplId =
          (raw['product_tmpl_id'] is List &&
              (raw['product_tmpl_id'] as List).isNotEmpty)
          ? (raw['product_tmpl_id'] as List).first as int
          : 0;

      String? uomName;
      if (raw['uom_id'] is List && (raw['uom_id'] as List).length >= 2) {
        uomName = _toStrOrNull((raw['uom_id'] as List)[1]);
      }
      String? categoryName;
      if (raw['categ_id'] is List && (raw['categ_id'] as List).length >= 2) {
        categoryName = _toStrOrNull((raw['categ_id'] as List)[1]);
      }

      final tpl = tplExtras[tmplId] ?? const {};
      final templateProdImg = _toStrOrNull(tpl['prod']);
      final templateUbicImg = _toStrOrNull(tpl['ubic_img']);
      final templateUbicTxt = _toStrOrNull(tpl['ubic_txt']);

      result.add(
        OdooProductDTO(
          id: id,
          tmplId: tmplId,
          name: _toStr(raw['name']),
          sku: _toStr(raw['default_code']),
          barcode: _toStrOrNull(raw['barcode']),
          qty: _toDouble(raw['qty_available']),
          price: _toDouble(raw['lst_price']),
          cost: _toDouble(raw['standard_price']),
          uomName: uomName,
          categoryName: categoryName,
          imageBase64: templateProdImg ?? _toStrOrNull(raw['image_128']),
          locationName: templateUbicTxt ?? 'Sin ubicación',
          locationImageBase64: templateUbicImg,
        ),
      );
    }

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<int> createProduct({
    required String name,
    required String sku,
    String? barcode,
    String? imageBase64,
    double? listPrice,
    double? standardPrice,
    int? uomId,
    int? categoryId,
  }) async {
    final vals = {
      'name': name,
      'default_code': sku,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      if (imageBase64 != null) 'image_1920': imageBase64,
      if (listPrice != null) 'list_price': listPrice,
      if (standardPrice != null) 'standard_price': standardPrice,
      if (uomId != null) 'uom_id': uomId,
      if (categoryId != null) 'categ_id': categoryId,
    };
    final id = await _callKw({
      'model': 'product.template',
      'method': 'create',
      'args': [vals],
      'kwargs': {},
    });
    return id as int;
  }

  Future<bool> updateProductBoth({
    required int productId,
    required int templateId,
    Map<String, dynamic>? productValues,
    Map<String, dynamic>? templateValues,
  }) async {
    bool ok = true;
    if (productValues != null && productValues.isNotEmpty) {
      ok =
          (await _callKw({
                'model': 'product.product',
                'method': 'write',
                'args': [
                  [productId],
                  productValues,
                ],
                'kwargs': {},
              })) ==
              true &&
          ok;
    }
    if (templateValues != null && templateValues.isNotEmpty) {
      ok =
          (await _callKw({
                'model': 'product.template',
                'method': 'write',
                'args': [
                  [templateId],
                  templateValues,
                ],
                'kwargs': {},
              })) ==
              true &&
          ok;
    }
    return ok;
  }
}
