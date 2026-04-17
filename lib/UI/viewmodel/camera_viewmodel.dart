// lib/ui/viewmodel/camera_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/repositories/product_repository.dart';
import '../../data/services/camera_service.dart';
import '../../state/providers/database_providers.dart';
import '../../state/riverpod/ai_state.dart';
import '../../state/riverpod/barcode_state.dart';

enum ActivePipeline { barcode, ai }

final activePipelineProvider = StateProvider<ActivePipeline>(
  (ref) => ActivePipeline.barcode,
);

class CameraViewModel {
  final Ref _ref;
  final ProductRepository _productRepository;
  final CameraService _cameraService;

  int? _textureId;
  Map<String, double>? _scanRegion;

  CameraViewModel(this._ref, this._productRepository)
      : _cameraService = CameraService(); // New instance per session

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

Future<int> initializeCamera() async {
  try {
    _textureId = await _cameraService.initialize();
    
    // В HNSW ПОСЛЕ ИНИЦИАЛИЗАЦИИ
    await _loadProductsToHNSW();
    
    await _loadScanRegion();
    _wireCameraCallbacks();
    return _textureId!;
  } catch (e) {
    if (kDebugMode) print('[CameraViewModel] init error: $e');
    rethrow;
  }
}

Future<void> _loadProductsToHNSW() async {
  try {
    final products = await _productRepository.getAll();
    final data = products
        .where((p) => p.hasEmbedding && p.embedding != null)
        .map((p) => {'skuId': p.skuId, 'embedding': p.embedding})
        .toList();
    
    if (data.isNotEmpty) {
      await _cameraService.loadAllProductsToHNSW(data);
      if (kDebugMode) {
        print('[CameraViewModel] Loaded ${data.length} products to HNSW');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('[CameraViewModel] Error loading to HNSW: $e');
    }
  }
}

  /// Wire callbacks once; they stay active for the full lifetime of the camera
  /// session.  Switching pipeline is purely a UI action — both streams keep
  /// running so there's no cold-start delay when the user toggles.
  void _wireCameraCallbacks() {
    _cameraService.onAIResult = (result) {
      _ref.read(aiStateProvider.notifier).updateResult(result);
      _updateScanCounts(result);
    };

    _cameraService.onBarcode = (codes) {
      if (kDebugMode) print('[CameraViewModel] barcode: $codes');
      _ref.read(barcodeStateProvider.notifier).addCodes(codes);
    };
  }

  // ---------------------------------------------------------------------------
  // Pipeline switching — UI only, no stream manipulation
  // ---------------------------------------------------------------------------

  void switchPipeline(ActivePipeline newPipeline) {
    _ref.read(activePipelineProvider.notifier).state = newPipeline;

    // Clear stale state for the mode we're leaving
    if (newPipeline == ActivePipeline.barcode) {
      _ref.read(aiStateProvider.notifier).reset();
    } else {
      // Don't clear barcodes — the user may want to review them after switching back
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _updateScanCounts(AIResult result) {
    for (final detection in result.detections) {
      if (detection.skuId != null) {
        unawaited(_updateProductScanCount(detection.skuId!));
      }
    }
  }

  Future<void> _updateProductScanCount(int skuId) async {
    final product = await _productRepository.getBySkuId(skuId);
    if (product != null) {
      await _productRepository.incrementScanCount(product);
    }
  }

  Future<void> _loadScanRegion() async {
    _scanRegion = await _cameraService.getScanRegion();
  }

  List<String> getBarcodeCodes() => _ref.read(barcodeStateProvider);

  int? get textureId => _textureId;
  Map<String, double>? get scanRegion => _scanRegion;

  void dispose() {
    _cameraService.dispose();
  }
}

final cameraViewModelProvider = Provider<CameraViewModel>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return CameraViewModel(ref, productRepo);
});