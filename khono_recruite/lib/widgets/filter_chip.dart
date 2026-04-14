import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool)? onSelected;
  final Color? backgroundColor;
  final Color? selectedColor;
  final IconData? icon;
  final Widget? avatar;

  const FilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.backgroundColor,
    this.selectedColor,
    this.icon,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return GestureDetector(
      onTap: () => onSelected?.call(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFC10D00)
              : themeProvider.isDarkMode
                  ? const Color(0xFF14131E).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFC10D00)
                : themeProvider.isDarkMode
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFFC10D00).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: selected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null) ...[
              avatar!,
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : themeProvider.isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : themeProvider.isDarkMode
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilterChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selectedValue;
  final Function(String?)? onSelected;
  final Map<String, IconData>? icons;
  final Map<String, Widget>? avatars;

  const FilterChipGroup({
    super.key,
    required this.options,
    this.selectedValue,
    this.onSelected,
    this.icons,
    this.avatars,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        return FilterChip(
          label: option,
          selected: selectedValue == option,
          onSelected: (selected) => onSelected?.call(selected ? option : null),
          icon: icons?[option],
          avatar: avatars?[option],
        );
      }).toList(),
    );
  }
}
