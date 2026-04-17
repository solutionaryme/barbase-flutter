// lib/ui/core/widgets/app_loader.dart

import 'dart:ui';

import 'package:flutter/material.dart';

class AppLoader extends StatefulWidget {
  final double size;
  final bool fullscreen;
  final Color? color;

  const AppLoader({
    super.key,
    this.size = 36,
    this.fullscreen = false,
    this.color,
  });

  @override
  State<AppLoader> createState() => _AppLoaderState();

  // Быстрый вызов fullscreen overlay
  static Future<void> show(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) => const AppLoader(fullscreen: true),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _resolveColor(BuildContext context) {
    if (widget.color != null) return widget.color!;

    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  Widget _buildLoader(BuildContext context) {
    final color = _resolveColor(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.fullscreen) {
      return _buildLoader(context);
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: Colors.black.withOpacity(0.2),
        child: Center(child: _buildLoader(context)),
      ),
    );
  }
}
