import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  final int? maxLength;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;
  final Color? backgroundColor;
  final Color? textColor;
  final bool obscureText;
  final TextAlign? textAlign;
  final TextStyle? style;

  final Color? labelColor;
  final Color? borderColor;

  final InputBorder? border;

  // ⭐ NEW: ADD THIS
  final Widget? suffixIcon;

  const CustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText = '',
    this.inputType = TextInputType.text,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.validator,
    this.backgroundColor,
    this.textColor,
    this.obscureText = false,
    this.textAlign,
    this.style,
    this.labelColor,
    this.borderColor,
    this.border,

    // ⭐ NEW PARAMETER
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ??
            const Color.fromARGB(0, 0, 0, 0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: border == null
            ? Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        keyboardType: inputType,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        validator: validator,
        obscureText: obscureText,
        textAlign: textAlign ?? TextAlign.start,
        style: style ??
            TextStyle(
              color: textColor ?? Colors.white,
            ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: labelColor ?? textColor?.withValues(alpha: 0.7) ?? Colors.white70,
          ),
          hintText: hintText.isNotEmpty ? hintText : null,
          hintStyle: TextStyle(
            color: textColor?.withValues(alpha: 0.5) ?? Colors.white54,
          ),

          // ⭐ Apply border from parameter
          border: border,
          enabledBorder: border,
          focusedBorder: border,

          // ⭐ NEW: add suffixIcon here
          suffixIcon: suffixIcon,

          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
