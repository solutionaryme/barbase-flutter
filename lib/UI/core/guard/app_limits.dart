// lib/core/guard/app_limits.dart
class AppLimits {
  // ========== ОБЩИЕ ЛИМИТЫ ==========
  static const int maxConcurrentInference = 1;
  static const Duration cameraWarmup = Duration(milliseconds: 500);
  
  // ========== BARCODE PIPELINE ==========
  static const int barcodeMaxBatchSize = 10;
  static const Duration barcodeDedupWindow = Duration(seconds: 2);
  static const int barcodeFrameSkip = 3;      // Каждый 2-й кадр
  static const int barcodeMaxFps = 15;        // ~15 FPS достаточно для штрихкодов
  
  // ========== AI PIPELINE ==========
  static const int aiFrameSkip = 2;            // Каждый 5-й кадр (экономия CPU)
  static const int aiMaxFps = 6;               // 6 FPS достаточно для детекции
  static const int aiMaxDetectionsPerFrame = 20;
  static const Duration aiInferenceTimeout = Duration(milliseconds: 200);
  static const int aiMaxQueueSize = 1;         // Только 1 кадр в очереди
  
  // ========== HNSW VECTOR SEARCH ==========
  static const int maxHnswMemoryMb = 50;
  static const int hnswMaxElements = 10000;
  static const int hnswEfSearch = 100;
  static const int hnswM = 16;
  
  // ========== UI ==========
  static const int uiUpdateThrottleMs = 66;    // ~15 FPS для UI обновлений
}