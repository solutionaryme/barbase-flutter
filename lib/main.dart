import 'package:bar_base/UI/Screens/main_screen.dart';
import 'package:bar_base/data/repositories/product_repository.dart';
import 'package:bar_base/data/services/camera_service.dart';
import 'package:bar_base/data/services/isar_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // init Isar x123456
  await IsarService.initialize();

  // Загружаем продукты в HNSW после инициализации
  // await _loadProductsToIndex(); // не работает!

  runApp(const ProviderScope(child: MyApp()));
}
/*
// Загружаем продукты
Future<void> _loadProductsToIndex() async {
  try {
    // Получаем экземпляр репозитория через IsarService
    final isar = IsarService.instance.isar;
    final productRepository = ProductRepository(isar);
    final cameraService = CameraService();

    // Получаем все продукты
    final products = await productRepository.getAll();

    final data = products
        .where((p) => p.hasEmbedding && p.embedding != null)
        .map((p) => {'skuId': p.skuId, 'embedding': p.embedding})
        .toList();

    if (data.isNotEmpty) {
      await cameraService.loadAllProductsToHNSW(data);
      if (kDebugMode) {
        print('Loaded ${data.length} products to HNSW index');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error loading products to HNSW: $e');
    }
  }
}
*/
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarCode Search App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
