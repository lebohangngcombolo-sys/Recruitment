import 'package:flutter/material.dart';

class WeightingConfigurationWidget extends StatelessWidget {
  final Map<String, int> weightings;
  final ValueChanged<Map<String, int>> onChanged;
  final String? errorText;

  const WeightingConfigurationWidget({
    super.key,
    required this.weightings,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final total = weightings.values.fold<int>(0, (sum, v) => sum + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSlider(
          context,
          label: "CV",
          value: weightings["cv"] ?? 0,
          onChanged: (value) => _updateWeighting("cv", value),
        ),
        _buildSlider(
          context,
          label: "Assessment",
          value: weightings["assessment"] ?? 0,
          onChanged: (value) => _updateWeighting("assessment", value),
        ),
        _buildSlider(
          context,
          label: "Interview",
          value: weightings["interview"] ?? 0,
          onChanged: (value) => _updateWeighting("interview", value),
        ),
        _buildSlider(
          context,
          label: "References",
          value: weightings["references"] ?? 0,
          onChanged: (value) => _updateWeighting("references", value),
        ),
        const SizedBox(height: 8),
        Text(
          "Total: $total%",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlider(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label: $value%"),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: "$value",
          onChanged: (val) => onChanged(val.round()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _updateWeighting(String key, int value) {
    final updated = Map<String, int>.from(weightings);
    updated[key] = value;
    onChanged(updated);
  }
}
