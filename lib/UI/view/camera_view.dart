// lib/ui/view/camera_view.dart
import 'package:bar_base/data/models/product.dart';
import 'package:bar_base/state/Riverpod/barcode_state.dart';
import 'package:bar_base/state/Riverpod/camera_providers.dart';
import 'package:bar_base/ui/core/guard/app_limits.dart';
import 'package:bar_base/ui/ml/barcode_mode.dart';
import 'package:bar_base/ui/viewmodel/camera_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Дает ConsumerStatefulWidget

import '../../state/riverpod/ai_state.dart';

class CameraView extends ConsumerStatefulWidget {
  const CameraView({super.key});

  @override
  ConsumerState<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<CameraView> {
  late final CameraViewModel _viewModel;
  bool _isStarting = true;
  bool _isReturning = false;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(cameraViewModelProvider);

    // Откладываем инициализацию до после билда
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeCamera();
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final textureId = await _viewModel.initializeCamera();
      if (mounted) {
        setState(() => _isStarting = false);
        _listenToBarcodes(); // если камера готова к этому движу
      }

      if (kDebugMode) print('[CameraView] Ready with textureId: $textureId');
    } catch (e) {
      if (kDebugMode) print('[CameraView] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Camera failed to start')));
        _safePop([]);
      }
    }
  }

  void _listenToBarcodes() {
    ref.listenManual(barcodeStateProvider, (previous, next) {
      if (kDebugMode) {
        print('[LISTENER] Previous: $previous');
        print('[LISTENER] Next: $next');
        print('[LISTENER] Mounted: $mounted, Returning: $_isReturning');
      }

      if (!mounted || _isReturning) {
        if (kDebugMode) {
          print('⚠️ [LISTENER] Skipping - not mounted or already returning');
        }
        return;
      }

      final mode = ref.read(barcodeModeProvider);
      if (kDebugMode) {
        print('[LISTENER] Current mode: $mode');
      }

      if (mode == BarcodeMode.single && next.isNotEmpty) {
        // Auto-close with the first scanned code
        _safePop(next);
      } else if (mode == BarcodeMode.multi &&
          next.length >= AppLimits.barcodeMaxBatchSize) {
        if (kDebugMode) {
          print('[LISTENER] Multi mode limit reached - closing');
        }
        // Auto-close when limit is reached
        _safePop(next);
      }
      // Otherwise just update UI (chips appear, user presses FINISH)
      // но он иногда и не работает - при условии что не найден (баг в нативке)
    });
  }

  void _safePop(List<String> codes) {
    if (kDebugMode) {
      print('_safePop called with codes: $codes, _isReturning: $_isReturning');
    }
    if (_isReturning) return;
    _isReturning = true;
    if (mounted) {
      Navigator.pop(context, codes);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _finish() {
    final codes = _viewModel.getBarcodeCodes();
    if (kDebugMode) {
      print('Finish pressed, returning codes: $codes');
    }
    _safePop(codes);
  }

  @override
  Widget build(BuildContext context) {
    final activePipeline = ref.watch(activePipelineProvider);
    // final barcodeCodes = ref.watch(barcodeStateProvider);
    final barcodeCodes = _viewModel.getBarcodeCodes();

    final aiResults = ref.watch(aiStateProvider);
    final screenSize = MediaQuery.of(context).size;
    final textureId = _viewModel.textureId;

    if (kDebugMode) {
      print('[BUILD] barcodeCodes from ViewModel: $barcodeCodes');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: const Text('Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _safePop(_viewModel.getBarcodeCodes()),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SegmentedButton<ActivePipeline>(
              segments: const [
                ButtonSegment(
                  value: ActivePipeline.barcode,
                  label: Text('Barcode'),
                  icon: Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
                ButtonSegment(
                  value: ActivePipeline.ai,
                  label: Text('AI Scan'),
                  icon: Icon(Icons.auto_awesome, color: Colors.white),
                ),
              ],
              selected: {activePipeline},
              onSelectionChanged: (Set<ActivePipeline> selection) {
                _viewModel.switchPipeline(selection.first);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Камера
          if (textureId != null)
            Positioned.fill(child: Texture(textureId: textureId))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Затемнение + область сканирования (только в режиме barcode)
          if (activePipeline == ActivePipeline.barcode &&
              _viewModel.scanRegion != null)
            _buildScanOverlay(screenSize, _viewModel.scanRegion!),

          // UI overlay с результатами
          if (!_isStarting)
            activePipeline == ActivePipeline.barcode
                ? _buildBarcodeUI(barcodeCodes)
                : _buildAIUI(aiResults, screenSize),
        ],
      ),
    );
  }

  // Затемнение с прозрачной областью сканирования
  Widget _buildScanOverlay(Size screenSize, Map<String, double> region) {
    // Конвертируем нормализованные координаты в пиксели (UI-трансформация)
    final scanRect = Rect.fromLTWH(
      region['x']! * screenSize.width,
      region['y']! * screenSize.height,
      region['width']! * screenSize.width,
      region['height']! * screenSize.height,
    );

    return Stack(
      children: [
        // Затемнение с вырезом
        CustomPaint(
          painter: ScanOverlayPainter(
            scanRect: scanRect,
            overlayColor: Colors.black.withOpacity(0.7),
          ),
          size: screenSize,
        ),

        // Рамка области сканирования
        Positioned(
          left: scanRect.left,
          top: scanRect.top,
          width: scanRect.width,
          height: scanRect.height,
          child: _buildScanFrame(),
        ),

        // Текст-подсказка
        Positioned(
          top: scanRect.bottom + 20,
          left: 0,
          right: 0,
          child: const Center(
            child: Text(
              'Place barcode inside the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Анимированная рамка сканирования
  Widget _buildScanFrame() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Уголки
          Positioned(left: -2, top: -2, child: _buildCorner(isTopLeft: true)),
          Positioned(right: -2, top: -2, child: _buildCorner(isTopLeft: false)),
          Positioned(
            left: -2,
            bottom: -2,
            child: _buildCorner(isTopLeft: false),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: _buildCorner(isTopLeft: true),
          ),

          // Анимированная линия сканирования
          Center(child: _buildScanLine()),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool isTopLeft}) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Colors.greenAccent, width: 3),
          left: isTopLeft
              ? const BorderSide(color: Colors.greenAccent, width: 3)
              : BorderSide.none,
          right: !isTopLeft
              ? const BorderSide(color: Colors.greenAccent, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildScanLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -0.5, end: 0.5),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * 200),
          child: Container(
            width: double.infinity,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.greenAccent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
      onEnd: () => setState(() {}), // Зацикливаем анимацию
    );
  }

  Widget _buildBarcodeUI(List<String> codes) {
    final actualCodes = _viewModel.getBarcodeCodes();
    final mode = ref.watch(barcodeModeProvider);

    if (kDebugMode) {
      print('[UI] Building with ViewModel codes: $actualCodes');
    }

    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Счетчик и переключатель режима в одной строке
          Row(
            children: [
              // Выпадающий список слева
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButton<BarcodeMode>(
                  value: mode,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: BarcodeMode.single,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.looks_one,
                            size: 18,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 8),
                          Text('Single'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: BarcodeMode.multi,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.looks_two,
                            size: 18,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 8),
                          Text('Multi'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (newMode) {
                    if (newMode != null) {
                      if (kDebugMode) {
                        print('[UI] Mode changed to: $newMode');
                      }
                      ref.read(barcodeModeProvider.notifier).state = newMode;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Счетчик справа
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isStarting
                        ? 'Starting camera...'
                        : mode == BarcodeMode.single
                        ? codes.isEmpty
                              ? 'Point at a barcode'
                              : 'Scanned: ${codes.length} code'
                        : 'Scanned: ${codes.length}/${AppLimits.barcodeMaxBatchSize}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ВСЕГДА показываем кнопку если есть коды
          if (actualCodes.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actualCodes
                  .map(
                    (code) => Chip(
                      label: Text(
                        code.length > 20 ? '${code.substring(0, 20)}...' : code,
                      ),
                      backgroundColor: Colors.white,
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: mode == BarcodeMode.multi
                          ? () => _removeCode(code)
                          : null,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('FINISH (${actualCodes.length})'),
            ),
          ] else ...[
            // Временная отладка - показываем что кодов нет
            if (!_isStarting)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withOpacity(0.5),
                child: Text(
                  'DEBUG: No codes in UI (state has ${actualCodes.length})',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _removeCode(String code) {
    ref.read(barcodeStateProvider.notifier).removeCode(code);
  }

  Widget _buildProductListItem(DetectionBox detection) {
    // Получаем название класса из ProductClass enum
    final productClass = ProductClass.fromId(detection.classId);
    String title;

    if (detection.skuId != null && detection.skuId != -1) {
      // Если есть SKU - показываем его
      title = 'SKU: ${detection.skuId}';
    } else {
      // Используем displayName из ProductClass
      title = productClass.displayName;
    }

    final color = detection.confidence > 0.7
        ? Colors.green
        : detection.confidence > 0.5
        ? Colors.orange
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white)),
          ),
          Text(
            '${(detection.confidence * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAIUI(AIResult? results, Size screenSize) {
    if (results == null) {
      return const Positioned(
        bottom: 40,
        left: 20,
        right: 20,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // отладочка
    if (kDebugMode) {
      print('[AI_UI] Total detections: ${results.detections.length}');
    }
    for (var d in results.detections) {
      if (kDebugMode) {
        print('[AI_UI]   - conf: ${d.confidence}, skuId: ${d.skuId}');
      }
    }

    // Только уверенные детекции, максимум 5? - в нативке изменил
    final detectionsToShow = results.detections
        .where((d) => d.confidence > 0.2)
        .take(10)
        .toList();

    if (kDebugMode) {
      print('[AI_UI] Showing ${detectionsToShow.length} boxes');
    }
    // оптимизация: RepaintBoundary
    return RepaintBoundary(
      child: Stack(
        children: [
          // оптимизация: ListView.builder для списка
          ...detectionsToShow.map(
            (detection) => _buildDetectionBox(detection, screenSize),
          ),

          // Нижняя панель
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'AI Mode: ${detectionsToShow.length} products detected',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                if (detectionsToShow.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: screenSize.height * 0.3,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: detectionsToShow.length,
                      itemBuilder: (context, index) {
                        final d = detectionsToShow[index];
                        return _buildProductListItem(d);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //в отдельные методы для лучшей производительности
  Widget _buildDetectionBox(DetectionBox detection, Size screenSize) {
    final left = detection.x * screenSize.width;
    final top = detection.y * screenSize.height;
    final width = detection.width * screenSize.width;
    final height = detection.height * screenSize.height;

    final color = detection.confidence > 0.7
        ? Colors.green
        : detection.confidence > 0.5
        ? Colors.orange
        : Colors.red;

    // Наконец тто Получаем название класса
    final productClass = ProductClass.fromId(detection.classId);
    final label = detection.skuId != null && detection.skuId != -1
        ? 'SKU: ${detection.skuId} (${(detection.confidence * 100).toInt()}%)'
        : '${productClass.displayName} (${(detection.confidence * 100).toInt()}%)';

    return Positioned(
      left: left,
      top: top,
      child: RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -25,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Кастомный Painter для затемнения с вырезом
class ScanOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final Color overlayColor;

  ScanOverlayPainter({required this.scanRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Рисуем затемнение через Path с вырезом
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
