import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CircleIcon extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;

  const CircleIcon({
    super.key,
    this.icon,
    this.imageAsset,
    this.backgroundColor = Colors.white,
    this.iconColor = AppColors.primary,
    this.size = 34,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon != null
            ? Icon(icon, color: iconColor, size: iconSize)
            : (imageAsset != null
                ? Image.asset(imageAsset!, width: iconSize, height: iconSize, color: iconColor)
                : const SizedBox.shrink()),
      ),
    );
  }
}
