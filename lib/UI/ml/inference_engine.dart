// lib/ui/ml/inference_engine.dart
class InferenceEngine {
  static final InferenceEngine _instance = InferenceEngine._internal();

  factory InferenceEngine() => _instance;

  InferenceEngine._internal();

  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
  }

  Future<void> stop() async {
    _running = false;
  }

  Future<void> processFrame(dynamic frame) async {
    if (!_running) return;

    // TODO: YOLO + embedding pipeline
  }
}