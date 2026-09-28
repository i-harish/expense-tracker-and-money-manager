import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/services/financial_service.dart';
import '../../../theme/app_theme.dart';

class TransactionFormDialog extends StatefulWidget {
  final FinancialService financialService;
  final AccountRepository accountRepository;

  const TransactionFormDialog({
    super.key,
    required this.financialService,
    required this.accountRepository,
  });

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  TransactionType _selectedType = TransactionType.expense;
  int? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  List<Account> _activeAccounts = [];
  bool _isLoadingAccounts = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.accountRepository.getActiveAccounts();
      if (mounted) {
        setState(() {
          _activeAccounts = accounts;
          if (accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
          }
          _isLoadingAccounts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an account'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();

    try {
      if (_selectedType == TransactionType.income) {
        await widget.financialService.recordIncome(
          accountId: _selectedAccountId!,
          amount: amount,
          description: description.isEmpty ? null : description,
          transactionDate: _selectedDate,
        );
      } else {
        await widget.financialService.recordExpense(
          accountId: _selectedAccountId!,
          amount: amount,
          description: description.isEmpty ? null : description,
          transactionDate: _selectedDate,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedType == TransactionType.income
                  ? 'Income recorded successfully'
                  : 'Expense recorded successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Transaction',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Transaction Type Segmented Button
                const Text(
                  'Transaction Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_downward,
                          size: 16, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_upward,
                          size: 16, color: Color(0xFF16A34A)),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Account Selection
                const Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (_isLoadingAccounts)
                  const Center(child: CircularProgressIndicator())
                else if (_activeAccounts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      'No active accounts found. Please add an account first.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    items: _activeAccounts.map((account) {
                      return DropdownMenuItem<int>(
                        value: account.id,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(account.name),
                            const SizedBox(width: 8),
                            Text(
                              '(${CurrencyFormatter.format(account.balance, currency: account.currency)})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAccountId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Account is required';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                // Amount
                const Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Enter a valid number';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description (Optional)
                const Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Salary, Groceries, Electricity Bill',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date
                const Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormatter.format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Transaction'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
