// lib/data/services/camera_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../state/riverpod/ai_state.dart';

// не трогать - сервис работает вместе - потерей кадров не замечено
// версия АПИ - 0.4
// история - переделали из двух потоков в один
// ранее были просадки на 10 и более кадров.

/// Thin wrapper around the native camera plugin.
///
/// Both event streams (barcode + AI) are permanently subscribed once
/// [initialize] is called.  Switching between barcode / AI mode is a
/// **pure UI decision** — the native side always emits on both channels
/// and Flutter simply renders whichever one the UI cares about.
class CameraService {
  static const _platform = MethodChannel('com.yourapp/camera');
  static const _aiChannel = EventChannel('com.yourapp/camera/ai_results');
  static const _barcodeChannel = EventChannel('com.yourapp/camera/barcodes');

  // Singleton
  // потому что достаточно одного выз
  // static final CameraService _instance = CameraService._internal();
  // factory CameraService() => _instance;
  // CameraService._internal();

  // Normal constructor:
  CameraService();

  StreamSubscription<AIResult>? _aiSubscription;
  StreamSubscription<List<String>>? _barcodeSubscription;

  int? _textureId;
  bool _isInitialized = false;

  /// Called whenever an AI result arrives.
  void Function(AIResult)? onAIResult;

  /// Called whenever one or more barcodes are detected.
  void Function(List<String>)? onBarcode;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<int> initialize() async {
    if (_isInitialized) return _textureId!;

    // 1. Subscribe to both streams BEFORE starting the camera so we never
    //    miss the first events that arrive right after `start`...
    _aiSubscription = _aiChannel
        .receiveBroadcastStream()
        .map((event) => AIResult.fromNative(event))
        .listen((result) {
          if (kDebugMode) {
            print(
              '[CameraService] AI result: ${result.detections.length} detections',
            );
          }
          onAIResult?.call(result);
        }, onError: (e) => print('[CameraService] AI stream error: $e'));

    _barcodeSubscription = _barcodeChannel
        .receiveBroadcastStream()
        .map((event) => List<String>.from(event as List))
        .listen((codes) {
          if (kDebugMode) {
            print('[CameraService] Barcode: $codes');
          }
          onBarcode?.call(codes);
        }, onError: (e) => print('[CameraService] Barcode stream error: $e'));

    // 2. Start the camera — native side begins emitting frames.
    _textureId = await _platform.invokeMethod<int>('start');
    _isInitialized = true;

    if (kDebugMode) {
      print('[CameraService] Initialized, textureId=$_textureId');
    }
    return _textureId!;
  }

  // кофликты двух разных методов проверить нативку!
  Future<void> loadAllProductsToHNSW(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;
    await _platform.invokeMethod('loadAllProductsToHNSW', data);
  }

  Future<Map<String, double>?> getScanRegion() async {
    try {
      final result = await _platform.invokeMethod('getScanRegion');
      if (result == null) return null;
      return Map<String, double>.from(result as Map);
    } catch (e) {
      if (kDebugMode) {
        print('[CameraService] getScanRegion error: $e');
      }
      return null;
    }
  }

  Future<void> stop() async {
    if (kDebugMode) {
      print('[CameraService] Stopping...');
    }

    // Отписываемся от стримов
    await _aiSubscription?.cancel();
    await _barcodeSubscription?.cancel();
    _aiSubscription = null;
    _barcodeSubscription = null;

    try {
      // Добавляем таймаут
      await _platform
          .invokeMethod('stop')
          .timeout(
            Duration(seconds: 2),
            onTimeout: () {
              if (kDebugMode) {
                print('[CameraService] Stop timeout - forcing');
              }
              return null;
            },
          );
    } catch (e) {
      if (kDebugMode) {
        print('[CameraService] stop error: $e');
      }
    }

    // Reset so the next call to initialize() works correctly.
    _isInitialized = false;
    _textureId = null;
    if (kDebugMode) {
      print('[CameraService] Stopped');
    }
  }

  void dispose() => stop();

  int? get textureId => _textureId;
}
