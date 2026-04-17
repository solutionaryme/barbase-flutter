// lib/ui/viewmodel/home_viewmodel.dart
import 'package:bar_base/data/models/product.dart';
import 'package:bar_base/data/repositories/product_repository.dart';
import 'package:bar_base/state/providers/database_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

/// ViewModel для домашнего экрана
/// но что делать с товарами не сохраненными?
/// так же не обновляется страница после добавления
class HomeViewModel extends StateNotifier<List<String>> {
  final ProductRepository _productRepository;

  // Кэш для "черновиков" товаров (ещё не сохранённых)
  final Map<String, Product> _draftProducts = {};

  HomeViewModel(this._productRepository) : super([]);

  /// Добавление отсканированных кодов (только в кэш, НЕ в БД)
  void addScannedCodes(List<String> codes) {
    for (final barcode in codes) {
      if (!_draftProducts.containsKey(barcode)) {
        _draftProducts[barcode] = Product()
          ..barcode = barcode
          ..name = 'Product $barcode'
          ..category = ProductCategory.other
          ..productClass = ProductClass.unknown
          ..isSynced = false;
      }
    }
    state = [...state, ...codes];
  }

  /// Получить черновик товара по штрихкоду
  Product? getDraftProduct(String barcode) {
    return _draftProducts[barcode];
  }

  /// Сохранить товар в БД (вызывается из ProductDetailsSheet)
  Future<void> saveProduct(Product product) async {
    await _productRepository.saveProduct(product);
    _draftProducts.remove(product.barcode);
  }

  /// Очистка всех результатов (и черновиков)
  void clearScannedCodes() {
    _draftProducts.clear();
    state = [];
  }

  /// Проверить, существует ли товар в БД
  Future<Product?> findProductByBarcode(String barcode) async {
    // Сначала ищем в черновиках
    if (_draftProducts.containsKey(barcode)) {
      return _draftProducts[barcode];
    }
    // Потом в БД
    return await _productRepository.getByBarcode(barcode);
  }
}

/// Провайдер для домашнего экрана
final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, List<String>>((ref) {
      final productRepo = ref.watch(productRepositoryProvider);
      return HomeViewModel(productRepo);
    });
