// lib/data/repositories/product_repository.dart
import 'package:isar_community/isar.dart';

import '../models/product.dart';

class ProductRepository {
  final Isar _isar;

  ProductRepository(this._isar);

  // ========== CREATE / UPDATE ==========
  Future<void> saveProduct(Product product) async {
    product.updatedAt = DateTime.now();
    product.firstScannedAt ??= DateTime.now();
    product.updateCategoryFromClass(); // Авто-категория
    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });
  }

  Future<void> saveProducts(List<Product> products) async {
    final now = DateTime.now();
    for (var p in products) {
      p.updatedAt = now;
      p.firstScannedAt ??= now;
      p.updateCategoryFromClass();
    }
    await _isar.writeTxn(() async {
      await _isar.products.putAll(products);
    });
  }

  // ========== READ ==========
  Future<Product?> getByBarcode(String barcode) async {
    return await _isar.products.where().barcodeEqualTo(barcode).findFirst();
  }

  Future<Product?> getBySkuId(int skuId) async {
    return await _isar.products.where().skuIdEqualTo(skuId).findFirst();
  }

  Future<Product?> getById(int id) async {
    return await _isar.products.get(id);
  }

  Future<List<Product>> getAll({int? limit, int? offset}) async {
    final query = _isar.products.where().sortByCreatedAtDesc();

    if (offset != null && limit != null) {
      return await query.offset(offset).limit(limit).findAll();
    } else if (offset != null) {
      return await query.offset(offset).findAll();
    } else if (limit != null) {
      return await query.limit(limit).findAll();
    }

    return await query.findAll();
  }

  // Поиск по названию (фильтрация в памяти)
  Future<List<Product>> searchByName(String query) async {
    final all = await _isar.products.where().findAll();
    final lowerQuery = query.toLowerCase();
    return all.where((p) => p.name.toLowerCase().contains(lowerQuery)).toList();
  }

  // Получить по классу (фильтрация в памяти)
  Future<List<Product>> getByClass(
    ProductClass productClass, {
    int limit = 50,
  }) async {
    final all = await _isar.products.where().findAll();
    final filtered = all.where((p) => p.productClass == productClass).toList();
    filtered.sort((a, b) => b.scanCount.compareTo(a.scanCount));
    return filtered.take(limit).toList();
  }

  // Получить по категории (фильтрация в памяти)
  Future<List<Product>> getByCategory(
    ProductCategory category, {
    int limit = 50,
  }) async {
    final all = await _isar.products.where().findAll();
    final filtered = all.where((p) => p.category == category).toList();
    filtered.sort((a, b) => b.scanCount.compareTo(a.scanCount));
    return filtered.take(limit).toList();
  }

  // Несинхронизированные (фильтрация в памяти)
  Future<List<Product>> getUnsynced({int limit = 50}) async {
    final all = await _isar.products.where().findAll();
    return all.where((p) => !p.isSynced).take(limit).toList();
  }

  // Популярные товары (фильтрация + сортировка в памяти)
  Future<List<Product>> getPopular({int limit = 20}) async {
    final all = await _isar.products.where().findAll();
    all.sort((a, b) => b.scanCount.compareTo(a.scanCount));
    return all.where((p) => p.scanCount > 0).take(limit).toList();
  }

  // Статистика по классам
  Future<Map<ProductClass, int>> getClassStats() async {
    final products = await _isar.products.where().findAll();
    final stats = <ProductClass, int>{};

    for (var p in products) {
      stats[p.productClass] = (stats[p.productClass] ?? 0) + 1;
    }

    return stats;
  }

  // Популярные классы
  Future<List<ProductClass>> getPopularClasses({int limit = 5}) async {
    final stats = await getClassStats();
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .where((e) => e.key != ProductClass.unknown)
        .take(limit)
        .map((e) => e.key)
        .toList();
  }

  // ========== UPDATE ACTIONS ==========
  Future<void> updateSkuId(Product product, int skuId) async {
    await _isar.writeTxn(() async {
      product.skuId = skuId;
      product.updatedAt = DateTime.now();
      await _isar.products.put(product);
    });
  }

  Future<void> incrementScanCount(Product product) async {
    await _isar.writeTxn(() async {
      product.scanCount++;
      product.lastScannedAt = DateTime.now();
      product.firstScannedAt ??= product.lastScannedAt;
      await _isar.products.put(product);
    });
  }

  Future<void> markAsSynced(Product product, {String? remoteId}) async {
    await _isar.writeTxn(() async {
      product.isSynced = true;
      product.updatedAt = DateTime.now();
      if (remoteId != null) {
        product.remoteId = remoteId;
      }
      await _isar.products.put(product);
    });
  }

  Future<void> markManyAsSynced(List<Product> products) async {
    await _isar.writeTxn(() async {
      for (var p in products) {
        p.isSynced = true;
        p.updatedAt = DateTime.now();
      }
      await _isar.products.putAll(products);
    });
  }

  // ========== DELETE ==========
  Future<void> deleteProduct(int id) async {
    await _isar.writeTxn(() async {
      await _isar.products.delete(id);
    });
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.products.clear();
    });
  }

  // Товары с истекающим сроком
  Future<List<Product>> getExpiringSoon({int daysThreshold = 7}) async {
    final all = await _isar.products.where().findAll();
    final now = DateTime.now();
    return all.where((p) {
      if (p.expiryDate == null) return false;
      final diff = p.expiryDate!.difference(now).inDays;
      return diff >= 0 && diff <= daysThreshold;
    }).toList();
  }

  // Просроченные товары
  Future<List<Product>> getExpired() async {
    final all = await _isar.products.where().findAll();
    final now = DateTime.now();
    return all
        .where((p) => p.expiryDate != null && p.expiryDate!.isBefore(now))
        .toList();
  }

  // Товары с низким остатком
  Future<List<Product>> getLowStock() async {
    final all = await _isar.products.where().findAll();
    return all.where((p) => p.stockQuantity <= p.minStockLevel).toList();
  }

  // Обновить количество
  Future<void> updateStock(Product product, int newQuantity) async {
    await _isar.writeTxn(() async {
      product.stockQuantity = newQuantity;
      product.updatedAt = DateTime.now();
      await _isar.products.put(product);
    });
  }

  // ========== UTILS ==========
  Future<int> count() async {
    return await _isar.products.count();
  }

  Stream<List<Product>> watchAll() {
    return _isar.products.where().sortByCreatedAtDesc().watch(
      fireImmediately: true,
    );
  }
}
