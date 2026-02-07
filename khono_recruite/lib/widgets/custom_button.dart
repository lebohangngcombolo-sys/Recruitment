import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool outlined;
  final bool small;
  final IconData? icon;
  final Color? iconColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final double? elevation;
  final Color? borderColor;
  final bool loading;
  final Color? backgroundColor;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = const Color.fromRGBO(151, 18, 8, 1),
    this.textColor = Colors.white,
    this.outlined = false,
    this.small = false,
    this.icon,
    this.iconColor,
    this.padding,
    this.borderRadius,
    this.elevation,
    this.borderColor,
    this.loading = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || loading;
    final Color buttonColor = backgroundColor ?? color;
    final Color finalTextColor = outlined ? buttonColor : textColor;
    final Color finalIconColor = iconColor ?? finalTextColor;

    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: outlined
            ? Colors.transparent
            : isDisabled
                ? buttonColor.withValues(alpha: 0.5)
                : buttonColor,
        foregroundColor: finalTextColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          side: outlined
              ? BorderSide(
                  color: isDisabled
                      ? buttonColor.withValues(alpha: 0.5)
                      : borderColor ?? buttonColor,
                  width: 2,
                )
              : BorderSide.none,
        ),
        padding: padding ??
            EdgeInsets.symmetric(
              vertical: small ? 8 : 16,
              horizontal: small ? 16 : 24,
            ),
        elevation: elevation ?? (outlined ? 0 : 4),
        shadowColor:
            outlined ? Colors.transparent : buttonColor.withValues(alpha: 0.3),
        textStyle: TextStyle(
          fontSize: small ? 14 : 16,
          fontWeight: small ? FontWeight.w500 : FontWeight.w600,
          letterSpacing: 0.5,
        ),
        minimumSize: Size(
          small ? 80 : 120,
          small ? 36 : 50,
        ),
        maximumSize: small ? const Size(200, 40) : null,
      ),
      child: loading
          ? SizedBox(
              height: small ? 20 : 24,
              width: small ? 20 : 24,
              child: CircularProgressIndicator(
                strokeWidth: small ? 2 : 3,
                valueColor: AlwaysStoppedAnimation<Color>(finalTextColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Padding(
                    padding: EdgeInsets.only(right: small ? 6 : 8),
                    child: Icon(
                      icon,
                      size: small ? 16 : 20,
                      color: finalIconColor,
                    ),
                  ),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: finalTextColor,
                      fontSize: small ? 14 : 16,
                      fontWeight: small ? FontWeight.w500 : FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
    );
  }
}

// Additional button variants for convenience
class ButtonVariants {
  static CustomButton primary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(151, 18, 8, 1), // Primary red
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton secondary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(33, 150, 243, 1), // Blue
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton success({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(46, 125, 50, 1), // Green
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton warning({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(237, 108, 2, 1), // Orange
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton outlinedPrimary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(151, 18, 8, 1),
      outlined: true,
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton outlinedSecondary({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: const Color.fromRGBO(33, 150, 243, 1),
      outlined: true,
      icon: icon,
      small: small,
      loading: loading,
    );
  }

  static CustomButton textButton({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool small = false,
    Color color = Colors.blue,
    bool loading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      color: color,
      outlined: true,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.symmetric(
        vertical: small ? 4 : 8,
        horizontal: small ? 8 : 12,
      ),
      icon: icon,
      small: small,
      loading: loading,
    );
  }
}
