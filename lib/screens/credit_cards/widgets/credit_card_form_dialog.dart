import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../theme/app_theme.dart';

class CreditCardFormDialog extends StatefulWidget {
  final CreditCard? card;
  final CreditCardRepository repository;

  const CreditCardFormDialog({
    super.key,
    this.card,
    required this.repository,
  });

  bool get isEditing => card != null;

  @override
  State<CreditCardFormDialog> createState() => _CreditCardFormDialogState();
}

class _CreditCardFormDialogState extends State<CreditCardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _lastFourController;
  late TextEditingController _limitController;
  late TextEditingController _outstandingController;
  late TextEditingController _billingCycleController;
  late TextEditingController _paymentDueController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _nameController = TextEditingController(text: card?.name ?? '');
    _lastFourController =
        TextEditingController(text: card?.lastFourDigits ?? '');
    _limitController = TextEditingController(
      text: card != null
          ? card.creditLimit.toStringAsFixed(card.creditLimit % 1 == 0 ? 0 : 2)
          : '',
    );
    _outstandingController = TextEditingController(
      text: card != null
          ? card.outstandingBalance
              .toStringAsFixed(card.outstandingBalance % 1 == 0 ? 0 : 2)
          : '0',
    );
    _billingCycleController = TextEditingController(
      text: card?.billingCycleDay != null
          ? card!.billingCycleDay.toString()
          : '',
    );
    _paymentDueController = TextEditingController(
      text: card?.paymentDueDay != null ? card!.paymentDueDay.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastFourController.dispose();
    _limitController.dispose();
    _outstandingController.dispose();
    _billingCycleController.dispose();
    _paymentDueController.dispose();
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
      final name = _nameController.text.trim();
      final lastFour = _lastFourController.text.trim();
      final limit = double.parse(_limitController.text.trim());
      final billingDay = _billingCycleController.text.trim().isNotEmpty
          ? int.parse(_billingCycleController.text.trim())
          : null;
      final dueDay = _paymentDueController.text.trim().isNotEmpty
          ? int.parse(_paymentDueController.text.trim())
          : null;

      if (widget.isEditing) {
        await widget.repository.updateCreditCard(
          id: widget.card!.id,
          name: name,
          lastFourDigits: lastFour,
          creditLimit: limit,
          billingCycleDay: billingDay,
          paymentDueDay: dueDay,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credit card updated successfully')),
          );
        }
      } else {
        final outstandingText = _outstandingController.text.trim();
        final outstanding =
            outstandingText.isNotEmpty ? double.parse(outstandingText) : 0.0;

        await widget.repository.createCreditCard(
          name: name,
          lastFourDigits: lastFour,
          creditLimit: limit,
          outstandingBalance: outstanding,
          billingCycleDay: billingDay,
          paymentDueDay: dueDay,
        );
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credit card added successfully')),
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
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEditing
                                ? 'Edit Credit Card'
                                : 'Add Credit Card',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            widget.isEditing
                                ? 'Update card details & limit'
                                : 'Track card liability & limits',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Card Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Card Name',
                    hintText: 'e.g. HDFC Millennia',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Card name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Last 4 Digits Field
                TextFormField(
                  controller: _lastFourController,
                  decoration: const InputDecoration(
                    labelText: 'Last 4 Digits',
                    hintText: '1234',
                    prefixIcon: Icon(Icons.pin_outlined),
                    prefixText: '•••• ',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Last 4 digits are required';
                    }
                    if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                      return 'Must be exactly 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Credit Limit Field
                TextFormField(
                  controller: _limitController,
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit (₹)',
                    hintText: '100000',
                    prefixIcon: Icon(Icons.credit_score_outlined),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Credit limit is required';
                    }
                    final limit = double.tryParse(value.trim());
                    if (limit == null || limit <= 0) {
                      return 'Credit limit must be greater than zero';
                    }
                    if (widget.isEditing &&
                        limit < widget.card!.outstandingBalance) {
                      return 'Limit cannot be less than outstanding balance (${CurrencyFormatter.format(widget.card!.outstandingBalance)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Initial Outstanding Balance Field (Only on Create)
                if (!widget.isEditing) ...[
                  TextFormField(
                    controller: _outstandingController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Outstanding Balance (₹)',
                      hintText: '0',
                      prefixIcon: Icon(Icons.receipt_long_outlined),
                      helperText: 'Existing debt before tracking in this app',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return null; // Defaults to 0
                      }
                      final outstanding = double.tryParse(value.trim());
                      if (outstanding == null || outstanding < 0) {
                        return 'Outstanding balance cannot be negative';
                      }
                      final limit =
                          double.tryParse(_limitController.text.trim()) ?? 0.0;
                      if (limit > 0 && outstanding > limit) {
                        return 'Outstanding balance cannot exceed credit limit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  // In Edit mode: Display read-only current outstanding balance
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Outstanding:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                              widget.card!.outstandingBalance),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Billing Cycle Day & Payment Due Day Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _billingCycleController,
                        decoration: const InputDecoration(
                          labelText: 'Bill Cycle Day',
                          hintText: '1–31',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final day = int.tryParse(value.trim());
                          if (day == null || day < 1 || day > 31) {
                            return 'Day 1–31';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _paymentDueController,
                        decoration: const InputDecoration(
                          labelText: 'Payment Due Day',
                          hintText: '1–31',
                          prefixIcon: Icon(Icons.event_available_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final day = int.tryParse(value.trim());
                          if (day == null || day < 1 || day > 31) {
                            return 'Day 1–31';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEditing ? 'Save Card' : 'Add Card',
                            ),
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
