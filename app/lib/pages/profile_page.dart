import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/odoo_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      setState(() {
        data = resp;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  ImageProvider _avatar() {
    final partner = (data?['partner'] as Map<String, dynamic>?) ?? {};
    final img = partner['image_1920'];
    if (img is String && img.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(img));
      } catch (_) {}
    }
    return const AssetImage('assets/avatar_placeholder.png');
  }

  Widget _tile(
    String title,
    String? value, {
    IconData icon = Icons.info_outline,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(value),
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  String _m2(dynamic m) => (m is List && m.length >= 2) ? "${m[1]}" : "";

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil'), centerTitle: true),
        body: Center(child: Text('Error al cargar: $error')),
      );
    }

    final user = Map<String, dynamic>.from(data!['user']);
    final partner = Map<String, dynamic>.from(data!['partner'] ?? {});
    final admin = Map<String, dynamic>.from(data!['admin'] ?? {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              ThemeController.of(context)?.toggle();
            },
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
                    partner['name'] ?? user['name'] ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
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
                  (user['last_login'] ?? '').toString(),
                  icon: Icons.lock_clock,
                ),
                _tile(
                  'Creado',
                  (user['create_date'] ?? '').toString(),
                  icon: Icons.event_available,
                ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6,
                  ),
                  child: Text(
                    'Contacto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _tile('Correo', partner['email'], icon: Icons.email_outlined),
                _tile('Teléfono', partner['phone'], icon: Icons.call_outlined),
                _tile(
                  'Móvil',
                  partner['mobile'],
                  icon: Icons.smartphone_outlined,
                ),
                _tile(
                  'Puesto',
                  partner['function'],
                  icon: Icons.badge_outlined,
                ),

                const Divider(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
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
                    (partner['street'] ?? '').toString(),
                    (partner['street2'] ?? '').toString(),
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
                          if ((admin['email'] ?? '').toString().isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.email_outlined),
                                const SizedBox(width: 8),
                                Expanded(child: Text(admin['email'])),
                                TextButton(
                                  onPressed: () async {
                                    final uri = Uri.parse(
                                      "mailto:${admin['email']}",
                                    );
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  child: const Text('Enviar correo'),
                                ),
                              ],
                            ),
                          if ((admin['phone'] ?? '').toString().isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.call_outlined),
                                const SizedBox(width: 8),
                                Expanded(child: Text(admin['phone'])),
                                TextButton(
                                  onPressed: () async {
                                    final uri = Uri.parse(
                                      "tel:${admin['phone']}",
                                    );
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  child: const Text('Llamar'),
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

class ThemeController extends InheritedWidget {
  final _ThemeControllerState data;
  const ThemeController({super.key, required this.data, required super.child});

  static _ThemeControllerState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeController>()?.data;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;
}

class ThemeControllerHost extends StatefulWidget {
  final Widget child;
  final ThemeMode initialMode;
  const ThemeControllerHost({
    super.key,
    required this.child,
    this.initialMode = ThemeMode.system,
  });

  @override
  State<ThemeControllerHost> createState() => _ThemeControllerState();
}

class _ThemeControllerState extends State<ThemeControllerHost> {
  ThemeMode mode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
  }

  void toggle() {
    setState(() {
      mode = (mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeController(data: this, child: widget.child);
  }
}
