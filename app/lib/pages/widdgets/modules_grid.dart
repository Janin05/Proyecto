// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';

class ModulesGrid extends StatelessWidget {
  const ModulesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.05,
      children: [
        _ModuleCard(
          title: "Inventario",
          icon: Icons.inventory,
          onTap: () => Navigator.pushNamed(context, '/inventario'),
        ),
        _ModuleCard(
          title: "Cotizaciones",
          icon: Icons.request_quote,
          onTap: () => Navigator.pushNamed(context, '/cotizaciones'),
        ),
        _ModuleCard(
          title: "Viáticos",
          icon: Icons.flight_takeoff,
          onTap: () => Navigator.pushNamed(context, '/viaticos'),
        ),
        _ModuleCard(
          title: "Herramienta",
          icon: Icons.verified_user,
          // No tienes ruta '/auditoria' en main.dart, así que lo mapeamos a Herramientas:
          onTap: () => Navigator.pushNamed(context, '/herramientas'),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  LinearGradient _gradientFor(String title) {
    switch (title) {
      case "Inventario": // azul-violeta
        return const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF6F86D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case "Cotizaciones": // naranja
        return const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFFCC80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case "Viáticos": // verde agua
        return const LinearGradient(
          colors: [Color.fromRGBO(38, 166, 154, 1), Color(0xFF00BFA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default: // Herramienta -> morado/teal
        return const LinearGradient(
          colors: [Color.fromRGBO(38, 166, 154, 1), Color(0xFFBA68C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: _gradientFor(title),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: const Color.fromARGB(212, 255, 255, 255),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color.fromARGB(182, 255, 255, 255),
                  fontSize: 18,
                  height: 1.2, // evita overflow en dos líneas
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text("Entrar", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
