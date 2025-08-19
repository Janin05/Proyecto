// lib/pages/herramientas.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';

import '../services/auth_manager.dart';
import '../services/odoo_service.dart';

class HerramientasPage extends StatefulWidget {
  const HerramientasPage({super.key});

  @override
  State<HerramientasPage> createState() => _HerramientasPageState();
}

class _HerramientasPageState extends State<HerramientasPage> {
  final _picker = ImagePicker();
  final _odoo = OdooService();

  // Formulario de metadatos
  String? _proyecto;
  final _folioCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  // Usuario (desde AuthManager)
  String? _usuarioNombre;
  String? _usuarioEmail;

  // Lote de fotos tomadas (ya procesadas/guardadas)
  final List<_FotoLote> _fotos = [];

  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _verificarPermisos();
  }

  Future<void> _cargarUsuario() async {
    final name = await AuthManager.instance.name;
    final email = await AuthManager.instance.email;
    if (!mounted) return;
    setState(() {
      _usuarioNombre = name ?? 'Usuario';
      _usuarioEmail = email ?? 'desconocido@local';
    });
  }

  Future<void> _verificarPermisos() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa la ubicación para sellar coordenadas.'),
        ),
      );
    }
    await Geolocator.requestPermission();
  }

  Future<Position?> _ubicar() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _tomarFoto() async {
    try {
      setState(() => _saving = true);

      // 1) Capturar
      final xfile = await _picker.pickImage(source: ImageSource.camera);
      if (xfile == null) {
        setState(() => _saving = false);
        return;
      }

      // 2) Metadatos
      final now = DateTime.now();
      final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final pos = await _ubicar();
      final lat = pos?.latitude.toStringAsFixed(6) ?? 'N/D';
      final lon = pos?.longitude.toStringAsFixed(6) ?? 'N/D';

      final proyecto = _proyecto ?? 'Sin proyecto';
      final folio = _folioCtrl.text.isNotEmpty ? _folioCtrl.text : 'S/F';
      final usuario = _usuarioNombre ?? 'Usuario';

      // 3) Leer, corregir orientación y aplicar marca de agua
      final bytes = await File(xfile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('No se pudo decodificar la imagen.');
      final corrected = img.bakeOrientation(decoded);

      final watermarked = await _aplicarMarcaAgua(corrected, [
        'Proyecto: $proyecto',
        'Folio: $folio',
        'Usuario: $usuario',
        'Fecha/Hora: $fecha',
        'Ubicación: $lat, $lon',
      ]);

      // 4) Guardar en almacenamiento app
      final savedFile = await _guardarImagenLocal(
        watermarked,
        prefix: 'reporte_',
      );

      // 5) Guardar en galería (con gal)
      try {
        await Gal.requestAccess();
        await Gal.putImage(savedFile.path, album: 'Reportes');
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo guardar en la galería (se guardó en la app).',
              ),
            ),
          );
        }
      }

      // 6) Agregar al lote
      if (!mounted) return;
      setState(() {
        _fotos.add(
          _FotoLote(
            file: savedFile,
            proyecto: proyecto,
            folio: folio,
            usuario: usuario,
            fecha: fecha,
            lat: lat,
            lon: lon,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar/guardar la foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<File> _guardarImagenLocal(
    img.Image im, {
    String prefix = 'img_',
  }) async {
    final bytes = Uint8List.fromList(img.encodeJpg(im, quality: 92));
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/$prefix$ts.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Marca de agua inferior con fondo semitransparente y líneas de texto.
  Future<img.Image> _aplicarMarcaAgua(img.Image src, List<String> lines) async {
    final im = img.copyResize(src, width: src.width);

    final barHeight = (src.height * 0.24).toInt().clamp(90, 360);
    final overlay = img.Image(width: src.width, height: barHeight);

    // Fondo negro semitransparente
    img.fill(overlay, color: img.ColorRgba8(0, 0, 0, 140));

    // Texto
    const int margin = 16;
    const int lineHeight = 26; // un poco más alto para arial24
    final textColor = img.ColorRgba8(255, 255, 255, 255);

    for (int i = 0; i < lines.length; i++) {
      img.drawString(
        overlay,
        lines[i],
        font: img.arial24, // fuente incluida en image ^4.x
        x: margin,
        y: margin + i * lineHeight,
        color: textColor,
      );
    }

    // Pegar la barra abajo
    img.compositeImage(im, overlay, dstX: 0, dstY: src.height - barHeight);
    return im;
  }

  Future<void> _subirLote() async {
    if (_fotos.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay fotos para subir')));
      return;
    }
    if ((_proyecto ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un proyecto')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final notas = _notasCtrl.text;

      await _odoo.uploadPhotoReport(
        proyecto: _proyecto!,
        folio: _folioCtrl.text,
        notas: notas,
        fotos: _fotos
            .map(
              (f) => UploadFoto(
                path: f.file.path,
                fecha: f.fecha,
                lat: f.lat,
                lon: f.lon,
                usuario: f.usuario,
                folio: f.folio,
                proyecto: f.proyecto,
              ),
            )
            .toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte subido correctamente')),
      );

      setState(() {
        _fotos.clear();
        _notasCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canTap = !_saving && !_uploading;

    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Proyecto + Folio + Notas
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _proyecto,
                  decoration: const InputDecoration(
                    labelText: 'Proyecto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Proyecto A',
                      child: Text('Proyecto A'),
                    ),
                    DropdownMenuItem(
                      value: 'Proyecto B',
                      child: Text('Proyecto B'),
                    ),
                    DropdownMenuItem(
                      value: 'Proyecto C',
                      child: Text('Proyecto C'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _proyecto = v),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _folioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Folio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notasCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas / Comentarios',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Botones principales
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canTap ? _tomarFoto : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: canTap ? _subirLote : null,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Subir'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text(
            'Fotos del lote',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_fotos.isEmpty) const Text('Aún no has tomado fotos.'),
          if (_fotos.isNotEmpty)
            ..._fotos.map(
              (f) => Card(
                child: ListTile(
                  leading: Image.file(
                    f.file,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                  title: Text('${f.proyecto}  •  ${f.folio}'),
                  subtitle: Text(
                    '${f.fecha}\n${f.lat}, ${f.lon} • ${f.usuario}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        _fotos.remove(f);
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FotoLote {
  final File file;
  final String proyecto;
  final String folio;
  final String usuario;
  final String fecha;
  final String lat;
  final String lon;

  _FotoLote({
    required this.file,
    required this.proyecto,
    required this.folio,
    required this.usuario,
    required this.fecha,
    required this.lat,
    required this.lon,
  });
}
