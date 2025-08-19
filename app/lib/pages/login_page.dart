import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../services/auth_manager.dart';
import '../services/login_guard.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _odoo = OdooService();

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _apiCtrl = TextEditingController();
  bool _loading = false;
  int _lockMs = 0;
  bool _showApiKey = false;
  @override
  void initState() {
    super.initState();
    _refreshLock();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _apiCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshLock() async {
    final ms = await LoginGuard.remainingLockMs();
    if (!mounted) return;
    setState(() => _lockMs = ms);

    if (ms > 0) {
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        final left = await LoginGuard.remainingLockMs();
        if (!mounted) return false;
        setState(() => _lockMs = left);
        return left > 0;
      });
    }
  }

  Future<void> _doLogin() async {
    final msLeft = await LoginGuard.remainingLockMs();
    if (msLeft > 0) {
      final s = (msLeft / 1000).ceil();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Espera $s s antes de intentar de nuevo.')),
      );
      return;
    }

    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    final apiKey = _apiCtrl.text;

    if (user.isEmpty || (_showApiKey ? apiKey.isEmpty : pass.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario y credencial requeridos.')),
      );
      // Pequeño bloqueo anti-spam
      await LoginGuard.lockForSeconds(3);
      _refreshLock();
      return;
    }

    setState(() => _loading = true);

    try {
      final uid = await _odoo.login(
        login: user,
        password: _showApiKey ? null : pass,
        apiKeyOverride: _showApiKey ? apiKey : null,
        timeout: const Duration(seconds: 6),
      );

      final tok = _showApiKey ? apiKey : pass;
      if (tok.isNotEmpty) {
        await AuthManager.instance.setToken(tok);
      }

      if (uid != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        await LoginGuard.lockForSeconds(15);
        _refreshLock();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Credenciales inválidas')));
      }
    } catch (e) {
      await LoginGuard.lockForSeconds(60);
      _refreshLock();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockMs > 0;
    final secondsLeft = (_lockMs / 1000).ceil();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Inicio de sesión',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                const SizedBox(height: 10),

                if (!_showApiKey)
                  TextField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                  )
                else
                  TextField(
                    controller: _apiCtrl,
                    decoration: const InputDecoration(labelText: 'API Key'),
                    obscureText: true,
                  ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _showApiKey = !_showApiKey;
                            });
                          },
                    child: Text(
                      _showApiKey ? 'Usar contraseña' : 'Usar API Key',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (locked || _loading) ? null : _doLogin,
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Text(
                            locked ? 'Bloqueado (${secondsLeft}s)' : 'Entrar',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
