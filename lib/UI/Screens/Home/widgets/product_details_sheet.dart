// lib/ui/screens/home/widgets/product_details_sheet.dart (исправленный)
import 'package:bar_base/UI/viewmodel/home_viewmodel.dart';
import 'package:bar_base/UI/viewmodel/storage_viewmodel.dart';
import 'package:bar_base/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

class ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailsSheet({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsSheet> createState() =>
      _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<ProductDetailsSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late ProductCategory _selectedCategory;
  late ProductClass _selectedClass;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _brandController = TextEditingController(text: widget.product.brand ?? '');
    _selectedCategory = widget.product.category;
    // Если класс unknown, но товар новый
    // — оставляем unknown??? - отмена - класс unknown не может быть
    _selectedClass = widget.product.productClass;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.product.name = _nameController.text;
    widget.product.brand = _brandController.text.isEmpty
        ? null
        : _brandController.text;
    widget.product.category = _selectedCategory;
    widget.product.productClass = _selectedClass;
    widget.product.updateCategoryFromClass();

    // Сохраняем через ViewModel
    final viewModel = ref.read(homeViewModelProvider.notifier);
    await viewModel.saveProduct(widget.product);

    ref.read(storageViewModelProvider.notifier).loadProducts();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Barcode: ${widget.product.barcode}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Product Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandController,
            decoration: const InputDecoration(labelText: 'Brand (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductCategory>(
            value: _selectedCategory,
            items: ProductCategory.values.map((c) {
              return DropdownMenuItem(value: c, child: Text(c.displayName));
            }).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          // Исключаем unknown из выпадающего списка
          DropdownButtonFormField<ProductClass>(
            value:
                _selectedClass == ProductClass.unknown &&
                    widget.product.id == Isar.autoIncrement
                ? null // Для нового товара placeholder
                : _selectedClass,
            hint: const Text('Select product class'),
            items: ProductClass.values
                .where((c) => c != ProductClass.unknown) // убер аем
                .map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.displayName));
                })
                .toList(),
            onChanged: (v) => setState(() => _selectedClass = v!),
            decoration: const InputDecoration(labelText: 'Product Class'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('SAVE PRODUCT'),
            ),
          ),
        ],
      ),
    );
  }
}
