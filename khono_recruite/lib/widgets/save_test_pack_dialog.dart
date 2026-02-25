import 'package:flutter/material.dart';
import 'custom_textfield.dart';

/// Dialog to create or edit a test pack (name, category, description, questions).
/// Returns a map with keys: name, category, description, questions (list).
/// Users can add, edit, and remove questions inline.
class SaveTestPackDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialQuestions;
  final String? initialName;
  final String? initialCategory;
  final String? initialDescription;

  const SaveTestPackDialog({
    super.key,
    required this.initialQuestions,
    this.initialName,
    this.initialCategory,
    this.initialDescription,
  });

  @override
  State<SaveTestPackDialog> createState() => _SaveTestPackDialogState();
}

class _SaveTestPackDialogState extends State<SaveTestPackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _category;

  /// Mutable list: each item has 'question', 'options' (List<String>), 'answer' (int 0-3), 'weight' (num).
  late List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _category = widget.initialCategory ?? 'technical';
    _questions = widget.initialQuestions.map((q) {
      final opts = (q['options'] is List)
          ? List<String>.from((q['options'] as List).map((e) => e.toString()))
          : <String>['', '', '', ''];
      while (opts.length < 4) opts.add('');
      return <String, dynamic>{
        'question': (q['question_text'] ?? q['question'] ?? '').toString(),
        'options': opts.take(4).toList(),
        'answer': (q['correct_option'] ?? q['correct_answer'] ?? q['answer'] ?? 0) is num
            ? ((q['correct_option'] ?? q['correct_answer'] ?? q['answer'] ?? 0) as num).toInt()
            : 0,
        'weight': (q['weight'] ?? 1) is num ? (q['weight'] as num).toInt() : 1,
      };
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'question': '',
        'options': ['', '', '', ''],
        'answer': 0,
        'weight': 1,
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _submit() {
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }
    final empty = _questions.indexWhere((q) =>
        (q['question'] ?? '').toString().trim().isEmpty);
    if (empty >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Question ${empty + 1} text is required')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final questions = _questions.map((q) {
        final opts = q['options'] is List
            ? List<String>.from((q['options'] as List).map((e) => e.toString()))
            : <String>['', '', '', ''];
        while (opts.length < 4) opts.add('');
        return <String, dynamic>{
          'question_text': (q['question'] ?? '').toString(),
          'options': opts.take(4).toList(),
          'correct_option': (q['answer'] ?? q['correct_option'] ?? 0) is num
              ? ((q['answer'] ?? q['correct_option'] ?? 0) as num).toInt()
              : 0,
          'weight': (q['weight'] ?? 1) is num ? (q['weight'] as num).toInt() : 1,
        };
      }).toList();

      Navigator.of(context).pop(<String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _category,
        'description': _descriptionController.text.trim(),
        'questions': questions,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Save as Test Pack'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pack name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'technical', child: Text('Technical')),
                  DropdownMenuItem(
                      value: 'role-specific', child: Text('Role-specific')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions (${_questions.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Add question'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _questions.length,
                  itemBuilder: (_, index) {
                    final q = _questions[index];
                    return _buildQuestionCard(context, index, q, isDark);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
      BuildContext context, int index, Map<String, dynamic> q, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: (isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                  tooltip: 'Remove question',
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: 'Question text',
              initialValue: q['question']?.toString() ?? '',
              hintText: 'Enter question',
              maxLines: 2,
              onChanged: (v) => q['question'] = v,
            ),
            const SizedBox(height: 8),
            Text(
              'Options (mark correct with ✓)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(4, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${String.fromCharCode(65 + i)}.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: (q['options'] as List?)?[i]?.toString() ?? '',
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) {
                          final opts = List<String>.from(q['options'] ?? ['', '', '', '']);
                          while (opts.length <= i) opts.add('');
                          opts[i] = v;
                          q['options'] = opts;
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        q['answer'] == i ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: q['answer'] == i ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                      onPressed: () => setState(() => q['answer'] = i),
                      tooltip: 'Correct answer',
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Weight:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    initialValue: (q['weight'] ?? 1).toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    onChanged: (v) => q['weight'] = int.tryParse(v) ?? 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
