// lib/pages/dashboard_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_manager.dart';
import '../services/odoo_service.dart';
import 'widdgets/modules_grid.dart';

// Ciclo: ⏰ entrada → 🍗 salida → 🦴 regreso → 🚪 salida final
enum AttStep { entrada, salidaComida, regresoComida, salidaFinal }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _odoo = OdooService();

  bool _loading = false;
  String _debugOutput = '';

  AttStep _displayStep = AttStep.entrada;
  AttStep _pendingStep = AttStep.entrada;

  static const Duration _lunchTotal = Duration(hours: 1);
  Timer? _ticker;
  DateTime? _workStart;
  DateTime? _lunchStart;

  DateTime? _cooldownUntil;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _restoreState() async {
    final sp = await SharedPreferences.getInstance();

    final ws = sp.getString('workStart');
    final ls = sp.getString('lunchStart');
    final disp = sp.getString('displayStep');
    final pend = sp.getString('pendingStep');
    final cd = sp.getString('cooldownUntil');

    setState(() {
      _workStart = (ws != null && ws.isNotEmpty) ? DateTime.tryParse(ws) : null;
      _lunchStart = (ls != null && ls.isNotEmpty)
          ? DateTime.tryParse(ls)
          : null;

      if (disp != null) _displayStep = AttStep.values[int.parse(disp)];
      if (pend != null) _pendingStep = AttStep.values[int.parse(pend)];

      _cooldownUntil = (cd != null && cd.isNotEmpty)
          ? DateTime.tryParse(cd)
          : null;
    });

    if (_workStart != null || _lunchStart != null || _cooldownUntil != null) {
      _startTicker();
    }
  }

  Future<void> _saveState() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('workStart', _workStart?.toIso8601String() ?? '');
    await sp.setString('lunchStart', _lunchStart?.toIso8601String() ?? '');
    await sp.setString('displayStep', _displayStep.index.toString());
    await sp.setString('pendingStep', _pendingStep.index.toString());
    await sp.setString(
      'cooldownUntil',
      _cooldownUntil?.toIso8601String() ?? '',
    );
  }

  bool get _inWork => _workStart != null && _lunchStart == null;
  bool get _inLunch => _lunchStart != null;
  bool get _inCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  Duration get workElapsed => _inWork && _workStart != null
      ? DateTime.now().difference(_workStart!)
      : Duration.zero;

  Duration get lunchElapsed => _inLunch && _lunchStart != null
      ? DateTime.now().difference(_lunchStart!)
      : Duration.zero;

  Duration get lunchRemaining {
    final rem = _lunchTotal - lunchElapsed;
    return rem.isNegative ? Duration.zero : rem;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_inCooldown && _workStart == null && _lunchStart == null) {
        _ticker?.cancel();
        _ticker = null;
      }
      setState(() {});
    });
  }

  void _stopAllTimers() {
    _workStart = null;
    _lunchStart = null;
    _ticker?.cancel();
    _ticker = null;
  }

  String _actionForStep(AttStep s) {
    switch (s) {
      case AttStep.entrada:
        return 'entrada';
      case AttStep.salidaComida:
        return 'salida_comida';
      case AttStep.regresoComida:
        return 'regreso_comida';
      case AttStep.salidaFinal:
        return 'salida_final';
    }
  }

  Widget _iconForStep(AttStep s) {
    switch (s) {
      case AttStep.entrada:
        return const Text('⏰', style: TextStyle(fontSize: 20));
      case AttStep.salidaComida:
        return const Text('🍗', style: TextStyle(fontSize: 20));
      case AttStep.regresoComida:
        return const Text('🦴', style: TextStyle(fontSize: 20));
      case AttStep.salidaFinal:
        return const Text('🚪', style: TextStyle(fontSize: 20));
    }
  }

  String _titleForStep(AttStep s) {
    switch (s) {
      case AttStep.entrada:
        return 'Entrada';
      case AttStep.salidaComida:
        return 'Salida a comer';
      case AttStep.regresoComida:
        return 'Regresar de comer';
      case AttStep.salidaFinal:
        return 'Salida final';
    }
  }

  String _confirmTextForStep(AttStep s) {
    switch (s) {
      case AttStep.entrada:
        return '¿Estás seguro de registrar tu ENTRADA?';
      case AttStep.salidaComida:
        return '¿Estás seguro de registrar SALIDA A COMER?';
      case AttStep.regresoComida:
        return '¿Estás seguro de registrar REGRESO DE COMER?';
      case AttStep.salidaFinal:
        return '¿Estás seguro de registrar tu SALIDA FINAL?';
    }
  }

  AttStep _nextStep(AttStep s) {
    switch (s) {
      case AttStep.entrada:
        return AttStep.salidaComida;
      case AttStep.salidaComida:
        return AttStep.regresoComida;
      case AttStep.regresoComida:
        return AttStep.salidaFinal;
      case AttStep.salidaFinal:
        return AttStep.entrada;
    }
  }

  Future<bool> _confirmAction(AttStep s) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(_titleForStep(s)),
            content: Text(_confirmTextForStep(s)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, continuar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _onPressAttendance() async {
    if (_loading || _inCooldown) return;

    setState(() => _displayStep = _pendingStep);

    final ok = await _confirmAction(_displayStep);
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final userId = await AuthManager.instance.uid;
      if (userId == null) throw Exception('No hay usuario en sesión.');

      final action = _actionForStep(_displayStep);
      await _odoo.marcarAccionAsistenciaPorUsuario(
        userId: userId,
        action: action,
      );

      switch (_displayStep) {
        case AttStep.entrada:
          _lunchStart = null;
          _workStart = DateTime.now();
          _snack('Entrada registrada. ¡Buen día!', Colors.green);
          break;
        case AttStep.salidaComida:
          _workStart = null;
          _lunchStart = DateTime.now();
          _snack('¡Buen provecho! Tienes 1 hora de comida.', Colors.red);
          break;
        case AttStep.regresoComida:
          _lunchStart = null;
          _workStart = DateTime.now();
          _snack('Regresaste de comer. Cronómetro reanudado.', Colors.teal);
          break;
        case AttStep.salidaFinal:
          _stopAllTimers();
          _snack('Salida final registrada. ¡Hasta luego!', Colors.red);
          break;
      }

      _startTicker();
      _pendingStep = _nextStep(_displayStep);
      await _startCooldown();
      await _saveState();
      setState(() => _debugOutput = '');
    } catch (e) {
      _snack('Error: $e', Colors.red);
      setState(() => _debugOutput = 'Error asistencia: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startCooldown() async {
    _cooldownUntil = DateTime.now().add(const Duration(minutes: 1));
    await _saveState();
    _startTicker();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        // ignore: deprecated_member_use
        backgroundColor: color.withOpacity(.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testOdoo() async {
    setState(() {
      _loading = true;
      _debugOutput = 'Consultando ...';
    });
    try {
      final result = await _odoo.callJsonRpc('/web/dataset/call_kw', {
        'model': 'res.partner',
        'method': 'search_read',
        'args': [
          [],
          ['id', 'name', 'email'],
        ],
        'kwargs': {'limit': 3},
      });
      final pretty = (result is List || result is Map)
          ? const JsonEncoder.withIndent('  ').convert(result)
          : result.toString();
      setState(() => _debugOutput = pretty);
    } catch (e) {
      setState(() => _debugOutput = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cooldownLeftText() {
    if (!_inCooldown) return '';
    final left = _cooldownUntil!.difference(DateTime.now());
    final s = left.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      IconButton(
        onPressed: _loading ? null : _testOdoo,
        icon: const Icon(Icons.cloud),
        tooltip: 'Probar Odoo',
      ),
      Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: (_loading || _inCooldown) ? null : _onPressAttendance,
            tooltip: _inCooldown
                ? 'Espera ${_cooldownLeftText()}'
                : _titleForStep(_displayStep),
            icon: _iconForStep(_displayStep),
          ),
          if (_inCooldown)
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.black.withOpacity(.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _cooldownLeftText(),
                  style: const TextStyle(
                    color: Color.fromARGB(233, 255, 255, 255),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
      IconButton(
        onPressed: () => Navigator.pushNamed(context, '/ajustes'),
        icon: const Icon(Icons.settings),
        tooltip: 'Ajustes',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color.fromARGB(235, 255, 254, 254),
      appBar: AppBar(title: const Text('Control Consultiva'), actions: actions),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_inWork || _inLunch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatusTimerCard(
                  inWork: _inWork,
                  workElapsed: workElapsed,
                  lunchElapsed: lunchElapsed,
                  lunchRemaining: lunchRemaining,
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Bienvenido',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const Expanded(child: ModulesGrid()),
            if (_debugOutput.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_debugOutput),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimerCard extends StatelessWidget {
  final bool inWork;
  final Duration workElapsed;
  final Duration lunchElapsed;
  final Duration lunchRemaining;

  const _StatusTimerCard({
    required this.inWork,
    required this.workElapsed,
    required this.lunchElapsed,
    required this.lunchRemaining,
  });

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = inWork ? Colors.green : Colors.red;
    final title = inWork ? 'En jornada' : 'En comida';
    final icon = inWork ? Icons.access_time : Icons.restaurant;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              // ignore: deprecated_member_use
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: inWork
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Tiempo trabajado: ${_fmt(workElapsed)}'),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Transcurrido: ${_fmt(lunchElapsed)}'),
                        Text('Restante:   ${_fmt(lunchRemaining)}'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
