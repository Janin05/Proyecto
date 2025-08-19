import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/odoo_inventory_service.dart';
import '../services/auth_manager.dart';

class Product {
  final String id;
  final String tmplId;
  final String name;
  final String sku;
  final String? barcode;
  final String location;
  final int quantity;
  final double price;
  final double cost;
  final String? uomName;
  final String? categoryName;
  final ImageProvider? imageProvider;
  final ImageProvider? locationImageProvider;
  final bool hasLocationImage;

  Product({
    required this.id,
    required this.tmplId,
    required this.name,
    required this.sku,
    this.barcode,
    required this.location,
    required this.quantity,
    required this.price,
    required this.cost,
    this.uomName,
    this.categoryName,
    this.imageProvider,
    this.locationImageProvider,
    required this.hasLocationImage,
  });
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _service = OdooInventoryService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Product> _products = [];
  bool _loading = false;
  String? _error;

  Future<void> _searchServer() async {
    final term = _searchCtrl.text.trim();
    if (term.length < 3) {
      setState(() {
        _products = [];
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe al menos 3 caracteres')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sessionId = await AuthManager.instance.sessionId;
      if (!mounted) return;
      await _service.ensureSession(sessionFromAuthManager: sessionId);
      if (!mounted) return;

      final list = await _service.listProducts(query: term);
      if (!mounted) return;

      final mapped = list.map((p) {
        ImageProvider? prodImg;
        if ((p.imageBase64 ?? '').isNotEmpty) {
          try {
            prodImg = MemoryImage(base64Decode(p.imageBase64!));
          } catch (_) {}
        }

        ImageProvider? locImg;
        final String? locB64 = p.locationImageBase64;
        final bool hasLocImg = (locB64 ?? '').isNotEmpty;
        if (hasLocImg) {
          try {
            locImg = MemoryImage(base64Decode(locB64!));
          } catch (_) {}
        }

        return Product(
          id: p.id.toString(),
          tmplId: p.tmplId.toString(),
          name: p.name,
          sku: p.sku,
          barcode: p.barcode,
          location: p.locationName ?? 'Sin ubicación',
          quantity: p.qty.round(),
          price: p.price,
          cost: p.cost,
          uomName: p.uomName,
          categoryName: p.categoryName,
          imageProvider: prodImg,
          locationImageProvider: locImg,
          hasLocationImage: hasLocImg,
        );
      }).toList();

      if (!mounted) return;
      setState(() => _products = mapped);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _products = [];
      _error = null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHint = _products.isEmpty && !_loading && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            onPressed: _clearSearch,
            icon: const Icon(Icons.clear_all),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _searchServer(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Nombre / SKU / Código / Ubicación (min. 3)',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _searchServer,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _searchServer)
          : showHint
          ? const _SearchHint()
          : _buildList(),
    );
  }

  Widget _buildList() {
    final items = _products;
    if (items.isEmpty) return const _EmptyState();

    return RefreshIndicator(
      onRefresh: _searchServer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          int crossAxis = 1;
          if (width >= 1200) {
            crossAxis = 4;
          } else if (width >= 900) {
            crossAxis = 3;
          } else if (width >= 600) {
            crossAxis = 2;
          }

          if (crossAxis == 1) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _ProductCard(
                product: items[i],
                onTap: () => _openProductDetail(items[i]),
                onEdit: () => _openProductForm(initial: items[i]),
                onDelete: () => _deleteProduct(items[i]),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _ProductCard(
              product: items[i],
              onTap: () => _openProductDetail(items[i]),
              onEdit: () => _openProductForm(initial: items[i]),
              onDelete: () => _deleteProduct(items[i]),
            ),
          );
        },
      ),
    );
  }

  void _deleteProduct(Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Seguro que deseas eliminar "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Implementa delete en Odoo (write/unlink)'),
                ),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _openProductForm({Product? initial}) async {
    final result = await showModalBottomSheet<_FormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ProductFormSheet(initial: initial),
    );
    if (result == null) return;

    try {
      await _service.ensureSession(
        sessionFromAuthManager: await AuthManager.instance.sessionId,
      );

      if (initial == null) {
        final newTmplId = await _service.createProduct(
          name: result.name,
          sku: result.sku,
          barcode: result.barcode,
          imageBase64: result.imageBase64,
          listPrice: result.price,
          standardPrice: result.cost,
        );
        await _searchServer();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Producto creado (Template $newTmplId)')),
        );
      } else {
        final ok = await _service.updateProductBoth(
          productId: int.parse(initial.id),
          templateId: int.parse(initial.tmplId),
          productValues: {
            'name': result.name,
            'default_code': result.sku,
            if (result.barcode != null) 'barcode': result.barcode,
          },
          templateValues: {
            if (result.price != null) 'list_price': result.price,
            if (result.cost != null) 'standard_price': result.cost,
          },
        );
        if (ok) {
          await _searchServer();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error guardando en Odoo: $e')));
    }
  }

  void _openProductDetail(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ProductDetailSheet(
        p: p,
        onEdit: () {
          Navigator.pop(ctx);
          _openProductForm(initial: p);
        },
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search, size: 72),
            SizedBox(height: 12),
            Text('Escribe y pulsa “Buscar” (mínimo 3 caracteres).'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 72),
          SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 12),
          Text('Error: $message', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _FormResult {
  final String name, sku;
  final String? barcode;
  final double? price;
  final double? cost;
  final String? imageBase64;
  _FormResult({
    required this.name,
    required this.sku,
    this.barcode,
    this.price,
    this.cost,
    this.imageBase64,
  });
}

class _ProductFormSheet extends StatefulWidget {
  final Product? initial;
  const _ProductFormSheet({this.initial});
  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;

  ImageProvider? _initialProductImg;
  ImageProvider? _initialLocationImg;
  String? _pickedProductB64;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    _costCtrl = TextEditingController(
      text: p != null ? p.cost.toStringAsFixed(2) : '',
    );
    _initialProductImg = p?.imageProvider;
    _initialLocationImg = (p?.hasLocationImage == true)
        ? p!.locationImageProvider
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProductImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _pickedProductB64 = base64Encode(bytes);
      _initialProductImg = MemoryImage(bytes);
    });
  }

