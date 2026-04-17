// lib/ui/screens/home/widgets/product_list_widget.dart
import 'package:bar_base/UI/Screens/Home/widgets/product_details_sheet.dart';
import 'package:bar_base/UI/viewmodel/home_viewmodel.dart';
import 'package:bar_base/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

class ProductListWidget extends ConsumerWidget {
  final List<String> barcodes;

  const ProductListWidget({super.key, required this.barcodes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory,
              size: 28,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Scanned Products (${barcodes.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: barcodes.length,
            itemBuilder: (context, index) {
              final barcode = barcodes[index];
              return _ProductCard(barcode: barcode);
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final String barcode;

  const _ProductCard({required this.barcode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(homeViewModelProvider.notifier);

    return FutureBuilder<Product?>(
      future: viewModel.findProductByBarcode(barcode),
      builder: (context, snapshot) {
        final product = snapshot.data;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                product?.displayTitle.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(product?.displayTitle ?? barcode),
            subtitle: Text(
              product?.id == Isar.autoIncrement
                  ? '⚠️ Needs details - tap to edit'
                  : (product?.displaySubtitle ?? 'Tap to edit'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showProductDetails(context, product, barcode),
          ),
        );
      },
    );
  }

  void _showProductDetails(
    BuildContext context,
    Product? product,
    String barcode,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductDetailsSheet(
        product:
            product ??
            (Product()
              ..barcode = barcode
              ..name = 'New Product'),
      ),
    );
  }
}
