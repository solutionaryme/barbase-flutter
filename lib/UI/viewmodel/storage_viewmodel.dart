import 'package:bar_base/data/models/product.dart';
import 'package:bar_base/data/repositories/product_repository.dart';
import 'package:bar_base/state/providers/database_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class StorageViewModel extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _productRepository;

  StorageViewModel(this._productRepository) : super(const AsyncValue.loading()) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    try {
      state = const AsyncValue.loading();
      final products = await _productRepository.getAll();
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteProduct(int id) async {
    await _productRepository.deleteProduct(id);
    await loadProducts();
  }

  Future<void> incrementScan(Product product) async {
    await _productRepository.incrementScanCount(product);
    await loadProducts();
  }

  void filterByCategory(ProductCategory? category) {
    // Реализуйте при необходимости
  }

  void searchProducts(String query) {
    // Реализуйте при необходимости
  }
}

final storageViewModelProvider = StateNotifierProvider<StorageViewModel, AsyncValue<List<Product>>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return StorageViewModel(repo);
});