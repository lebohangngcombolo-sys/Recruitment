import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../constants/brand_tokens.dart';
import '../../widgets/themed_dialog.dart';
import '../../widgets/themed_surface_card.dart';

// Mock classes for testing
class TestPack {
  final int id;
  final String name;
  final String category;
  final int questionCount;
  final String description;
  final List<Map<String, dynamic>> questions;

  TestPack({
    required this.id,
    required this.name,
    required this.category,
    required this.questionCount,
    required this.description,
    this.questions = const [],
  });
}

class TestPackService {
  Future<List<TestPack>> getTestPacks() async {
    // Mock data for testing
    return [
      TestPack(
        id: 1,
        name: 'JavaScript Basics',
        category: 'Programming',
        questionCount: 2,
        description: 'Basic JavaScript concepts and syntax',
        questions: [
          {
            'question_text': 'What is a variable?',
            'options': [
              'Container for data',
              'A function',
              'A loop',
              'A condition'
            ],
            'correct_answer': 0,
            'weight': 1,
          },
          {
            'question_text': 'What is a function?',
            'options': [
              'A variable',
              'Reusable code block',
              'A loop',
              'An array'
            ],
            'correct_answer': 1,
            'weight': 1,
          },
        ],
      ),
      TestPack(
        id: 2,
        name: 'Python Fundamentals',
        category: 'Programming',
        questionCount: 2,
        description: 'Core Python programming concepts',
        questions: [
          {
            'question_text': 'What is Python?',
            'options': [
              'Database',
              'Programming language',
              'Framework',
              'Library'
            ],
            'correct_answer': 1,
            'weight': 1,
          },
          {
            'question_text': 'What are data types?',
            'options': [
              'Functions',
              'Variables',
              'Classifications of data',
              'Loops'
            ],
            'correct_answer': 2,
            'weight': 1,
          },
        ],
      ),
    ];
  }

  Future<void> deleteTestPack(int id) async {
    // Mock delete operation
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> createTestPack(Map<String, dynamic> data) async {
    // Mock create operation
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> updateTestPack(int id, Map<String, dynamic> data) async {
    // Mock update operation
    await Future.delayed(const Duration(seconds: 1));
  }
}

class SaveTestPackDialog extends StatelessWidget {
  final TestPack? pack;
  final List<Map<String, dynamic>>? initialQuestions;
  final String? initialName;
  final String? initialCategory;
  final String? initialDescription;

  const SaveTestPackDialog({
    super.key,
    this.pack,
    this.initialQuestions,
    this.initialName,
    this.initialCategory,
    this.initialDescription,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedDialog(
      title: pack == null ? 'Add Test Pack' : 'Edit Test Pack',
      subtitle: 'Configure your test pack settings',
      icon: Icon(pack == null ? Icons.add : Icons.edit,
          color: BrandTokens.primary),
      iconColor: BrandTokens.primary,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Test Pack Name',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: initialName),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: initialCategory),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            controller: TextEditingController(text: initialDescription),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Return mock data for testing
            Navigator.pop(context, {
              'name': initialName ?? 'Test Pack',
              'category': initialCategory ?? 'General',
              'description': initialDescription ?? 'Test description',
              'questions': initialQuestions ?? [],
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandTokens.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(pack == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

class TestPackManagementScreen extends StatefulWidget {
  const TestPackManagementScreen({super.key});

  @override
  State<TestPackManagementScreen> createState() =>
      _TestPackManagementScreenState();
}

class _TestPackManagementScreenState extends State<TestPackManagementScreen> {
  final TestPackService _service = TestPackService();
  List<TestPack> _packs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getTestPacks();
      if (mounted) setState(() => _packs = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(TestPack pack) async {
    final confirm = await ThemedAlertDialog.showConfirm(
      context: context,
      title: 'Delete test pack',
      subtitle:
          'Delete "${pack.name}"? Existing jobs linked to it will keep using its questions until you change them.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      iconData: Icons.delete_outline,
      iconColor: Colors.red,
    );
    if (confirm != true || !mounted) return;
    try {
      await _service.deleteTestPack(pack.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test pack deleted')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const SaveTestPackDialog(initialQuestions: []),
    );
    if (result == null || !mounted) return;
    try {
      await _service.createTestPack(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test pack created')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _edit(TestPack pack) async {
    final questions = pack.questions.map((q) {
      final opts = (q['options'] is List)
          ? List<String>.from((q['options'] as List).map((e) => e.toString()))
          : <String>['', '', '', ''];
      while (opts.length < 4) opts.add('');
      return <String, dynamic>{
        'question': q['question_text'] ?? q['question'] ?? '',
        'options': opts,
        'answer': q['correct_option'] ?? q['correct_answer'] ?? 0,
        'weight': q['weight'] ?? 1,
      };
    }).toList();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SaveTestPackDialog(
        initialQuestions: questions,
        initialName: pack.name,
        initialCategory: pack.category,
        initialDescription: pack.description,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _service.updateTestPack(pack.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test pack updated')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Test Packs',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Add test pack'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_packs.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No test packs yet. Create one or add questions in a job and use "Save as Test Pack".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.grey.shade400
                          : Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _packs.length,
                  itemBuilder: (_, i) {
                    final pack = _packs[i];
                    return ThemedSurfaceCard(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          pack.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${pack.category} · ${pack.questionCount} questions\n${pack.description.isEmpty ? "No description" : pack.description}',
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey.shade400
                                : Colors.black54,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _edit(pack),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _delete(pack),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
