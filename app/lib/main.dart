import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_manager.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/modules_hub_page.dart';
import 'pages/inventory_page.dart';
import 'pages/quotes_page.dart';
import 'pages/viaticos_page.dart';
import 'pages/herramientas_page.dart';
import 'pages/ajustes_page.dart';
import 'pages/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await AuthManager.instance.hydrate();
  final uid = await AuthManager.instance.uid;
  runApp(MyApp(isLoggedIn: uid != null));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return ThemeControllerHost(
      initialMode: _mode,
      child: Builder(
        builder: (context) {
          final themeController = ThemeController.of(context)!;
          _mode = themeController.mode;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Plataforma Odoo',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: _mode,
            routes: {
              '/': (_) =>
                  widget.isLoggedIn ? const DashboardPage() : const LoginPage(),
              '/hub': (_) => const ModulesHubPage(),
              '/inventario': (_) => const InventoryPage(),
              '/cotizaciones': (_) => const QuotesPage(),
              '/viaticos': (_) => const ViaticosPage(),
              '/herramientas': (_) => const HerramientasPage(),
              '/ajustes': (_) => const AjustesPage(),
              '/perfil': (_) => const ProfilePage(),
            },
          );
        },
      ),
    );
  }
}
