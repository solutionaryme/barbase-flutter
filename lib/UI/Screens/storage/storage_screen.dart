import 'package:bar_base/data/models/product.dart';
import 'package:bar_base/ui/screens/home/widgets/product_details_sheet.dart';
import 'package:bar_base/ui/viewmodel/storage_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(storageViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Storage'),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(storageViewModelProvider.notifier).loadProducts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (products) {
          final filteredProducts = _searchQuery.isEmpty
              ? products
              : products
                    .where(
                      (p) =>
                          p.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          p.barcode.contains(_searchQuery),
                    )
                    .toList();

          if (filteredProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No products yet'
                        : 'No products found',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Scan barcodes to add products',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${filteredProducts.length} products',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      Chip(
                        label: const Text('Filtered'),
                        onDeleted: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _ProductCard(product: product);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Dismissible(
        key: Key('product_${product.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Product'),
              content: Text('Delete "${product.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          ref.read(storageViewModelProvider.notifier).deleteProduct(product.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // TODO: вернуть undo
                },
              ),
            ),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getCategoryColor(product.category),
            child: Text(
              product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(product.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.barcode),
              if (product.scanCount > 0)
                Text(
                  'Scanned: ${product.scanCount} times',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(product.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  product.productClass.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getCategoryColor(product.category),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _showProductDetails(context, product),
        ),
      ),
    );
  }

  // Цвета основаны на категориях из ProductClass
  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      // Beverages - оттенки синего/голубого
      case ProductCategory.beverages:
        return Colors.blue;

      // Snacks - оттенки оранжевого/желтого
      case ProductCategory.snacks:
        return Colors.orange;

      // Pantry - оттенки коричневого/зеленого
      case ProductCategory.pantry:
        return Colors.brown;

      // Instant Food - красный/оранжевый
      case ProductCategory.instant:
        return Colors.red;

      // Household - серый/синий
      case ProductCategory.household:
        return Colors.teal;

      // Dairy - голубой/белый
      case ProductCategory.dairy:
        return Colors.lightBlue;

      // Other/Unknown - серый
      case ProductCategory.other:
      case ProductCategory.unknown:
      default:
        return Colors.grey;
    }
  }

  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductDetailsSheet(product: product),
    );
  }
}
