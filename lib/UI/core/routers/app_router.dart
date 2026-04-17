// lib/core/routers/app_router.dart
import 'package:flutter/material.dart';
import '../../view/camera_view.dart';

class AppRouter {
  static void openCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraView(),
      ),
    );
  }

  static void close(BuildContext context) {
    Navigator.pop(context);
  }
}