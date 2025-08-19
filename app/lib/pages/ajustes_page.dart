import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/odoo_service.dart';
import 'profile_page.dart' show ThemeController;

class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});
  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  final _odoo = OdooService();
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _odoo.getCurrentUserFullProfile();
      if (!mounted) return;
      setState(() {
        // ignore: unnecessary_type_check
        data = (resp is Map)
            ? resp.cast<String, dynamic>()
            : <String, dynamic>{};
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String? _strOrNull(dynamic v) {
    if (v == null || v == false) return null;
    if (v is String) return v.trim().isEmpty ? null : v.trim();
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _str(dynamic v) => _strOrNull(v) ?? '';
  String _m2(dynamic m) {
    if (m is List && m.length >= 2) return _str(m[1]);
    return '';
  }

  ImageProvider<Object> _avatar() {
    final partner =
        (data?['partner'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final img = _strOrNull(partner['image_1920']);
    if (img != null) {
      try {
        return MemoryImage(base64Decode(img));
      } catch (_) {}
    }
    return const AssetImage('assets/avatar_placeholder.png');
  }

  String _cleanDigits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  String _toIntlNumber(String raw, {String defaultCountryCode = '52'}) {
    final digits = _cleanDigits(raw);
    if (digits.isEmpty) return '';
    if (digits.length >= 12) return digits; // ya trae código de país
    return '$defaultCountryCode$digits';
  }

  Future<void> _openMail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTel(String phone) async {
    final uri = Uri.parse('tel:${_cleanDigits(phone)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final number = _toIntlNumber(phone); // MX por defecto (52)
    if (number.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _tile(
    String title,
    dynamic value, {
    IconData icon = Icons.info_outline,
  }) {
    final s = _strOrNull(value);
    if (s == null) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(s),
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustes'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustes'), centerTitle: true),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText('Error: $error'),
          ),
        ),
      );
    }

    final user =
        (data!['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final partner =
        (data!['partner'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final admin =
        (data!['admin'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => ThemeController.of(context)?.toggle(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Scrollbar(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 12),

                Center(
                  child: CircleAvatar(radius: 48, backgroundImage: _avatar()),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _str(partner['name']).isNotEmpty
                        ? _str(partner['name'])
                        : _str(user['name']),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    'Apariencia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Modo oscuro'),
                  subtitle: const Text(
                    'Cambiar manualmente entre claro y oscuro',
                  ),
                  value: isDark,
                  onChanged: (_) => ThemeController.of(context)?.toggle(),
                  secondary: const Icon(Icons.brightness_6_outlined),
                  dense: true,
                ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    'Cuenta',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _tile('Usuario', user['login'], icon: Icons.person_outline),
                _tile('Zona horaria', user['tz'], icon: Icons.schedule),
                _tile('Idioma', user['lang'], icon: Icons.language),
                _tile(
                  'Compañía',
                  _m2(user['company_id']),
                  icon: Icons.business,
                ),
                _tile(
                  'Último acceso',
                  _strOrNull(user['last_login']) ?? '—',
                  icon: Icons.lock_clock,
                ),
                _tile(
                  'Creado',
                  _strOrNull(user['create_date']) ?? '—',
                  icon: Icons.event_available,
                ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    'Contacto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                if (_strOrNull(partner['email']) != null)
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(_str(partner['email'])),
                    onTap: () => _openMail(_str(partner['email'])),
                    trailing: TextButton(
                      onPressed: () => _openMail(_str(partner['email'])),
                      child: const Text('Enviar'),
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                if (_strOrNull(partner['phone']) != null)
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: Text(_str(partner['phone'])),
                    onTap: () => _openTel(_str(partner['phone'])),
                    trailing: TextButton(
                      onPressed: () => _openTel(_str(partner['phone'])),
                      child: const Text('Llamar'),
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                if (_strOrNull(partner['mobile']) != null)
                  ListTile(
                    leading: const FaIcon(FontAwesomeIcons.whatsapp),
                    title: Text(_str(partner['mobile'])),
                    subtitle: const Text('Enviar WhatsApp'),
                    onTap: () => _openWhatsApp(_str(partner['mobile'])),
                    trailing: TextButton(
                      onPressed: () => _openWhatsApp(_str(partner['mobile'])),
                      child: const Text('Abrir'),
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    'Dirección',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _tile(
                  'Calle',
                  [
                    _str(partner['street']),
                    _str(partner['street2']),
                  ].where((e) => e.isNotEmpty).join(' '),
                  icon: Icons.location_on_outlined,
                ),
                _tile(
                  'Ciudad',
                  partner['city'],
                  icon: Icons.location_city_outlined,
                ),
                _tile(
                  'Código Postal',
                  partner['zip'],
                  icon: Icons.local_post_office_outlined,
                ),
                _tile(
                  'Estado',
                  _m2(partner['state_id']),
                  icon: Icons.map_outlined,
                ),
                _tile(
                  'País',
                  _m2(partner['country_id']),
                  icon: Icons.flag_outlined,
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.support_agent),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '¿Necesitas ayuda? Contacta al administrador',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_strOrNull(admin['email']) != null)
                            Row(
                              children: [
                                const Icon(Icons.email_outlined),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_str(admin['email']))),
                                TextButton(
                                  onPressed: () =>
                                      _openMail(_str(admin['email'])),
                                  child: const Text('Enviar correo'),
                                ),
                              ],
                            ),

                          if (_strOrNull(admin['phone']) != null)
                            Row(
                              children: [
                                const Icon(Icons.call_outlined),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_str(admin['phone']))),
                                TextButton(
                                  onPressed: () =>
                                      _openTel(_str(admin['phone'])),
                                  child: const Text('Llamar'),
                                ),
                              ],
                            ),

                          if (_strOrNull(admin['phone']) != null)
                            Row(
                              children: [
                                const FaIcon(FontAwesomeIcons.whatsapp),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_str(admin['phone']))),
                                TextButton(
                                  onPressed: () =>
                                      _openWhatsApp(_str(admin['phone'])),
                                  child: const Text('WhatsApp'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
