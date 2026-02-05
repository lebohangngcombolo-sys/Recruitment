import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final double? blur;
  final double? opacity;
  final Gradient? gradient; // Add optional gradient

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur,
    this.opacity,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: gradient == null
            ? Colors.white.withValues(alpha: opacity ?? 0.15)
            : null, // Only use color if gradient is not set
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: blur ?? 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
