import 'package:bar_base/UI/viewmodel/storage_viewmodel.dart';
import 'package:bar_base/ui/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/home_screen.dart';
import 'storage/storage_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [HomeScreen(), StorageScreen()],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Обновление при переходе на Storage
          if (index == 1) {
            ref.read(storageViewModelProvider.notifier).loadProducts();
          }
        },
      ),
    );
  }
}
