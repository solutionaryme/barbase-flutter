// lib/state/providers/database_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/isar_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService.instance;
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ref.watch(isarServiceProvider).productRepository;
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.watchAll();
});

final productByBarcodeProvider = FutureProvider.family<Product?, String>((
  ref,
  barcode,
) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getByBarcode(barcode);
});

final productBySkuIdProvider = FutureProvider.family<Product?, int>((
  ref,
  skuId,
) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getBySkuId(skuId);
});

final unsyncedCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final unsynced = await repo.getUnsynced();
  return unsynced.length;
});

final popularProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getPopular(limit: 20);
});

final classStatsProvider = FutureProvider<Map<ProductClass, int>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getClassStats();
});

// Новые провайдеры
final expiringSoonProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getExpiringSoon();
});

final expiredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getExpired();
});

final lowStockProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getLowStock();
});