  // SOLO botón “Ver” (sin preview)
  Widget _viewButtonOnly(
    String title,
    ImageProvider? provider,
    String emptyText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (provider == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              emptyText,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _openViewer(provider, title: title),
            icon: const Icon(Icons.remove_red_eye_outlined),
            label: const Text('Ver'),
          ),
      ],
    );
  }

  void _openViewer(ImageProvider provider, {String? title}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Flexible(
              child: InteractiveViewer(child: Image(image: provider)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final res = _FormResult(
      name: _nameCtrl.text.trim(),
      sku: _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
      cost: double.tryParse(_costCtrl.text.replaceAll(',', '.')),
      imageBase64: _isEdit ? null : _pickedProductB64,
    );
    Navigator.pop(context, res);
  }

  Widget _imageOnlyPreview(ImageProvider? provider, String emptyText) {
    if (provider == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(emptyText, style: TextStyle(color: Colors.grey.shade700)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image(image: provider, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Editar producto' : 'Nuevo producto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.label_important_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Código de barras',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio (venta)',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Costo',
                      prefixIcon: Icon(Icons.attach_money_outlined),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: const Text('Ubicación física (A1-R2-F3)'),
              subtitle: Text(widget.initial?.location ?? 'Sin ubicación'),
            ),

            const SizedBox(height: 16),
            if (_isEdit) ...[
              _viewButtonOnly(
                'Ubicación',
                _initialLocationImg,
                'Sin imagen de ubicación',
              ),
              const SizedBox(height: 20),
              const Text(
                'Imagen del producto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _imageOnlyPreview(_initialProductImg, 'Sin imagen de producto'),
            ] else ...[
              const Text(
                'Imagen del producto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _imageOnlyPreview(_initialProductImg, 'Sin imagen de producto'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickProductImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Elegir imagen de producto'),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final avatarImg = product.locationImageProvider ?? product.imageProvider;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.imageProvider != null)
                    Ink.image(image: product.imageProvider!, fit: BoxFit.cover)
                  else
                    Container(
                      color: const Color.fromARGB(227, 238, 238, 238),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                      ),
                    ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (avatarImg != null) ...[
                            CircleAvatar(
                              backgroundImage: avatarImg,
                              radius: 10,
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            const Icon(
                              Icons.place,
                              size: 16,
                              color: Color.fromARGB(217, 255, 255, 255),
                            ),
                            const SizedBox(width: 6),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              product.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color.fromARGB(216, 255, 255, 255),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SKU: ${product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if ((product.barcode ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.qr_code, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      product.barcode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Precio: ${product.price.toStringAsFixed(2)}'),
                  const SizedBox(width: 12),
                  if ((product.uomName ?? '').isNotEmpty)
                    Text('UoM: ${product.uomName}'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.inventory, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Cantidad: ${product.quantity}')),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatelessWidget {
  final Product p;
  final VoidCallback onEdit;
  const _ProductDetailSheet({required this.p, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(p.categoryName ?? 'Sin categoría'),
            const Divider(height: 24),
            _kv('SKU', p.sku),
            _kv('Código de barras', p.barcode ?? '—'),
            _kv('Cantidad a la mano', '${p.quantity} ${p.uomName ?? ""}'),
            _kv('Precio (venta)', p.price.toStringAsFixed(2)),
            _kv('Costo', p.cost.toStringAsFixed(2)),
            _kv('Ubicación física', p.location),

            const SizedBox(height: 16),
            const Text(
              'Ubicación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (p.hasLocationImage && p.locationImageProvider != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image(
                    image: p.locationImageProvider!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              const Text('Sin imagen de ubicación'),

            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Listo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
