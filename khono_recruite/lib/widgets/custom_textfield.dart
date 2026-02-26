import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String hintText;
  final TextInputType inputType;
  final int maxLines;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final Color? labelColor;
  final Color? hintColor;
  final Color? iconColor;
  final bool? obscureText;
  final bool enabled;
  final bool readOnly;
  final bool showCursor;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double borderRadius;
  final double borderWidth;
  final double focusedBorderWidth;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool expands;
  final int? maxLength;
  final bool showCounter;
  final String? counterText;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final TextStyle? errorStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final bool enableInteractiveSelection;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText = '',
    this.inputType = TextInputType.text,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.focusedBorderColor,
    this.labelColor,
    this.hintColor,
    this.iconColor,
    this.obscureText,
    this.enabled = true,
    this.readOnly = false,
    this.showCursor = true,
    this.prefixIcon,
    this.suffixIcon,
    this.borderRadius = 12,
    this.borderWidth = 1.5,
    this.focusedBorderWidth = 2,
    this.contentPadding,
    this.margin,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.expands = false,
    this.maxLength,
    this.showCounter = false,
    this.counterText,
    this.labelStyle,
    this.hintStyle,
    this.errorStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.enableInteractiveSelection = true,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors based on theme
    final defaultBackgroundColor =
        isDark ? Colors.grey.shade900.withValues(alpha: 0.7) : Colors.white;

    final defaultTextColor = isDark ? Colors.white : Colors.black87;
    final defaultLabelColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final defaultHintColor =
        isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final defaultBorderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final defaultFocusedBorderColor = theme.primaryColor;
    final defaultIconColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with optional required indicator
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  Text(
                    label,
                    style: labelStyle ??
                        TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: labelColor ?? defaultLabelColor,
                          letterSpacing: 0.3,
                        ),
                  ),
                  if (validator != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '*',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          TextFormField(
            controller: controller,
            initialValue: initialValue,
            keyboardType: inputType,
            maxLines: maxLines,
            minLines: 1,
            expands: expands,
            maxLength: maxLength,
            textInputAction: textInputAction,
            focusNode: focusNode,
            autofocus: autofocus,
            readOnly: readOnly,
            showCursor: showCursor,
            enabled: enabled,
            obscureText: obscureText ?? false,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            textAlign: textAlign,
            textAlignVertical: textAlignVertical,
            enableInteractiveSelection: enableInteractiveSelection,
            textCapitalization: textCapitalization,
            style: TextStyle(
              color: (textColor ?? defaultTextColor).withValues(alpha: 1.0),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: hintStyle ??
                  TextStyle(
                    color: hintColor ?? defaultHintColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
              prefixIcon: prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        color: iconColor ?? defaultIconColor,
                        size: 20,
                      ),
                      child: prefixIcon!,
                    )
                  : null,
              suffixIcon: suffixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        color: iconColor ?? defaultIconColor,
                        size: 20,
                      ),
                      child: suffixIcon!,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: borderColor ?? defaultBorderColor,
                  width: borderWidth,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: borderColor ?? defaultBorderColor,
                  width: borderWidth,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: focusedBorderColor ?? defaultFocusedBorderColor,
                  width: focusedBorderWidth,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: BorderSide(
                  color: (borderColor ?? defaultBorderColor)
                      .withValues(alpha: 0.5),
                  width: borderWidth,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 2,
                ),
              ),
              filled: backgroundColor != null,
              fillColor: backgroundColor ?? defaultBackgroundColor,
              contentPadding: contentPadding ??
                  EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: maxLines > 1 ? 16 : 14,
                  ),
              isDense: true,
              counterText: showCounter ? null : '',
              errorStyle: errorStyle ??
                  const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
              errorMaxLines: 2,
              alignLabelWithHint: maxLines > 1,
            ),
            cursorColor: focusedBorderColor ?? defaultFocusedBorderColor,
            cursorWidth: 1.5,
            cursorRadius: const Radius.circular(2),
          ),

          // Character counter (optional)
          if (maxLength != null && showCounter)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder(
                  valueListenable: controller!,
                  builder: (context, value, child) {
                    final text = value.text;
                    final length = text.length;
                    return Text(
                      counterText ?? '$length/$maxLength',
                      style: TextStyle(
                        fontSize: 12,
                        color: length > maxLength!
                            ? Colors.redAccent
                            : hintColor ?? defaultHintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Static method to create login fields with specified styling
  static Widget buildLoginFields({
    required TextEditingController emailController,
    required TextEditingController passwordController,
  }) {
    return Column(
      children: [
        CustomTextField(
          label: "Email",
          controller: emailController,
          inputType: TextInputType.emailAddress,
          backgroundColor: Color(0x33f2f2f2), // #f2f2f2 with 20% opacity
          textColor: Color(0xFFC10D00), // #c10d00
          borderColor: Color(0xFFC10D00), // #c10d00 stroke
        ),
        const SizedBox(height: 12),
        CustomTextField(
          label: "Password",
          controller: passwordController,
          obscureText: true,
          backgroundColor: Color(0x33f2f2f2), // #f2f2f2 with 20% opacity
          textColor: Color(0xFFC10D00), // #c10d00
          borderColor: Color(0xFFC10D00), // #c10d00 stroke
        ),
      ],
    );
  }
}
