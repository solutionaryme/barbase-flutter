// lib/state/camera_providers.dart (оставить только базовое)
import 'package:bar_base/ui/ml/barcode_mode.dart';
import 'package:flutter_riverpod/legacy.dart';

final barcodeModeProvider = StateProvider<BarcodeMode>(
  (ref) => BarcodeMode.single, // default mode = позже фикс!!! не забыть!!!
);
