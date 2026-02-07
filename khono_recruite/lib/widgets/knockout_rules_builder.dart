import 'package:flutter/material.dart';

class KnockoutRulesBuilder extends StatelessWidget {
  final List<Map<String, dynamic>> rules;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const KnockoutRulesBuilder({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  static const _ruleTypes = [
    "certification",
    "experience",
    "skills",
    "education",
    "location",
    "salary",
  ];

  static const _operators = [">=", ">", "==", "!=", "<", "<="];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rules.length,
          itemBuilder: (context, index) {
            final rule = rules[index];
            final ruleType = _ruleTypes.contains(rule["type"])
                ? rule["type"] as String
                : _ruleTypes.first;
            final ruleOperator = _operators.contains(rule["operator"])
                ? rule["operator"] as String
                : _operators.first;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ruleType,
                            items: _ruleTypes
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                _updateRule(index, {"type": value}),
                            decoration: const InputDecoration(
                              labelText: "Rule Type",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeRule(index),
                          tooltip: "Remove Rule",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: rule["field"]?.toString(),
                      decoration: const InputDecoration(
                        labelText: "Field",
                        hintText: "e.g. years_experience, java_cert",
                      ),
                      onChanged: (value) =>
                          _updateRule(index, {"field": value}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ruleOperator,
                            items: _operators
                                .map((op) => DropdownMenuItem(
                                      value: op,
                                      child: Text(op),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                _updateRule(index, {"operator": value}),
                            decoration: const InputDecoration(
                              labelText: "Operator",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: rule["value"]?.toString(),
                            decoration: const InputDecoration(
                              labelText: "Value",
                            ),
                            onChanged: (value) =>
                                _updateRule(index, {"value": value}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addRule,
          icon: const Icon(Icons.add),
          label: const Text("Add Rule"),
        ),
      ],
    );
  }

  void _addRule() {
    final updated = List<Map<String, dynamic>>.from(rules);
    updated.add({
      "type": _ruleTypes.first,
      "field": "",
      "operator": _operators.first,
      "value": "",
    });
    onChanged(updated);
  }

  void _removeRule(int index) {
    final updated = List<Map<String, dynamic>>.from(rules);
    updated.removeAt(index);
    onChanged(updated);
  }

  void _updateRule(int index, Map<String, dynamic> changes) {
    final updated = List<Map<String, dynamic>>.from(rules);
    final rule = Map<String, dynamic>.from(updated[index]);
    rule.addAll(changes);
    updated[index] = rule;
    onChanged(updated);
  }
}
