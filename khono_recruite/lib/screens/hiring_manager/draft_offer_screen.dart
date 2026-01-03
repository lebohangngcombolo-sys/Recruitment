import 'package:flutter/material.dart';
import '../../models/application.dart';
import '../../services/offer_service.dart';

class DraftOfferScreen extends StatefulWidget {
  final Application application;

  const DraftOfferScreen({super.key, required this.application});

  @override
  _DraftOfferScreenState createState() => _DraftOfferScreenState();
}

class _DraftOfferScreenState extends State<DraftOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final OfferService _offerService = OfferService();

  final TextEditingController _baseSalaryController = TextEditingController();
  final TextEditingController _contractTypeController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic> allowances = {};
  Map<String, dynamic> bonuses = {};

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draft Offer Letter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSubmitting ? null : _submitDraft,
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCandidateInfo(),
                    const SizedBox(height: 20),
                    _buildSalarySection(),
                    const SizedBox(height: 20),
                    _buildAllowancesSection(),
                    const SizedBox(height: 20),
                    _buildBonusesSection(),
                    const SizedBox(height: 20),
                    _buildContractDetails(),
                    const SizedBox(height: 20),
                    _buildNotesSection(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCandidateInfo() {
    final appliedDate = widget.application.appliedDate;
    final appliedDateStr = appliedDate != null
        ? '${appliedDate.toLocal().toString().split(' ')[0]}'
        : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Candidate: ${widget.application.candidateName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Position: ${widget.application.jobTitle}'),
            Text('Application ID: ${widget.application.id}'),
            Text('Applied: $appliedDateStr'),
          ],
        ),
      ),
    );
  }

  Widget _buildSalarySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compensation Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _baseSalaryController,
              decoration: const InputDecoration(
                labelText: 'Base Salary (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter base salary';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowancesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Allowances',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addAllowance,
                ),
              ],
            ),
            if (allowances.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No allowances added',
                  style: TextStyle(
                      color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ...allowances.entries.map((entry) => _buildAllowanceItem(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowanceItem(MapEntry<String, dynamic> entry) {
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet),
      title: Text(entry.key),
      subtitle: Text('\$${entry.value.toStringAsFixed(2)}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _removeAllowance(entry.key),
      ),
    );
  }

  Widget _buildBonusesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bonuses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addBonus,
                ),
              ],
            ),
            if (bonuses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No bonuses added',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ...bonuses.entries.map((entry) => _buildBonusItem(entry)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusItem(MapEntry<String, dynamic> entry) {
    return ListTile(
      leading: const Icon(Icons.card_giftcard),
      title: Text(entry.key),
      subtitle: Text('\$${entry.value.toStringAsFixed(2)}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _removeBonus(entry.key),
      ),
    );
  }

  Widget _buildContractDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contract Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contractTypeController,
              decoration: const InputDecoration(
                labelText: 'Contract Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
                hintText: 'e.g., Full-time, Part-time, Contract',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter contract type';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _startDateController,
              decoration: const InputDecoration(
                labelText: 'Start Date (YYYY-MM-DD)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
                hintText: '2024-01-15',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter start date';
                }
                if (DateTime.tryParse(value) == null) {
                  return 'Please enter a valid date (YYYY-MM-DD)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workLocationController,
              decoration: const InputDecoration(
                labelText: 'Work Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                hintText: 'e.g., New York, NY or Remote',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter work location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Notes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter any additional terms, benefits, or notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitDraft,
        icon: const Icon(Icons.save),
        label: const Text(
          'Save Draft',
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _addAllowance() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(
        title: 'Add Allowance',
        label1: 'Allowance Name',
        label2: 'Amount (\$)',
      ),
    );

    if (result != null) {
      setState(() {
        allowances[result['name']] = result['amount'];
      });
    }
  }

  void _addBonus() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(
        title: 'Add Bonus',
        label1: 'Bonus Name',
        label2: 'Amount (\$)',
      ),
    );

    if (result != null) {
      setState(() {
        bonuses[result['name']] = result['amount'];
      });
    }
  }

  void _removeAllowance(String key) {
    setState(() {
      allowances.remove(key);
    });
  }

  void _removeBonus(String key) {
    setState(() {
      bonuses.remove(key);
    });
  }

  Future<void> _submitDraft() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final offerData = {
          'application_id': widget.application.id,
          'base_salary': double.parse(_baseSalaryController.text),
          'allowances': allowances,
          'bonuses': bonuses,
          'contract_type': _contractTypeController.text,
          'start_date': _startDateController.text,
          'work_location': _workLocationController.text,
          'notes':
              _notesController.text.isNotEmpty ? _notesController.text : null,
        };

        final offer = await _offerService.draftOffer(offerData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer #${offer.id} drafted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, offer);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _AddItemDialog extends StatefulWidget {
  final String title;
  final String label1;
  final String label2;

  const _AddItemDialog({
    required this.title,
    required this.label1,
    required this.label2,
  });

  @override
  __AddItemDialogState createState() => __AddItemDialogState();
}

class __AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: widget.label1,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: widget.label2,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
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
            if (_nameController.text.isNotEmpty &&
                _amountController.text.isNotEmpty &&
                double.tryParse(_amountController.text) != null) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'amount': double.parse(_amountController.text),
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
