# BarBase — Barcode Scanner

Native barcode scanner for Flutter apps.

## Features

- **Fast barcode scanning** — native AVFoundation, 15+ FPS
- **Batch mode** — scan multiple codes in one session
- **Product lookup** — search by barcode in local database
- **Scan history** — track product visits with timestamps

## Production version

The production build includes **AI visual search** with:
- YOLOv8 object detection
- EfficientNet embeddings
- HNSW vector search

AI models run on-device via TensorFlow Lite.

## Tech Stack

- Flutter 3.x + Riverpod
- iOS native (AVFoundation, Vision)
- Isar — local database
- TensorFlow Lite / ONNX Runtime

## Getting Started

```bash
git clone https://github.com/yourusername/bar_base.git
cd bar_base
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Build
```bash
flutter build ios --release
```
## LICENCE
--------------------------------------------------