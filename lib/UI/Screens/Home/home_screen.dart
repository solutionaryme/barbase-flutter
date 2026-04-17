// lib/ui/screens/home/home_screen.dart
import 'package:bar_base/UI/Screens/Home/widgets/product_details_sheet.dart';
import 'package:bar_base/UI/core/navigation/app_navigator.dart';
import 'package:bar_base/UI/viewmodel/home_viewmodel.dart';
import 'package:bar_base/UI/widgets/app_loader.dart';
import 'package:bar_base/UI/widgets/error_banner.dart';
import 'package:bar_base/data/models/product.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/empty_state_widget.dart';
import 'widgets/product_list_widget.dart';
import 'widgets/search_bar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isProcessing = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    ref.read(homeViewModelProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    if (_isProcessing) return;
    _isProcessing = true;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // Очистка кэша перед открытием камеры
      ref.read(homeViewModelProvider.notifier).clearScannedCodes();

      final result = await AppNavigator.openCamera(context);

      if (kDebugMode) {
        print('Returned from CameraView with result: ${result.data}');
      }

      if (result.success && result.data.isNotEmpty) {
        // Только добавляем в кэш, НЕ сохраняем в БД
        ref.read(homeViewModelProvider.notifier).addScannedCodes(result.data);

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.data.length} barcode(s) ready to add'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No barcodes were scanned';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No barcodes detected'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Camera error: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Please enter a barcode to search');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // ViewModel для поиска
      final product = await ref
          .read(homeViewModelProvider.notifier)
          .findProductByBarcode(query);

      if (mounted) {
        setState(() => _isLoading = false);

        if (product != null) {
          _showProductDetails(product);
        } else {
          setState(() => _errorMessage = 'Product not found');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Search error: $e';
      });
    }
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ProductDetailsSheet(product: product),
    );
  }

  void _clearError() {
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    final scanResults = ref.watch(homeViewModelProvider);
    final hasError = _errorMessage != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BarBase'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (scanResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(homeViewModelProvider.notifier).clearScannedCodes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All products cleared'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SearchBarWidget(
                  controller: _searchController,
                  onSearch: _search,
                  onCamera: _openCamera,
                ),
                const SizedBox(height: 16),
                if (hasError)
                  ErrorBanner(message: _errorMessage!, onClose: _clearError),
                const SizedBox(height: 24),
                Expanded(
                  child: scanResults.isNotEmpty
                      ? ProductListWidget(barcodes: scanResults)
                      : const EmptyStateWidget(),
                ),
              ],
            ),
          ),
          if (_isLoading) const AppLoader(fullscreen: true),
        ],
      ),
    );
  }
}
