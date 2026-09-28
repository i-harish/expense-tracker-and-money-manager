import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/accounts.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../theme/app_theme.dart';

class AccountFormDialog extends StatefulWidget {
  final Account? account;
  final AccountRepository repository;

  const AccountFormDialog({
    super.key,
    this.account,
    required this.repository,
  });

  bool get isEditing => account != null;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late AccountType _selectedType;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.account != null
          ? widget.account!.balance.toStringAsFixed(
              widget.account!.balance % 1 == 0 ? 0 : 2)
          : '',
    );
    _selectedType = widget.account?.type ?? AccountType.bank;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.isEditing) {
        await widget.repository.updateAccountDetails(
          id: widget.account!.id,
          name: _nameController.text.trim(),
          type: _selectedType,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account updated successfully')),
          );
        }
      } else {
        final balance = double.parse(_balanceController.text.trim());
        await widget.repository.createAccount(
          name: _nameController.text.trim(),
          type: _selectedType,
          balance: balance,
          currency: 'INR',
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
                    Text(
                      widget.isEditing ? 'Edit Account' : 'Add Account',
                      style: const TextStyle(
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

                // Account Name
                const Text(
                  'Account Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  autofocus: !widget.isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Main Bank, Savings, Cash',
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
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Account name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Account Type
                const Text(
                  'Account Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<AccountType>(
                  initialValue: _selectedType,
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
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AccountType.bank,
                      child: Row(
                        children: [
                          Icon(Icons.account_balance,
                              size: 20, color: AppTheme.primaryColor),
                          SizedBox(width: 10),
                          Text('Bank'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AccountType.savings,
                      child: Row(
                        children: [
                          Icon(Icons.savings,
                              size: 20, color: AppTheme.secondaryColor),
                          SizedBox(width: 10),
                          Text('Savings'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AccountType.cash,
                      child: Row(
                        children: [
                          Icon(Icons.payments,
                              size: 20, color: Color(0xFF16A34A)),
                          SizedBox(width: 10),
                          Text('Cash'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (AccountType? value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Opening Balance (Only shown on Creation)
                if (!widget.isEditing) ...[
                  const Text(
                    'Opening Balance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _balanceController,
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
                        return 'Opening balance is required';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null) {
                        return 'Enter a valid number (e.g. 10000)';
                      }
                      if (parsed < 0) {
                        return 'Opening balance cannot be negative';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Default currency is INR (₹).',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ] else ...[
                  // Non-editable balance info during editing
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(widget.account!.balance,
                              currency: widget.account!.currency),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Balance cannot be edited directly.',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Buttons
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
                          : Text(widget.isEditing
                              ? 'Save Changes'
                              : 'Create Account'),
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
