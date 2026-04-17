import 'package:flutter_riverpod/legacy.dart';

class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final int? skuId;
  final int classId;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    this.skuId,
    required this.classId,
  });
}

class AIResult {
  final List<DetectionBox> detections;
  final DateTime timestamp;

  AIResult({required this.detections, required this.timestamp});

  factory AIResult.fromNative(dynamic event) {
    final List<dynamic> data = event as List<dynamic>;
    final detections = data.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return DetectionBox(
        x: (map['x'] as num).toDouble(),
        y: (map['y'] as num).toDouble(),
        width: (map['width'] as num).toDouble(),
        height: (map['height'] as num).toDouble(),
        confidence: (map['confidence'] as num).toDouble(),
        skuId: map['skuId'] != -1 ? map['skuId'] as int : null,
        classId: map['classId'] as int? ?? 0,
      );
    }).toList();

    return AIResult(detections: detections, timestamp: DateTime.now());
  }
}


class AINotifier extends StateNotifier<AIResult?> {
  AINotifier() : super(null);

  void updateResult(AIResult result) {
    state = result;
  }

  void reset() {
    state = null;
  }
}

final aiStateProvider = StateNotifierProvider<AINotifier, AIResult?>((ref) {
  return AINotifier();
});
