import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  DateTime? _selectedDate;

  // Contract type options
  final List<String> _contractTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Temporary',
    'Internship',
    'Remote',
    'Hybrid'
  ];

  // Common work locations
  final List<String> _commonLocations = [
    'Remote',
    'On-site',
    'Hybrid',
    'New York, NY',
    'San Francisco, CA',
    'London, UK',
    'Singapore',
    'Tokyo, Japan'
  ];

  // Common allowance types
  final List<String> _allowanceTypes = [
    'Housing Allowance',
    'Transportation Allowance',
    'Meal Allowance',
    'Travel Allowance',
    'Education Allowance',
    'Health Allowance',
    'Communication Allowance',
    'Entertainment Allowance',
    'Other Allowance'
  ];

  // Common bonus types
  final List<String> _bonusTypes = [
    'Signing Bonus',
    'Performance Bonus',
    'Annual Bonus',
    'Quarterly Bonus',
    'Retention Bonus',
    'Referral Bonus',
    'Project Bonus',
    'Holiday Bonus',
    'Other Bonus'
  ];

  @override
  void initState() {
    super.initState();
    // Set default start date to today + 2 weeks
    _selectedDate = DateTime.now().add(const Duration(days: 14));
    _startDateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Draft Offer Letter',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSubmitting ? null : _submitDraft,
            tooltip: 'Save Draft',
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Saving Draft...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCandidateInfo(),
                    const SizedBox(height: 24),
                    _buildSalarySection(),
                    const SizedBox(height: 24),
                    _buildAllowancesSection(),
                    const SizedBox(height: 24),
                    _buildBonusesSection(),
                    const SizedBox(height: 24),
                    _buildContractDetails(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCandidateInfo() {
    final appliedDate = widget.application.appliedDate;
    final appliedDateStr = appliedDate != null
        ? DateFormat('MMM dd, yyyy').format(appliedDate.toLocal())
        : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.application.candidateName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.application.jobTitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: ${widget.application.id.toString()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoItem(
                    Icons.calendar_today, 'Applied Date', appliedDateStr),
                const SizedBox(width: 24),
                _buildInfoItem(Icons.access_time, 'Status', 'Draft'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Compensation Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _baseSalaryController,
              decoration: InputDecoration(
                labelText: 'Base Salary',
                hintText: 'Enter annual salary',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: 'per year',
                suffixStyle: TextStyle(color: Colors.grey.shade600),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter base salary';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid amount';
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Allowances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addAllowance,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Allowance'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (allowances.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No allowances added',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add housing, transportation, or other allowances',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (allowances.isNotEmpty) ...[
              ...allowances.entries.map((entry) => _buildAllowanceItem(entry)),
              const SizedBox(height: 8),
              Text(
                'Total Allowances: \$${allowances.values.fold(0.0, (sum, value) => sum + value).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllowanceItem(MapEntry<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          entry.key,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Monthly allowance',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${entry.value.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeAllowance(entry.key),
              color: Colors.grey.shade500,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusesSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.card_giftcard_outlined,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Bonuses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _addBonus,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Bonus'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bonuses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No bonuses added',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add performance, signing, or annual bonuses',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (bonuses.isNotEmpty) ...[
              ...bonuses.entries.map((entry) => _buildBonusItem(entry)),
              const SizedBox(height: 8),
              Text(
                'Total Bonuses: \$${bonuses.values.fold(0.0, (sum, value) => sum + value).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBonusItem(MapEntry<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.card_giftcard_outlined,
            color: Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          entry.key,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'One-time bonus',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${entry.value.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeBonus(entry.key),
              color: Colors.grey.shade500,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractDetails() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Contract Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _contractTypeController.text.isEmpty
                  ? null
                  : _contractTypeController.text,
              decoration: InputDecoration(
                labelText: 'Contract Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.work_outline),
              ),
              items: _contractTypes.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _contractTypeController.text = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select contract type';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Start Date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () => _selectDate(context),
                ),
              ),
              onTap: () => _selectDate(context),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select start date';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _workLocationController.text.isEmpty
                  ? null
                  : _workLocationController.text,
              decoration: InputDecoration(
                labelText: 'Work Location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              items: _commonLocations.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _workLocationController.text = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select work location';
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.note_outlined,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Additional Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter any additional terms, benefits, or notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitDraft,
            icon: const Icon(Icons.save, size: 22),
            label: const Text(
              'Save Draft',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addAllowance() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddItemDialog(
        title: 'Add Allowance',
        label1: 'Allowance Name',
        label2: 'Monthly Amount (\$)',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: Colors.green,
        dropdownItems: _allowanceTypes,
        allowCustomInput: true,
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
        icon: Icons.card_giftcard_outlined,
        iconColor: Colors.orange,
        dropdownItems: _bonusTypes,
        allowCustomInput: true,
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        Navigator.pop(context, offer);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
  final IconData icon;
  final Color iconColor;
  final List<String> dropdownItems;
  final bool allowCustomInput;

  const _AddItemDialog({
    required this.title,
    required this.label1,
    required this.label2,
    this.icon = Icons.add,
    this.iconColor = Colors.blue,
    this.dropdownItems = const [],
    this.allowCustomInput = false,
  });

  @override
  __AddItemDialogState createState() => __AddItemDialogState();
}

class __AddItemDialogState extends State<_AddItemDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedItem;
  bool _showCustomInput = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.dropdownItems.isNotEmpty && !_showCustomInput)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedItem,
                    decoration: InputDecoration(
                      labelText: widget.label1,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: widget.allowCustomInput
                          ? IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                setState(() {
                                  _showCustomInput = true;
                                });
                              },
                              tooltip: 'Custom Input',
                            )
                          : null,
                    ),
                    items: widget.dropdownItems.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedItem = value;
                        _nameController.text = value ?? '';
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select or enter a value';
                      }
                      return null;
                    },
                  ),
                  if (widget.allowCustomInput)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showCustomInput = true;
                              });
                            },
                            child: const Text('Enter Custom'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (_showCustomInput || widget.dropdownItems.isEmpty)
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: widget.label1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: widget.dropdownItems.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.arrow_drop_down),
                          onPressed: () {
                            setState(() {
                              _showCustomInput = false;
                            });
                          },
                          tooltip: 'Select from list',
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: widget.label2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money_outlined),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.isNotEmpty
                        ? _nameController.text
                        : _selectedItem;

                    if (name != null &&
                        name.isNotEmpty &&
                        _amountController.text.isNotEmpty &&
                        double.tryParse(_amountController.text) != null) {
                      Navigator.pop(context, {
                        'name': name,
                        'amount': double.parse(_amountController.text),
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
