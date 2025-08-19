import 'package:flutter/material.dart';

class ModulesHubPage extends StatelessWidget {
  const ModulesHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => Navigator.pushNamed(context, '/ajustes'),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: ColoredModulesGrid(),
      ),
    );
  }
}

class ColoredModulesGrid extends StatelessWidget {
  const ColoredModulesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = _items();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: items
          .map(
            (m) => _ModuleCard(
              title: m.title,
              icon: m.icon,
              color: m.color,
              onTap: () => Navigator.pushNamed(context, m.route),
            ),
          )
          .toList(),
    );
  }
}

List<_ModuleItem> _items() => <_ModuleItem>[
  _ModuleItem(
    title: 'Inventario',
    icon: Icons.inventory_2_rounded,
    color: Colors.indigo,
    route: '/inventario',
  ),
  _ModuleItem(
    title: 'Cotizaciones',
    icon: Icons.request_quote_rounded,
    color: Colors.orange,
    route: '/cotizaciones',
  ),
  _ModuleItem(
    title: 'Viáticos',
    icon: Icons.flight_takeoff_rounded,
    color: Colors.teal,
    route: '/viaticos',
  ),
  _ModuleItem(
    title: 'Herramienta',
    icon: Icons.build_rounded,
    color: Colors.purple,
    route: '/herramientas',
  ),
];

class _ModuleItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  _ModuleItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final lighter = hsl
        .withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0))
        .toColor();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, lighter],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color.fromARGB(
                  255,
                  204,
                  204,
                  204,
                ).withOpacity(.18),
                child: Icon(
                  icon,
                  size: 36,
                  color: const Color.fromARGB(223, 255, 255, 255),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color.fromARGB(238, 207, 206, 206),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Entrar',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color.fromARGB(
                    255,
                    197,
                    196,
                    196,
                  ).withOpacity(.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
