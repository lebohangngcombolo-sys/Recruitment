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
    final cv = weightings["cv"] ?? 0;
    final assessment = weightings["assessment"] ?? 0;
    final total = cv + assessment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSlider(
          context,
          label: "CV",
          value: cv,
          onChanged: (value) => _updateWeighting("cv", value),
        ),
        _buildSlider(
          context,
          label: "Assessment",
          value: assessment,
          onChanged: (value) => _updateWeighting("assessment", value),
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
    // Keep interview and references at 0 for backend; only CV and Assessment are editable
    updated["interview"] = 0;
    updated["references"] = 0;
    onChanged(updated);
  }
}
