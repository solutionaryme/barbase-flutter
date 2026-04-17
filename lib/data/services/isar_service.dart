// lib/data/services/isar_service.dart
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

class IsarService {
  static IsarService? _instance;
  static IsarService get instance {
    if (_instance == null) {
      throw StateError('IsarService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  late final Isar isar;
  late final ProductRepository productRepository;

  IsarService._(this.isar) {
    productRepository = ProductRepository(isar);
  }

  static Future<void> initialize() async {
    if (_instance != null) return;

    final dir = await getApplicationDocumentsDirectory();
    
    final isar = await Isar.open(
      [ProductSchema],
      directory: dir.path,
      inspector: kDebugMode,
    );

    _instance = IsarService._(isar);
  }

  static Future<void> close() async {
    await _instance?.isar.close();
    _instance = null;
  }
}