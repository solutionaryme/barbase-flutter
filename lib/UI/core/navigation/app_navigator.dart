// lib/UI/core/navigation/app_navigator.dart
import 'package:bar_base/UI/view/camera_view.dart';
import 'package:flutter/material.dart';

class NavigationResult {
  final bool success;
  final List<String> data;
  final String? error;

  const NavigationResult({
    required this.success,
    this.data = const [],
    this.error,
  });
}

class AppNavigator {
  static Future<NavigationResult> openCamera(BuildContext context) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraView()),
      );

      if (result is List<String>) {
        return NavigationResult(success: true, data: result);
      }
      return const NavigationResult(success: false, data: []);
    } catch (e) {
      return NavigationResult(success: false, error: e.toString());
    }
  }
}
