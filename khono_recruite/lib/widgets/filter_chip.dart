import 'package:flutter/material.dart';

class FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;
  final Color? backgroundColor;
  final Color? selectedColor;

  const FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: selectedColor ?? Theme.of(context).primaryColor,
      backgroundColor: backgroundColor ?? Colors.grey.shade200,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
