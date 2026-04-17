// lib/ui/widgets/error_banner.dart
import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  
  const ErrorBanner({required this.message, required this.onClose});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Image.asset('assets/icons/alert.png', width: 24, height: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700))),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red.shade700),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}