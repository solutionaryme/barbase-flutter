import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

// lib/state/riverpod/barcode_state.dart
class BarcodeNotifier extends StateNotifier<List<String>> {
  BarcodeNotifier() : super([]);

  void addCodes(List<String> newCodes) {
    if (kDebugMode) {
      print('[NOTIFIER] Adding codes: $newCodes');
    }
    if (kDebugMode) {
      print('[NOTIFIER] Current state before: $state');
    }

    final existing = Set<String>.from(state);
    final uniqueNew = newCodes
        .where((code) => !existing.contains(code))
        .toList();

    if (uniqueNew.isNotEmpty) {
      state = [...state, ...uniqueNew];
      if (kDebugMode) {
        print('[NOTIFIER] New state: $state');
      }
    } else {
      if (kDebugMode) {
        print('[NOTIFIER] No new codes to add');
      }
    }
  }

  void removeCode(String code) {
    if (kDebugMode) {
      print('[NOTIFIER] Removing code: $code');
    }
    state = state.where((c) => c != code).toList();
  }

  void clear() {
    if (kDebugMode) {
      print('[NOTIFIER] Clearing all codes');
    }
    state = [];
  }

  void reset() {
    state = [];
  }
}

final barcodeStateProvider =
    StateNotifierProvider<BarcodeNotifier, List<String>>((ref) {
      return BarcodeNotifier();
    });
