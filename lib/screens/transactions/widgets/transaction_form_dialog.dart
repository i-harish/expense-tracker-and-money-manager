import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/credit_card_extensions.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/services/financial_service.dart';
import '../../../theme/app_theme.dart';

class TransactionFormDialog extends StatefulWidget {
  final FinancialService financialService;
  final AccountRepository accountRepository;
  final CreditCardRepository? creditCardRepository;
  final TransactionType? initialType;
  final int? initialCreditCardId;
  final int? initialAccountId;

  const TransactionFormDialog({
    super.key,
    required this.financialService,
    required this.accountRepository,
    this.creditCardRepository,
    this.initialType,
    this.initialCreditCardId,
    this.initialAccountId,
  });

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late final CreditCardRepository _creditCardRepository;

  late TransactionType _selectedType;
  int? _selectedAccountId;
  int? _selectedCreditCardId;
  DateTime _selectedDate = DateTime.now();

  List<Account> _activeAccounts = [];
  List<CreditCard> _activeCreditCards = [];
  bool _isLoadingAccounts = true;
  bool _isLoadingCards = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TransactionType.expense;
    _selectedAccountId = widget.initialAccountId;
    _selectedCreditCardId = widget.initialCreditCardId;
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _creditCardRepository = widget.creditCardRepository ??
        DriftCreditCardRepository(AppDatabase.instance);
    _loadAccounts();
    _loadCreditCards();
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
          if (_selectedAccountId == null && accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
          } else if (_selectedAccountId != null &&
              !accounts.any((a) => a.id == _selectedAccountId) &&
              accounts.isNotEmpty) {
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

  Future<void> _loadCreditCards() async {
    try {
      final cards = await _creditCardRepository.getActiveCreditCards();
      if (mounted) {
        setState(() {
          _activeCreditCards = cards;
          if (_selectedCreditCardId == null && cards.isNotEmpty) {
            _selectedCreditCardId = cards.first.id;
          } else if (_selectedCreditCardId != null &&
              !cards.any((c) => c.id == _selectedCreditCardId) &&
              cards.isNotEmpty) {
            _selectedCreditCardId = cards.first.id;
          }
          _isLoadingCards = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCards = false;
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

    if (_selectedType == TransactionType.creditCardPurchase) {
      if (_selectedCreditCardId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a credit card'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    } else if (_selectedType == TransactionType.creditCardPayment) {
      if (_selectedCreditCardId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a credit card'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select a source account'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    } else {
      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select an account'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
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
      } else if (_selectedType == TransactionType.expense) {
        await widget.financialService.recordExpense(
          accountId: _selectedAccountId!,
          amount: amount,
          description: description.isEmpty ? null : description,
          transactionDate: _selectedDate,
        );
      } else if (_selectedType == TransactionType.creditCardPurchase) {
        await widget.financialService.recordCreditCardPurchase(
          creditCardId: _selectedCreditCardId!,
          amount: amount,
          description: description.isEmpty ? null : description,
          transactionDate: _selectedDate,
        );
      } else if (_selectedType == TransactionType.creditCardPayment) {
        await widget.financialService.recordCreditCardPayment(
          creditCardId: _selectedCreditCardId!,
          sourceAccountId: _selectedAccountId!,
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
                  : _selectedType == TransactionType.expense
                      ? 'Expense recorded successfully'
                      : _selectedType == TransactionType.creditCardPurchase
                          ? 'Credit card purchase recorded successfully'
                          : 'Credit card bill payment recorded successfully',
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
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.arrow_downward,
                          size: 14, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.arrow_upward,
                          size: 14, color: Color(0xFF16A34A)),
                    ),
                    ButtonSegment(
                      value: TransactionType.creditCardPurchase,
                      label: Text('Card', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.credit_card,
                          size: 14, color: AppTheme.secondaryColor),
                    ),
                    ButtonSegment(
                      value: TransactionType.creditCardPayment,
                      label: Text('Bill Pay', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.payments_outlined,
                          size: 14, color: Color(0xFF2563EB)),
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

                // Dynamic Form Selectors
                if (_selectedType == TransactionType.creditCardPayment) ...[
                  // 1. Credit Card selector
                  const Text(
                    'Credit Card',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingCards)
                    const Center(child: CircularProgressIndicator())
                  else if (_activeCreditCards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Text(
                        'No active credit cards found. Please add a credit card first.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCreditCardId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      items: _activeCreditCards.map((card) {
                        return DropdownMenuItem<int>(
                          value: card.id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${card.name} ****${card.lastFourDigits}'),
                              const SizedBox(width: 8),
                              Text(
                                '(Due: ${CurrencyFormatter.format(card.outstandingBalance)})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: card.outstandingBalance > 0
                                      ? Colors.red.shade700
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCreditCardId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Credit card is required';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // 2. Pay From Account selector
                  const Text(
                    'Pay From',
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
                        'No active asset accounts found. Please add an account first.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF92400E)),
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
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
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
                          return 'Source account is required';
                        }
                        return null;
                      },
                    ),
                ] else if (_selectedType == TransactionType.creditCardPurchase) ...[
                  const Text(
                    'Credit Card',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingCards)
                    const Center(child: CircularProgressIndicator())
                  else if (_activeCreditCards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Text(
                        'No active credit cards found. Please add a credit card first.',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCreditCardId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 2),
                        ),
                      ),
                      items: _activeCreditCards.map((card) {
                        return DropdownMenuItem<int>(
                          value: card.id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${card.name} ****${card.lastFourDigits}'),
                              const SizedBox(width: 8),
                              Text(
                                '(Avail: ${CurrencyFormatter.format(card.availableCredit)})',
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
                          _selectedCreditCardId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Credit card is required';
                        }
                        return null;
                      },
                    ),
                ] else ...[
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
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF92400E)),
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
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
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
                ],
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
                      return 'Enter a valid amount';
                    }
                    if (parsed <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    if (_selectedType == TransactionType.creditCardPurchase &&
                        _selectedCreditCardId != null) {
                      final card = _activeCreditCards
                          .where((c) => c.id == _selectedCreditCardId)
                          .firstOrNull;
                      if (card != null && parsed > card.availableCredit) {
                        return 'Insufficient available credit';
                      }
                    }
                    if (_selectedType == TransactionType.creditCardPayment) {
                      if (_selectedCreditCardId != null) {
                        final card = _activeCreditCards
                            .where((c) => c.id == _selectedCreditCardId)
                            .firstOrNull;
                        if (card != null) {
                          if (card.outstandingBalance <= 0) {
                            return 'No outstanding balance';
                          }
                          if (parsed > card.outstandingBalance) {
                            return 'Payment exceeds outstanding balance';
                          }
                        }
                      }
                      if (_selectedAccountId != null) {
                        final account = _activeAccounts
                            .where((a) => a.id == _selectedAccountId)
                            .firstOrNull;
                        if (account != null && parsed > account.balance) {
                          return 'Insufficient account balance';
                        }
                      }
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
                    hintText: _selectedType == TransactionType.creditCardPayment
                        ? 'Credit Card Bill'
                        : 'e.g. Salary, Groceries, Electricity Bill',
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
                          : Text(
                              _selectedType == TransactionType.creditCardPayment
                                  ? 'Make Payment'
                                  : 'Save Transaction',
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

