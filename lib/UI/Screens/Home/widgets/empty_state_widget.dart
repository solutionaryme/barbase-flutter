// lib/ui/screens/home/widgets/empty_state_widget.dart
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/icons/empty.png',
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.inventory_2_outlined,
                size: 120,
                color: Colors.grey.shade400,
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the camera button to scan barcodes',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
